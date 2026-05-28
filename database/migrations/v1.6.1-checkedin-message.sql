-- Migration: v1.6.1-checkedin-message
-- Description: Add an optional per-event `checkedin_message` column to the
--              event table. Renders in a card between the "You're checked
--              in!" hero and the polls inbox; supports inline HTML (e.g.,
--              <a href="..."> links) the same way welcome_message does.
-- Date: 2026-05-27
--
-- Single ALTER TABLE. No backfill, no defaults, no constraints. Existing
-- rows stay NULL and the frontend treats NULL / whitespace-only as "no
-- card to render".
--
-- To apply: paste this entire file into the Supabase SQL editor and run.
-- To roll back: run v1.6.1-checkedin-message-rollback.sql.

BEGIN;

ALTER TABLE public.event
    ADD COLUMN checkedin_message text;

COMMENT ON COLUMN public.event.checkedin_message IS
    'Optional per-event message shown after check-in, between the "You''re '
    'checked in!" hero and the polls inbox. Supports inline HTML (same '
    'trust model as welcome_message). NULL or whitespace-only hides the card.';

COMMIT;
