# Discovery
This document captures the raw, unfiltered idea or initial AI prompt that sparked the project.

## Starting Prompt
I have a Meetup where people come to see presentations in person.  This is not online.   It's at a physical location.   My app's flow is as follows.

1. User goes to particular URL for that event.
2. They get a "Welcome screen" that has a welcome message and big button that says "check-in".
3. When they click on "check-in", it sends them to the check-in screen with 4 fields (first name, last name and email address, share something interesting fact about themselves).  There is also a "Check In" button.  
4. They click on the "Check In" button, it sends them to the "Checked In" Screen that shows them the "Checked In Message".

The app is mobile first.  Needs to work for phone screens.  Must be web (accessible via a URL).   The URL will be: https://meetup.icodewith.ai/eventid/

I want to use Supabase for the database. I think it should have 3 tables.   Please look at the @assets folder at the @Meetup Online Registration Proposed DB.png image for the proposed DB structure.  I'm open to any other suggestions.  

From a tech stack, I want it to be very light and simple.   Use a framework that will accomplish doing this securely, but is not bloated.

From a UX perspective, I want to keep it simple, elegant and large buttons (not too large, but easy to navigate)

## Q&A
**[AI AGENT TODO: Ask the user as many questions as you need to fully understand the project.  Try not to overload the USER with too many though.  Remember you can have follow up questions after the USER answers the initial ones.]**

**[AI AGENT TODO: When iterating on the q&a, separate new questions by sections (e.g. *** Clarification Questions *** ).]**

*** Technical Clarification Questions ***

**AGENT Q1:** I don't see the assets folder or the DB schema image you referenced. Could you share the proposed database structure or tell me where to find it?

> Check .vibedocs/assets/Meetup Online Registration Proposed DB.png

**AGENT Q2:** For the tech stack - are you open to suggestions like Next.js, SvelteKit, or Nuxt.js for the framework? These are lightweight but secure options that work well with Supabase.

> 100% open. But light, secure and easy to maintain is the key/

**AGENT Q3:** What information do you need to capture about the events themselves? Just the event ID from the URL, or do you need event names, descriptions, dates, etc.?

> The image listed in Q1 will tell you.

*** User Flow & Features Questions ***

**AGENT Q4:** Should there be any validation on the check-in form (required fields, email format, duplicate prevention)?

> All fields are required.  You will have a userID, but when you save their information, the key (unique) will be their email.  So you'll update / insert via that.

**AGENT Q5:** Do you need an admin interface to view check-ins, or is this purely for attendee self-check-in?

> I think I can use supabase.  For this iteration, not now.  Maybe we'll do that later.

**AGENT Q6:** Should the "interesting fact" field have a character limit? Any content moderation needed?

> I think keeping it to a standard 255 character limit of a varchar?

*** Authentication & Security Questions ***

**AGENT Q7:** Do you need any authentication for event organizers, or is the event accessible to anyone with the URL?

> Nope.  Anyone with the URL.   I do want the ability to turn it off.  Now that you asked that, so in the databased image I provided you, we should add a "active" field (boolean).  If it's active, the URL will display the welcome message.  If it's not, it will say, "This event is no longer active".

**AGENT Q8:** Should there be any rate limiting to prevent spam check-ins?

> Well, it's only for the people that show up.  So what do you think?  I'll let you make that decision.

**USER A8:** I recommend basic rate limiting (like 1 check-in per email per event) since you're using email as the unique key anyway. This prevents accidental duplicate submissions while keeping it simple.

*** Hosting Questions ***

**AGENT Q9:** Where can I host this? I have netlify. What do you recommend?

**USER A9:** Since you have Netlify and we're using Supabase, this is actually a perfect combination! Netlify is excellent for hosting static sites and SvelteKit apps. Here's my recommendation:

- **Frontend**: Deploy SvelteKit app to Netlify (supports SSR and static generation)
- **Backend**: Supabase handles database, API, and authentication
- **Domain**: You can use Netlify's custom domain features for meetup.icodewith.ai
- **Benefits**: Free tier available, automatic deployments from Git, edge functions if needed, excellent performance

This keeps your hosting costs minimal while providing enterprise-grade reliability.

## Discovery Summary

Based on our Q&A, here's my understanding of your meetup check-in application:

**Core Application:**
- Mobile-first web app for in-person meetup check-ins
- Simple 3-screen flow: Welcome → Check-in Form → Confirmation
- URL structure: `https://meetup.icodewith.ai/eventid/`
- Built with lightweight, secure framework (SvelteKit recommended)
- Supabase backend for database and hosting

**Database Structure (3 tables):**
1. **Events** - ID, URL_ID, Title, Welcome Message, Checked In Message, Active (boolean)
2. **Attendees** - ID, First Name, Last Name, Email (unique), Interesting Fact
3. **Event_Attendees** - Event ID, Attendee ID (junction table)

**Key Features:**
- All form fields required with email validation
- Upsert logic using email as unique identifier
- Event activation toggle (active events show welcome, inactive show "no longer active")
- Clean, elegant UI with large, accessible buttons
- No admin interface needed initially (using Supabase dashboard)
- 255 character limit on interesting facts
- Basic rate limiting (1 check-in per email per event)

**Technical Requirements:**
- Secure, lightweight, maintainable codebase
- Mobile-responsive design
- No authentication required for attendees
- Public URL access for anyone with the link

**Hosting & Deployment:**
- Frontend: Netlify (SvelteKit deployment)
- Backend: Supabase (database, API)
- Domain: meetup.icodewith.ai via Netlify
- Cost-effective solution with free tiers available