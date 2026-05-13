-- Rollback: v1.4.0-secure-and-restructure-attendee
-- Description: Reverses v1.4.0. Drops check_in_attendee(), restores the 5
--              permissive RLS policies, restores the wide anon GRANTs,
--              re-adds attendee.community_id (backfilled from
--              community_attendee), and drops community_attendee.
-- Date: 2026-05-13
--
-- This rollback runs as a single transaction. If any step fails, the entire
-- rollback is undone and no data is lost.
--
-- LOSSY: information about multi-community attendees collapses back to a
-- single community_id per attendee (the earliest community they joined).
--
-- To apply: paste this entire file into the Supabase SQL editor and run.

BEGIN;

-- ============================================================================
-- 1. Drop the check_in_attendee function
-- ============================================================================
DROP FUNCTION IF EXISTS public.check_in_attendee(text, text, text, text, uuid);

-- ============================================================================
-- 2. Restore the 5 permissive RLS policies (verbatim from pre-v1.4.0 state)
-- ============================================================================
CREATE POLICY "Allow public read access to attendees"
    ON public.attendee FOR SELECT TO public USING (true);

CREATE POLICY "Allow public insert access to attendees"
    ON public.attendee FOR INSERT TO public WITH CHECK (true);

CREATE POLICY "Allow public update access to attendees"
    ON public.attendee FOR UPDATE TO public USING (true);

CREATE POLICY "Allow public read access to event_attendee"
    ON public.event_attendee FOR SELECT TO public USING (true);

CREATE POLICY "Allow public insert access to event_attendee"
    ON public.event_attendee FOR INSERT TO public WITH CHECK (true);

-- ============================================================================
-- 3. Restore wide anon GRANTs (matches the legacy Supabase default)
-- ============================================================================
GRANT ALL ON public.attendee       TO anon, authenticated, service_role;
GRANT ALL ON public.event_attendee TO anon, authenticated, service_role;

-- ============================================================================
-- 4. Re-add attendee.community_id (nullable first, then backfill, then NOT NULL)
-- ============================================================================
ALTER TABLE public.attendee
    ADD COLUMN community_id uuid;

-- Backfill: pick the earliest community_attendee row per attendee so the
-- restored value is deterministic. Multi-community attendees lose information
-- here -- only their first community is recovered onto attendee.community_id.
UPDATE public.attendee a
SET community_id = ca.community_id
FROM (
    SELECT DISTINCT ON (attendee_id)
        attendee_id,
        community_id
    FROM public.community_attendee
    ORDER BY attendee_id, created_at ASC
) ca
WHERE a.id = ca.attendee_id;

-- Any attendee without a community_attendee row (should not exist if v1.4.0
-- backfill succeeded) would be left NULL. Set NOT NULL only after backfill.
ALTER TABLE public.attendee
    ALTER COLUMN community_id SET NOT NULL;

ALTER TABLE public.attendee
    ADD CONSTRAINT fk_attendee_community
        FOREIGN KEY (community_id) REFERENCES public.community(id);

-- ============================================================================
-- 5. Drop the community_attendee join table
-- ============================================================================
DROP TABLE public.community_attendee;

COMMIT;
