# CheckInto App

[![Version](https://img.shields.io/badge/version-1.3.4-blue.svg)](https://github.com/bymarcelolewin/checkinto-app)
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
- **Complete data isolation** - Each community maintains separate attendees, venues, and talent
- **Subdomain-based routing** - Secure event access via `{communityname}.checkinto.io/{eventId}`
- **Cross-community flexibility** - Same user can participate in multiple communities independently
- **Scalable design** - Support for unlimited community organizers without conflicts

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

### Data Isolation
- **Complete tenant separation** - Each community maintains its own attendees, venues, and talent records
- **Cross-community user support** - Same email address can register for events across different communities
- **Secure routing** - Events are validated against both event ID and community profile name
- **Database-level isolation** - All core tables include `community_id` foreign key constraints

### Real-World Example
A user with email `john@example.com` can:
1. Register for `ibuildwithaimeetup.checkinto.io/082025` as "John Smith"
2. Register for `seattle.checkinto.io/082025` as "J. Smith" 
3. Register for `vancouver.checkinto.io/082025` as "Johnny"

Each community sees them as separate attendees with their own check-in history, while the system maintains proper isolation and prevents conflicts.

## License

This software is licensed under a **Commercial License**. 

- ✅ **Permitted**: Use for its intended purpose, viewing source code, educational study
- ❌ **Prohibited**: Modification, redistribution, derivative works, commercial redistribution

The source code is publicly available for transparency and educational purposes only. See the [LICENSE](LICENSE) file for complete terms and conditions.

For commercial licensing inquiries: marcelo@redpillbluepillstudios.com

## Version History

- **v1.3.4** - Unified event screen combining welcome and confirmation into single adaptive screen
- **v1.3.3** - Added event-level flag for controlling event details visibility
- **v1.3.2** - GitHub organization migration to checkinto-io
- **v1.3.1** - DB Schema update for group table to "community" table
- **v1.3.0** - Complete multi-tenant architecture with data isolation and secure routing
- **v1.2.0** - CSS consolidation and styling improvements
- **v1.1.0** - Multi-tenant image folder restructure with community-based organization
- **v1.0.0** - Production deployment with custom domain and full feature set
- **v0.8.0** - Real-time raffle system implementation
- **v0.7.0** - Community host integration and talent management
- **v0.6.0** - Persistent state management for confirmation screens
- **v0.5.0** - Database schema normalization and optimization
- **v0.1.0-v0.4.0** - Core functionality development and polish
