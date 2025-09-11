-- Migration: v1.3.3-add-show-event-details-field.sql
-- Purpose: Add show_event_details boolean field to event table for controlling confirmation page display
-- Date: 2025-01-10
-- Version: v1.3.3-add-event-flag-for-checked-in-page
-- 
-- This migration adds a new boolean field 'show_event_details' to the event table that allows
-- organizers to control whether attendees see the detailed event information box on the 
-- confirmation/checked-in page.
--
-- Default value: true (maintains current behavior for all existing events)
-- 
-- IMPORTANT: This script should be run in a transaction. Test thoroughly before production.

BEGIN;

-- Step 1: Add the new show_event_details column to the event table
-- Default to true to maintain current behavior for existing events
ALTER TABLE event 
ADD COLUMN show_event_details BOOLEAN NOT NULL DEFAULT true;

-- Step 2: Explicitly set all existing events to show_event_details = true
-- This ensures consistent behavior even if the default changes in the future
UPDATE event 
SET show_event_details = true 
WHERE show_event_details IS NULL OR show_event_details IS NOT true;

-- Step 3: Add a comment to document the field's purpose
COMMENT ON COLUMN event.show_event_details IS 'Controls whether the event details box is displayed on the confirmation page after check-in. When false, attendees will not see community, venue, or talent information.';

-- Step 4: Verification queries (commented out - uncomment to verify after migration)
-- 
-- Verify column was added:
-- SELECT column_name, data_type, is_nullable, column_default 
-- FROM information_schema.columns 
-- WHERE table_name = 'event' AND column_name = 'show_event_details';
--
-- Verify all existing events have show_event_details = true:
-- SELECT COUNT(*) as total_events, 
--        COUNT(*) FILTER (WHERE show_event_details = true) as events_with_details_true,
--        COUNT(*) FILTER (WHERE show_event_details = false) as events_with_details_false
-- FROM event;
--
-- Sample query to test the new field:
-- SELECT id, title, show_event_details FROM event LIMIT 5;

COMMIT;

-- Post-migration notes:
-- 1. Frontend code will need to be updated to check this field before rendering event details
-- 2. Database service methods should include this field in event queries
-- 3. TypeScript Event interface needs to be updated to include show_event_details: boolean
-- 4. Consider adding admin interface in future releases to manage this setting
-- 5. Performance optimization: skip fetching event details when show_event_details = false