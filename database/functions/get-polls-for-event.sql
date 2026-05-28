-- Function: Get Polls For Event
-- Version: v1.6.0-event-voting
-- Description: Returns the entire polls payload for an event in one round
--              trip. Used by PollsInbox and PollPopup to drive the UI.
-- Usage: SELECT get_polls_for_event(p_event_id, p_attendee_id);
--
-- Security model:
--   - SECURITY DEFINER runs the function as the owner (postgres), so it can
--     read poll/poll_item/poll_winner_label/poll_vote even though anon has
--     no direct GRANTs on those tables.
--   - SET search_path = public, pg_temp prevents search-path injection.
--   - Visibility rules enforced inside the function:
--       1. Caller (attendee) must be checked into the requested event.
--          Otherwise returns { polls: [] } — graceful degradation.
--       2. Only polls where event_id = p_event_id AND active = true are
--          returned. Inactive polls and polls from other events are
--          invisible.
--       3. Closed polls are still returned (active=true, status='closed') so
--          attendees can see results. active controls visibility; status
--          controls whether voting is open.
--
-- Return shape (jsonb):
--   {
--     "polls": [
--       {
--         "id": "<uuid>",
--         "title": "<text>",
--         "status": "open" | "closed",
--         "top_n_winners": <int>,
--         "show_vote_count": <bool>,
--         "thanks_message": "<text>",
--         "closed_message": "<text>",
--         "no_votes_message": "<text>",
--         "display_order": <int>,
--         "items": [{ "id", "name", "display_order" }, ...],
--         "my_vote_item_id": "<uuid>" | null,
--         "winner_labels": { "<rank>": "<label>", ... },
--         "results": [{ "poll_item_id", "name", "vote_count", "rank", "is_my_vote" }, ...] | null
--       }
--     ]
--   }
--
-- Ranking semantics:
--   - results is null when status='open'.
--   - When closed, results uses RANK() OVER (ORDER BY COUNT DESC) so ties
--     get the same rank and the next rank skips (competition ranking).
--   - Items at the cutoff are all included even if ties push the count past
--     top_n_winners (e.g., 3-way tie for 2nd with top_n=3 returns 4 items).

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

    -- Caller must be checked into the event.
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

-- Grant execute permission to anon and authenticated.
-- service_role and the owner can call it directly without an explicit grant.
GRANT EXECUTE ON FUNCTION public.get_polls_for_event(uuid, uuid) TO anon, authenticated;

-- Revoke from PUBLIC so only the explicitly granted roles can call it.
REVOKE EXECUTE ON FUNCTION public.get_polls_for_event(uuid, uuid) FROM PUBLIC;
