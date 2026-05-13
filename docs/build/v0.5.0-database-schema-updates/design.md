# Release Design Document : v0.5.0-database-schema-updates
Technical implementation and design guide for the upcoming release.

## 1. Features Summary
_Overview of features included in this release._

This release implements a major database schema restructure to introduce proper data normalization and support for reusable entities:

- **New Tables**: Add `meetup`, `venue`, and `presenter` tables for better data organization
- **Schema Normalization**: Restructure `event` table to reference new entities via foreign keys (all required)
- **Field Cleanup**: Remove unused `checked_in_message` field from event table
- **Dynamic Logo Support**: Replace hardcoded logo paths with database-driven logo filenames from meetup table
- **Profile Photo Support**: Add profile_photo field to presenter table for speaker images
- **File Organization**: Reorganize static assets into `/static/images/meetup/` and `/static/images/presenters/`
- **Maintain Compatibility**: Ensure existing application functionality remains unchanged

## 2. Technical Architecture Overview
_High-level technical structure that supports all features in this release._

**Database Layer Changes:**
- **New Tables**: `meetup` (with logo field), `venue`, `presenter` (with profile_photo field) with proper relationships
- **Event Table Updates**: Add foreign keys (`meetup_id`, `venue_id`, `presenter_id`) and new content fields (`about_presentation`, `about_working_session`)
- **Field Removal**: Drop `checked_in_message` column from event table
- **Required Relationships**: All foreign keys are NOT NULL - events must have meetup, venue, and presenter
- **Relationship Structure**: Maintain existing `event_attendee` many-to-many relationship

**Application Layer Updates:**
- **Type Definitions**: Update TypeScript interfaces to reflect new schema with all new fields
- **Logo Rendering**: Modify all three screens to use dynamic logo from meetup table (`/static/images/meetup/{logo}`)
- **Logo Fallback**: Hide logo entirely if file doesn't exist (no default fallback)
- **Database Queries**: Use JOIN queries to fetch related meetup, venue, presenter data efficiently
- **File Organization**: Move existing meetup-logo.png to new `/static/images/meetup/` folder
- **No UI Changes**: Maintain existing three-screen user flow and styling

**Data Population:**
- Manual population of new tables via Supabase dashboard by user
- SQL schema files stored in `/database` folder for user to execute
- No automated migration of existing data required

## 3. Implementation Notes
_Shared technical considerations across all features in this release._

**Database Schema Migration:**
- Create new tables first: `meetup` (with logo), `venue`, `presenter` (with profile_photo)
- Add new columns to `event` table: `about_presentation`, `about_working_session`, `presenter_id`, `meetup_id`, `venue_id`
- Drop `checked_in_message` column from `event` table
- All foreign keys are NOT NULL (required relationships)
- SQL scripts provided in `/database` folder for user execution

**Application Code Updates:**
- Update `src/lib/types.ts` to reflect new Event, Meetup, Venue, Presenter interfaces
- Modify database service calls to JOIN and fetch related meetup, venue, presenter data
- Replace hardcoded `/images/meetup-logo.png` with dynamic `/images/meetup/{meetup.logo}` in all three screens
- Implement logo existence check - hide logo entirely if file doesn't exist
- Move existing meetup-logo.png to `/static/images/meetup/` folder

**Testing Requirements:**
- Verify all three screens still render correctly
- Confirm logo displays properly from database
- Test event loading with new relationships
- Validate form submission still works unchanged

## 4. Other Technical Considerations
_Shared any other technical information that might be relevant to building this release._

**Performance Considerations:**
- New foreign key relationships may require JOIN queries
- Consider query optimization for fetching related data
- Monitor database query performance with new schema

**Backward Compatibility:**
- Existing `event_attendee` relationships remain unchanged
- URL structure stays the same (`/eventid/`)
- User experience remains identical

**File Management:**
- Meetup logos stored in `/static/images/meetup/` directory
- Presenter photos stored in `/static/images/presenters/` directory  
- Database stores only filename, application constructs full path
- Hide logo/photo entirely if file doesn't exist (no fallback)

**Data Integrity:**
- Foreign key constraints ensure referential integrity
- All relationships are required (NOT NULL constraints)
- Validation for logo and profile_photo filename format

## 5. Open Questions
_Unresolved technical or product questions affecting this release._

1. **Logo File Path Strategy**: Should logos be stored in `/static/images/logos/` subdirectory or continue using `/static/images/`?
> store it in /static/images/meetup/.   Please create that new subfolder and move the meetup-logo.png to the new folder.

2. **Missing Logo Handling**: What should happen if a logo filename is specified but the file doesn't exist? Show default logo or hide logo entirely?
> Don't display any logo.  Hide it entirely.

3. **Foreign Key Constraints**: Should the new foreign keys be nullable to allow events without assigned meetup/venue/presenter, or required?
> Events must belong to a meetup and have a venue and presenter.

4. **Query Optimization**: Should we fetch related data (meetup, venue, presenter) in a single JOIN query or separate queries?
> Whatever is the safest, secure and performant way.

5. **Database Seeding**: Do we need any default/seed data for the new tables, or will everything be populated manually?
> I will populate meetup, venu, presenter, and event tables manually.  So when you create the tasklist, after I run the updates to the database, I will populate it with content and then tell  you.
> Also, please keep in mind that we store DB schemas in the /database folder.   Please create the schema update there and when you tell me, I can use the SQL to run it directly in supabase.

6. **New Field**: This is not in the DB Changes image I provided, but I just thought that the "presenter" table needs a profile_photo.  It will hold just the filename (similar to the meetup logo in #1 above).  I'll store the profile photo in /static/images/presenters/  I will manually add one there.