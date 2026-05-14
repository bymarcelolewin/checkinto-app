# Release Notes

This document lists new features, bug fixes and other changes implemented during a particular build, also known as a version.

## Table of Contents
- [v1.5.0-per-event-interesting-fact](#v150-per-event-interesting-fact---2026-05-13)
- [v1.4.0-secure-and-restructure-attendee](#v140-secure-and-restructure-attendee---2026-05-13)
- [v1.3.5-donation-link](#v135-donation-link---2026-01-28)
- [v1.3.4-unified-event-screen](#v134-unified-event-screen---2026-01-28)
- [Older Versions (v1.3.3 and earlier)](#older-versions)

---

# v1.5.0-per-event-interesting-fact - 2026-05-13

## Overview
This release moves the `interesting_fact` field from the global `attendee` row to the per-event `event_attendee` link. Each check-in now records its own fact, scoped to that specific gathering. Previously, the same person checking in at a second event would silently overwrite the fact displayed for every prior event they had attended.

## Key Features
- **Per-event interesting facts**: The `interesting_fact` column now lives on `event_attendee`, so the same attendee can share different things at different gatherings. Re-submitting within an event still allows fixing a typo — but only that event's value is affected.
- **Atomic upsert semantics preserved**: The `check_in_attendee()` RPC signature is unchanged. Internally it now uses `INSERT ... ON CONFLICT (event_id, attendee_id) DO UPDATE SET interesting_fact = EXCLUDED.interesting_fact` and the Postgres `xmax = 0` idiom to keep the `already_checked_in` return value accurate.

## Enhancements
- `attendee` becomes a pure identity table: `id`, `email`, `first_name`, `last_name`, `created_at`, `updated_at`. No profile data lives on the identity row.
- TypeScript `Attendee` interface drops `interesting_fact`; `EventAttendee` gains it. `AttendeeInput` is redeclared so the RPC payload type still carries the field.

## Bug Fixes
- Fixed: re-checking in at a second event silently rewrote the fact shown for prior events because the data lived globally. Each event now keeps its own value.

## Breaking Changes
- `attendee.interesting_fact` column dropped. External scripts or dashboard queries referencing it will break.
- `event_attendee.interesting_fact` is now `NOT NULL`. Any external code inserting into `event_attendee` directly (the app does not — it goes through the RPC) must supply a value.

## Database Changes
- New column: `public.event_attendee.interesting_fact text NOT NULL`.
- Backfill: every existing `event_attendee` row's value seeded from its attendee's prior global fact (237 rows, 0 nulls after backfill).
- Dropped column: `public.attendee.interesting_fact`.
- Updated function: `public.check_in_attendee()` body changed; signature and grants unchanged.
- A rollback migration is shipped alongside (`v1.5.0-per-event-interesting-fact-rollback.sql`). Note: rollback is lossy — per-event divergence collapses back to one fact per attendee (the earliest event_attendee row's value).

## Migration Files
- `database/migrations/v1.5.0-per-event-interesting-fact.sql`
- `database/migrations/v1.5.0-per-event-interesting-fact-rollback.sql`
- `database/functions/check-in-attendee.sql` (canonical function source)

---

# v1.4.0-secure-and-restructure-attendee - 2026-05-13

## Overview
This release locks down anonymous Data API access to attendee data and restructures the attendee↔community relationship into a proper many-to-many model. Anonymous check-in now flows through a single `SECURITY DEFINER` Postgres function (`check_in_attendee()`), and direct anon access to the `attendee` and `event_attendee` tables has been revoked. No user-facing UI changes.

## Key Features
- **Function-based check-in**: A new `check_in_attendee()` Postgres function is the only path anonymous users have to write attendee or check-in data. The function validates all inputs server-side, derives the community from the event, upserts the attendee by email, links the community, and inserts the event check-in — atomically in a single round trip.
- **Many-to-many attendee↔community**: New `community_attendee` join table replaces the misleading `attendee.community_id` column. Backfilled from existing data via UNION of the dropped column and `event_attendee → event.community_id` so no community associations are lost.
- **Idempotent check-in**: Re-submitting the same email/event no longer fails or duplicates rows — the function returns `already_checked_in: true` while still updating the attendee's name/fact if they typed something new.
- **Tightened RLS**: The five permissive `using = true` policies on `attendee` and `event_attendee` are dropped. Anon has no direct grant on those tables or on `community_attendee`. The four read-only tables (`event`, `community`, `talent`, `venue`) remain anon-readable for the check-in page.

## Enhancements
- Server-side validation in the RPC mirrors the existing `VALIDATION_RULES` exactly (1–50 chars for names, valid email format, 1–255 chars for interesting fact). A malicious client cannot bypass these by calling the API directly.
- `search_path = public, pg_temp` is set on the function to defeat search-path injection.
- `src/lib/database.ts` shrunk by ~210 lines: seven now-unused helpers removed (`createAttendee`, `upsertAttendee`, `updateAttendee`, `getAttendeeByEmail`, `linkAttendeeToEvent`, `isEmailRegisteredForEvent`, `getEventById`).
- Check-in now requires one network round-trip instead of five sequential queries.

## Bug Fixes
- The legacy `attendee.community_id` column was set on first registration but never updated, so it incorrectly suggested attendees belonged to a single community when in fact they could attend events across communities. Removed.

## Breaking Changes
- `attendee.community_id` column dropped. Any external script or dashboard query referencing it will break. The `database/admin/raffle-admin-script.sql` was audited and does not reference it.
- Direct `INSERT`/`UPDATE`/`SELECT` on `attendee` and `event_attendee` from the anon key now returns PostgREST error `42501`. Use the `check_in_attendee()` RPC instead.

## Database Changes
- New table: `public.community_attendee (attendee_id, community_id, created_at)` — composite primary key, foreign keys to `attendee.id` and `community.id` with `ON DELETE CASCADE`.
- New function: `public.check_in_attendee(text, text, text, text, uuid) RETURNS jsonb` (SECURITY DEFINER).
- Dropped column: `attendee.community_id`.
- Dropped policies: `Allow public read/insert/update access to attendees` (3), `Allow public read/insert access to event_attendee` (2).
- Revoked grants: all anon privileges on `attendee` and `event_attendee`.
- A rollback migration is shipped alongside (`v1.4.0-secure-and-restructure-attendee-rollback.sql`).

## Migration Files
- `database/migrations/v1.4.0-secure-and-restructure-attendee.sql`
- `database/migrations/v1.4.0-secure-and-restructure-attendee-rollback.sql`
- `database/functions/check-in-attendee.sql` (canonical function source)

---

# v1.3.5-donation-link - 2026-01-28

## Overview
This release adds an optional donation box to the Event Screen, allowing communities to request financial support from attendees. The donation box displays below the welcome message and is fully database-driven, appearing only when a donation link is configured.

## Key Features
- **Donation Box Component**: New UI section with customizable message and "Donate" button
- **Database-Driven Content**: Both the donation link and message are pulled from the `community` table
- **Conditional Display**: Box only appears when `donation_link` field has a value
- **Dual-State Visibility**: Donation box shows for both checked-in and non-checked-in users
- **Line Break Support**: Donation messages support `\n` for multi-line formatting

## Enhancements
- Updated Community interface with `donation_link` and `donation_message` fields
- Modified Supabase queries to fetch donation fields alongside community data
- Green gradient styling on Donate button matching existing Check In button
- Reduced button size from large to medium for better visual balance
- Tightened padding and spacing on welcome and donation boxes

## Bug Fixes
None

## Other Notes
- Database migration required: Add `donation_link` (text, nullable) and `donation_message` (text, nullable) columns to `community` table
- Uses existing `formatLineBreaks` utility for message formatting

---

# v1.3.4-unified-event-screen - 2026-01-28

## Overview
This release consolidates the three-screen user flow (Welcome → Check-in Form → Confirmation) into a streamlined two-screen flow (Event Screen → Check-in Form). Users now see all event details immediately upon arrival, with conditional UI elements based on their check-in status.

## Key Features
- **Unified Event Screen**: Merged Welcome and Confirmation screens into a single EventScreen component that adapts based on user's check-in status
- **Immediate Event Details**: Venue, hosts, WiFi, restrooms, and refreshments are now visible on initial page load
- **Conditional Check-In Display**: Shows "Check In" button for new users, "You're checked in!" message with checkmark icon for confirmed users
- **Clear Check-In Link**: Small footer link allowing users to reset their checked-in state for edge cases

## Enhancements
- Simplified navigation system reduced from 3 screen types to 2 ('event' | 'checkin')
- Welcome box styling with gray background matching event info grid
- Green gradient button with white text for check-in action
- Consistent spacing between banner and content boxes across screens
- Form page simplified to show only banner and form fields (removed redundant title)
- Raffle polling only activates when user is checked in, reducing unnecessary API calls

## Bug Fixes
None

## Other Notes
- Removed "Check In Another Person" button - each attendee should use their own device
- Deleted deprecated WelcomeScreen.svelte and ConfirmationScreen.svelte files
- Estimated ~400 lines of code reduced through component consolidation

---

# Older Versions

Compact history for releases prior to v1.3.4. For detailed notes on these versions, see the corresponding folders under `docs/build/`.

- **v1.3.3** - Added event-level flag for controlling event details visibility
- **v1.3.2** - GitHub organization migration to checkinto-io
- **v1.3.1** - Database schema rename: `group` table → `community` table
- **v1.3.0** - Complete multi-tenant architecture with data isolation and secure routing
- **v1.2.0** - CSS consolidation and styling improvements
- **v1.1.0** - Multi-tenant image folder restructure with community-based organization
- **v1.0.0** - Production deployment with custom domain and full feature set
- **v0.8.0** - Real-time raffle system implementation
- **v0.7.0** - Community host integration and talent management
- **v0.6.0** - Persistent state management for confirmation screens
- **v0.5.0** - Database schema normalization and optimization
- **v0.1.0–v0.4.0** - Core functionality development and polish
