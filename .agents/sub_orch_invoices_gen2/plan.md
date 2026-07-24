# Milestone 4 Implementation Plan: Feature.Invoices UI Refinement (Pass 3)

## Objective
Refine the UI/UX of `Feature.Invoices` across component elevation, empty/loading/error states, interactive affordances, and contrast/accessibility.

## Target Files & Proposed Changes

### 1. Style guide token mapping & layout refinement
* **`Sources/Feature_Invoices/Views/InvoiceEditor.swift`**:
  - Replace `Color(NSColor.controlBackgroundColor)` background color with `StyleGuide.Colors.background`.
  - Add `.loadingOverlay(isLoading: viewModel.isLoading, message: "Loading template details...")` view modifier on the top-level editor view.
* **`Sources/Feature_Invoices/Views/Components/InvoicesDetailToolbar.swift`**:
  - Replace `.font(.caption)` with `.font(StyleGuide.Typography.caption)` for `complianceMessage`.
* **`Sources/Feature_Invoices/Views/InvoiceLineItemsSection.swift`**:
  - Refactor manual `VStack` inputs in `LineItemEditor` to use the `FormField` component from `SharedUI`.
  - Wrap the empty list label `"No items added"` in a styled frame matching standard spacing.

### 2. Loading, Empty, and Error state polish
* **`Sources/Feature_Invoices/ViewModels/InvoicesContainerViewModel.swift` & `+List.swift`**:
  - Add `@Observation` property `public var listLoadError: String? = nil`.
  - Capture localized database/fetch errors to `listLoadError` on failure, and reset to `nil` on success.
* **`Sources/Feature_Invoices/Views/InvoicesColumns.swift`**:
  - If `listLoadError` is present, display `EmptyStateView(icon: "exclamationmark.triangle.fill", title: "Failed to Load Invoices", message: error)`.
  - If `cachedProjection` is nil (and no error), render `LoadingView("Loading invoices...")` instead of raw `ProgressView()`.
* **`Sources/Feature_Invoices/Views/InvoiceTemplateRendererView.swift`**:
  - Add `@State private var isLoading = false` property.
  - Set `isLoading = true` during `loadTemplate()`, resetting to `false` in `defer`.
  - Wrap canvas rendering in `ZStack` and overlay a styled spinner (`ProgressView()`) when `isLoading` is true.

### 3. Visual Feedback & Interactive Affordances
* **`Sources/Feature_Invoices/Views/InvoiceLineItemsSection.swift`**:
  - For pencil (Edit) and trash (Delete) buttons in list:
    - Add `.pointerStyle(.link)`.
    - Implement `@State private var hoveredButtonId: String? = nil` to conditionally change foreground color on hover (e.g. blue for edit, red/error for delete).
    - Add `.accessibilityLabel` and `.accessibilityHint`.
  - For "Add Line Item" button:
    - Add `.pointerStyle(.link)`.
    - Implement hover state changing background opacity/overlay borders.
    - Add `.accessibilityLabel` and `.accessibilityHint`.
  - For `LineItemEditor` popover:
    - Add a header with a prominent "Done" button that commits changes and dismisses the popover.
    - Add voiceover labels for text fields.
* **`Sources/Feature_Invoices/Views/InvoiceFilterPopoverContent.swift`**:
  - For status and client filter buttons:
    - Add hover state checking and change background opacity dynamically.
    - Add `.pointerStyle(.link)`.
    - Add accessibility traits (`.isButton`, `.isSelected` when active).
  - For date inputs:
    - Dim using `.opacity(viewModel.isDateFilterActive ? 1.0 : 0.6)` when inactive.
  - Fix token mismatch: set `clientListMaxHeight` to `DetailSectionTokens.listMinHeight` (`200.0`) instead of `DetailSectionTokens.sortPickerWidth` (`120.0`).
* **`Sources/Feature_Invoices/Views/InvoicesView.swift`**:
  - For multi-select toolbar action buttons (Cancel, Delete, Export, Email):
    - Implement hover feedback changing visual opacity/contrast.
    - Add `.pointerStyle(.link)` when enabled, and `.default` when disabled.
    - Fade backgrounds (e.g., opacity `0.4`) when disabled to clearly communicate inactive state.
    - Add `.accessibilityLabel` for screen readers.

### 4. Accessibility & Contrast (WCAG AA Compliance)
* **Replace Low-Contrast Gray**:
  - Replace `ColorSystem.Neutral.gray500` with `StyleGuide.Colors.textSecondary` in:
    - Grid headers in `InvoiceLineItemsSection.swift`.
    - Percent `%` and currency `$` decorators next to numeric input fields in `InvoiceInspectorFormView.swift`.
* **Toolbar Titles & Counts Visibility**:
  - In `InvoicesContentToolbar.swift`, set `compactLabels: false` for menus and filter buttons so text labels showing current sort field and active filter counts are visible on macOS.
