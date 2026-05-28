-- Rollback: v1.6.1-checkedin-message
-- Description: Reverses v1.6.1. Drops the checkedin_message column from
--              the event table.
-- Date: 2026-05-27
--
-- LOSSY: any populated checkedin_message values will be permanently lost
-- when this column is dropped.
--
-- To apply: paste this entire file into the Supabase SQL editor and run.

BEGIN;

ALTER TABLE public.event
    DROP COLUMN checkedin_message;

COMMIT;
