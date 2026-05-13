-- Migration: vX.Y.Z-short-description
-- Description: One-line summary of what this migration does
-- Date: YYYY-MM-DD
--
-- ============================================================================
-- TEMPLATE: copy this file and edit. Read database/migrations/CLAUDE.md first.
-- ============================================================================
--
-- Use this pattern whenever a migration creates a NEW table in the "public"
-- schema. As of 2026-10-30, Supabase no longer auto-grants new public tables
-- to the Data API roles (anon, authenticated, service_role). Without explicit
-- GRANTs, supabase-js / PostgREST / GraphQL cannot see the table and queries
-- will fail with PostgREST error code 42501.
--
-- This file does NOT need to be applied — it is a reference only.

-- ----------------------------------------------------------------------------
-- 1. Create the table
-- ----------------------------------------------------------------------------
CREATE TABLE public.your_table (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  -- ... your columns
  CONSTRAINT your_table_pkey PRIMARY KEY (id)
);

-- ----------------------------------------------------------------------------
-- 2. Grant Data API access (REQUIRED for new tables after 2026-10-30)
-- ----------------------------------------------------------------------------
-- Adjust per role to the MINIMUM the app actually needs.
--
-- anon          → unauthenticated browser client (uses the anon key).
--                 Tighten this — most tables should be SELECT-only for anon,
--                 or remove the grant entirely if anon should never see it.
-- authenticated → logged-in users (this app does not currently use auth, so
--                 these grants are forward-compatible only).
-- service_role  → server-side / admin scripts. Full access is conventional.

GRANT SELECT ON public.your_table TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.your_table TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.your_table TO service_role;

-- ----------------------------------------------------------------------------
-- 3. Enable Row Level Security
-- ----------------------------------------------------------------------------
-- GRANTs are coarse (table-level). RLS is fine-grained (row-level) and is
-- what actually gates which rows each role can see/modify. Without RLS,
-- anon could read/write every row the GRANT permits.

ALTER TABLE public.your_table ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 4. Add RLS policies
-- ----------------------------------------------------------------------------
-- Example: allow anon to read all rows (matches the read pattern used by
-- event/community/venue/talent in this project).
CREATE POLICY "anon can read your_table"
  ON public.your_table
  FOR SELECT
  TO anon
  USING (true);

-- Example: allow anon to insert rows (matches the pattern used by attendee
-- and event_attendee during check-in).
-- CREATE POLICY "anon can insert your_table"
--   ON public.your_table
--   FOR INSERT
--   TO anon
--   WITH CHECK (true);
