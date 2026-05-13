# Multi-Tenant Logic Analysis

## Scenario: Cross-Group Check-ins

### Test Case
- Email: `marcelo@thelewinbunch.com`
- 3 Groups: Group A, Group B, Group C
- Each group has 2 events
- User uses different names each time

### Expected Behavior

| Check-in | Group | Event | Name Used | Expected Result |
|----------|-------|-------|-----------|----------------|
| 1 | Group A | Event 1 | "Marc Lewin" | Creates new attendee record |
| 2 | Group A | Event 2 | "Marcelo L" | Updates Group A attendee |
| 3 | Group B | Event 1 | "M Lewin-Bunch" | Creates new attendee record |
| 4 | Group B | Event 2 | "Marcie LB" | Updates Group B attendee |
| 5 | Group C | Event 1 | "Marcel Bunch" | Creates new attendee record |

### Final Attendee Table State
```
| id | email                      | first_name | last_name    | group_id      |
|----|----------------------------|------------|--------------|---------------|
| 1  | marcelo@thelewinbunch.com  | Marcelo    | L            | group-a-uuid  |
| 2  | marcelo@thelewinbunch.com  | Marcie     | LB           | group-b-uuid  |
| 3  | marcelo@thelewinbunch.com  | Marcel     | Bunch        | group-c-uuid  |
```

## Current Implementation Analysis

### ✅ Email Registration Check (`isEmailRegisteredForEvent`)
```typescript
static async isEmailRegisteredForEvent(eventId: string, email: string): Promise<boolean> {
    const { data, error } = await supabase
        .from('event_attendee')
        .select('attendee!inner(email)')
        .eq('event_id', eventId)
        .eq('attendee.email', email)
        .limit(1);
    
    return data && data.length > 0;
}
```

**Status: ✅ CORRECT**
- Queries through `event_attendee -> attendee` relationship
- Since events are group-isolated, only finds attendees within same group
- Properly prevents duplicate registrations within same group/event

### ✅ Attendee Creation (`checkInAttendee`)
```typescript
// Get event to retrieve group_id
const event = await this.getEventById(eventId);

// Add group_id to attendee data
const attendeeDataWithGroup = {
    ...attendeeData,
    group_id: event.group_id
};

// Upsert the attendee
const attendee = await this.upsertAttendee(attendeeDataWithGroup);
```

**Status: ✅ CORRECT**
- Automatically gets group_id from event
- Ensures attendee is associated with correct group
- Maintains proper tenant isolation

### 🚨 Database Constraint Issue

**Current Schema:**
```sql
CREATE TABLE public.attendee (
  -- ...
  email text NOT NULL UNIQUE,
  -- ...
  group_id uuid NOT NULL,
  -- ...
);
```

**Problem:**
The `UNIQUE` constraint on `email` prevents the same email from being used across different groups, which breaks the multi-tenant design.

**Required Fix:**
```sql
-- Remove current unique constraint
ALTER TABLE public.attendee DROP CONSTRAINT attendee_email_key;

-- Add composite unique constraint
ALTER TABLE public.attendee ADD CONSTRAINT attendee_email_group_unique UNIQUE (email, group_id);
```

## Impact Assessment

### With Current Schema (BROKEN)
- ❌ Same email cannot register for events in different groups
- ❌ Database error when trying to create attendee with existing email
- ❌ Multi-tenant isolation is compromised

### With Fixed Schema (CORRECT)
- ✅ Same email can register for events in different groups
- ✅ Each group maintains separate attendee records
- ✅ Proper multi-tenant isolation
- ✅ No cross-group data leakage

## Recommended Actions

1. **Immediate Fix Required:**
   ```sql
   ALTER TABLE public.attendee DROP CONSTRAINT attendee_email_key;
   ALTER TABLE public.attendee ADD CONSTRAINT attendee_email_group_unique UNIQUE (email, group_id);
   ```

2. **Update Schema Documentation:**
   - Update `database/latest-schema.sql` with correct constraint

3. **Testing:**
   - Test cross-group check-ins with same email
   - Verify upsert behavior within same group
   - Confirm no cross-group data access

## Code Review Status

| Component | Status | Notes |
|-----------|--------|-------|
| Email registration check | ✅ Correct | Properly isolated through event relationship |
| Attendee creation logic | ✅ Correct | Automatically assigns correct group_id |
| Database constraints | 🚨 Needs Fix | Email uniqueness breaks multi-tenancy |
| TypeScript interfaces | ✅ Correct | All include group_id field |
| Frontend forms | ✅ Correct | No changes needed |

## Multi-Tenant Principles Validation

- ✅ **Data Isolation:** Each group has separate attendee records
- ✅ **Security:** No cross-group data access possible
- 🚨 **Scalability:** Blocked by email constraint issue
- ✅ **Flexibility:** Same user can participate in multiple groups
- ✅ **Maintainability:** Clean separation of concerns