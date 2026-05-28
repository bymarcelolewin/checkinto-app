-- Migration: v1.6.0-event-voting
-- Description: Per-event polls that checked-in attendees vote on. Adds four
--              new tables (poll, poll_item, poll_winner_label, poll_vote),
--              two helper functions, and tightens access so all reads/writes
--              go through SECURITY DEFINER functions.
-- Date: 2026-05-27
--
-- This migration runs as a single transaction. If any step fails, the entire
-- migration rolls back and no data is lost.
--
-- Order matters (no inter-table data already exists, so the constraints are
-- the only real dependency):
--   1. Create poll                  (FK → event, community)
--   2. Create poll_item             (FK → poll)
--   3. Create poll_winner_label     (FK → poll, composite PK (poll_id, rank))
--   4. Create poll_vote             (FK → poll, attendee, poll_item;
--                                    composite PK (poll_id, attendee_id))
--   5. CREATE INDEXes
--   6. Enable RLS on all four tables. No anon policies — anon has no direct
--      access. Function-only path.
--   7. GRANTs: authenticated + service_role get full; anon gets NOTHING.
--   8. Install submit_vote() function.
--   9. Install get_polls_for_event() function.
--
-- Access model:
--   - anon does NOT have direct SELECT/INSERT/UPDATE/DELETE on any of the
--     four new tables. All reads go through get_polls_for_event(); all
--     writes go through submit_vote(). This is by design — exposing
--     poll_vote to anon would leak who voted for what.
--   - Both functions are SECURITY DEFINER with search_path locked to
--     public, pg_temp. Both grant EXECUTE to anon and authenticated.
--
-- Visibility model:
--   - poll.active controls whether the poll is visible to attendees at all
--     (admin uses active=false while drafting items + labels).
--   - poll.status (open|closed) controls whether attendees see the ballot
--     or the ranked results once the poll is visible.
--
-- To apply: paste this entire file into the Supabase SQL editor and run.
-- To roll back: run v1.6.0-event-voting-rollback.sql.

BEGIN;

-- ============================================================================
-- 1. Create poll
--    community_id is denormalized from event.community_id (must be inserted
--    consistent with event.community_id). It exists so future community-
--    admin RLS policies can scope by community without JOINing through event.
-- ============================================================================
CREATE TABLE public.poll (
    id                uuid NOT NULL DEFAULT gen_random_uuid(),
    event_id          uuid NOT NULL,
    community_id      uuid NOT NULL,
    title             text NOT NULL,
    active            boolean NOT NULL DEFAULT false,
    status            text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
    top_n_winners     integer NOT NULL DEFAULT 3 CHECK (top_n_winners > 0),
    show_vote_count   boolean NOT NULL DEFAULT false,
    thanks_message    text NOT NULL DEFAULT 'Thanks for voting. Stay tuned for the winners.',
    closed_message    text NOT NULL DEFAULT 'Voting has closed.',
    no_votes_message  text NOT NULL DEFAULT 'No votes were recorded for this poll.',
    display_order     integer NOT NULL DEFAULT 0,
    created_at        timestamp with time zone NOT NULL DEFAULT now(),
    updated_at        timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT poll_pkey PRIMARY KEY (id),
    CONSTRAINT fk_poll_event
        FOREIGN KEY (event_id) REFERENCES public.event(id) ON DELETE CASCADE,
    CONSTRAINT fk_poll_community
        FOREIGN KEY (community_id) REFERENCES public.community(id)
);

COMMENT ON TABLE public.poll IS
    'Per-event poll. active controls visibility to attendees; status controls open/closed voting state. '
    'community_id is denormalized from event.community_id and must be set consistent with it.';

-- ============================================================================
-- 2. Create poll_item — the choices on a poll's ballot
-- ============================================================================
CREATE TABLE public.poll_item (
    id             uuid NOT NULL DEFAULT gen_random_uuid(),
    poll_id        uuid NOT NULL,
    name           text NOT NULL,
    display_order  integer NOT NULL DEFAULT 0,
    created_at     timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT poll_item_pkey PRIMARY KEY (id),
    CONSTRAINT fk_poll_item_poll
        FOREIGN KEY (poll_id) REFERENCES public.poll(id) ON DELETE CASCADE
);

COMMENT ON TABLE public.poll_item IS
    'Free-text ballot items belonging to a poll. Ordered for display by display_order, then name.';

