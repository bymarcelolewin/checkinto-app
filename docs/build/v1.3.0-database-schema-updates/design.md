# Release Design Document : v1.3.0-database-schema-updates
Technical implementation and design guide for comprehensive "meetup" to "group" terminology migration and database schema enhancements.

## 1. Features Summary
_Overview of features included in this release._

This release implements a comprehensive migration from "meetup" terminology to "group" throughout the entire CheckInto application, along with database schema enhancements to support improved group management.

### Primary Goals:
- **Database Schema Migration**: Rename `meetup` table to `group` with enhanced fields
- **Terminology Standardization**: Replace all "meetup" references with "group" across codebase
- **Enhanced Group Features**: Add profile name and favicon support for better branding
- **Code Consistency**: Update all TypeScript interfaces, components, and UI text

### Database Changes:
1. **Table Rename**: `meetup` → `group`
2. **Field Rename**: `logo` → `banner`
3. **New Fields**: 
   - `profilename` (text, unique, NOT NULL) - Group identifier for URL routing (e.g., "codingwithai" in codingwithai.checkinto.io/082025)
   - `favicon` (text, NOT NULL) - Custom favicon filename with same constraints as banner
4. **Field Constraints**: All fields except `learn_more_link` are now NOT NULL (required)
5. **Foreign Key Updates**: All `meetup_id` references → `group_id`, `meetup_host_id` → `group_host_id`

### Code Impact Areas:
- Database layer (queries, types, interfaces)
- Component props and data fetching
- User interface terminology and labels
- API endpoints and service methods
- Static asset references and paths

## 2. Technical Architecture Overview
_High-level technical structure that supports all features in this release._

### Current Architecture:
- **Frontend**: SvelteKit with TypeScript
- **Database**: Supabase PostgreSQL with foreign key relationships
- **Current Schema**: 6 tables with `meetup` as central organizing entity

### Migration Architecture:
```
Database Layer:
├── Migration Script (forward-only)
│   ├── Table rename: meetup → group
│   ├── Field operations: logo → banner, add profilename, add favicon
│   └── Foreign key updates: meetup_id → group_id
│
Frontend Layer:
├── Type Definitions (/src/lib/types/)
│   ├── Update all interfaces: Meetup → Group
│   └── Update database response types
│
├── Database Services (/src/lib/services/)
│   ├── Update Supabase queries
│   └── Update service method names
│
├── Components (/src/lib/screens/)
│   ├── Update data fetching logic
│   ├── Update prop types and references
│   └── Update UI terminology
│
└── Static Assets
    ├── Update image path references
    └── Add favicon handling logic
```

### Key Relationships Post-Migration:
- `event.group_id` → `group.id` (was `event.meetup_id` → `meetup.id`)
- Group entity supports enhanced branding: banner, favicon, profilename
- All UI references consistently use "group" terminology

## 3. Implementation Notes
_Shared technical considerations across all features in this release._

### Migration Strategy:
1. **Database-First Approach**: Execute schema migration before code changes
2. **Comprehensive Search**: Use project-wide search for all "meetup" references
3. **Type Safety**: Update TypeScript interfaces first to catch compilation errors
4. **Component Testing**: Verify each screen maintains functionality post-migration

### Critical Files to Update:
```
Database:
- /database/migrations/v1.3.0-meetup-to-group-migration.sql

Types & Interfaces:
- /src/lib/types/ (all interface definitions)
- /src/app.d.ts (if any global type references)

Database Services:
- /src/lib/services/ (Supabase query methods)

Components:
- /src/lib/screens/WelcomeScreen.svelte
- /src/lib/screens/CheckinForm.svelte  
- /src/lib/screens/ConfirmationScreen.svelte
- /src/routes/+error.svelte

Configuration:
- Any environment or config files with "meetup" references
```

