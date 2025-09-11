# Release Tasklist – v0.7.0-add-meetup-host-combine-people
This document outlines all the tasks to work on to delivery this particular version, grouped by phases.

| Status |      |
|--------|------|
| 🔴 | Not Started |
| 🟡 | In Progress |
| 🟢 | Completed |


## **Phase 1: Database Migration Planning**

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|----------|--------|
| T001 | Create database migration script | Create SQL migration to rename presenter→talent, add meetup_host_id, rename workshop_host_id→workshop_lead_id | None | 🟢 Completed | AGENT |
| T002 | Validate migration script syntax | Test migration script syntax and ensure it handles constraints properly | T001 | 🟢 Completed | AGENT |
| T003 | Create rollback migration script | Create reverse migration script in case rollback is needed | T001 | 🟢 Completed | AGENT |


## **Phase 2: TypeScript Interface Updates**

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|----------|--------|
| T004 | Update Presenter interface to Talent | Rename Presenter interface to Talent throughout codebase | None | 🟢 Completed | AGENT |
| T005 | Update Event interface | Add meetup_host field, rename workshop_host to workshop_lead in Event interface | T004 | 🟢 Completed | AGENT |
| T006 | Update all type imports and exports | Update all imports/exports that reference Presenter to use Talent | T004, T005 | 🟢 Completed | AGENT |


## **Phase 3: Database Service Updates**

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|----------|--------|
| T007 | Update database service queries | Modify JOIN queries to fetch meetup_host and reference talent table instead of presenter | T005 | 🟢 Completed | AGENT |
| T008 | Update validation logic | Update getEventByUrlId validation to check for all three talent relationships | T007 | 🟢 Completed | AGENT |
| T009 | Test database service changes | Verify all database operations work with new schema (before running migration) | T007, T008 | 🟢 Completed | AGENT |


## **Phase 4: UI Component Updates**

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|----------|--------|
| T010 | Update ConfirmationScreen component | Add "Hosted By" section, rename "Workshop Host" to "Workshop Lead By", update order | T005 | 🟢 Completed | AGENT |
| T011 | Update component heading labels | Change headings to "Hosted By", "Presented By", "Workshop Lead By" | T010 | 🟢 Completed | AGENT |
| T012 | Add person icon for meetup host | Use same person icon style for new "Hosted By" section | T010 | 🟢 Completed | AGENT |


## **Phase 5: Database Migration Execution**

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|----------|--------|
| T013 | Run database migration in Supabase | Execute the migration script to update schema and data | T001, T002, T003, T009 | 🟢 Completed | USER |
| T014 | Verify migration success | Confirm all data migrated correctly and constraints are proper | T013 | 🟢 Completed | USER |
| T015 | Update existing events with meetup_host_id | Populate the new required meetup_host_id field for existing events | T013, T014 | 🟢 Completed | USER |


## **Phase 6: Integration Testing**

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|----------|--------|
| T016 | Test event loading with new schema | Verify events load properly with all three talent relationships | T015 | 🟢 Completed | AGENT |
| T017 | Test confirmation screen display | Verify all three role sections display correctly with proper data | T016 | 🟢 Completed | AGENT |
| T018 | Test talent links functionality | Verify all talent links work properly for all three roles | T017 | 🟢 Completed | AGENT |


## **Phase 7: Final Validation & Cleanup**

| ID  | Task             | Description                             | Dependencies | Status | Assigned To |
|-----|------------------|-----------------------------------------|-------------|----------|--------|
| T019 | End-to-end testing | Complete flow testing from welcome to confirmation with new talent display | T016, T017, T018 | 🟢 Completed | AGENT |
| T020 | Code cleanup and optimization | Remove any unused code references and optimize new talent queries | T019 | 🟢 Completed | AGENT |
| T021 | Update code documentation | Update comments and documentation to reflect talent table and new roles | T020 | 🟢 Completed | AGENT |