-- Rollback: v1.5.0-per-event-interesting-fact
-- Description: Reverses v1.5.0. Restores attendee.interesting_fact (backfilled
--              from the earliest event_attendee row per attendee), restores
--              the v1.4.0 function body, and drops event_attendee.interesting_fact.
-- Date: 2026-05-13
--
-- This rollback runs as a single transaction. If any step fails, the entire
-- rollback is undone and no data is lost.
--
-- LOSSY: per-event interesting_fact divergence collapses back to a single
-- value per attendee (the fact from their earliest event_attendee row).
--
-- To apply: paste this entire file into the Supabase SQL editor and run.

BEGIN;

-- ============================================================================
-- 1. Re-add attendee.interesting_fact (nullable for backfill)
-- ============================================================================
ALTER TABLE public.attendee
    ADD COLUMN interesting_fact text;

-- ============================================================================
-- 2. Backfill attendee.interesting_fact from each attendee's earliest
--    event_attendee row (deterministic, single value per attendee).
-- ============================================================================
UPDATE public.attendee a
SET interesting_fact = ea.interesting_fact
FROM (
    SELECT DISTINCT ON (attendee_id)
        attendee_id,
        interesting_fact
    FROM public.event_attendee
    ORDER BY attendee_id, created_at ASC
) ea
WHERE a.id = ea.attendee_id;

-- ============================================================================
-- 3. Defensive check: every attendee must have a non-null fact before we
--    can apply NOT NULL. Orphaned attendees (no event_attendee history)
--    would otherwise fail at the SET NOT NULL step with a less clear error.
-- ============================================================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.attendee WHERE interesting_fact IS NULL) THEN
        RAISE EXCEPTION
            'Rollback cannot proceed: % attendee row(s) have no event_attendee history to source a fact from. Manually set their interesting_fact and re-run.',
            (SELECT count(*) FROM public.attendee WHERE interesting_fact IS NULL);
    END IF;
END;
$$;

-- ============================================================================
-- 4. Set attendee.interesting_fact NOT NULL
-- ============================================================================
ALTER TABLE public.attendee
    ALTER COLUMN interesting_fact SET NOT NULL;

-- ============================================================================
-- 5. Replace check_in_attendee() with the v1.4.0 body (writes fact to
--    attendee, leaves event_attendee fact-less, ON CONFLICT DO NOTHING).
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

    INSERT INTO attendee (email, first_name, last_name, interesting_fact)
    VALUES (v_email, v_first_name, v_last_name, v_interesting_fact)
    ON CONFLICT (email) DO UPDATE
        SET first_name       = EXCLUDED.first_name,
            last_name        = EXCLUDED.last_name,
            interesting_fact = EXCLUDED.interesting_fact,
            updated_at       = now()
    RETURNING id INTO v_attendee_id;

    INSERT INTO community_attendee (attendee_id, community_id)
    VALUES (v_attendee_id, v_community_id)
    ON CONFLICT (attendee_id, community_id) DO NOTHING;

    WITH inserted AS (
        INSERT INTO event_attendee (event_id, attendee_id)
        VALUES (p_event_id, v_attendee_id)
        ON CONFLICT (event_id, attendee_id) DO NOTHING
        RETURNING 1
    )
    SELECT EXISTS (SELECT 1 FROM inserted) INTO v_was_inserted;

    RETURN jsonb_build_object(
        'success',            true,
        'already_checked_in', NOT v_was_inserted,
        'attendee_id',        v_attendee_id
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_in_attendee(text, text, text, text, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.check_in_attendee(text, text, text, text, uuid) TO anon, authenticated;

-- ============================================================================
-- 6. Drop event_attendee.interesting_fact (now unused by the restored function)
-- ============================================================================
ALTER TABLE public.event_attendee
    DROP COLUMN interesting_fact;

COMMIT;