### Search Patterns for Migration:
- **Database**: `meetup`, `meetup_id`, `meetup_host_id`, `fk_event_meetup`, `fk_event_meetup_host`
- **TypeScript**: `Meetup`, `meetupId`, `meetupHostId`, interface definitions
- **UI Text**: "meetup", "Meetup", user-facing labels
- **File Paths**: Any image or asset paths containing "meetup"

### Data Preservation:
- All existing data maintained during table/field renames
- Foreign key relationships preserved with updated naming
- No data loss during migration process

## 4. Other Technical Considerations
_Shared any other technical information that might be relevant to building this release._

### Database Constraints:
```sql
-- New constraints for enhanced group table
CONSTRAINT group_profilename_unique UNIQUE (profilename)
CONSTRAINT group_favicon_check CHECK (favicon IS NULL OR length(favicon) > 0 AND length(favicon) <= 255)
CONSTRAINT group_banner_check CHECK (banner IS NULL OR length(banner) > 0 AND length(banner) <= 255)
```

### Migration Script Safety:
- Use `ALTER TABLE` statements for renames to preserve data
- Add new fields with appropriate defaults
- Update foreign key constraints safely
- Verify referential integrity post-migration

### TypeScript Interface Updates:
```typescript
// Before
interface Meetup {
  id: string;
  name: string;
  logo?: string;
  // ... other fields
}

// After  
interface Group {
  id: string;
  name: string;
  banner?: string;
  profilename: string;
  favicon?: string;
  // ... other fields
}
```

### Component Prop Updates:
- All `meetup` props → `group`
- Update destructuring assignments
- Update component imports/exports
- Verify prop drilling chains

### UI Terminology Standards:
- **Consistent Capitalization**: "Group" for proper nouns, "group" for general references
- **User-Facing Labels**: Update all form labels, headings, descriptions
- **Error Messages**: Update any error text containing "meetup"
- **Success Messages**: Update confirmation and success text

### Asset Management:
- Image paths may need updates if they reference "meetup" directories
- Favicon handling requires new component logic
- Banner field rename affects existing image references

## 5. Technical Notes
_Additional implementation details clarified during planning._

### Enhanced Group Identification Architecture:
- **Profilename Usage**: The `profilename` field serves as the group identifier for URL routing and asset paths
- **URL Pattern**: `{profilename}.checkinto.io/{event_url_id}` (e.g., `codingwithai.checkinto.io/082025`)
- **Asset Path Resolution**: Image paths now use `event.group.profilename` instead of hostname parsing
- **Improved Reliability**: No longer dependent on subdomain detection - works in all environments (localhost, IP addresses, production)
- **Uniqueness Critical**: Profilename must be globally unique to prevent conflicts
- **Frontend Validation**: Client-side validation will ensure profilename meets subdomain requirements

### Confirmed Implementation Details:
1. **Foreign Key Constraint Naming**: Update `fk_event_meetup` → `fk_event_group`, `fk_event_meetup_host` → `fk_event_group_host`
2. **Host Field Update**: Additional migration needed for `meetup_host_id` → `group_host_id`
3. **Frontend Validation**: Profilename validation handled client-side as specified
4. **Rollback Strategy**: Not required for this release
5. **Data Migration**: No existing data to migrate
6. **Previous Version Files**: No updates to prior version documentation needed
7. **Database Constraints**: All group table fields now NOT NULL except `learn_more_link`
8. **Asset Path Improvement**: Image paths now use `event.group.profilename` eliminating hostname detection issues

### Implementation Dependencies:
- Database migration must complete successfully before frontend changes
- TypeScript compilation must pass before component testing
- All screens must maintain visual and functional consistency
- Asset references must resolve correctly post-migration

### Testing Requirements:
- Database integrity verification post-migration
- Component functionality testing across all screens
- UI terminology consistency validation
- Asset loading verification (banner, favicon)
- Foreign key relationship validation

### Performance Considerations:
- Table rename operations are atomic in PostgreSQL
- Index preservation during table rename
- Foreign key constraint updates should be efficient
- No expected performance impact on application queries