# Migration rules

## New tables MUST include explicit GRANTs

As of 2026-10-30, Supabase no longer auto-exposes new tables in the `public`
schema to the Data API. Any `CREATE TABLE public.foo (...)` written without
explicit `GRANT` statements will be invisible to `supabase-js`, PostgREST,
and GraphQL. Queries against such a table will fail with PostgREST error
code `42501`.

This app uses the Data API (see `src/lib/database.ts`), so every new
`public` table needs grants in the same migration file.

### Required pattern

Every migration that contains `CREATE TABLE public.<name>` must also contain,
in the same file:

```sql
GRANT SELECT ON public.<name> TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.<name> TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.<name> TO service_role;

ALTER TABLE public.<name> ENABLE ROW LEVEL SECURITY;
-- + CREATE POLICY statements
```

Tighten `anon`'s grant to the minimum the app actually needs. For most
tables in this project `anon` only needs `SELECT`; `attendee` and
`event_attendee` also need `INSERT` and `UPDATE` for the check-in flow.

See `TEMPLATE.sql` in this directory for a copyable starting point.

### Out of scope

- `ALTER TABLE ... ADD COLUMN` migrations do not need new grants; column
  access follows the table-level grant.
- Existing tables created before 2026-10-30 keep their grants — do not
  re-grant them.
