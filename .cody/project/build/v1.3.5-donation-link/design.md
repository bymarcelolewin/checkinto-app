# Version Design Document: v1.3.5-donation-link
Technical implementation and design guide for the upcoming version.

## 1. Features Summary
_Overview of features included in this version._

This version adds a donation call-to-action box to the EventScreen component. The box displays below the welcome box (before check-in) with matching styling, containing a message asking users if they want to help cover event expenses, along with a "Donate" button that links to the community's donation URL.

**Key behaviors:**
- Donation box appears below the welcome box (same gray background styling)
- Text: "Enjoying this event? Want to help cover expenses?"
- Green gradient "Donate" button (same style as Check In button)
- Only displays when `community.donation_link` has a value
- Opens donation link in new tab when clicked

## 2. Technical Architecture Overview
_High-level technical structure that supports all features in this version._

### Database Layer
- **Field already exists**: `donation_link` (text, nullable) in the `community` table
- No database migration needed - user confirmed the field is already added

### TypeScript Types
- Update `Community` interface in `src/lib/types.ts` to include `donation_link: string | null`

### Data Flow
1. Supabase query already fetches community data via JOIN
2. Need to ensure `donation_link` is included in the select statement
3. `event.community.donation_link` will be available in EventScreen component

### UI Layer
- **EventScreen.svelte**: Add new donation box section below welcome box
- Conditional rendering: `{#if event.community?.donation_link}`
- Reuse existing button styling from welcome box

## 3. Implementation Notes
_Shared technical considerations across all features in this version._

### Styling Approach
The donation box should mirror the welcome box styling:
```css
.donation-box {
  background: var(--color-content-bg);  /* Same gray as welcome box */
  border-radius: 1rem;
  padding: 2rem;
  text-align: center;
  box-shadow: 0 10px 25px var(--shadow-light);
}
```

The button inherits the green gradient styling already applied to `.welcome-box :global(.btn-primary)`.

### Button Implementation
Use an anchor tag styled as a button (or Button component with href) to open external donation link:
```svelte
<a href={event.community.donation_link} target="_blank" rel="noopener noreferrer">
  Donate
</a>
```

### Placement in DOM
The donation box should appear:
1. After the welcome box (when user is NOT checked in)
2. The `.event-main` container uses `gap: 2rem` which will provide appropriate spacing

## 4. Other Technical Considerations
_Shared any other technical information that might be relevant to building this version._

### Accessibility
- Button should have proper focus states
- External link indicator (target="_blank") requires `rel="noopener noreferrer"` for security
- Consider adding aria-label for screen readers

### Mobile Responsiveness
- Same responsive behavior as welcome box (padding reduction on small screens)
- Button maintains min-height: 44px for touch targets

### Files to Modify
1. `src/lib/types.ts` - Add donation_link to Community interface
2. `src/lib/services/supabase.ts` - Verify donation_link is in select query (if needed)
3. `src/lib/screens/EventScreen.svelte` - Add donation box UI
4. `database/latest-schema.sql` - Add donation_link field to community table definition

## 5. Open Questions
_Unresolved technical or product questions affecting this version._

None - requirements are clear:
- Donation box below welcome box
- Only show when donation_link exists
- Same styling as welcome box with green gradient button
