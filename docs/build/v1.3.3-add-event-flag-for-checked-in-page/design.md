# Version Design Document : v1.3.3-add-event-flag-for-checked-in-page
Technical implementation and design guide for the upcoming version.

## 1. Features Summary
_Overview of features included in this version._

This version adds event-level control for displaying detailed information on the confirmation page. The feature introduces a new boolean field `show_event_details` to the event table that allows organizers to control whether attendees see the detailed event information box after checking in.

**Key Features:**
- **F083**: Database Schema Enhancement - Add `show_event_details` boolean field to event table with default true
- **F084**: Database Migration Script - Create migration to add field and set all existing events to true  
- **F085**: Conditional UI Rendering - Modify confirmation page to conditionally show/hide event details box
- **F086**: Data Fetching Optimization - Skip event details queries when `show_event_details` is false
- **F087**: TypeScript Interface Updates - Update Event interface to include `show_event_details` field

## 2. Technical Architecture Overview
_High-level technical structure that supports all features in this version._

**Database Layer:**
- Supabase PostgreSQL database with new boolean column on `event` table
- Migration script to safely add the field with proper defaults

**Frontend Layer:**
- SvelteKit components with conditional rendering logic
- TypeScript interfaces updated to include new field
- Optimized data fetching to skip unnecessary queries

**Data Flow:**
1. Event data fetched from Supabase includes `show_event_details` flag
2. Frontend checks flag before rendering details box
3. When flag is false, skip fetching related event details (community, venue, talent data)
4. When flag is true, render full details box as currently implemented

## 3. Implementation Notes
_Shared technical considerations across all features in this version._

**Database Migration Strategy:**
- Use ALTER TABLE to add the new column with DEFAULT true
- Update all existing records to true to maintain current behavior
- No breaking changes to existing functionality

**Frontend Optimization:**
- Check `show_event_details` flag before making additional API calls for event details
- Maintain existing UI layout when details are hidden (no empty space)
- Preserve all other confirmation page functionality (raffle system, buttons, etc.)

**TypeScript Safety:**
- Update Event interface in `src/lib/types.ts` to include new field
- Ensure type safety across all components using event data
- Update database service methods to handle new field

## 4. Other Technical Considerations
_Any other technical information that might be relevant to building this version._

**Backward Compatibility:**
- Default value of `true` ensures existing events continue working unchanged
- No changes to event creation workflow initially
- Future admin interface can expose this setting

**Performance Impact:**
- Positive performance impact when `show_event_details` is false (fewer queries)
- No performance degradation when true (same behavior as current)

**Testing Considerations:**
- Test both true and false states of the flag
- Verify data fetching optimization works correctly
- Ensure UI renders appropriately in both scenarios

## 5. Open Questions
_Unresolved technical or product questions affecting this version._

1. **Admin Interface**: Should we add UI for organizers to toggle this setting, or keep it database-only for now?
   - **Decision**: Keep database-only for this version, defer UI to future release

2. **Default Behavior**: Should new events default to true or false for `show_event_details`?
   - **Decision**: Default to true to maintain current user experience expectations

3. **Partial Details**: Should there be granular control over which parts of the details box to show/hide?
   - **Decision**: Keep simple boolean for this version, can be enhanced later if needed