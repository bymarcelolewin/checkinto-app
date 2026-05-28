# Version Tasklist – v1.6.1-checkedin-message
This document outlines all the tasks to work on to deliver this particular version, grouped by phases.

| Status |      |
|--------|------|
| 🔴 | Not Started |
| 🟡 | In Progress |
| 🟢 | Completed |


## Phase 1: Author SQL Migration

References features F141, F142.

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T01 | Author v1.6.1 migration | Write `database/migrations/v1.6.1-checkedin-message.sql`. Single `ALTER TABLE public.event ADD COLUMN checkedin_message text;` — nullable, no default, no length CHECK. | None | 🟢 Completed | AGENT |
| T02 | Author v1.6.1 rollback | Write `database/migrations/v1.6.1-checkedin-message-rollback.sql`. Single `ALTER TABLE public.event DROP COLUMN checkedin_message;`. LOSSY — any populated messages will be lost. | T01 | 🟢 Completed | AGENT |


## Phase 2: Apply Migration in Supabase

USER runs SQL in the Supabase SQL editor.

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T03 | Apply v1.6.1 migration | Paste `v1.6.1-checkedin-message.sql` into Supabase SQL editor and run. Confirm success. Verify with `SELECT column_name FROM information_schema.columns WHERE table_name = 'event' AND column_name = 'checkedin_message';` — expect one row returned. | T01 | 🟢 Completed | USER |


## Phase 3: Frontend

References features F143, F144, F145.

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T04 | Update Event TypeScript interface | In `src/lib/types.ts`, add `checkedin_message: string \| null;` to the `Event` interface. | T03 | 🟢 Completed | AGENT |
| T05 | Add checked-in message card to EventScreen | In `src/lib/screens/EventScreen.svelte`, add a gray card block at the top of `event-main` (above the polls inbox), wrapped in `{#if isCheckedIn && event.checkedin_message?.trim()}`. Use `{@html formatLineBreaks(event.checkedin_message)}` for the body. Styling: gray background (matches donation/polls), rounded corners, padded, no header, left-justified text. Inline links inherit the existing green accent color (via `:global(a)` so `{@html}` content is reached). | T04 | 🟢 Completed | AGENT |


## Phase 4: Smoke Test

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T06 | End-to-end smoke test | USER picks a real or test event and exercises the cases: (a) `UPDATE event SET checkedin_message = 'Get your buildathon document <a href="…">now</a>!'` — link renders, clickable; (b) message with `\n` newlines — line breaks render; (c) `'   '` (whitespace only) — card hidden; (d) `NULL` — card hidden; (e) populated message visible only after check-in (not on the pre-check-in welcome view). All cases verified in production. | T03, T05 | 🟢 Completed | USER |


## Phase 5: Documentation

References feature F146.

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T07 | Update latest-schema.sql | Add `checkedin_message text` to the `event` table block; bump the "Snapshot reflects state after …" header to v1.6.1. | T06 | 🟢 Completed | AGENT |
| T08 | Update README.md | Bump the version badge from 1.6.0 to 1.6.1. Add a one-line bullet under "Event Voting (v1.6.0)" or in a new tiny section noting per-event checked-in messages. | T06 | 🟢 Completed | AGENT |
| T09 | Mark v1.6.1 complete in backlog | Update `docs/build/feature-backlog.md`: set v1.6.1 status to 🟢 Completed and F141–F146 rows to 🟢 Completed. | T07, T08 | 🟢 Completed | AGENT |


## Phase 6: Wrap-Up

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|--------------|--------|-------------|
| T10 | Write retrospective | Create `docs/build/v1.6.1-checkedin-message/retrospective.md` from template. | T09 | 🟢 Completed | AGENT |
| T11 | Update cody.json | Set `version` to `1.6.1` and `updatedAt` to today's date. | T09 | 🟢 Completed | AGENT |
| T12 | Update release-notes.md | Add v1.6.1 entry to `release-notes.md` at project root. | T09 | 🟢 Completed | AGENT |
| T13 | Commit to git | USER commits all changes with a descriptive message. | T12 | 🟢 Completed | USER |