-- ============================================================================
-- 3. Create poll_winner_label — optional per-rank labels for results display
--    Composite PK (poll_id, rank) guarantees at most one label per rank per
--    poll. Multiple ranks may share the same label text (e.g., ranks 4 and 5
--    both labeled "Honorable Mention"). Zero rows for a poll means the UI
--    falls back to client-rendered ordinal defaults ("1st Place", etc.).
-- ============================================================================
CREATE TABLE public.poll_winner_label (
    poll_id     uuid NOT NULL,
    rank        integer NOT NULL CHECK (rank > 0),
    label       text NOT NULL,
    created_at  timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT poll_winner_label_pkey PRIMARY KEY (poll_id, rank),
    CONSTRAINT fk_poll_winner_label_poll
        FOREIGN KEY (poll_id) REFERENCES public.poll(id) ON DELETE CASCADE
);

COMMENT ON TABLE public.poll_winner_label IS
    'Optional per-rank custom labels for a poll''s closed-results display. '
    'Missing ranks fall back to client-side ordinal defaults.';

-- ============================================================================
-- 4. Create poll_vote — one row per (poll, attendee)
--    Composite PK (poll_id, attendee_id) is the single-vote-per-attendee
--    enforcement. submit_vote() does ON CONFLICT DO UPDATE so re-submitting
--    a vote replaces the prior choice (the "change your vote" affordance).
-- ============================================================================
CREATE TABLE public.poll_vote (
    poll_id       uuid NOT NULL,
    attendee_id   uuid NOT NULL,
    poll_item_id  uuid NOT NULL,
    created_at    timestamp with time zone NOT NULL DEFAULT now(),
    updated_at    timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT poll_vote_pkey PRIMARY KEY (poll_id, attendee_id),
    CONSTRAINT fk_poll_vote_poll
        FOREIGN KEY (poll_id) REFERENCES public.poll(id) ON DELETE CASCADE,
    CONSTRAINT fk_poll_vote_attendee
        FOREIGN KEY (attendee_id) REFERENCES public.attendee(id),
    CONSTRAINT fk_poll_vote_item
        FOREIGN KEY (poll_item_id) REFERENCES public.poll_item(id) ON DELETE CASCADE
);

COMMENT ON TABLE public.poll_vote IS
    'One row per (poll, attendee). Function-only access — never exposed to anon. '
    'submit_vote() upserts on the composite PK so change-vote is just a re-call.';

-- ============================================================================
-- 5. CREATE INDEXes
--    The composite PKs already cover lookups by their leading columns.
--    These extra indexes support the access patterns:
--      - filter polls by event_id (get_polls_for_event)
--      - filter polls by community_id (future community-admin queries)
--      - filter items by poll_id (ballot rendering)
--      - count votes per item (results query)
-- ============================================================================
CREATE INDEX idx_poll_event_id      ON public.poll(event_id);
CREATE INDEX idx_poll_community_id  ON public.poll(community_id);
CREATE INDEX idx_poll_item_poll_id  ON public.poll_item(poll_id);
CREATE INDEX idx_poll_vote_item_id  ON public.poll_vote(poll_item_id);

-- ============================================================================
-- 6. Enable RLS on all four tables. Defense in depth — the lack of anon
--    grants is the primary block, but RLS ensures any accidental future
--    grant doesn't open a hole.
-- ============================================================================
ALTER TABLE public.poll              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_item         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_winner_label ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_vote         ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 7. GRANTs. No anon access to any of the four tables — all reads go
--    through get_polls_for_event(), all writes through submit_vote().
-- ============================================================================
REVOKE ALL ON public.poll              FROM anon;
REVOKE ALL ON public.poll_item         FROM anon;
REVOKE ALL ON public.poll_winner_label FROM anon;
REVOKE ALL ON public.poll_vote         FROM anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.poll              TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.poll              TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.poll_item         TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.poll_item         TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.poll_winner_label TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.poll_winner_label TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.poll_vote         TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.poll_vote         TO service_role;

