## 2026-06-13T02:10:00Z
MISSION:
Implement all UI refinements in the `Packages/Feature.Invoices` package as outlined in the plan:
`/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/sub_orch_invoices/plan.md`

Refinement areas:
1. Component Elevation & Visual Hierarchy:
   - `InvoiceEditor.swift`: Replace `Color(NSColor.controlBackgroundColor)` with `StyleGuide.Colors.background`.
   - `InvoicesDetailToolbar.swift`: Replace `.font(.caption)` with `.font(StyleGuide.Typography.caption)`.
   - `InvoiceLineItemsSection.swift`: Refactor custom label-input VStacks in `LineItemEditor` to use the `FormField` component from `SharedUI`. Format: `FormField("Label") { TextField(...) }`. Wrap the empty label `"No items added"` in a clean styled container (e.g. standard spacing).

2. Loading, Empty, and Error state polish:
   - `InvoicesContainerViewModel.swift` & `InvoicesContainerViewModel+List.swift`: Add `@Observation` property `public var listLoadError: String? = nil`. Set it on fetch/database errors, reset to `nil` on success.
   - `InvoicesColumns.swift`: Handle `listLoadError` by rendering `EmptyStateView(icon: "exclamationmark.triangle.fill", title: "Failed to Load Invoices", message: error)`. If projection is nil, show `LoadingView("Loading invoices...")` instead of `ProgressView()`.
   - `InvoiceTemplateRendererView.swift`: Add `@State private var isLoading = false` property. Set it during template loading, and render a ProgressView overlay when true.
   - `InvoiceEditor.swift`: Add `.loadingOverlay(isLoading: viewModel.isLoading, message: "Loading template details...")` modifier.

3. Visual Feedback & Interactive Affordances:
   - `InvoiceLineItemsSection.swift`:
     - Add `.pointerStyle(.link)` and hover color changes for Edit (blue) and Delete (red) action buttons in list. Add accessibility properties.
     - Add `.pointerStyle(.link)` and hover feedback for "Add Line Item" button. Add accessibility properties.
     - Modify `LineItemEditor` popover: add a header with a "Done" button that commits changes and dismisses the popover. Update popover presentation in line items section to support this. Add voiceover labels for text fields.
   - `InvoiceFilterPopoverContent.swift`:
     - Status & Client filter buttons: add hover states, `.pointerStyle(.link)`, and selection accessibility traits.
     - Date inputs: dim when inactive (`opacity(0.6)`).
     - Fix token usage: set `clientListMaxHeight` to `DetailSectionTokens.listMinHeight` (`200`).
   - `InvoicesView.swift`:
     - Action buttons in multi-select toolbar (Cancel, Delete, Export, Email): implement hover feedback, link/default cursor styles based on enabled status, and fade background/foreground opacity (e.g. `0.4`) when disabled. Add accessibility labels.

4. Accessibility & Contrast:
   - Replace low-contrast `ColorSystem.Neutral.gray500` with `StyleGuide.Colors.textSecondary` in line items grid headers and form decorators (`%` and `$`).
   - `InvoicesContentToolbar.swift`: Set `compactLabels: false` for menus and buttons so current sort status and active filter counts are visible.

VERIFICATION:
- Build the Feature.Invoices package and overall application.
- Ensure all test targets pass.
- Document build and test commands and results in your handoff report.
