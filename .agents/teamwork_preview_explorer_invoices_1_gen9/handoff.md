# Handoff Report: Style & Layout Token Standardization for Feature.Invoices

## 1. Observation
- Scanned all 14 view files under `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/`.
- In `InvoicesView.swift`, detected the following styling violations/deprecations:
  - **Scaled Corner Radius** (Line 28): `@ScaledMetric(relativeTo: .body) private var cornerRadiusSmall = StyleGuide.Dimensions.cornerRadiusSmall`
  - **Raw Animation Duration** (Line 171): `withAnimation(.easeOut(duration: 0.2)) {`
  - **Deprecated Color Modifier** (Lines 212, 229, 245, 262, 279): `.foregroundColor(Color.white)`
  - **Inconsistent Button Padding** (Lines 230-231): `.padding(.horizontal, paddingMediumLarge)` and `.padding(.vertical, paddingSmall)` (using local `@ScaledMetric` aliases) vs. sibling buttons that use unscaled global tokens directly (e.g. Lines 246-247, 263-264, 280-281).
  - **Deprecated Corner Radius Modifier** (Lines 233, 249, 266, 283): `.cornerRadius(cornerRadiusSmall)`
- Verified that all other views (`InvoiceFilterPopoverContent.swift`, `InvoiceInspectorFormView.swift`, `InvoiceLineItemsSection.swift`, etc.) properly use `StyleGuide` and `ColorSystem` tokens.
- Ran tests via `swift test --package-path Packages/Feature.Invoices` which compiled and passed successfully with 0 failures:
  ```
  Build complete! (8.69s)
  Executed 19 tests, with 0 failures (0 unexpected)
  ```

## 2. Logic Chain
- Standardized UI guidelines (per `PROJECT.md` M4) require centralizing layout and animation constants into the `SharedUI` module's `StyleGuide` and `ColorSystem`.
- A raw animation duration of `0.2` (Observation 1) bypasses the centralized animation duration tokens, which could lead to motion inconsistencies.
- Scaling a corner radius (Observation 1) violates standard design systems where corner radii remain static at all text sizes.
- Sibling action buttons in the multi-select toolbar have inconsistent padding scales (Observation 1), meaning that when a user increases text size, the buttons will scale differently, leading to a mismatched layout.
- The `.cornerRadius` and `.foregroundColor` modifiers are deprecated in SwiftUI and should be replaced with `.clipShape`/`.background(..., in:)` and `.foregroundStyle` to avoid future compiler warnings.

## 3. Caveats
- `Color.white` / `.white` should be retained for text on solid color buttons (e.g., Delete, Export PDFs) since using `ColorSystem.Neutral.white` (which is `NSColor.windowBackgroundColor`) would make the text dark/grey in dark mode, rendering it unreadable on colored backgrounds.

## 4. Conclusion
- No raw hex colors were found in the `Feature.Invoices` Views.
- Standardizing the views in `Feature.Invoices` requires localized fixes in `InvoicesView.swift` to clean up deprecated modifiers, align button paddies, use animation tokens, and remove scaled corner radii.
- Detailed proposals and standardizations have been written to `analysis.md`.

## 5. Verification Method
- **Verify compile/tests**: Run `swift test --package-path Packages/Feature.Invoices` in the workspace root.
- **Inspect changes**: Inspect the proposed changes and recommendations in `analysis.md`.
