# Version Design Document : v1.6.1-checkedin-message
Technical implementation and design guide for the upcoming version.

## 1. Features Summary
_Overview of features included in this version._

Add an optional per-event message that surfaces after an attendee checks in — e.g., *"Get your buildathon document [now](https://...)!"*. The message renders in a gray card between the "You're checked in!" hero and the polls inbox, with no header and left-justified text. Supports inline HTML (notably `<a href>` tags) so admins can embed download links directly without any new schema for resource URLs.

**Features included**

| Feature | ID |
|---|---|
| Schema Migration | F141 |
| Rollback Migration | F142 |
| TypeScript Interface Update | F143 |
| Checked-In Message Card | F144 |
| Wire into Unified Main Screen | F145 |
| Update latest-schema.sql | F146 |

## 2. Technical Architecture Overview
_High-level technical structure that supports all features in this version._

### Database (Supabase Postgres)

Single column added to `public.event`:

```sql
ALTER TABLE public.event ADD COLUMN checkedin_message text;
```

- **Nullable** — most events won't have one; default behavior is "no card renders".
- **No length limit** — matches `welcome_message`'s lack of a CHECK constraint. Trusted admin input.
- **No default** — existing rows stay NULL.

No new grants, RLS changes, or function changes required. `event` is already anon-SELECT and the field rides along with the existing `SELECT *` event queries.

### Frontend (SvelteKit)

- **`src/lib/types.ts`** — add `checkedin_message: string | null` to the `Event` interface.
- **`src/lib/screens/EventScreen.svelte`** — add a new card block between the "You're checked in!" hero (which lives in `event-header`) and the polls inbox (top of `event-main`). The card is wrapped in `{#if isCheckedIn && event.checkedin_message?.trim()}` so it only renders when (a) the attendee is checked in and (b) the message is non-empty and not whitespace-only.

**Render pattern** (mirrors `welcome_message`):

```svelte
{#if isCheckedIn && event.checkedin_message?.trim()}
    <div class="checkedin-message">
        <p>{@html formatLineBreaks(event.checkedin_message)}</p>
    </div>
{/if}
```

Styling follows the existing gray-card pattern (donation box, polls inbox) — `background: var(--color-content-bg)`, rounded corners, padded, no header. Inline links inherit the green accent color used elsewhere.

### Position in the unified main screen

After this version, the rendering order when checked in becomes:

1. Banner image (header)
2. "You're checked in!" hero (header)
3. **NEW: checked-in message card** (top of `event-main`, if message is set)
4. Polls inbox (if any active polls)
5. Donation box (if `community.donation_link`)
6. Event details (if `event.show_event_details`)

## 3. Implementation Notes
_Shared technical considerations across all features in this version._

**Migration is the simplest possible** — single `ALTER TABLE ... ADD COLUMN`. No backfill, no transaction-wrapping required (single statement is atomic), no RLS or grant changes. The rollback is `DROP COLUMN`.

**HTML rendering is `@html` — by design.** Same trust model as `welcome_message` and `donation_message`: only admins write these fields directly in Supabase, and admins are trusted. There is no new XSS surface — we're extending an existing capability, not creating a new one. Documented to keep this clear for any future contributor reading the code.

**Whitespace-only is treated as empty.** Frontend uses `event.checkedin_message?.trim()` as the truthiness check rather than a bare null check. An admin who accidentally types a space or hits enter into Supabase Studio shouldn't end up with an invisible card eating layout space.

**No new component file.** Like the donation box, this is a small enough piece to live inline in `EventScreen.svelte` rather than in its own `.svelte` file. Matches the existing pattern for similar checked-in-only content.

**`SELECT *` carries the new column.** `DatabaseService.getEventByUrlIdAndProfile` uses `select('*', ...)` (or the equivalent) for the event row, so adding the column to the DB automatically flows into the response. No service-method changes required — just the type update.

## 4. Other Technical Considerations
_Shared any other technical information that might be relevant to building this version._

**Behavioral change for end users:** none, unless an admin populates `checkedin_message` on a given event. Existing events with NULL just behave as before.

**Visibility flag (`show_event_details`) does NOT gate this.** `show_event_details` controls the event details block (venue, hosts, etc.). The checked-in message is independent — admins can set both, neither, or one. This matches how the donation box already behaves.

**Out of scope for v1.6.1:**
- Per-event multiple messages (just one slot per event).
- Rich-text editor for admins (raw HTML in Supabase Studio is fine for now).
- Time-based scheduling ("show message starting at 7pm"). If needed later, we can add a separate column or use the same admin-toggle pattern `active` uses on poll.
- An admin UI for managing the message — write it directly in Supabase Studio.

**Smoke test plan:** After applying the migration, set `checkedin_message` on a test event to (a) plain text, (b) text with `<a href>`, (c) text with `\n` line breaks, (d) only whitespace (`'   '`), (e) `NULL`. Verify on a checked-in phone view: (a) renders, (b) link is clickable, (c) line breaks appear, (d) card is hidden, (e) card is hidden.

## 5. Open Questions
_Unresolved technical or product questions affecting this version._

None. The user-facing behavior and technical approach are fully specified.
