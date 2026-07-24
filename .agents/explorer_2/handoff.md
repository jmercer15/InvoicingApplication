# Handoff Report: Requirement R2 Investigation

## 1. Observation

Direct observations from codebase inspection of `Packages/Feature.InvoiceTemplateEditor`:

1. **Document Preview Page Navigation**:
   - `InvoiceDocumentPreview.swift:7-144`: View displays live pages using `renderedPages` / `viewModel.invoicePages`.
   - `InvoicePagination.swift:17-315`: `InvoicePagination.paginate(input:dimensions:)` splits content across pages, returning `[InvoicePageContent]`.
   - `InvoiceDocumentPreview.swift:153-167`: `pageChromeLabel` renders e.g. `"2 pages"`.
   - No PageUp, PageDown, Home, End keyboard shortcut handlers exist in `InvoiceDocumentPreview.swift` or `InvoiceEditorFocusedActions.swift:10-128`.
   - No `AccessibilityNotification.Announcement` or `NSAccessibility.post` page announcements exist in `InvoiceDocumentPreview.swift`.

2. **Save-Failure Recovery Banner**:
   - `InvoiceRootView.swift:645-674`: `InvoiceTemplateSaveFailureBanner` renders in bottom overlay when `templateSaveState == .failed`.
   - `InvoiceEditorView.swift:279-414`: `InvoiceEditorStatusBanner` renders error banners in invoice mode.
   - `InvoiceRootView.swift:671-672`: `InvoiceTemplateSaveFailureBanner` uses `.accessibilityElement(children: .contain)` and `.accessibilityLabel("Template save failed")`.
   - Focus is not programmatically moved to the banner/Retry button via `@FocusState` or `@AccessibilityFocusState` when save failure occurs.

3. **Validated Decimal Fields**:
   - `InvoiceValidatedDecimalField.swift:43-154`: `InvoiceValidatedDecimalField` parses decimal strings using `InvoiceDecimalInput.parse` (`NumberFormatter`).
   - `InvoiceValidatedDecimalField.swift:86-90,95-100`: Error UI renders red border overlay `RoundedRectangle(cornerRadius: 5).stroke(.red, lineWidth: 1)` and red caption text `Text("Enter a valid number.")`.
   - `InvoiceValidatedDecimalField.swift:92-93`: Accessibility value set to `.accessibilityValue(isInvalid ? "Invalid number" : text)`. Below-field red text set to `.accessibilityHidden(true)`.
   - `InvoiceEditorViewModel.swift:73,88-95,1059-1062`: `invalidNumericInputIDs` blocks `saveCurrentInvoice` when invalid text is present.

4. **Existing Tests**:
   - `Tests/InvoiceTableLayoutEditorTests/InvoicePaginationTests.swift:1-58`: Tests pagination line item distribution and totals/footer logic.
   - `Tests/InvoiceTableLayoutEditorTests/InvoiceEditorSeparationTests.swift:1-1722`: Tests decimal parsing (`testDecimalInputRequiresCompleteLocalizedNumber`), double parsing, status banners, template save recovery policy (`testTemplateSaveRecoveryAppearsOnlyForActionablePersistenceFailure`).
   - `Tests/InvoiceTableLayoutEditorTests/InvoiceModelActorIntegrationTests.swift:1-1133`: Tests SwiftData actor operations, client options, revision conflict handling.

---

## 2. Logic Chain

1. **Preview Navigation Analysis**:
   - `InvoiceDocumentPreview` renders all pages vertically in a single `ScrollView`.
   - Page indices exist in `InvoicePageContent.pageIndex`, but there is no state tracking the currently visible/active page index during scrolling.
   - Without key event listeners for PageUp/PageDown/Home/End or active page tracking, keyboard users cannot navigate between pages by keyboard shortcut, and VoiceOver cannot announce page transitions.

2. **Save-Failure Recovery Banner Analysis**:
   - Save failures correctly transition state to `.failed` (template mode) or set error status message (invoice mode).
   - Recovery banners display warning icons and action buttons ("Retry", "Open Format").
   - Accessibility traits and labels are present on the banner container, but focus management lacks auto-focusing on failure banner display.

3. **Validated Decimal Field Analysis**:
   - Decimal validation separates invalid string input state (`InvoiceNumericInputDraftStore`) from model decimal properties, avoiding model corruption.
   - Error presentation provides clear visual (red outline/text) and VoiceOver feedback (`accessibilityValue`).

4. **Test Coverage Analysis**:
   - Data and pagination logic have high unit test coverage.
   - View-level interactive behaviors (keyboard shortcuts, VoiceOver announcements, accessibility focus shifting) currently lack test coverage.

---

## 3. Caveats

- No code changes were implemented in `Packages/Feature.InvoiceTemplateEditor` (read-only investigation).
- Tests were inspected but not executed during this investigation turn.

---

## 4. Conclusion

Requirement R2 implementation for `Feature.InvoiceTemplateEditor` requires:
1. Implementing active page tracking, PageUp/PageDown/Home/End key shortcuts, and VoiceOver page announcement triggers in `InvoiceDocumentPreview`.
2. Enhancing `InvoiceTemplateSaveFailureBanner` and `InvoiceEditorStatusBanner` with focus management (`@FocusState` / `@AccessibilityFocusState`) and VoiceOver announcement triggers on save failure.
3. Maintaining the existing `InvoiceValidatedDecimalField` design while expanding test coverage for navigation shortcuts, VoiceOver announcements, and accessibility focus handling.

---

## 5. Verification Method

To verify these findings:
1. Inspect `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceDocumentPreview.swift` lines 7-191 to verify absence of PageUp/PageDown key handlers and VoiceOver announcements.
2. Inspect `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceRootView.swift` lines 645-674 to check `InvoiceTemplateSaveFailureBanner` focus handling.
3. Inspect `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceValidatedDecimalField.swift` lines 43-154 to verify validation logic and accessibility attributes.
4. Run `swift test` on `Feature.InvoiceTemplateEditor` target via `xcodebuild` or `swift test`.
