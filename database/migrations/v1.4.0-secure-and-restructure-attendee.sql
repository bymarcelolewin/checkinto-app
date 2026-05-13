-- Migration: v1.4.0-secure-and-restructure-attendee
-- Description: Lock down Data API access for attendee + event_attendee via a
--              SECURITY DEFINER function, and restructure the attendee-to-
--              community relationship into a proper many-to-many join table.
-- Date: 2026-05-13
--
-- This migration runs as a single transaction. If any step fails, the entire
-- migration rolls back and no data is lost.
--
-- Order matters:
--   1. Create community_attendee table.
--   2. Backfill community_attendee from existing data.
--   3. Drop attendee.community_id column.
--   4. Install check_in_attendee() function.
--   5. Drop 5 permissive RLS policies.
--   6. Revoke direct anon GRANTs on attendee and event_attendee.
--   7. Enable RLS on community_attendee (no anon policies).
--
-- To apply: paste this entire file into the Supabase SQL editor and run.
-- To roll back: run v1.4.0-secure-and-restructure-attendee-rollback.sql.

BEGIN;

-- ============================================================================
-- 1. Create the community_attendee join table
-- ============================================================================
CREATE TABLE public.community_attendee (
    attendee_id  uuid NOT NULL,
    community_id uuid NOT NULL,
    created_at   timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT community_attendee_pkey PRIMARY KEY (attendee_id, community_id),
    CONSTRAINT community_attendee_attendee_id_fkey
        FOREIGN KEY (attendee_id) REFERENCES public.attendee(id) ON DELETE CASCADE,
    CONSTRAINT community_attendee_community_id_fkey
        FOREIGN KEY (community_id) REFERENCES public.community(id) ON DELETE CASCADE
);

COMMENT ON TABLE public.community_attendee IS
    'Many-to-many link between attendees and the communities they have interacted with. '
    'Populated by the check_in_attendee() function. Direct table access is restricted.';

-- ============================================================================
-- 2. Backfill community_attendee from both sources
--    a) The legacy attendee.community_id (first community the person joined).
--    b) Every (attendee, community) pair implied by existing event_attendee
--       rows joined to event.community_id.
--    UNION + ON CONFLICT DO NOTHING dedupes any overlap.
-- ============================================================================
INSERT INTO public.community_attendee (attendee_id, community_id)
SELECT id, community_id FROM public.attendee
UNION
SELECT ea.attendee_id, e.community_id
FROM public.event_attendee ea
JOIN public.event e ON e.id = ea.event_id
ON CONFLICT (attendee_id, community_id) DO NOTHING;

-- ============================================================================
-- 3. Drop the legacy attendee.community_id column
-- ============================================================================
ALTER TABLE public.attendee DROP COLUMN community_id;

-- ============================================================================
-- 4. Install the check_in_attendee() function (canonical copy lives at
--    database/functions/check-in-attendee.sql)
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
-- 5. Drop the 5 permissive RLS policies on attendee and event_attendee
-- ============================================================================
DROP POLICY IF EXISTS "Allow public read access to attendees"   ON public.attendee;
DROP POLICY IF EXISTS "Allow public insert access to attendees" ON public.attendee;
DROP POLICY IF EXISTS "Allow public update access to attendees" ON public.attendee;

DROP POLICY IF EXISTS "Allow public read access to event_attendee"   ON public.event_attendee;
DROP POLICY IF EXISTS "Allow public insert access to event_attendee" ON public.event_attendee;

-- ============================================================================
-- 6. Revoke direct anon GRANTs on attendee and event_attendee
--    The function (running as SECURITY DEFINER / postgres) retains access.
-- ============================================================================
REVOKE SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
    ON public.attendee FROM anon;

REVOKE SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
    ON public.event_attendee FROM anon;

-- ============================================================================
-- 7. Enable RLS on community_attendee with no anon policies.
--    Direct table access from anon is blocked entirely; the function bypasses
--    RLS because it runs as SECURITY DEFINER.
-- ============================================================================
ALTER TABLE public.community_attendee ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.community_attendee FROM anon;

COMMIT;
