-- Function: Check-In Attendee
-- Version: v1.5.0-per-event-interesting-fact
-- Description: Atomic, validated check-in flow callable by the anon role.
--              Stores per-event interesting_fact on event_attendee.
-- Usage: SELECT check_in_attendee(p_email, p_first_name, p_last_name, p_interesting_fact, p_event_id);
--
-- Security model:
--   - SECURITY DEFINER runs the function as the owner (postgres), so it can
--     write to attendee / community_attendee / event_attendee even though
--     anon has no direct GRANTs on those tables.
--   - SET search_path = public, pg_temp prevents search-path injection.
--   - All inputs are validated server-side before any writes.
--
-- Return shape (jsonb):
--   Success:  { "success": true,  "already_checked_in": <bool>, "attendee_id": "<uuid>" }
--   Failure:  { "success": false, "error": "<human readable message>" }

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
    -- ------------------------------------------------------------------------
    -- Input validation (mirrors VALIDATION_RULES in src/lib/types.ts)
    -- ------------------------------------------------------------------------
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

    -- ------------------------------------------------------------------------
    -- Resolve event → community. Reject if event is missing or inactive.
    -- ------------------------------------------------------------------------
    SELECT community_id INTO v_community_id
    FROM event
    WHERE id = p_event_id AND active = true;

    IF v_community_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Event not found or inactive');
    END IF;

    -- ------------------------------------------------------------------------
    -- Upsert attendee by email (global identity). interesting_fact is no
    -- longer stored here as of v1.5.0; it lives on event_attendee.
    -- ------------------------------------------------------------------------
    INSERT INTO attendee (email, first_name, last_name)
    VALUES (v_email, v_first_name, v_last_name)
    ON CONFLICT (email) DO UPDATE
        SET first_name = EXCLUDED.first_name,
            last_name  = EXCLUDED.last_name,
            updated_at = now()
    RETURNING id INTO v_attendee_id;

    -- ------------------------------------------------------------------------
    -- Ensure community_attendee link exists.
    -- ------------------------------------------------------------------------
    INSERT INTO community_attendee (attendee_id, community_id)
    VALUES (v_attendee_id, v_community_id)
    ON CONFLICT (attendee_id, community_id) DO NOTHING;

    -- ------------------------------------------------------------------------
    -- Insert (or update) event_attendee with the per-event interesting_fact.
    -- DO UPDATE lets a returning user fix a typo on their fact for this
    -- event. xmax = 0 distinguishes "row was inserted" from "row was
    -- updated" so we can return already_checked_in accurately.
    -- ------------------------------------------------------------------------
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

-- Grant execute permission to anon and authenticated.
-- service_role and the owner can call it directly without an explicit grant.
GRANT EXECUTE ON FUNCTION public.check_in_attendee(text, text, text, text, uuid) TO anon, authenticated;

-- Revoke from PUBLIC so only the explicitly granted roles can call it.
REVOKE EXECUTE ON FUNCTION public.check_in_attendee(text, text, text, text, uuid) FROM PUBLIC;
