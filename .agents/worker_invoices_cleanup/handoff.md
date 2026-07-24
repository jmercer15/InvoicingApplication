# Handoff — Invoices Styling Cleanup

## 1. Observation
We observed custom, non-native styling logic in three views within the `Feature.Invoices` package:

1. **`InvoiceFilterPopoverContent.swift`**:
   - `StatusFilterButton` and `ClientFilterButton` used an `@State private var isHovered` property and `.onHover { hovering in isHovered = hovering }` blocks.
   - Dynamic opacities/strokes were applied on background/overlay based on `isHovered`.

2. **`InvoiceLineItemsSection.swift`**:
   - "Add Line Item" button had `isAddHovered` and `.onHover` tracking.
   - Edit (pencil) and Delete (trash) buttons used a shared `hoveredButtonId` state to set the foregroundStyle.

3. **`InvoicesView.swift`**:
   - The multi-select bottom action toolbar (lines 221-290) used custom `.buttonStyle(.plain)` buttons with an overlay of manual padding/background shapes and `.onHover` tracking to toggle the `hoveredButton` state.

Verification of workspace build and package test execution:
- `./scripts/refactor-verify.sh` successfully executed `swift build` and `xcodebuild` targeting macOS with result:
  `** BUILD SUCCEEDED **`
- `swift test --package-path Packages/Feature.Invoices` ran all 19 tests in the `Feature.Invoices` package and all passed successfully:
  `Executed 19 tests, with 0 failures (0 unexpected) in 1.647 (1.651) seconds`

---

## 2. Logic Chain
- **Requirement 1**: Remove custom hover states and `.onHover` modifiers in `InvoiceFilterPopoverContent.swift`.
  - *Action*: Removed `@State private var isHovered = false` from `StatusFilterButton` and `ClientFilterButton`.
  - *Action*: Replaced `.background(...)` and `.strokeBorder(...)` with static color opacity values when selected, and a clear border when unselected.
  - *Action*: Removed `.onHover` modifiers.

- **Requirement 2**: Simplify "Add Line Item", edit, and delete buttons in `InvoiceLineItemsSection.swift`.
  - *Action*: Removed `isAddHovered` and `hoveredButtonId` `@State` properties.
  - *Action*: Removed `.onHover` blocks from all three buttons.
  - *Action*: Simplified backgrounds/strokes on "Add Line Item" using static opacities.
  - *Action*: Styled edit button foreground as constant `ColorSystem.Primary.blue` and delete button as constant `ColorSystem.Status.error`.

- **Requirement 3**: Use native macOS buttons in the bottom toolbar in `InvoicesView.swift`.
  - *Action*: Removed `@State private var hoveredButton` and the unused local `actionButtonShape`.
  - *Action*: Replaced custom plain styled Buttons with native Button components styled using `.buttonStyle(.bordered)` (Cancel) and `.buttonStyle(.borderedProminent)` with `.tint(...)` (Delete with `.tint(.red)`, Export/Email with `.tint(.blue)`).
  - *Action*: Removed all `.onHover` tracking from these toolbar buttons.

---

## 3. Caveats
- Checked and verified that no custom styles in these three files now bypass the macOS native style guidelines.
- Preserved existing layout structure, frames, paddings, and button actions to ensure no functional regression.

---

## 4. Conclusion
The non-native styling features (manual hover highlights, complex state-driven background opacities/strokes, plain-button hacks) have been successfully cleaned up in `Feature.Invoices`. The views now conform to standard macOS native UI behaviors and look-and-feel. The project builds cleanly and all tests pass.

---

## 5. Verification Method
1. Run the package verification script to compile and run all tests:
   ```bash
   ./scripts/refactor-verify.sh
   ```
2. Run the `Feature.Invoices` package tests specifically:
   ```bash
   swift test --package-path Packages/Feature.Invoices
   ```
3. Inspect files to confirm removal of hover-related states:
   - `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterPopoverContent.swift`
   - `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceLineItemsSection.swift`
   - `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesView.swift`
