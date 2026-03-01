# Service Account Analysis - v1.3.2

## Current Service Configurations (Before Migration)

### Vercel Configuration
**Current State:**
- **Personal Username:** icodewithai
- **Team Configuration:** (TBD - needs user verification)
- **Deployment Status:** Active (though domain DNS needs configuration)
- **Repository Connection:** Currently points to https://github.com/icodewith-ai/checkinto-app.git
- **Environment Variables:** Should be configured for Supabase integration

**Target State:**
- **Personal Username:** bymarcelolewin
- **Team Name:** checkintoapp-projects
- **Team URL:** checkintoapp-projects (to be confirmed)
- **Repository Connection:** Will update to https://github.com/checkinto-io/checkinto-app.git

**Migration Steps Required:**
1. Change personal username from icodewithai → bymarcelolewin
2. Update team name to checkintoapp-projects
3. Verify deployment continues working after GitHub transfer
4. Ensure environment variables persist

### Supabase Configuration
**Current State:**
- **Organization Display Name:** (Current name unknown - needs user verification)
- **Project Configuration:** Active and functional
- **Database:** PostgreSQL with community, event, venue, talent, and related tables
- **Edge Functions:** Raffle system functionality active
- **API Keys:** Should remain the same (no URL changes planned)

**Target State:**
- **Organization Display Name:** "Check Into App"
- **All other configurations:** Remain unchanged
- **Project URL:** Should stay the same (only display name changing)

**Migration Steps Required:**
1. USER updates organization display name to "Check Into App"
2. Verify no URL or API key changes needed
3. Test that Edge Functions continue working

### Domain Configuration
**Current State:**
- **Primary Domain:** checkinto.io (owned but DNS not configured)
- **Subdomain Pattern:** {communityname}.checkinto.io/{eventId}
- **Current Test:** codingwithai.checkinto.io shows default SvelteKit page

**Target State:**
- **Same Domain:** checkinto.io
- **Same Subdomain Pattern:** {communityname}.checkinto.io/{eventId}
- **Proper Configuration:** DNS pointing to Vercel with working subdomains

**Migration Steps Required:**
1. Ensure Vercel account changes don't break domain configuration
2. Configure DNS properly for checkinto.io → Vercel
3. Test subdomain routing after migration

### Environment Variables Analysis
**Expected Configuration:**
```
PUBLIC_SUPABASE_URL=your_supabase_project_url
PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
```

**Migration Risk Assessment:**
- Environment variables should persist through Vercel account changes
- Supabase keys should remain valid (no URL changes)
- Need to verify after GitHub transfer

### Critical Dependencies
1. **GitHub Repository Transfer** → Affects Vercel deployment source
2. **Vercel Account Changes** → May affect domain configuration
3. **Domain DNS Configuration** → Currently not working, needs setup
4. **Supabase Organization Name** → Cosmetic change only

### Risk Assessment
- **Low Risk:** Supabase organization rename (display only)
- **Medium Risk:** Vercel account/team changes (may need reconnection)
- **Medium Risk:** GitHub transfer (Vercel should auto-reconnect)
- **High Risk:** Domain DNS configuration (currently broken, needs fixing)

### User Actions Required
1. **GitHub Transfer:** Transfer repository to checkinto-io organization
2. **Vercel Username:** Change personal username to bymarcelolewin
3. **Vercel Team:** Update team name to checkintoapp-projects
4. **Supabase:** Rename organization display name to "Check Into App"
5. **DNS:** Configure checkinto.io to point to Vercel properly

### Verification Steps After Migration
1. Test deployment pipeline works with new repository
2. Verify checkinto.io domain resolves and works
3. Test subdomain routing: codingwithai.checkinto.io
4. Verify application functionality (check-in flow)
5. Test raffle system (Supabase Edge Functions)
6. Confirm environment variables are intact