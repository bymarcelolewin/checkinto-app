# Version Design Document : v1.3.4-unified-event-screen
Technical implementation and design guide for the upcoming version.

## 1. Features Summary
_Overview of features included in this version._

This version consolidates the Welcome and Confirmation screens into a single unified Event Screen that displays all event details immediately upon arrival. The user experience shifts from a 3-screen flow to a 2-screen flow:

**Current Flow (3 screens):**
1. Welcome Screen (minimal - banner, title, "Check In" button)
2. Check-in Form
3. Confirmation Screen (detailed - all event info, "You're checked in!")

**New Flow (2 screens):**
1. **Event Screen** (detailed - all event info with conditional "Check In" button or "You're checked in!")
2. Check-in Form

**Key Changes:**
- F088: Merge welcome and confirmation screens into single main event screen
- F089: Conditional display - "Check In" button (not checked in) vs "You're checked in!" (checked in)
- F090: Remove "Check In Another Person" button
- F091: Show all event details (venue, hosts, amenities) immediately on page load
- F092: Update form submission to return to main screen
- F093: Refactor state management for unified screen flow
- F094: Preserve `show_event_details` flag functionality
- F095: Maintain raffle winner display for checked-in users

## 2. Technical Architecture Overview
_High-level technical structure that supports all features in this version._

### Components Affected

| File | Change Type | Description |
|------|-------------|-------------|
| `src/lib/screens/WelcomeScreen.svelte` | **DELETE** | No longer needed |
| `src/lib/screens/ConfirmationScreen.svelte` | **RENAME/REFACTOR** | Becomes `EventScreen.svelte` with conditional rendering |
| `src/routes/[eventId]/+page.svelte` | **MODIFY** | Update to use new 2-screen flow |
| `src/lib/stores/navigation.ts` | **MODIFY** | Simplify to 2 screens: 'event' and 'checkin' |
| `src/lib/screens/CheckinForm.svelte` | **MODIFY** | Update navigation after submission |

### Screen State Flow

```
┌─────────────────────────────────────────────────────────┐
│                    EventScreen.svelte                    │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Banner + Event Details (always shown if enabled) │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ IF not checked in:  [Check In Button]            │   │
│  │ IF checked in:      ✓ You're checked in!         │   │
│  │                     + Raffle Winners (if any)    │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
           │                              ▲
           │ Click "Check In"             │ Submit form
           ▼                              │
┌─────────────────────────────────────────────────────────┐
│                   CheckinForm.svelte                     │
│                   (unchanged logic)                      │
└─────────────────────────────────────────────────────────┘
```

### Navigation Store Changes

**Current Screen Types:**
```typescript
type Screen = 'welcome' | 'checkin' | 'confirmation';
```

**New Screen Types:**
```typescript
type Screen = 'event' | 'checkin';
```

The `isCheckedIn` state will be tracked separately to control UI rendering within the EventScreen.

## 3. Implementation Notes
_Shared technical considerations across all features in this version._

### Conditional Rendering Logic

The EventScreen will use a derived state to determine what to display:

```typescript
// Check if user has confirmed check-in (from localStorage)
let isCheckedIn = $derived(hasConfirmationState(event?.url_id));

// In template:
{#if isCheckedIn}
  <!-- Show "You're checked in!" message and raffle winners -->
{:else}
  <!-- Show "Check In" button -->
{/if}
```

### State Persistence

The existing localStorage mechanism will continue to work:
- When user completes check-in → store confirmation state
- On page load → check for existing confirmation state
- No changes needed to the storage utilities

### Raffle Winner Display

Raffle polling should only activate when user is checked in:
- Move raffle polling logic to be conditional on `isCheckedIn`
- This prevents unnecessary API calls for non-checked-in users

### show_event_details Flag

The `show_event_details` flag from v1.3.3 must continue to work:
- When `false`: Hide the event details grid (venue, hosts, amenities)
- When `false`: Still show banner (for branding)
- When `false`: Still show check-in button or confirmation status

## 4. Other Technical Considerations
_Shared any other technical information that might be relevant to building this version._

### CSS Considerations

- Most styling from ConfirmationScreen can be reused
- The "Check In" button styling should match the current welcome screen's prominent button
- Consider adding a visual transition/animation when state changes from not-checked-in to checked-in

### Mobile Responsiveness

- The unified screen should maintain the existing mobile-first design
- The 2-column grid layout for event details should continue to collapse to 1 column on mobile

### Backward Compatibility

- Users with existing localStorage confirmation state should seamlessly see "You're checked in!" on the new EventScreen
- No data migration needed

### Code Cleanup

After implementation, the following can be removed:
- `WelcomeScreen.svelte` file (deleted)
- `handleCheckInAnother` function (removed from EventScreen)
- Related form clearing logic that was only used for "Check In Another Person"

## 5. Open Questions
_Unresolved technical or product questions affecting this version._

- **Resolved:** Welcome message placement - Will show banner and event title, the welcome_message field can be removed or repurposed (keeping for now, can address in future version)
- **Resolved:** 24-hour expiration not needed since each event has unique URL
- **Resolved:** "Check In Another Person" removed - each person uses their own device
