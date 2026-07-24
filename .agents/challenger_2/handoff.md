# Handoff Report — Requirement R2 Stress-Test Assessment

## 1. Observation

- **Environment & Build Verification Command**:
  Command: `swift test --package-path Packages/Feature.InvoiceTemplateEditor` (executed with `BypassSandbox: true`).
  Baseline Result: 137 tests executed in `InvoiceTableLayoutEditorTests`, 0 failures.
  Updated Result (with `RequirementR2StressTests.swift`): 146 tests executed, 0 failures.

- **Observed Code Snippets**:
  - `InvoiceEditorViewModel.swift` (lines 76-85):
    ```swift
    var currentPageIndex: Int = 0 {
      didSet {
        let maxIndex = max(0, totalPages - 1)
        if currentPageIndex < 0 {
          currentPageIndex = 0
        } else if currentPageIndex > maxIndex {
          currentPageIndex = maxIndex
        }
      }
    }
    ```
  - `InvoiceEditorViewModel.swift` (lines 1499-1508):
    ```swift
    func removeLineItems(at offsets: IndexSet) {
      let removedIDs = offsets.compactMap { index in
        lineItems.indices.contains(index) ? lineItems[index].id : nil
      }
      lineItems.remove(atOffsets: offsets)
      clearInvalidNumericInputs(for: removedIDs)
      for index in lineItems.indices {
        updateLineItem(id: lineItems[index].id) { $0.sortOrder = index }
      }
    }
    ```
  - `InvoiceEditorView.swift` (lines 428-436):
    ```swift
    .onChange(of: message) { _, newMessage in
        if Self.isError(newMessage) {
            isBannerFocused = true
            let announcement = newMessage.hasPrefix("Save failed") || newMessage.hasPrefix("Failed to save")
                ? newMessage
                : "Save failed. \(newMessage)"
            AccessibilityNotification.Announcement(announcement).post()
        }
    }
    ```
  - `InvoiceRootView.swift` (lines 675-678 in `InvoiceTemplateSaveFailureBanner`):
    ```swift
    .onAppear {
        isRetryFocused = true
        AccessibilityNotification.Announcement("Save failed. Template changes couldn't be saved.").post()
    }
    ```
  - `InvoiceValidatedDecimalField.swift` (lines 33-41 in `InvoiceDecimalInput`):
    ```swift
    private static func formatter(locale: Locale) -> NumberFormatter {
      let formatter = NumberFormatter()
      formatter.locale = locale
      formatter.numberStyle = .decimal
      formatter.generatesDecimalNumbers = true
      formatter.isLenient = false
      formatter.usesGroupingSeparator = true
      return formatter
    }
    ```

## 2. Logic Chain

1. **Page Navigation & Boundary Limits**:
   - **Step 1.1**: `goToNextPage()`, `goToPreviousPage()`, `goToFirstPage()`, and `goToLastPage()` calculate a `target` using `max(0, min(requestedIndex, totalPages - 1))`.
   - **Step 1.2**: On single-page documents (`totalPages == 1`), `target` is 0. If `currentPageIndex == 0`, `target == currentPageIndex` returns early without side effects. Page 0 and Page N-1 boundaries correctly clamp requests to `[0, totalPages - 1]`.
   - **Step 1.3**: When `removeLineItems` or `lineItems = []` is called on a multi-page document, `lineItems` shrinks and `totalPages` drops to 1. Because `removeLineItems` does NOT call `clampPageIndex()`, `currentPageIndex` is NOT re-assigned. Therefore, `didSet` does not run, leaving `currentPageIndex` at a stale index (e.g. 2) while `totalPages` is 1 (`currentPageIndex >= totalPages`).
   - **Step 1.4**: In this stale state, `accessibilityValue` in `InvoiceDocumentPreview.swift` prints out-of-bounds strings such as `"Page 3 of 1"`.

2. **Save Failure Banner Focus Handling**:
   - **Step 2.1**: `InvoiceEditorStatusBanner` uses `.onAppear` and `.onChange(of: message)` to set `@AccessibilityFocusState private var isBannerFocused = true`.
   - **Step 2.2**: If a save fails, sets `statusMessage = "Save failed. X"`, and the user retries without clearing the message (or if the same error string is re-assigned), `newMessage` equals the current `message`. `.onChange(of: message)` does not fire because the string value did not change. `.onAppear` does not fire because the view is already visible.
   - **Step 2.3**: `InvoiceTemplateSaveFailureBanner` only implements `.onAppear`. When a retry attempt fails while the banner remains visible, `.onAppear` does not re-execute, so accessibility focus is lost and no new announcement is posted.

3. **Decimal Field Parsing (Locales & Rapid Typing)**:
   - **Step 3.1**: `InvoiceDecimalInput.parse` uses `NumberFormatter` with `isLenient = false`.
   - **Step 3.2**: In German (`de_DE`) locale, `,` is decimal separator and `.` is thousands separator. When a German user enters `"1234.56"` using the numeric keypad dot, `NumberFormatter` evaluates `.` as a misplaced thousands separator and returns `nil`. The field is flagged as invalid.
   - **Step 3.3**: During rapid typing in `en_US`, typing `"12."` causes `NumberFormatter` to parse `"12."` as `12` with `consumedRange = (0, 3)`. Parsing succeeds (returns `Decimal(12)`), preventing an immediate invalid error. However, if text synchronization is triggered before fraction digits are typed, `InvoiceDecimalInput.string(for: 12)` produces `"12"`, stripping the user's trailing decimal point.

