# Release Notes

This document lists new features, bug fixes and other changes implemented during a particular build, also known as a version.

## Table of Contents
- [v1.3.4-unified-event-screen](#v134-unified-event-screen---2026-01-28)

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
