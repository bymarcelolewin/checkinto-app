# Release Notes

This document lists new features, bug fixes and other changes implemented during a particular build, also known as a version.

## Table of Contents
- [v1.3.5-donation-link](#v135-donation-link---2026-01-28)
- [v1.3.4-unified-event-screen](#v134-unified-event-screen---2026-01-28)

---

# v1.3.5-donation-link - 2026-01-28

## Overview
This release adds an optional donation box to the Event Screen, allowing communities to request financial support from attendees. The donation box displays below the welcome message and is fully database-driven, appearing only when a donation link is configured.

## Key Features
- **Donation Box Component**: New UI section with customizable message and "Donate" button
- **Database-Driven Content**: Both the donation link and message are pulled from the `community` table
- **Conditional Display**: Box only appears when `donation_link` field has a value
- **Dual-State Visibility**: Donation box shows for both checked-in and non-checked-in users
- **Line Break Support**: Donation messages support `\n` for multi-line formatting

## Enhancements
- Updated Community interface with `donation_link` and `donation_message` fields
- Modified Supabase queries to fetch donation fields alongside community data
- Green gradient styling on Donate button matching existing Check In button
- Reduced button size from large to medium for better visual balance
- Tightened padding and spacing on welcome and donation boxes

## Bug Fixes
None

## Other Notes
- Database migration required: Add `donation_link` (text, nullable) and `donation_message` (text, nullable) columns to `community` table
- Uses existing `formatLineBreaks` utility for message formatting

---

# v1.3.4-unified-event-screen - 2026-01-28

## Overview
This release consolidates the three-screen user flow (Welcome → Check-in Form → Confirmation) into a streamlined two-screen flow (Event Screen → Check-in Form). Users now see all event details immediately upon arrival, with conditional UI elements based on their check-in status.

## Key Features
- **Unified Event Screen**: Merged Welcome and Confirmation screens into a single EventScreen component that adapts based on user's check-in status
- **Immediate Event Details**: Venue, hosts, WiFi, restrooms, and refreshments are now visible on initial page load
- **Conditional Check-In Display**: Shows "Check In" button for new users, "You're checked in!" message with checkmark icon for confirmed users
- **Clear Check-In Link**: Small footer link allowing users to reset their checked-in state for edge cases

## Enhancements
- Simplified navigation system reduced from 3 screen types to 2 ('event' | 'checkin')
- Welcome box styling with gray background matching event info grid
- Green gradient button with white text for check-in action
- Consistent spacing between banner and content boxes across screens
- Form page simplified to show only banner and form fields (removed redundant title)
- Raffle polling only activates when user is checked in, reducing unnecessary API calls

## Bug Fixes
None

## Other Notes
- Removed "Check In Another Person" button - each attendee should use their own device
- Deleted deprecated WelcomeScreen.svelte and ConfirmationScreen.svelte files
- Estimated ~400 lines of code reduced through component consolidation