## 3. Caveats

- Tests were run on macOS 14/15 host environment using Xcode 16/16+ Swift toolchain (`swift test`).
- Review-only constraint strictly observed: no application implementation code in `Sources/` was modified. Verification was performed by writing tests in `Tests/InvoiceTableLayoutEditorTests/RequirementR2StressTests.swift` and executing `swift test`.
- UI focus behavior (`@AccessibilityFocusState`) was analyzed via static code inspection and unit test logic since headless `swift test` cannot attach an active VoiceOver screen reader process.

## 4. Conclusion

Requirement R2 implementation in `Packages/Feature.InvoiceTemplateEditor` is overall functional and robust for standard flows, but contains four specific edge-case failure modes:
1. **Stale Page Index on Item Deletion**: Deleting line items shrinks `totalPages` without clamping `currentPageIndex`, creating out-of-bounds state (`currentPageIndex >= totalPages`).
2. **Failure Banner Re-trigger Focus Loss**: Re-triggering save errors with identical error messages or failed retries does not re-apply `@AccessibilityFocusState` or post secondary VoiceOver announcements.
3. **Numeric Keypad Dot Rejection in Comma Locales**: German (`de_DE`) users entering decimal numbers with keypad dot (`"1234.56"`) fail parsing due to strict `isLenient = false` grouping checks.
4. **Rapid Typing Trailing Decimal Point Stripping**: Entering `"12."` parses as `12`, but text synchronization strips the trailing dot if triggered before typing fraction digits.

## 5. Verification Method

Run the following terminal command from the workspace root:
```bash
swift test --package-path Packages/Feature.InvoiceTemplateEditor
```
Inspect test results in:
`Packages/Feature.InvoiceTemplateEditor/Tests/InvoiceTableLayoutEditorTests/RequirementR2StressTests.swift`

Verification passes when all 146 tests in `InvoiceTableLayoutEditorTests` complete with 0 failures.

---

## Adversarial Challenge Report

### Challenge Summary
**Overall risk assessment**: MEDIUM

### Challenges

#### [Medium] Challenge 1: Page index becomes out-of-bounds when line items are removed
- **Assumption challenged**: Page count changes always adjust `currentPageIndex`.
- **Attack scenario**: User is on Page 3 of a 3-page invoice. User deletes line items via `removeLineItems(at:)`. `totalPages` becomes 1, but `currentPageIndex` remains 2.
- **Blast radius**: Out-of-bounds page index causing invalid accessibility strings (`Page 3 of 1`) and erratic shortcut navigation jumps.
- **Mitigation**: Call `clampPageIndex()` inside `removeLineItems(at:)` and whenever `lineItems` changes.

#### [Medium] Challenge 2: Save failure banner focus is lost on re-triggered save failures
- **Assumption challenged**: `.onChange(of: message)` and `.onAppear` are sufficient for banner focus and screen reader announcements.
- **Attack scenario**: User encounters a save error, leaves banner open, and clicks Save again. Save fails with same error string. Neither `.onAppear` nor `.onChange` fires.
- **Blast radius**: Screen reader users receive no feedback that the second save attempt failed.
- **Mitigation**: Observe `statusMessageID` instead of `message` for focus/announcement updates, and add `.onChange(of: templateSaveState)` to `InvoiceTemplateSaveFailureBanner`.

#### [Low] Challenge 3: German / Comma locales reject keypad dot decimal entry
- **Assumption challenged**: `isLenient = false` is safe for all locales.
- **Attack scenario**: German user enters `1234.56` using number pad dot key.
- **Blast radius**: Valid user numeric input is rejected as invalid (`nil`).
- **Mitigation**: Normalize dot to comma in comma-decimal locales before parsing.

#### [Low] Challenge 4: Trailing decimal point stripped during text sync pause
- **Assumption challenged**: `InvoiceDecimalInput.string(for: parse(text))` is idempotent for intermediate inputs.
- **Attack scenario**: User types `12.` and pauses or triggers focus change.
- **Blast radius**: Trailing dot disappears from input field while user is mid-typing.
- **Mitigation**: Avoid synchronizing text while input field is active or preserving raw decimal text during editing.

### Stress Test Results

- Single-page shortcut navigation → No-op on `totalPages == 1` → Page remains 0 → PASS
- Multi-page boundary limit (`Page -1` / `Page N+1`) → Clamped to `0` and `N-1` → Clamped correctly → PASS
- Line item removal page index clamping → `currentPageIndex` checked after line items deleted → `currentPageIndex = 2`, `totalPages = 1` → FAIL / BUG CONFIRMED
- German locale keypad dot (`1234.56` in `de_DE`) → Strict parse → Returns `nil` → FAIL / BUG CONFIRMED
- Rapid typing intermediate dot (`12.`) → `parse("12.")` → Returns `12`, string back is `"12"` → IMPERFECT SYNC BEHAVIOR CONFIRMED
