# DISPATCH — Explorer M3 (Scripts & refactor-verify.sh Modernization)

## Objective
Investigate Milestone 1 items:
1. Legacy python migration scripts in `scripts/` (e.g. `balance_expect_parens.py`, `dedupe_test_harness.py`, `migrate_xctest_to_swift_testing.py`, etc.) and `scripts/__pycache__/`. List all 13 scripts to be safely removed.
2. Modernization of `scripts/refactor-verify.sh`. Check all active SPM packages under `Packages/` (and root project if applicable). Verify how `refactor-verify.sh` currently runs builds/tests and how it should be updated to run `swift test` across all active packages (e.g., Core, Data, DataInterfaces, WorkspaceUI, AppShell, Feature.BillingHub, Feature.Clients, Feature.Invoices, Feature.NDIS, Feature.InvoiceTemplateEditor, PersistenceModels, Feature.Calendar, Feature.Settings, SharedUI).

## Relevant Paths
- `scripts/`
- `scripts/refactor-verify.sh`
- `Packages/`
- `REFACTOR_PLAN.md` Section 1.1.D & Section 3.2.4
- Original Request: `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/ORIGINAL_REQUEST.md`

## Required Output
Write your findings and recommendations to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_m1_3/handoff.md`.
