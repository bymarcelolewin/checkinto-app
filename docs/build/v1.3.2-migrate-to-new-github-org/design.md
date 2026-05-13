# Release Design Document: v1.3.2-migrate-to-new-github-org
Technical implementation and design guide for migrating the CheckInto project from `icodewith-ai` organization to `checkinto-io` organization.

## 1. Features Summary
_Overview of features included in this release._

This release focuses on organizational migration and service account consolidation:

- **GitHub Repository Migration**: Transfer `checkinto-app` from `icodewith-ai` to `checkinto-io` organization
- **Service Account Updates**: Update Vercel personal username to `bymarcelolewin` and team to `checkintoapp-projects`  
- **Supabase Organization Rename**: Update display name to "Check Into App"
- **Documentation Updates**: Update all references to new GitHub organization and contact information
- **Deployment Verification**: Ensure all services continue working with new configuration

## 2. Technical Architecture Overview
_High-level technical structure that supports all features in this release._

**Current State:**
- Repository: `https://github.com/icodewith-ai/checkinto-app.git`
- Vercel: Personal account `icodewithai` with deployment
- Supabase: Organization with existing display name
- Domains: checkinto.io configured through Vercel

**Target State:**
- Repository: `https://github.com/checkinto-io/checkinto-app.git`
- Vercel: Personal username `bymarcelolewin`, team `checkintoapp-projects`
- Supabase: Organization display name "Check Into App"
- Domains: checkinto.io domain, updated deployment configuration

**Migration Strategy:**
1. **GitHub Transfer** - Use GitHub's built-in repository transfer feature
2. **Service Updates** - Update account settings in Vercel and Supabase
3. **Local Configuration** - Update git remotes and documentation
4. **Verification** - Test deployment and domain routing

## 3. Implementation Notes
_Shared technical considerations across all features in this release._

**Critical Order of Operations:**
1. Complete GitHub transfer first to minimize downtime
2. Update Vercel configuration to point to new repository
3. Update local development environment  
4. Update documentation and references
5. Test deployment pipeline thoroughly

**Risk Mitigation:**
- GitHub transfer preserves all history, issues, and settings
- Vercel deployments should automatically redirect to new repository after transfer
- Local git remotes need manual updating
- Domain configuration should remain intact during transfer

**Files Requiring Updates:**
- `README.md` - GitHub badge URL and contact email
- `package.json` - Version number update to 1.3.2
- Local git configuration - Remote origin URL
- `.vercel/` directory - Clear build artifacts for fresh deployment

## 4. Other Technical Considerations
_Any other technical information that might be relevant to building this release._

**Domain Considerations:**
- Primary domain: checkinto.io 
- Subdomain routing: `{communityname}.checkinto.io/{eventId}`
- No domain configuration changes required

**Service Account Security:**
- Vercel username change from `icodewithai` to `bymarcelolewin` for brand consistency
- Team name `checkintoapp-projects` allows for future project expansion
- All API keys and environment variables should remain functional

**Deployment Pipeline:**
- Vercel auto-deployment from main branch should continue working
- SSL certificates automatically managed through Vercel
- No downtime expected during GitHub transfer

**Legacy Support:**
- Old GitHub URLs will automatically redirect after transfer
- Existing deployment should remain functional during transition
- Domain configuration preserved

## 5. Open Questions
_Unresolved technical or product questions affecting this release._

**Resolved through discussion:**
- ✅ Repository name: Keep as `checkinto-app`
- ✅ Transfer method: Use GitHub's transfer feature, then delete old copy
- ✅ Vercel approach: Update existing personal account username, update team name
- ✅ Supabase approach: Display name change only, no URL changes
- ✅ Domain strategy: Keep existing domains (checkinto.io, chkin.io)

**Still to verify during implementation:**
- Will Vercel deployment automatically reconnect after GitHub transfer?
- Are there any webhook URLs or external services that reference the old repo?
- Do we need to notify any external services about the migration?