# Visual Design Refresh Coordination Plan

This plan coordinates the visual design refresh validation and verification across all packages in the Invoicing Application.

## Milestones and Status

| Milestone | Objective | Strategy | Target Package(s) | Status |
|-----------|-----------|----------|-------------------|--------|
| M1 | Initial Check | Spawn Explorer/Worker to run tests & builds on main workspace. Inspect for raw literals. | Workspace / All | DONE |
| M2 | Feature.NDIS Visual Verification | Fix remaining .animation literals using Centralized Tokens. | Feature_NDIS | DONE |
| M3 | Feature.Clients Visual Verification | Fix remaining .animation literals using Centralized Tokens. | Feature_Clients | DONE |
| M4 | Feature.Invoices Visual Verification | Verify Feature.Invoices is fully clean. | Feature_Invoices | DONE |
| M5 | Feature.BillingHub & Calendar | Fix custom colors and raw animations to conform to ColorSystem and StyleGuide.Animations. | Feature_BillingHub, Feature_Calendar | DONE |
| M6 | Feature.Settings & ITE | Refactor raw paddings, font size/weight literals, and NSColor calls. | Feature_Settings, Feature_InvoiceTemplateEditor | DONE |
| M7 | AppShell & SharedUI/WorkspaceUI | Clean up remaining corner radius, font size, and animation literals in AppShell, SharedUI, and WorkspaceUI. | AppShell, SharedUI, WorkspaceUI | DONE |
| M8 | Final Assembly and Forensic Audit | Run all test suites, compile, and run Forensic Auditor checks. | App, all packages | DONE |

## Detailed Steps

1. **Baseline build and test check (Milestone 1)**:
   - Spawned baseline explorer (`9c1b6186-b23a-4802-8932-e73befdba298`). Report delivered. Baseline builds successfully. (DONE)

2. **Phase A: NDIS, Clients, Invoices (Milestones 2, 3, 4)**:
   - Spawned `worker_ndis_clients_invoices` (`eb35b7d7-d1fc-4a01-bbbb-6540f933f876`). Handoff report verified. All tests pass. (DONE)

3. **Phase B: BillingHub, Calendar, Settings (Milestones 5, 6-part)**:
   - Spawned `worker_billinghub_calendar_settings` (`7eefb3df-2e41-487e-a7fd-85fbd8f60a13`). Handoff report verified. All tests pass. (DONE)

4. **Phase C: InvoiceTemplateEditor, AppShell, SharedUI/WorkspaceUI (Milestones 6-part, 7)**:
   - Spawned `worker_ite_appshell_ui` (`a0b10691-668a-4875-9c82-79178e544b83`). Handoff report verified. All tests pass. (DONE)

5. **Phase D: Final Assembly & Audit (Milestone 8)**:
   - Spawned victory verifier to compile the entire app and run all package test suites. Checked successfully. (DONE)
   - Spawned Forensic Auditor (`teamwork_preview_auditor_aesthetic_retry2` - ID: `13165a12-71db-4aea-8d58-a3c126ecc92a`). Verdict: **CLEAN**. (DONE)
