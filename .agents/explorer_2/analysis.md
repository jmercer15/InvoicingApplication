# Analysis Report: Package Feature.InvoiceTemplateEditor (Requirement R2 Investigation)

## Executive Summary

Investigation of `Packages/Feature.InvoiceTemplateEditor` was conducted to evaluate existing capabilities and architecture for Requirement R2. 
The package features a clean separation between data modeling (`InvoiceModelActor`, `InvoiceSnapshot`, `InvoiceEditorViewModel`), layout calculation (`InvoicePagination`), and presentation views (`InvoiceDocumentPreview`, `InvoiceRootView`, `InvoiceEditorInspector`, `InvoiceValidatedDecimalField`).

---

## Detailed Findings

### 1. Document Preview Page Navigation

* **Location & Architecture**:
  * View: `InvoiceDocumentPreview` (`Sources/InvoiceTableLayoutEditor/Views/InvoiceDocumentPreview.swift:7-191`).
  * Page layout engine: `InvoicePagination` (`Sources/InvoiceTableLayoutEditor/Views/InvoicePagination.swift:17-315`).
  * Off-screen geometry measurer: `InvoicePaginationMeasurer` (`Sources/InvoiceTableLayoutEditor/Views/InvoicePaginationMeasurer.swift`).
  * Page container views: `InvoiceDocumentPreviewScaledPage` and `InvoiceDocumentPreviewPage` (`InvoiceDocumentPreview.swift:312-518`).

* **Page State Management**:
  * Driven by `@State private var renderedPages: [InvoicePageContent]` in `InvoiceDocumentPreview` (lines 20-24), falling back to `viewModel.invoicePages`.
  * `InvoicePageContent` (in `InvoicePagination.swift:5-14`) tracks: `pageIndex`, `totalPages`, `showsDocumentHeader`, `showsLineItemsSectionTitle`, `lineItemIDs`, `showsTableHeader`, `showsTotals`, `showsFooter`.
  * Measurements collected async via `InvoicePaginationMeasurementReporter` (lines 220-270) and stored in `viewModel.measuredDimensions`.
  * Chrome label (`InvoiceDocumentPreview.swift:153-167`) displays paper size, orientation, dimensions, page count (e.g. `2 pages`), and zoom scale.
  * Preview pages are rendered in a vertical stack: `VStack(spacing: 20)` within `ScrollView([.horizontal, .vertical])` (`InvoiceDocumentPreview.swift:53-82`).

* **Page Up / Down / Home / End Keyboard Shortcuts**:
  * **Finding**: No explicit page navigation keyboard shortcuts (PageUp, PageDown, Home, End) or active page selection state are implemented in `InvoiceDocumentPreview.swift`, `InvoiceEditorFocusedActions.swift`, or `InvoiceRootView.swift`.
  * `ScrollView` currently relies entirely on default AppKit scrolling gestures and scrollbar dragging.

* **VoiceOver Page Announcement Triggers**:
  * **Finding**: No VoiceOver page announcements (such as `AccessibilityNotification.Announcement` or `NSAccessibility.post`) are posted when scrolling between pages or when the page count changes.
  * Preview element has static accessibility attributes: `.accessibilityLabel("Invoice document preview")`, `.accessibilityValue(zoom.percentLabel)` (`InvoiceDocumentPreview.swift:126-131`).
  * Chrome label has `.accessibilityLabel(...)` (`InvoiceDocumentPreview.swift:166`).

---

### 2. Save-Failure Recovery Banner

* **Location & Failure State**:
  * **Template Mode**: Tracked in `InvoiceRootView.swift` via `templateSaveState` (`InvoiceTemplateSaveState`: `.saved`, `.saving`, `.failed`, `.invalid`). `InvoiceTemplateSaveRecoveryPolicy.issue` (`InvoiceEditorView.swift` & `InvoiceEditorSeparationTests.swift:1071-1133`) resolves `.saveFailure` when `saveState == .failed` and `hasInvalidInputs == false`.
  * **Invoice Mode**: Errors captured in `InvoiceEditorViewModel.statusMessage` (e.g. starting with `"Failed to save invoice: ..."` or `"Invoice couldn't be ..."`).

* **Recovery Banner View**:
  * **Template Mode**: `InvoiceTemplateSaveFailureBanner` (`InvoiceRootView.swift:645-674`). Rendered in `overlay(alignment: .bottom)` of `InvoiceRootView`. Contains warning icon (`Image(systemName: "exclamationmark.triangle.fill")`), message `Text("Template changes couldn’t be saved.")`, `Button("Retry")`, and `Button("Open Format")`.
  * **Invoice Mode**: `InvoiceEditorStatusBanner` (`InvoiceEditorView.swift:279-414`). Rendered in `overlay(alignment: .bottom)` of `InvoiceRootView`. Displays error message with red warning icon and dismiss button (`xmark.circle.fill`).

* **Focus Management**:
  * `InvoiceTemplateSaveFailureBanner` provides `Button("Open Format")` which calls `revealEditorInspector()`, setting `editorInspectorPresented = true`.
  * `InvoiceEditorViewModel` has `validationRecoveryRequestRevision` which triggers `revealInspector()` and moves focus to the first invalid field via `previewInteraction.select(target)` (`InvoiceEditorView.swift:129-135`).
  * **Finding**: Neither banner automatically shifts VoiceOver focus or `@FocusState` directly to the banner or Retry button when a save failure occurs.

