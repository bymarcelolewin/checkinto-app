-- Function: Submit Vote
-- Version: v1.6.0-event-voting
-- Description: Atomic, validated vote submission for an attendee on a poll.
--              Same function handles initial votes and change-vote (via
--              ON CONFLICT DO UPDATE on the (poll_id, attendee_id) PK).
-- Usage: SELECT submit_vote(p_poll_id, p_poll_item_id, p_attendee_id);
--
-- Security model:
--   - SECURITY DEFINER runs the function as the owner (postgres), so it can
--     write to poll_vote even though anon has no direct GRANTs on the table.
--   - SET search_path = public, pg_temp prevents search-path injection.
--   - Three validation checks run server-side before the upsert:
--       1. Poll exists, is active, and is open. (Single collapsed error so
--          the client cannot distinguish missing / inactive / closed —
--          avoids leaking the existence of hidden polls.)
--       2. The item belongs to this poll.
--       3. The caller (attendee) is checked into the poll's event.
--
-- Return shape (jsonb):
--   Success:  { "success": true,  "poll_item_id": "<uuid>" }
--   Failure:  { "success": false, "error": "<error code>" }
--     Error codes: poll_unavailable | invalid_item | not_checked_in
--                  | All fields are required

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

    -- Poll must exist, be active, and be open.
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

    -- Upsert. ON CONFLICT DO UPDATE so change-vote is a re-call with no
    -- separate API.
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

-- Grant execute permission to anon and authenticated.
-- service_role and the owner can call it directly without an explicit grant.
GRANT EXECUTE ON FUNCTION public.submit_vote(uuid, uuid, uuid) TO anon, authenticated;

-- Revoke from PUBLIC so only the explicitly granted roles can call it.
REVOKE EXECUTE ON FUNCTION public.submit_vote(uuid, uuid, uuid) FROM PUBLIC;
