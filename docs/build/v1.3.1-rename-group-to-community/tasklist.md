# Release Tasklist – v1.3.1-rename-group-to-community
This document outlines all the tasks to work on to delivery this particular version, grouped by phases.

| Status |      |
|--------|------|
| 🔴 | Not Started |
| 🟡 | In Progress |
| 🟢 | Completed |

## Phase 1: Database Schema Migration

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|----------|--------|
| T001 | Create Migration Script | Create complete SQL migration script: rename group→community table, all foreign keys (group_id→community_id, group_host_id→community_host_id), and constraint names | None | 🟢 Completed | AGENT |
| T002 | Execute Migration | Run migration script in database | T001 | 🟢 Completed | USER |
| T003 | Verify Migration | Confirm all tables, fields, and constraints updated correctly | T002 | 🟢 Completed | AGENT |

## Phase 2: Database Functions Update

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|----------|--------|
| T004 | Update Database Functions | Update get-raffle-winners.sql to use community table, verify select-raffle-winner.sql | T003 | 🟢 Completed | AGENT |
| T005 | Test Database Functions | Execute functions to ensure no PostgreSQL reserved keyword errors | T004 | 🟢 Completed | USER |

## Phase 3: Frontend Code Updates

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|----------|--------|
| T006 | Update TypeScript Interfaces | Change all Group interfaces to Community in /src/lib/types/ and app.d.ts | T005 | 🟢 Completed | AGENT |
| T007 | Update Database Services | Update Supabase queries, service methods, and all foreign key references (group_id→community_id, group_host_id→community_host_id) | T006 | 🟢 Completed | AGENT |

## Phase 4: Component Updates

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|----------|--------|
| T008 | Update All Components | Update WelcomeScreen, CheckinForm, ConfirmationScreen, and Error components to use Community types and prop references | T007 | 🟢 Completed | AGENT |
| T008B | Update Static Image Folders | Rename static/images/groups → communities and group → community category folders | T008 | 🟢 Completed | USER |

## Phase 5: Testing and Final Steps

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|----------|--------|
| T009 | Comprehensive Testing | Test all application functionality, database functions, and data integrity | T008 | 🟢 Completed | USER |
| T010 | Update Schema Documentation | Update latest-schema.sql with community table structure | T009 | 🟢 Completed | AGENT |
| T011 | Final Verification | Project-wide search for any remaining "group" references and fix if found | T010 | 🟢 Completed | AGENT |
| T011B | Update README.md | Replace group references with community terminology | T011 | 🟢 Completed | AGENT |
| T012 | Commit Changes | Git commit with all group → community changes | T011B | 🟢 Completed | USER |