* **Accessibility Traits & Labels**:
  * `InvoiceTemplateSaveFailureBanner`: `.accessibilityElement(children: .contain)` with `.accessibilityLabel("Template save failed")` (`InvoiceRootView.swift:671-672`).
  * `InvoiceEditorStatusBanner`: `.accessibilityLabel("Error: \(message)")` (`InvoiceEditorView.swift:390`) and `.accessibilityLabel("Dismiss status message")` (`InvoiceEditorView.swift:401`).

---

### 3. Validated Decimal Fields

* **Location & Component Structure**:
  * Defined in `Sources/InvoiceTableLayoutEditor/Views/InvoiceValidatedDecimalField.swift`.
  * Components: `InvoiceValidatedDecimalField` (lines 43-154) and `InvoiceValidatedDoubleField` (lines 201-329).
  * Helper utilities: `InvoiceDecimalInput` (lines 4-41) and `InvoiceDoubleInput` (lines 156-199).

* **Validation Logic**:
  * `InvoiceDecimalInput.parse(_ text: String, locale: Locale)`:
    * Uses `NumberFormatter` with `numberStyle = .decimal`, `generatesDecimalNumbers = true`, `isLenient = false`, `usesGroupingSeparator = true`.
    * Enforces exact string consumption (`NSRange(location: 0, length: (trimmed as NSString).length)`). Incomplete text or invalid characters return `nil`.
  * `InvoiceDoubleInput.parse(_ text: String, in range: ClosedRange<Double>, locale: Locale)`:
    * Parses decimal number and checks finite value and range membership.

* **Error Feedback Display**:
  * **Visual**: TextField overlay with red border: `RoundedRectangle(cornerRadius: 5).stroke(.red, lineWidth: 1)` (`InvoiceValidatedDecimalField.swift:87-90`). Red error message text below field: `Text("Enter a valid number.")` (lines 95-100).
  * **Accessibility**: `TextField.accessibilityValue(isInvalid ? "Invalid number" : text)` and `.accessibilityHint(isInvalid ? "Enter a valid number" : "")`. The below-field error text has `.accessibilityHidden(true)` to avoid redundant VoiceOver announcements.

* **State Binding**:
  * `@Binding var value: Decimal` / `@Binding var value: Double`.
  * Local `@State private var text: String` and `@State private var isInvalid = false`.
  * Unparseable text is stored in `InvoiceNumericInputDraftStore` so invalid user typing is preserved in UI without setting invalid values on the model.
  * Validity changes trigger `onValidityChange: (String, Bool) -> Void`, updating `invalidNumericInputIDs` in `InvoiceEditorViewModel`. Save operations check `hasInvalidNumericInput` and block saving with `"Enter valid numeric values before saving."`.

---

### 4. Existing Tests

* **Test Suite Locations**:
  1. `Tests/InvoiceTableLayoutEditorTests/InvoicePaginationTests.swift`:
     * Tests pagination with uniform row heights, multi-page splits, line item preservation, totals/footer location.
  2. `Tests/InvoiceTableLayoutEditorTests/InvoiceEditorSeparationTests.swift`:
     * Tests decimal parsing (`testDecimalInputRequiresCompleteLocalizedNumber`, `testDecimalInputRoundTripsLocalizedDisplay`), double input parsing, numeric draft store, template recovery policy (`testTemplateSaveRecoveryAppearsOnlyForActionablePersistenceFailure`), status banner auto-dismissal (`testStatusBannerAutoDismissesSuccessButKeepsActionableErrors`), command capabilities, inspector presentation policies, atomic PDF writing.
  3. `Tests/InvoiceTableLayoutEditorTests/InvoiceModelActorIntegrationTests.swift`:
     * Tests SwiftData persistence actor, draft updates, client options loading, revision conflict resolution, creation defaults.

* **Coverage Gaps Identified**:
  * No tests for preview page navigation keyboard shortcuts (PageUp, PageDown, Home, End).
  * No tests for VoiceOver page change announcement triggers.
  * No tests for VoiceOver focus movement / Accessibility focus on save failure recovery banners.

---

## Recommendations for Requirement R2 Implementation

1. **Document Preview Page Navigation**:
   * Add active page tracking state (e.g. `currentPageIndex: Int`) to `InvoiceEditorViewModel` or `InvoiceDocumentPreview`.
   * Add keyboard shortcut handlers (PageUp, PageDown, Home, End) via `.onKeyPress` or commands to scroll/jump between preview pages.
   * Trigger VoiceOver announcement (e.g. `AccessibilityNotification.Announcement("Page \(index + 1) of \(totalPages)").post()`) when active page changes.

2. **Save-Failure Recovery Banner Focus & Accessibility**:
   * Add `@AccessibilityFocusState` or `@FocusState` to `InvoiceTemplateSaveFailureBanner` and `InvoiceEditorStatusBanner` to direct focus to the banner or "Retry" button when a save failure occurs.
   * Post VoiceOver announcement on save failure: `AccessibilityNotification.Announcement("Save failed. Template changes couldn't be saved.").post()`.

3. **Validated Decimal Fields**:
   * Standardize accessibility error announcements when invalid input occurs.
   * Retain `InvoiceNumericInputDraftStore` and `onValidityChange` mechanism as it handles invalid input gracefully.

4. **Test Suite Expansion**:
   * Add unit tests in `InvoicePaginationTests.swift` for active page navigation and page bounds checking.
   * Add unit tests in `InvoiceEditorSeparationTests.swift` for save failure banner accessibility traits, focus state transitions, and VoiceOver announcement triggers.
