# Prototype – Polls UI

This document captures a throwaway, interactive prototype built to test an idea. A prototype is independent of the Plan and Build phases: build one whenever you want to try something, then ask Cody to use it when planning or building.

## Created
2026-05-27

## Last Updated
2026-05-27 (session closed)

## The Idea
_The idea this prototype is testing, and what the **USER** hopes to learn from it._

v1.6.0-event-voting introduces per-event polls that checked-in attendees can vote on. The data model and per-poll states are already designed (see `docs/build/v1.6.0-event-voting/design.md`), but three UI layout decisions were deliberately deferred to this prototype:

- **Where do polls live in the app?** Inline on the unified main screen, behind a dedicated "Polls" button/route, or both?
- **How are multiple concurrent polls displayed?** Vertical stack, tabs, or collapsible accordions?
- **Where does the "Polls" button live (if any)?** Bottom-nav button, header icon, or no button at all?

We need a tactile feel for these layouts on a real phone before committing to one in the implementation.

## What to Test
_The specific things to try, click through, or evaluate in the prototype._

- What the Polls button looks like and where it lives (bottom nav vs header vs none).
- What happens when you tap the Polls button (full-screen route vs modal sheet vs inline expansion).
- How a single open poll renders and how voting feels (tap a radio, hit Vote, see the thanks state, change vote).
- How multiple polls render together in each layout variant — does stacking feel right? do tabs feel right? do accordions hide too much?
- How closed-poll results render — ranked list, "your pick" badge, tie handling, vote counts toggled on/off.
- Whether closed polls should still appear inline on the main screen, only in the Polls history page, or both.
- Mobile feel — does the layout breathe on a 375px-wide phone screen? Is the Vote button reachable with one thumb?

## Build Approach
_How the prototype is built and any tech choices. Kept lightweight -- it is throwaway._

Static HTML + CSS + a small amount of vanilla JS, all in `docs/prototypes/polls-ui/`. No build step, no framework, no node_modules. Open `index.html` directly in a browser (or serve with `python3 -m http.server` from the prototype folder if you want a localhost URL).

A dev-only control panel at the top lets the **USER** toggle between layout variants live so they can compare them side-by-side on the same screen. The actual app would never ship this panel — it exists purely to drive the comparison.

Mock data hard-coded in JS: three polls covering all the per-poll states (open-not-voted, open-already-voted, closed-with-results), plus realistic event/community chrome (welcome box, event details, donation box, bottom nav) so the polls sit in context, not in a vacuum.

## Findings Log
_What was learned, updated throughout the prototype session._

| Date | Finding |
|------|---------|
| 2026-05-27 | **Where polls live:** inline on the unified main screen, immediately after the "You're checked in!" hero and before the donation box / event details card. Polls are the time-sensitive action item and earn the top slot; donation + event details are passive reference info and live below. |
| 2026-05-27 | **Multi-poll layout:** vertical stack of cards. Matches the existing card-stack pattern (welcome card, donation card, event details card already use this language). Tabs and accordions add UI complexity that doesn't fit the rest of the screen. Scales from 1 → N polls just by getting taller. |
| 2026-05-27 | **No "Polls" bottom-nav button.** The app today has no bottom nav; adding one for what is a current-event-only feature is over-investment. Closed polls stay inline in the same card slot they lived in while open. If a future need for cross-event history surfaces, revisit. |
| 2026-05-27 | **Closed-poll results render inline in place** (no "See results" click-through, no separate route). Results are bounded by `top_n_winners` (default 3), so the card stays compact. Heavy ties past the cutoff could push the card taller in rare cases — fine to leave unhandled in v1.6.0; revisit if it becomes annoying. |
| 2026-05-27 | **Pivot — popup + inbox model.** The original "everything inline" model gets a refinement: voting happens in a **modal popup** (active engagement, time-sensitive); a persistent **polls inbox card** sits between the "You're checked in!" hero and the donate box, listing every active poll with its state (Vote / Voted / Closed). Tapping any inbox row reopens the popup for that poll — vote form if open, results if closed. When there's an un-voted open poll, the popup auto-opens once on page load. This collapses the earlier multi-poll/layout/history-button questions: the inbox = stacked list, no separate Polls button needed, closed-poll results live in the popup. |
| 2026-05-27 | **Inbox pills:** un-voted polls render a red **"Vote"** pill (single word, urgency color). Voted polls render a green "Voted" pill. Closed polls render an amber "Results" pill. Single-word labels keep the row compact. |
| 2026-05-27 | **Popup close affordance:** only the X at the top-right of the popup card is needed in the production UI. Tapping the dim overlay and pressing Escape also close, but those are bonus standard behaviors — no visible bottom "Close" button. |
| 2026-05-27 | **Vote persistence — falls out of the existing identity model.** `attendee_id` is already stored in localStorage from check-in (v0.6.0). The vote lives on `poll_vote(poll_id, attendee_id)` in the DB. On every page load, `get_polls_for_event` returns `my_vote_item_id` per poll, so the inbox renders the right pill and the popup pre-selects the prior choice. No new persistence code needed; behaves identically to how raffle wins and the per-event fact already persist. |
| 2026-05-27 | **"Clear check-in" does NOT delete poll votes.** Clearing check-in is a local reset (wipe localStorage), not a destructive action. The DB keeps the attendee row, raffle wins, fact, and votes. Re-checking-in with the same email restores `attendee_id` and the votes reappear in the inbox. This matches the established pattern for raffle wins. A "really delete my vote" action would require a new RPC and a trust model; out of scope for v1.6.0. |

## Likes & Dislikes
_The **USER's** judgment about the prototype: what works, what does not, what to keep, what to throw away, and opinions on the design and architecture._

**Likes / what to keep:**
- The popup + inbox card model end-to-end. "I'm good with the way it looks and works. I like everything as is. I want to implement it exactly as we finalized here."
- Auto-popup on load for the first un-voted open poll — surfaces the action without burying it.
- Single-word red "Vote" pill on the inbox row for un-voted polls — clearer call to action than "Vote now".
- X-only close affordance on the popup; no need for a bottom Close button.
- Inbox card placement between "You're checked in!" hero and the donation box.
- Closed polls staying in the inbox with a "Results" pill and opening the ranked results in the popup on tap — same surface as voting, no extra navigation.
- Persistence falling out of the existing identity model (no new persistence code, votes ride on the localStorage `attendee_id` like raffle wins do).

**Dislikes / things addressed during the session:**
- Original "Vote now" copy → shortened to "Vote".
- Bottom "Close" button on the popup → removed; the X alone is enough.
- Popup escaping the phone frame (a CSS bug during prototype iteration) → fixed.
- Original multi-axis dev controls (layout, button placement, etc.) → no longer needed once the popup + inbox model was chosen.

**Opinions on design and architecture:**
- Inline-only multi-poll layouts (stacked / tabs / accordion) were initially explored but dropped in favor of the popup + inbox model, which scales cleanly from 1 to N polls without any layout variant logic.
- A dedicated "Polls" bottom-nav button is not needed — the inbox card IS the polls list and the natural entry point.
