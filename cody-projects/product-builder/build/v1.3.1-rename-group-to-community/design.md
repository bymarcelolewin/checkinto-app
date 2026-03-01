# Release Design Document : v1.3.1-rename-group-to-community
Technical implementation and design guide for renaming "group" table to "community" to resolve PostgreSQL reserved keyword conflicts.

## 1. Features Summary
_Overview of features included in this release._

This release resolves PostgreSQL reserved keyword conflicts by renaming the "group" table to "community" throughout the entire CheckInto application. The "group" keyword causes syntax errors in PostgreSQL functions and queries, requiring comprehensive migration to "community" terminology.

### Primary Goals:
- **Resolve PostgreSQL Conflicts**: Eliminate reserved keyword issues causing database function failures
- **Database Schema Migration**: Rename `group` table to `community` with all related foreign keys
- **Code Consistency**: Update all TypeScript interfaces, components, and database services
- **Maintain Functionality**: Preserve all existing features while fixing underlying database issues

### Database Changes:
1. **Table Rename**: `group` → `community`
2. **Foreign Key Updates**: 
   - `attendee.group_id` → `attendee.community_id`
   - `event.group_id` → `event.community_id`  
   - `talent.group_id` → `talent.community_id`
   - `venue.group_id` → `venue.community_id`
   - `event.group_host_id` → `event.community_host_id`
3. **Constraint Updates**: All foreign key constraint names updated accordingly
4. **Function Updates**: Database functions in `@database/functions/` updated to use `community` table

### Code Impact Areas:
- Database layer (queries, types, interfaces)
- Database functions (get-raffle-winners.sql)
- Component props and data fetching
- TypeScript interfaces and service methods

## 2. Technical Architecture Overview
_High-level technical structure that supports all features in this release._

### Current Architecture:
- **Frontend**: SvelteKit with TypeScript
- **Database**: Supabase PostgreSQL with foreign key relationships
- **Current Issue**: "group" reserved keyword causing function execution failures

### Migration Architecture:
```
Database Layer:
├── Migration Script (forward-only)
│   ├── Table rename: group → community
│   ├── Foreign key updates: group_id → community_id
│   ├── Foreign key updates: group_host_id → community_host_id
│   └── Constraint name updates
│
├── Database Functions
│   ├── get-raffle-winners.sql (fix JOIN syntax)
│   └── select-raffle-winner.sql (verify no changes needed)
│
Frontend Layer:
├── Type Definitions (/src/lib/types/)
│   ├── Update all interfaces: Group → Community
│   └── Update database response types
│
├── Database Services (/src/lib/services/)
│   ├── Update Supabase queries
│   └── Update service method names
│
└── Components (/src/lib/screens/)
    ├── Update data fetching logic
    ├── Update prop types and references
    └── Update variable names
```

### Key Relationships Post-Migration:
- `event.community_id` → `community.id` (was `event.group_id` → `group.id`)
- `attendee.community_id` → `community.id`
- `talent.community_id` → `community.id`
- `venue.community_id` → `community.id`
- `event.community_host_id` → `talent.id` (was `event.group_host_id`)

## 3. Implementation Notes
_Shared technical considerations across all features in this release._

### Migration Strategy:
1. **Database-First Approach**: Execute schema migration before code changes
2. **Comprehensive Search**: Use project-wide search for all "group" references in code
3. **Type Safety**: Update TypeScript interfaces first to catch compilation errors
4. **Function Testing**: Verify database functions execute without reserved keyword errors

### Critical Files to Update:
```
Database:
- /database/migrations/v1.3.1-group-to-community-migration.sql
- /database/functions/get-raffle-winners.sql
- /database/latest-schema.sql (documentation)

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
```

### Search Patterns for Migration:
- **Database**: `group`, `group_id`, `group_host_id`, `fk_.*_group`, `"group"`
- **TypeScript**: `Group`, `groupId`, `groupHostId`, interface definitions
- **Functions**: JOIN statements with reserved `group` keyword

### Data Preservation:
- All existing data maintained during table/field renames
- Foreign key relationships preserved with updated naming
- No data loss during migration process

## 4. Other Technical Considerations
_Shared any other technical information that might be relevant to building this release._

### PostgreSQL Reserved Keyword Resolution:
```sql
-- Problem: Reserved keyword requires escaping
JOIN "group" g ON e.group_id = g.id

-- Solution: Use non-reserved table name
JOIN community c ON e.community_id = c.id
```

### Migration Script Safety:
- Use `ALTER TABLE` statements for renames to preserve data
- Update foreign key constraints safely with CASCADE options
- Verify referential integrity post-migration
- Test database functions execute without syntax errors

### TypeScript Interface Updates:
```typescript
// Before
interface Group {
  id: string;
  name: string;
  banner?: string;
  profilename: string;
  favicon?: string;
  // ... other fields
}

// After  
interface Community {
  id: string;
  name: string;
  banner?: string;
  profilename: string;
  favicon?: string;
  // ... other fields
}
```

### Component Prop Updates:
- All `group` props → `community`
- Update destructuring assignments
- Update component imports/exports
- Verify prop drilling chains

### Database Function Fixes:
- Remove need for `"group"` escaping in SQL
- Cleaner, more readable function code
- Eliminate PostgreSQL syntax warnings

## 5. Requirements Clarification
_All technical and product questions have been resolved._

All requirements clarified during planning:
- UI text changes not needed (no user-facing "group" text)
- Naming conventions established (keep existing patterns)
- Migration strategy confirmed (forward-only, no rollback needed)
- Scope defined (table and foreign key names only)

### Implementation Dependencies:
- Database migration must complete successfully before frontend changes
- TypeScript compilation must pass before component testing
- Database functions must execute without reserved keyword errors
- All screens must maintain visual and functional consistency

### Testing Requirements:
- Database integrity verification post-migration
- Database function execution verification
- Component functionality testing across all screens
- Foreign key relationship validation
- PostgreSQL syntax validation (no reserved keyword conflicts)