-- ============================================================================
-- 8. Install submit_vote() function. Canonical copy lives at
--    database/functions/submit-vote.sql.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.submit_vote(
    p_poll_id       uuid,
    p_poll_item_id  uuid,
    p_attendee_id   uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_event_id  uuid;
BEGIN
    IF p_poll_id IS NULL OR p_poll_item_id IS NULL OR p_attendee_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'All fields are required');
    END IF;

    -- Poll must exist, be active, and be open. We collapse missing / inactive /
    -- closed into one error code so the client can't distinguish which case
    -- applies (avoids leaking info about hidden polls).
    SELECT event_id INTO v_event_id
    FROM poll
    WHERE id = p_poll_id AND active = true AND status = 'open';

    IF v_event_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'poll_unavailable');
    END IF;

    -- Item must belong to this poll.
    IF NOT EXISTS (SELECT 1 FROM poll_item WHERE id = p_poll_item_id AND poll_id = p_poll_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'invalid_item');
    END IF;

    -- Attendee must be checked into the poll's event.
    IF NOT EXISTS (SELECT 1 FROM event_attendee WHERE event_id = v_event_id AND attendee_id = p_attendee_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'not_checked_in');
    END IF;

    -- Upsert the vote — change-vote is just a re-call.
    INSERT INTO poll_vote (poll_id, attendee_id, poll_item_id)
    VALUES (p_poll_id, p_attendee_id, p_poll_item_id)
    ON CONFLICT (poll_id, attendee_id) DO UPDATE
        SET poll_item_id = EXCLUDED.poll_item_id,
            updated_at   = now();

    RETURN jsonb_build_object(
        'success',      true,
        'poll_item_id', p_poll_item_id
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.submit_vote(uuid, uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.submit_vote(uuid, uuid, uuid) TO anon, authenticated;

-- ============================================================================
-- 9. Install get_polls_for_event() function. Canonical copy lives at
--    database/functions/get-polls-for-event.sql.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_polls_for_event(
    p_event_id     uuid,
    p_attendee_id  uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_polls jsonb;
BEGIN
    IF p_event_id IS NULL OR p_attendee_id IS NULL THEN
        RETURN jsonb_build_object('polls', '[]'::jsonb);
    END IF;

    -- Caller must be checked into the requested event. Otherwise return
    -- empty polls — graceful degradation; the UI shouldn't be calling this
    -- for non-checked-in users anyway.
    IF NOT EXISTS (SELECT 1 FROM event_attendee
                   WHERE event_id = p_event_id AND attendee_id = p_attendee_id) THEN
        RETURN jsonb_build_object('polls', '[]'::jsonb);
    END IF;

    SELECT COALESCE(jsonb_agg(poll_obj ORDER BY display_order, created_at), '[]'::jsonb)
      INTO v_polls
    FROM (
        SELECT
            p.id,
            p.display_order,
            p.created_at,
            jsonb_build_object(
                'id',                p.id,
                'title',             p.title,
                'status',            p.status,
                'top_n_winners',     p.top_n_winners,
                'show_vote_count',   p.show_vote_count,
                'thanks_message',    p.thanks_message,
                'closed_message',    p.closed_message,
                'no_votes_message',  p.no_votes_message,
                'display_order',     p.display_order,
                'items',             COALESCE((
                    SELECT jsonb_agg(jsonb_build_object(
                        'id',            pi.id,
                        'name',          pi.name,
                        'display_order', pi.display_order
                    ) ORDER BY pi.display_order, pi.name)
                    FROM poll_item pi
                    WHERE pi.poll_id = p.id
                ), '[]'::jsonb),
                'my_vote_item_id', (
                    SELECT pv.poll_item_id
                    FROM poll_vote pv
                    WHERE pv.poll_id = p.id AND pv.attendee_id = p_attendee_id
                ),
                'winner_labels', COALESCE((
                    SELECT jsonb_object_agg(pwl.rank::text, pwl.label)
                    FROM poll_winner_label pwl
                    WHERE pwl.poll_id = p.id
                ), '{}'::jsonb),
                'results',
                CASE WHEN p.status = 'closed' THEN COALESCE((
                    SELECT jsonb_agg(jsonb_build_object(
                        'poll_item_id', r.poll_item_id,
                        'name',         r.name,
                        'vote_count',   r.vote_count,
                        'rank',         r.rank,
                        'is_my_vote',   r.is_my_vote
                    ) ORDER BY r.rank, r.display_order, r.name)
                    FROM (
                        SELECT
                            pi.id            AS poll_item_id,
                            pi.name,
                            pi.display_order,
                            COUNT(pv.attendee_id)::int AS vote_count,
                            RANK() OVER (ORDER BY COUNT(pv.attendee_id) DESC) AS rank,
                            COALESCE(BOOL_OR(pv.attendee_id = p_attendee_id), false) AS is_my_vote
                        FROM poll_item pi
                        LEFT JOIN poll_vote pv ON pv.poll_item_id = pi.id
                        WHERE pi.poll_id = p.id
                        GROUP BY pi.id, pi.name, pi.display_order
                    ) r
                    WHERE r.rank <= p.top_n_winners AND r.vote_count > 0
                ), '[]'::jsonb)
                ELSE NULL END
            ) AS poll_obj
        FROM poll p
        WHERE p.event_id = p_event_id AND p.active = true
    ) sub;

    RETURN jsonb_build_object('polls', v_polls);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_polls_for_event(uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_polls_for_event(uuid, uuid) TO anon, authenticated;

COMMIT;
