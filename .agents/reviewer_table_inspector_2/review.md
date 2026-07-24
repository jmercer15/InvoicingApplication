# Table and Table-Cell Inspector Review Report

## Review Summary

**Verdict**: REQUEST_CHANGES

The table and cell property inspectors demonstrate a highly cohesive layout architecture, strong typing, and good structural organization. However, there are significant gaps regarding layout stability (violating macOS HIG expectations of no sudden shifts on interaction) and accessibility (unlabeled buttons/text fields for VoiceOver users). Addressing these findings will elevate the UX to production-ready quality.

---

## Findings

### [Major] Finding 1: Layout Instability via Conditional Sizing Controls
- **What**: Sizing controls in the table cell selection inspector shift and jump when settings are changed.
- **Where**: `TableElementPropertyEditor+SelectionSection.swift` inside `TableSelectionSectionView` (lines 138-164, 188-214, and 239-260).
- **Why**: When `selectedRowsHeightMode`, `selectedColsWidthMode`, or `currentStyle?.padding` change, the "Height", "Width", and "Padding" steppers are conditionally added or removed from the view hierarchy using `if` blocks. This causes the entire inspector layout to shift vertically upon interaction, creating visual stuttering. This inconsistent layout strategy conflicts with `RowInspectorSectionView` and `ColumnInspectorSectionView` (in `TableElementPropertyEditor+RowColumnSections.swift`), which keep controls present but visually dim and disable them.
- **Suggestion**: Replace conditional `if` blocks with `.disabled(...)` and `.opacity(...)` modifiers on the stepper controls to maintain layout stability:
  ```swift
  // Instead of: if selectedRowsHeightMode == .fixed { ... }
  InspectorGridCell {
      Text("Height")
  } content: {
      InspectorStepper(...)
  }
  .disabled(selectedRowsHeightMode != .fixed)
  .opacity(selectedRowsHeightMode == .fixed ? 1.0 : 0.5)
  ```

### [Major] Finding 2: Unlabeled Alignment Buttons in VoiceOver
- **What**: The 3x3 alignment picker buttons are silent and unlabeled for VoiceOver users.
- **Where**: `AlignmentGridPicker.swift` inside `AlignmentButton` (lines 67-119).
- **Why**: The internal `Button` wraps an image that is explicitly hidden from accessibility (`.accessibilityHidden(true)`). Although it has `.accessibilityElement(children: .combine)` and `.accessibilityAddTraits`, it lacks any `.accessibilityLabel(...)`. VoiceOver will announce it simply as "Button, selected" without reading its direction/purpose (e.g. "Top Left Alignment").
- **Suggestion**: Add a mapped accessibility label to the `Button`:
  ```swift
  private var alignmentDescription: String {
      let hLabel: String
      switch horizontal {
      case .leading: hLabel = "Left"
      case .center: hLabel = "Center"
      case .trailing: hLabel = "Right"
      }
      
      let vLabel: String
      switch vertical {
      case .top: vLabel = "Top"
      case .center: vLabel = "Middle"
      case .bottom: vLabel = "Bottom"
      }
      
      return "\(vLabel) \(hLabel) Alignment"
  }
  
  // Apply on Button:
  .accessibilityLabel(alignmentDescription)
  ```

### [Minor] Finding 3: Unlabeled TextField in InspectorStepper
- **What**: The editable text field inside the stepper does not describe what it edits to VoiceOver.
- **Where**: `InspectorTypographyAndStepper.swift` inside `InspectorStepper` (lines 111-126).
- **Why**: The `TextField("", text: $textValue)` has an empty placeholder and lacks a direct accessibility label. When a user focuses the text field itself, VoiceOver has no descriptive context.
- **Suggestion**: Pass the tooltip or label down to the stepper, or add a fallback label:
  ```swift
  TextField("Value", text: $textValue)
      .accessibilityLabel(suffix.isEmpty ? "Value" : "\(suffix) value")
  ```

### [Minor] Finding 4: Missing Expansion State Announcements in Collapsible Headers
- **What**: Collapsible sections and group boxes do not announce their expanded or collapsed state.
- **Where**:
  - `InspectorContentLayout.swift` inside `SectionHeaderButton` (lines 138-182)
  - `InspectorAccordionSection.swift` inside `InspectorGroupBox` (lines 124-172)
- **Why**: These collapsible controls act as disclosure buttons but do not announce whether the section is currently open or closed to screen readers.
- **Suggestion**: Add `.accessibilityValue(isExpanded ? "Expanded" : "Collapsed")` and `.accessibilityHint("Double tap to toggle visibility")` to both header buttons.

---

## Verified Claims

- **Package Compilation & Target Unit Tests** → verified via `swift test --package-path Packages/Feature.InvoiceTemplateEditor` → **PASS**
  - Executed all 73 tests in `Feature.InvoiceTemplateEditor` and all 27 tests in `SharedUI` successfully with 0 failures.
- **Logical Spacing & Typographic Hierarchy** → verified via static inspection of `InspectorTypography` and `InspectorContentLayout` → **PASS**
  - Consistent spacings (`groupBoxPadding`, `groupBoxSpacing`, `cellPadding`, and rounded titles) are cleanly centralized.
- **Accordion Coordinator Single Expansion Behavior** → verified via `InspectorAccordionContext` logic → **PASS**
  - Accurately tracks and enforces single-expansion accordion style across multiple group boxes to preserve vertical space.

---

## Coverage Gaps

- **Canvas Rendering Parity** — risk level: Low — recommendation: Accept risk.
  - The inspector successfully binds to `InvoiceDocument` styles, but canvas rendering of these overrides (e.g., custom cell text colors/paddings on the editor grid itself) lies in the canvas package, which was outside this review's scope.

---

## Unverified Items

- **Runtime VoiceOver Speech Feedback** — reason not verified: Xcode simulator and native screen reader testing cannot be executed directly via script in this environment. Verification was completed via code structure and accessibility hierarchy inspection.
