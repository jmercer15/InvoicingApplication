# Scope: InvoicingApplication UI Refinement (Pass 3)

## Architecture
- macOS SwiftUI Application with SwiftData persistence.
- Modularity: Feature packages (`Feature.NDIS`, `Feature.Clients`, `Feature.Invoices`, `Feature.BillingHub`, `Feature.Calendar`, `Feature.Settings`, `Feature.InvoiceTemplateEditor`) and `AppShell` integration.
- Shared design tokens in `SharedUI` (`StyleGuide`, `ColorSystem`, `PanelShellTokens`).

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Baseline Check & Planning | Run baseline builds and test commands to verify no pre-existing failures. | none | DONE |
| 2 | Feature.NDIS UI Refinement | Refine layout, depth/elevation, state polish, feedback, accessibility for NDIS | M1 | DONE |
| 3 | Feature.Clients UI Refinement | Refine layout, depth/elevation, state polish, feedback, accessibility for Clients | M2 | DONE |
| 4 | Feature.Invoices UI Refinement | Refine layout, depth/elevation, state polish, feedback, accessibility for Invoices | M3 | DONE |
| 5 | Feature.BillingHub & Calendar UI Refinement | Refine layout, depth/elevation, state polish, feedback, accessibility for BillingHub & Calendar | M4 | DONE |
| 6 | Feature.Settings & ITE UI Refinement | Refine layout, depth/elevation, state polish, feedback, accessibility for Settings & ITE | M5 | PLANNED |
| 7 | AppShell UI Refinement | Refine layout, depth/elevation, state polish, feedback, accessibility for AppShell | M6 | PLANNED |
| 8 | Final Acceptance & Integration | End-to-end verification, compile and test verification gate | M7 | PLANNED |

## Interface Contracts
All features must leverage `SharedUI` tokens and views. Refined components must align with core accessibility/contrast guidelines.
