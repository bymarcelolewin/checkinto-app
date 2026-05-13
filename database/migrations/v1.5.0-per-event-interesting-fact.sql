-- Migration: v1.5.0-per-event-interesting-fact
-- Description: Move interesting_fact from the global attendee row to the
--              per-event event_attendee link. Each check-in now records its
--              own fact for that specific gathering.
-- Date: 2026-05-13
--
-- This migration runs as a single transaction. If any step fails, the entire
-- migration rolls back and no data is lost.
--
-- Order matters:
--   1. Add nullable event_attendee.interesting_fact column.
--   2. Backfill from attendee.interesting_fact (joined on attendee_id).
--   3. Defensive NULL check (raises if backfill was incomplete).
--   4. Set event_attendee.interesting_fact NOT NULL.
--   5. Drop attendee.interesting_fact.
--   6. Replace check_in_attendee() with the v1.5.0 body.
--
-- To apply: paste this entire file into the Supabase SQL editor and run.
-- To roll back: run v1.5.0-per-event-interesting-fact-rollback.sql.

BEGIN;

-- ============================================================================
-- 1. Add the column to event_attendee (nullable for backfill)
-- ============================================================================
ALTER TABLE public.event_attendee
    ADD COLUMN interesting_fact text;

-- ============================================================================
-- 2. Backfill from attendee.interesting_fact
--    Each event_attendee row inherits the current single fact stored on its
--    attendee. Since each attendee has exactly one fact today, this preserves
--    the displayed state for every existing check-in. Per-event divergence
--    begins with the first check-in after this migration.
-- ============================================================================
UPDATE public.event_attendee ea
SET interesting_fact = a.interesting_fact
FROM public.attendee a
WHERE ea.attendee_id = a.id;

-- ============================================================================
-- 3. Defensive check: every event_attendee row must have a non-null fact
--    before we can apply NOT NULL. The FK from event_attendee.attendee_id to
--    attendee.id guarantees the join matches, so the only way this fails is
--    if some attendee.interesting_fact was NULL — which the current schema
--    prohibits. Belt and suspenders.
-- ============================================================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.event_attendee WHERE interesting_fact IS NULL) THEN
        RAISE EXCEPTION 'v1.5.0 backfill incomplete: % event_attendee rows still have NULL interesting_fact',
            (SELECT count(*) FROM public.event_attendee WHERE interesting_fact IS NULL);
    END IF;
END;
$$;

-- ============================================================================
-- 4. Set event_attendee.interesting_fact NOT NULL
-- ============================================================================
ALTER TABLE public.event_attendee
    ALTER COLUMN interesting_fact SET NOT NULL;

-- ============================================================================
-- 5. Drop attendee.interesting_fact
-- ============================================================================
ALTER TABLE public.attendee
    DROP COLUMN interesting_fact;

-- ============================================================================
-- 6. Replace check_in_attendee() with the v1.5.0 body (canonical copy lives
--    at database/functions/check-in-attendee.sql)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.check_in_attendee(
    p_email            text,
    p_first_name       text,
    p_last_name        text,
    p_interesting_fact text,
    p_event_id         uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_email            text;
    v_first_name       text;
    v_last_name        text;
    v_interesting_fact text;
    v_community_id     uuid;
    v_attendee_id      uuid;
    v_was_inserted     boolean;
BEGIN
    IF p_email IS NULL OR p_first_name IS NULL OR p_last_name IS NULL
       OR p_interesting_fact IS NULL OR p_event_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'All fields are required');
    END IF;

    v_email            := btrim(p_email);
    v_first_name       := btrim(p_first_name);
    v_last_name        := btrim(p_last_name);
    v_interesting_fact := btrim(p_interesting_fact);

    IF char_length(v_first_name) < 1 OR char_length(v_first_name) > 50 THEN
        RETURN jsonb_build_object('success', false, 'error', 'First name must be 1-50 characters');
    END IF;

    IF char_length(v_last_name) < 1 OR char_length(v_last_name) > 50 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Last name must be 1-50 characters');
    END IF;

    IF char_length(v_email) < 1 OR char_length(v_email) > 254
       OR v_email !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Please enter a valid email address');
    END IF;

    IF char_length(v_interesting_fact) < 1 OR char_length(v_interesting_fact) > 255 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Interesting fact must be 1-255 characters');
    END IF;

    SELECT community_id INTO v_community_id
    FROM event
    WHERE id = p_event_id AND active = true;

    IF v_community_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Event not found or inactive');
    END IF;

    INSERT INTO attendee (email, first_name, last_name)
    VALUES (v_email, v_first_name, v_last_name)
    ON CONFLICT (email) DO UPDATE
        SET first_name = EXCLUDED.first_name,
            last_name  = EXCLUDED.last_name,
            updated_at = now()
    RETURNING id INTO v_attendee_id;

    INSERT INTO community_attendee (attendee_id, community_id)
    VALUES (v_attendee_id, v_community_id)
    ON CONFLICT (attendee_id, community_id) DO NOTHING;

    WITH upserted AS (
        INSERT INTO event_attendee (event_id, attendee_id, interesting_fact)
        VALUES (p_event_id, v_attendee_id, v_interesting_fact)
        ON CONFLICT (event_id, attendee_id) DO UPDATE
            SET interesting_fact = EXCLUDED.interesting_fact
        RETURNING (xmax = 0) AS was_inserted
    )
    SELECT was_inserted INTO v_was_inserted FROM upserted;

    RETURN jsonb_build_object(
        'success',            true,
        'already_checked_in', NOT v_was_inserted,
        'attendee_id',        v_attendee_id
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_in_attendee(text, text, text, text, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.check_in_attendee(text, text, text, text, uuid) TO anon, authenticated;

COMMIT;
