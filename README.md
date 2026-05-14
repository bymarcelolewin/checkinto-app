# CheckInto App

[![Version](https://img.shields.io/badge/version-1.5.0-blue.svg)](https://github.com/bymarcelolewin/checkinto-app)
[![Release Notes](https://img.shields.io/badge/release_notes-view-green.svg)](release-notes.md)
[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](LICENSE)

A mobile-first web application that enables seamless self-service check-in for in-person community event attendees with real-time raffle functionality and full multi-tenant support.

## Purpose

This application streamlines the check-in process for community events by providing a simple, branded experience that:
- Eliminates manual attendance tracking
- Collects attendee information digitally
- Provides venue details to checked-in attendees
- Enables real-time raffle winner announcements during events
- Scales to support multiple community organizers through subdomain architecture

## How It Works

**For Attendees:**
1. Visit your community's custom URL: `https://{communityname}.checkinto.io/{eventId}`
2. Complete the simple two-screen flow:
   - **Event Screen** - View event details, venue info, and hosts immediately. Click "Check In" to register
   - **Check-In Form** - Provide name, email, and an interesting fact
   - After check-in, return to the Event Screen showing "You're checked in!" with raffle announcements

**Example:** [https://ibuildwithaimeetup.checkinto.io/012026](https://ibuildwithaimeetup.checkinto.io/012026)

## Key Features

### ✅ Core Check-In Flow
- Mobile-optimized responsive design
- Event-specific branding and messaging
- Real-time form validation
- Duplicate email handling (upsert logic)

### ✅ Raffle System
- Real-time winner announcements
- Support for multiple raffle rounds
- Personalized messaging for winners vs. non-winners
- Admin-triggered winner selection via Supabase Edge Functions

### ✅ Multi-Tenant Architecture
- **Subdomain-based routing** - Secure event access via `{communityname}.checkinto.io/{eventId}`
- **Per-community ownership** - Each community owns its own events, venues, and talent records
- **Shared attendee identity** - One global identity per email; a `community_attendee` join table tracks which communities each person has interacted with
- **Per-event context** - Each check-in stores its own "interesting fact" scoped to that specific gathering
- **Scalable design** - Support for unlimited community organizers without conflicts

### ✅ Donation Support
- Optional donation box with customizable message
- Database-driven content (no code changes needed)
- Conditional display - only shows when donation link is configured

## Tech Stack

- **Frontend**: SvelteKit with TypeScript
- **Styling**: Tailwind CSS with mobile-first design
- **Backend**: Supabase (PostgreSQL database, API, Edge Functions)
- **Hosting**: Vercel with custom domain routing
- **Domain**: Both checkinto.io and chkin.io with subdomain architecture

## Production Deployment

The application is deployed on Vercel with:
- Automatic deployments from main branch
- Custom domain configuration through Namecheap
- SSL certificates automatically managed
- Environment variables securely configured

## URL Structure & Multi-Tenant Routing

Events are accessed via: `https://{communityname}.checkinto.io/{eventId}`

The application automatically:
1. **Extracts the community identifier** from the subdomain (`{communityname}`)
2. **Validates event access** by checking both `eventId` AND `communityname` 
3. **Ensures data isolation** - communities cannot access each other's events even with same event IDs
4. **Provides fallback routing** for development environments via URL parameters

Examples:
- `https://ibuildwithaimeetup.checkinto.io/082025` - Building with AI community, August 2025 event
- `https://seattle.checkinto.io/082025` - Seattle community, August 2025 event (same ID, different community - no conflict!)
- `http://localhost:5173/082025?community=ibuildwithaimeetup` - Development routing

## Environment Variables

```sh
PUBLIC_SUPABASE_URL=your_supabase_project_url
PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
```

## Local Development

To run the application locally:

```sh
# Install dependencies
npm install

# Start development server
npm run dev
```

The app will be available at `http://localhost:5173`

To test a specific event, use the community query parameter:
```
http://localhost:5173/{eventId}?community={communityname}
```

Example: `http://localhost:5173/012026?community=ibuildwithaimeetup`

## Image Asset Organization

Assets are organized in a community-based structure for multi-tenant scaling:

```
static/images/communities/
└── {communityname}/
    ├── community/      # Community logos and branding
    ├── talent/         # Speaker/presenter photos  
    └── events/         # Event-specific images
```

**Example:**
```
static/images/communities/ibuildwithaimeetup/
├── community/ibuildwithaimeetup-banner.png
├── talent/marcelo-lewin.png
└── events/ (for future event images)
```

## Multi-Tenant Support Details

### Data Model
- **Per-community ownership** - Each community owns its own `event`, `venue`, and `talent` records via `community_id` foreign keys
- **Global attendee identity** - The `attendee` table holds one row per email across the entire system (`id`, `email`, `first_name`, `last_name`, timestamps). No per-community attendee duplication.
- **Many-to-many community membership** - The `community_attendee` join table records every (attendee, community) pair, populated automatically the first time someone checks in to one of a community's events
- **Per-event check-in details** - The `event_attendee` join table links attendees to events and stores the per-event `interesting_fact` shared at that specific gathering. Same person at two different events records two different facts.
- **Anon access lockdown** - Anonymous clients (the browser using the Supabase anon key) have **no direct grants** on `attendee`, `event_attendee`, or `community_attendee`. All check-in writes go through the `check_in_attendee()` SECURITY DEFINER Postgres function, which validates input server-side.
- **Secure routing** - Events are validated against both event ID and community profile name; communities cannot access each other's events even with identical event IDs

### Real-World Example
A user with email `john@example.com` can:
1. Register for `ibuildwithaimeetup.checkinto.io/082025` with the fact "Building an AI agent this month."
2. Later register for `seattle.checkinto.io/082025` with the fact "Visiting from Vancouver."
3. Later register for `vancouver.checkinto.io/082025` with the fact "Hosting a meetup next month."

There is exactly **one** John Smith row in the `attendee` table. The `community_attendee` table records his membership in all three communities. Each event records his fact for that gathering independently — the iBuildWithAI event still displays "Building an AI agent this month" even after he checks in to the Seattle and Vancouver events with different facts.

His name (e.g., "John Smith") is global identity — typing a different name at a later check-in updates the single attendee row across all communities. Per-community display names are not currently supported; they would be a future feature addition.

## License

This software is licensed under a **Commercial License**. 

- ✅ **Permitted**: Use for its intended purpose, viewing source code, educational study
- ❌ **Prohibited**: Modification, redistribution, derivative works, commercial redistribution

The source code is publicly available for transparency and educational purposes only. See the [LICENSE](LICENSE) file for complete terms and conditions.

For commercial licensing inquiries: marcelo@ibuildwith.ai
