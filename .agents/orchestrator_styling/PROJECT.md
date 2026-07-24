# Project: InvoicingApplication Styling Cleanup

## Architecture
- macOS SwiftUI Application with SwiftData persistence.
- Target: Unify design style with standard macOS native styling.
- Packages:
  - `SharedUI`
  - `Feature.NDIS`
  - `Feature.Clients`
  - `Feature.Invoices`
  - `Feature.BillingHub`
  - `Feature.Calendar`
  - `Feature.Settings`
  - `Feature.InvoiceTemplateEditor`
  - `AppShell`

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Baseline Check & Audit | Search and compile baseline | None | DONE |
| 2 | Feature.NDIS | Remove non-native styles | M1 | DONE |
| 3 | Feature.Clients | Remove non-native styles | M2 | DONE |
| 4 | Feature.Invoices | Remove non-native styles | M3 | DONE |
| 5 | Feature.BillingHub & Calendar | Remove non-native styles | M4 | DONE |
| 6 | Feature.Settings & ITE | Remove non-native styles | M5 | DONE |
| 7 | AppShell & SharedUI | Remove non-native styles | M6 | DONE |
| 8 | Final Verification | Verification tests & audit | M7 | DONE |

## Interface Contracts
- Clean up custom `.shadow` modifiers on cards/views that deviate from macOS system styling.
- Clean up `.onHover` states that alter selection highlights/background colors.
- Preserve system-default selection and hover styles on macOS List / Table / Button components.

## Code Layout
- `Packages/SharedUI/Sources/SharedUI/`
- `Packages/Feature.NDIS/Sources/Feature_NDIS/`
- `Packages/Feature.Clients/Sources/Feature_Clients/`
- `Packages/Feature.Invoices/Sources/Feature_Invoices/`
- `Packages/Feature.BillingHub/Sources/Feature_BillingHub/`
- `Packages/Feature.Calendar/Sources/Feature_Calendar/`
- `Packages/Feature.Settings/Sources/Feature_Settings/`
- `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/`
- `Packages/AppShell/Sources/AppShell/`
