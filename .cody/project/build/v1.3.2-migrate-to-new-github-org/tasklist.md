# Release Tasklist – v1.3.2-migrate-to-new-github-org
This document outlines all the tasks to work on to deliver this particular version, grouped by phases.

| Status |      |
|--------|------|
| 🔴 | Not Started |
| 🟡 | In Progress |
| 🟢 | Completed |


## Phase 1: Pre-Migration Preparation

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|--------|---------| 
| T001 | Version Update | Update package.json version to 1.3.2 | None | 🟢 Completed | AGENT |
| T002 | Pre-migration Backup | Verify current deployment state and create backup notes | None | 🟢 Completed | AGENT |
| T003 | Service Account Analysis | Document current Vercel and Supabase configurations | None | 🟢 Completed | AGENT |

## Phase 2: GitHub Repository Migration

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|--------|---------|
| T004 | Repository Transfer | Transfer repo from icodewith-ai to checkinto-io organization | T001-T003 | 🟢 Completed | USER |
| T005 | Verify Transfer Complete | Confirm repo is accessible at new location | T004 | 🟢 Completed | AGENT |
| T006 | Delete Old Copy | Remove any remaining copy from old organization | T005 | 🟢 Completed | USER |

## Phase 3: Local Development Environment Updates

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|--------|---------|
| T007 | Update Git Remote | Change local git remote to new repository URL | T005 | 🟢 Completed | AGENT |
| T008 | Clear Build Artifacts | Remove .vercel directory contents for fresh deployment | T007 | 🟢 Completed | AGENT |
| T009 | Test Local Development | Verify local development environment still works | T008 | 🟢 Completed | AGENT |

## Phase 4: Service Account Updates

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|--------|---------|
| T010 | Supabase Organization Rename | Update Supabase organization display name to "Check Into App" | None | 🟢 Completed | USER |
| T011 | Vercel Username Update | Change Vercel personal username from icodewithai to bymarcelolewin | T005 | 🟢 Completed | USER |
| T012 | Vercel Team Update | Update team name to CheckInto Projects and team URL to checkinto-projects | T011 | 🟢 Completed | USER |
| T013 | Vercel Deployment Reconnection | Ensure deployment points to new GitHub repository | T012 | 🟢 Completed | USER |

## Phase 5: Documentation and Reference Updates

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|--------|---------|
| T014 | Update README Badge | Change GitHub badge URL to checkinto-io organization | T007 | 🟢 Completed | AGENT |
| T015 | Update Contact Email | Change contact email from marcelo@icodewith.ai to marcelo@redpillbluepillstudios.com | T014 | 🟢 Completed | AGENT |
| T016 | Update Vibedocs Version | Update vdconfig.json version if needed | T015 | 🟢 Completed (Not Required) | AGENT |

## Phase 6: Deployment Verification and Testing

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|--------|---------|
| T017 | Test Deployment Pipeline | Trigger new deployment and verify it works with new configuration | T013 | 🟢 Completed | USER |
| T018 | Verify Domain Routing | Test that checkinto.io subdomain routing still works correctly | T017 | 🟢 Completed | USER |
| T019 | Test Application Functionality | Complete end-to-end test of check-in flow | T018 | 🟢 Completed | USER |
| T020 | Verify Raffle System | Test that Supabase Edge Functions still work properly | T019 | 🟢 Completed | USER |

## Phase 7: Final Validation and Cleanup

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|--------|---------|
| T021 | Migration Verification | Confirm all services and integrations are working with new setup | T020 | 🟢 Completed | USER |
| T022 | Documentation Cleanup | Update any remaining references or documentation | T021 | 🟢 Completed | AGENT |
| T023 | Final Testing | Comprehensive testing of production environment | T022 | 🟢 Completed | USER |