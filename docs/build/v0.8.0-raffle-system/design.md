# Release Design Document : v0.8.0-raffle-system
Technical implementation and design guide for the upcoming release.

## 1. Features Summary
_Overview of features included in this release._

This release implements a comprehensive raffle winner announcement system for meetup events:

- **Database Schema Updates**: Add `raffle_winner` (boolean) and `raffle_round` (integer) fields to `event_attendee` table
- **Meetup Display Control**: Add `raffle_winners_to_display` (integer, default 1) field to `meetup` table for controlling winner announcements
- **Real-time Winner Display**: Frontend polling every 5 seconds to check for new raffle winners
- **Personalized Messaging**: Different messages for winners vs. non-winners with personalized congratulations
- **Admin Winner Selection**: Supabase script for administrators to randomly select winners with race condition protection
- **Multiple Winners Support**: Support for multiple raffle rounds with ordinal display (1st, 2nd, 3rd Place, etc.)
- **Complex Query Joins**: Chain `event_attendee` → `attendee` → `event` → `meetup` to retrieve display settings and winner data

## 2. Technical Architecture Overview
_High-level technical structure that supports all features in this release._

**Database Layer Changes:**
- **Event Attendee Table**: Add `raffle_winner` (boolean, default false) and `raffle_round` (integer, nullable) columns
- **Meetup Table**: Add `raffle_winners_to_display` (integer, default 1) column to control how many winners are displayed
- **Data Integrity**: Maintain existing foreign key relationships and constraints
- **Race Condition Protection**: Use database transactions and atomic operations for winner selection

**Frontend Polling Architecture:**
- **5-Second Interval**: Continuous polling to fetch latest winner status from API
- **Efficient Queries**: JOIN queries across four tables to minimize database calls
- **State Management**: Track current winners and update UI reactively
- **Personalization Logic**: Client-side logic to determine if current user is a winner

**Admin Script Architecture:**
- **Supabase Function**: Server-side script for secure winner selection
- **Random Selection**: SQL-based random selection with transaction safety
- **Round Management**: Support for multiple raffle rounds with proper sequencing
- **Audit Trail**: Track when winners were selected via database timestamps

**User Experience Flow:**
- **Confirmation Screen Enhancement**: Add winner announcement section at the top in its own classy box, pushing content down
- **Real-time Updates**: Winners appear without page refresh via polling
- **Personalized Messaging**: Dynamic text based on user's winner status
- **Graceful Degradation**: Handle API failures and network issues

## 3. Implementation Notes
_Shared technical considerations across all features in this release._

**Database Schema Migration:**
- Add `raffle_winner BOOLEAN DEFAULT false` to `event_attendee` table
- Add `raffle_round INTEGER` (nullable) to `event_attendee` table  
- Add `raffle_winners_to_display INTEGER DEFAULT 1` to `meetup` table
- Create composite index on `(event_id, raffle_winner, raffle_round)` for efficient winner queries
- Maintain backward compatibility with existing `event_attendee` records

**Frontend Polling Implementation:**
- Use `setInterval()` with 5-second polling in ConfirmationScreen component
- Implement `onMount()` and `onDestroy()` lifecycle hooks for proper cleanup
- Create dedicated API endpoint `/api/events/[eventId]/winners` for winner data
- Handle component unmounting to prevent memory leaks
- Implement exponential backoff on API failures

**Query Architecture:**
```sql
SELECT 
  ea.raffle_winner, ea.raffle_round,
  a.first_name, a.last_name,
  m.raffle_winners_to_display
FROM event_attendee ea
JOIN attendee a ON ea.attendee_id = a.id  
JOIN event e ON ea.event_id = e.id
JOIN meetup m ON e.meetup_id = m.id
WHERE ea.event_id = ? AND ea.raffle_winner = true
ORDER BY ea.raffle_round ASC
```

**Winner Selection Script:**
- Implement as Supabase Edge Function for security
- Use `BEGIN/COMMIT` transactions for atomicity
- Select random attendees excluding existing winners
- Update `raffle_winner` and `raffle_round` fields atomically
- Return winner details for confirmation

**TypeScript Type Updates:**
- Extend `EventAttendee` interface with raffle fields
- Extend `Meetup` interface with `raffle_winners_to_display` field
- Create `RaffleWinner` interface for API responses
- Add type guards for raffle-related data validation

## 4. Other Technical Considerations
_Shared any other technical information that might be relevant to building this release._

**Performance Considerations:**
- Index `(event_id, raffle_winner, raffle_round)` for fast winner queries
- Limit polling queries to only fetch changed data (consider ETags)
- Cache winner data on frontend to reduce redundant API calls
- Monitor database performance with increased query frequency

**Security Considerations:**
- Admin script requires authentication/authorization
- Validate event ownership before allowing winner selection
- Prevent unauthorized access to winner selection endpoints
- Rate limiting on polling endpoints to prevent abuse

**Error Handling:**
- Graceful degradation when raffle features are disabled
- Handle network failures in polling with retry logic
- Fallback messages when winner data cannot be loaded
- User-friendly error messages for admin script failures

**Scalability Considerations:**
- Polling frequency may need adjustment for large events
- Consider WebSocket upgrade for real-time updates in future
- Database connection pooling for increased concurrent polling
- Monitor API rate limits and implement client-side throttling

**Browser Compatibility:**
- Ensure `setInterval()` cleanup works across all target browsers
- Test polling behavior with browser tab switching/background
- Handle browser refresh scenarios gracefully
- Consider service worker for background polling (future enhancement)

## 5. Open Questions
_Unresolved technical or product questions affecting this release._

1. **Polling Frequency**: Is 5-second polling optimal, or should it be configurable per meetup?
   - Consider impact on server load with multiple simultaneous events
   - Balance between real-time experience and resource usage

   > The closer to real time the better.   But balance that with performance.

2. **Winner Selection Timing**: Should there be a delay between raffle rounds, or is immediate sequential selection acceptable?
   - May need UI controls for admin to pace announcements
   - Consider dramatic effect vs. efficient selection

   > Let's not worry about this now. I'm running it.  For now, make a note of this.  I'll know to wait a couple of seconds in between if I run multiple raffles.

3. **Historical Winner Data**: Should past winners be displayed after new rounds are selected, or only current round?
   - Storage implications for long-term winner history
   - UI complexity for displaying multiple rounds simultaneously

   > It's based on the field in meetup table.

4. **Offline Handling**: How should the system behave when users are offline during winner announcements?
   - Consider local storage for winner status
   - Sync mechanism when connectivity returns

   > I think offline syncing is for the future. Right now, it won't work for them.

5. **Admin Interface**: Should winner selection be integrated into existing admin UI, or remain as separate script?
   - User experience for event organizers
   - Integration with existing authentication system

   > No admin interface.

6. **Winner Validation**: Should there be confirmation step before announcing winners, or immediate display?
   - Prevent accidental selections
   - Balance between safety and user experience

   > Nope.  Once the script picks it, after the 5 second polling, it should announce it.

7. **Multiple Event Polling**: If user has multiple browser tabs for different events, how to handle concurrent polling?
   - Resource usage optimization
   - Shared worker vs. individual timers

   > Let's not worry about this for now.  Put it on the backlog.

8. **Raffle Round Limits**: Should there be a maximum number of raffle rounds per event?
   - Database storage considerations
   - UI limitations for displaying many winners

   > Not really.  Not right now.