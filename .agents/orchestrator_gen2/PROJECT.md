# Project: InvoicingApplication UI Token Standardization

## Architecture
- Apple SwiftUI App with SwiftData persistence.
- Design tokens defined in Packages/SharedUI:
  - `StyleGuide` (Dimensions, Typography, Animations, Shadows, Opacity)
  - `ColorSystem` (Theme-defined colors)
  - `PanelShellTokens` / `PanelShellModifiers` (Panel layout)
  - `FormField`, `StatusBadge`, `EnhancedGroupBoxStyle`, `SidebarItemRow`

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Baseline Check | Run compile and test commands, scan codebase for raw literals | none | DONE |
| 2 | Feature.NDIS | Migrate and unify remaining spacing/typography/colors in NDIS | M1 | DONE |
| 3 | Feature.Clients | Migrate and unify remaining spacing/typography/colors in Clients | M2 | DONE |
| 4 | Feature.Invoices | Migrate and unify remaining spacing/typography/colors in Invoices | M3 | PLANNED |
| 5 | Feature.BillingHub & Calendar | Migrate and unify remaining spacing/typography/colors in BillingHub/Calendar | M4 | PLANNED |
| 6 | Feature.Settings & ITE | Migrate and unify remaining spacing/typography/colors in Settings/ITE | M5 | PLANNED |
| 7 | AppShell | Migrate and unify remaining spacing/typography/colors in AppShell | M6 | PLANNED |
| 8 | Final Assembly | End-to-end verification, compile and test verification gate | M7 | PLANNED |

## Interface Contracts
All feature packages must use the central `SharedUI` tokens and components. No duplicate styles or local color/font lookup wrappers.

## Code Layout
- `Packages/SharedUI/Sources/SharedUI/` - Shared design system definitions
- `Packages/Feature.NDIS/Sources/Feature_NDIS/` - NDIS Views
- `Packages/Feature.Clients/Sources/Feature_Clients/` - Clients Views
- `Packages/Feature.Invoices/Sources/Feature_Invoices/` - Invoices Views
- `Packages/Feature.BillingHub/Sources/Feature_BillingHub/` - Billing Hub Views
- `Packages/Feature.Calendar/Sources/Feature_Calendar/` - Calendar Views
- `Packages/Feature.Settings/Sources/Feature_Settings/` - Settings Views
- `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/` - Template Editor Views
- `Packages/AppShell/Sources/AppShell/` - App Shell Views
