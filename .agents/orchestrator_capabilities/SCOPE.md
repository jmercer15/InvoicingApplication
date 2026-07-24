# Scope: Core Capabilities Expansion

## Architecture
Targeting Swift packages `Packages/Feature.Invoices` and `Packages/Feature.InvoiceTemplateEditor` plus application integration and test suites in `InvoicingApplication`.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Exploration & Analysis | Codebase investigation & architecture mapping | None | DONE |
| 2 | Feature.Invoices Enhancements | Revenue analytics summary, invoice duplication workflow, batch CSV/JSON export + unit tests | M1 | IN_PROGRESS |
| 3 | Feature.InvoiceTemplateEditor Enhancements | Preset management, brand accent & logo customization, page margin & pagination controls + unit tests | M1 | PLANNED |
| 4 | Final Verification | Comprehensive test suites (`swift test`, `xcodebuild test`, `architecture-check.sh`) & forensic audit | M2, M3 | PLANNED |

## Interface Contracts
- Feature.Invoices: `InvoiceAnalyticsEngine`, `RevenueAnalyticsSummary`, `InvoiceNumberGenerator`, `InvoiceDataExporter`.
- Feature.InvoiceTemplateEditor: `InvoiceCustomTemplatePreset`, `InvoiceCustomPresetStore`, `InvoiceLogoStyle`, margin drag clamping & pagination breakpoint indicators.
