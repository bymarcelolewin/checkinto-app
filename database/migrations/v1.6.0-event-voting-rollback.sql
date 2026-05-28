-- Rollback: v1.6.0-event-voting
-- Description: Reverses v1.6.0. Drops the two new functions and the four
--              new tables. There is no prior version of these objects to
--              restore — they were introduced fresh in v1.6.0.
-- Date: 2026-05-27
--
-- This rollback runs as a single transaction. If any step fails, the entire
-- rollback is undone and no data is lost.
--
-- LOSSY: every row in poll, poll_item, poll_winner_label, and poll_vote
-- will be deleted. Export any polls you want to keep before running this.
--
-- Drop order (reverse of create order, to respect FK constraints):
--   1. Drop function get_polls_for_event(uuid, uuid)
--   2. Drop function submit_vote(uuid, uuid, uuid)
--   3. Drop table poll_vote          (FK → poll, attendee, poll_item)
--   4. Drop table poll_winner_label  (FK → poll)
--   5. Drop table poll_item          (FK → poll)
--   6. Drop table poll               (FK → event, community)
--
-- To apply: paste this entire file into the Supabase SQL editor and run.

BEGIN;

-- ============================================================================
-- 1. Drop get_polls_for_event()
-- ============================================================================
DROP FUNCTION IF EXISTS public.get_polls_for_event(uuid, uuid);

-- ============================================================================
-- 2. Drop submit_vote()
-- ============================================================================
DROP FUNCTION IF EXISTS public.submit_vote(uuid, uuid, uuid);

-- ============================================================================
-- 3-6. Drop the four tables. ON DELETE CASCADE on the FKs means we can drop
--      in reverse-FK order without DELETE statements first.
-- ============================================================================
DROP TABLE IF EXISTS public.poll_vote;
DROP TABLE IF EXISTS public.poll_winner_label;
DROP TABLE IF EXISTS public.poll_item;
DROP TABLE IF EXISTS public.poll;

COMMIT;
