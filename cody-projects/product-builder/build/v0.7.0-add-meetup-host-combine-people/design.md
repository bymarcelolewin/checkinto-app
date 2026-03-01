# Release Design Document - v0.7.0-add-meetup-host-combine-people
Technical implementation and design guide for refactoring talent management and adding meetup host functionality.

## 1. Features Summary
_Overview of features included in this release._

### Database Schema Refactoring
- **Table Rename**: Rename `presenter` table to `talent` to better represent all team member roles
- **Field Rename**: Change `workshop_host_id` to `workshop_lead_id` in event table for clarity
- **New Meetup Host**: Add required `meetup_host_id` field to event table referencing talent table
- **Constraint Updates**: Update all foreign key relationships to reference new `talent` table

### Enhanced Role Display
- **Three Distinct Roles**: Display Hosted By, Presented By, and Workshop Lead By sections
- **Consistent UI Pattern**: All three roles use same person icon and layout structure
- **Improved Labeling**: More descriptive headings that clearly indicate the role relationship
- **Maintained Linking**: All roles retain clickable links to talent profile pages when available

### Data Integrity & Migration
- **Safe Migration**: Database migration preserves all existing data during table rename
- **Foreign Key Integrity**: Proper constraint handling during schema changes  
- **Backward Compatibility**: Seamless transition without data loss or application downtime

## 2. Technical Architecture Overview
_High-level technical structure that supports all features in this release._

### Database Architecture Changes
```sql
-- Before (Current Schema)
CREATE TABLE presenter (
  id, first_name, last_name, learn_more_link, ...
);
CREATE TABLE event (
  ..., presenter_id, workshop_host_id, ...
  FOREIGN KEY (presenter_id) REFERENCES presenter(id),
  FOREIGN KEY (workshop_host_id) REFERENCES presenter(id)
);

-- After (New Schema)  
CREATE TABLE talent (
  id, first_name, last_name, learn_more_link, ...
);
CREATE TABLE event (
  ..., presenter_id, workshop_lead_id, meetup_host_id, ...
  FOREIGN KEY (presenter_id) REFERENCES talent(id),
  FOREIGN KEY (workshop_lead_id) REFERENCES talent(id), 
  FOREIGN KEY (meetup_host_id) REFERENCES talent(id)
);
```

### Application Layer Updates
- **TypeScript Interfaces**: Update all type definitions to reflect new schema
- **Database Service**: Modify JOIN queries to fetch all three talent relationships  
- **Component Updates**: Enhance ConfirmationScreen to display all three role sections
- **State Management**: Update navigation and form state to handle new talent structure

### Migration Strategy
- **Atomic Operations**: All schema changes within single transaction
- **Constraint Handling**: Temporary constraint dropping and recreation as needed
- **Data Preservation**: Table rename preserves all existing presenter data
- **Foreign Key Updates**: Systematic update of all referencing constraints

## 3. Implementation Notes
_Shared technical considerations across all features in this release._

### Database Migration Requirements
```sql
-- Key migration steps:
1. Rename presenter table to talent
2. Update all foreign key constraints 
3. Rename workshop_host_id to workshop_lead_id in event table
4. Add meetup_host_id column (required) to event table
5. Create new foreign key constraint for meetup_host_id
```

### TypeScript Interface Updates
```typescript
// Before
interface Event {
  presenter_id: string;
  workshop_host_id: string;
  presenter?: Presenter;
  workshop_host?: Presenter;
}

// After  
interface Event {
  presenter_id: string;
  workshop_lead_id: string;
  meetup_host_id: string;
  presenter?: Talent;
  workshop_lead?: Talent;
  meetup_host?: Talent;
}
```

### UI Component Structure
```svelte
<!-- Consistent pattern for all three roles -->
<div class="info-item">
  <div class="info-icon">[person icon]</div>
  <div class="info-content">
    <h4>[Role Label]</h4>
    <p>[Name with optional link]</p>
  </div>
</div>
```

### Database Service Enhancements
- **Extended JOIN Query**: Fetch presenter, workshop_lead, and meetup_host in single query
- **Validation Updates**: Ensure all three talent relationships exist and are valid
- **Error Handling**: Graceful handling of missing talent relationships

## 4. Other Technical Considerations
_Shared any other technical information that might be relevant to building this release._

### Data Consistency & Validation
- **Required Field**: meetup_host_id is required for all events
- **Multiple Roles**: Same talent can serve multiple roles (presenter + host + lead)
- **Referential Integrity**: All talent IDs must reference valid entries in talent table

### Performance Considerations
- **JOIN Query Optimization**: Single query with three talent JOINs vs multiple queries
- **Index Strategy**: Ensure proper indexing on all foreign key columns
- **Caching Impact**: Update any caching logic to account for new talent relationships

### Migration Safety
- **Backup Strategy**: Recommend database backup before running migration
- **Rollback Plan**: Document steps to reverse migration if needed
- **Testing Protocol**: Validate migration on development environment first
- **Downtime Minimization**: Migration designed for minimal application interruption

### Development Workflow
- **Incremental Testing**: Test each migration step individually
- **Interface Updates**: Update TypeScript interfaces before database changes
- **Component Testing**: Verify UI updates work with mock data before database migration
- **End-to-End Validation**: Full flow testing after all changes complete

## 5. Open Questions
_Unresolved technical or product questions affecting this release._

### Resolved Questions
1. **Q: Should meetup_host_id be required or optional?**
   A: Required - every event must have a meetup host

2. **Q: Do we need validation to prevent duplicate roles?**  
   A: No - same person can serve multiple roles in one event

3. **Q: What order should roles be displayed?**
   A: Hosted By, Presented By, Workshop Lead By (in that order)

4. **Q: Should we preserve existing data during table rename?**
   A: Yes - all existing presenter data must be preserved in talent table

5. **Q: How should we handle the database migration?**
   A: Create single migration script that can be run in Supabase

### No Outstanding Questions
All technical and product requirements have been clarified and documented above. The implementation approach is well-defined and ready for development.