# Table Inspector UI Analysis & UX Improvements

## Executive Summary
Analysis of Feature_InvoiceTemplateEditor table inspector views shows token inconsistencies, alignment/layout issues, lack of keyboard focus support in custom grids, and dynamic layout shifts. Propose standardizing token usage, aligning layout grids, resolving layout shifts, and implementing proper accessibility traits for macOS HIG compliance.

---

## Detailed Findings & Token Gaps

### 1. Styling & Token Inconsistency

*   **Hardcoded Colors in `AlignmentGridPicker.swift`**
    *   **File Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/AlignmentGridPicker.swift`
    *   **Lines**: 87-90
    *   **Observation**:
        ```swift
        isSelected ? Color.blue :
            isPressed ? Color(.systemGray).opacity(0.5) :
            isHovered ? Color(.systemGray).opacity(0.35) :
            Color(.systemGray).opacity(0.2)
        ```
    *   **Impact**: Bypasses the application color system, leading to visual inconsistency when light/dark theme changes.
    *   **Recommendation**: Replace with standard `ColorSystem.Primary.blue` and `ColorSystem.Status.inactive` (or `Color.secondaryFill`).

*   **Direct AppKit Color Bindings**
    *   **File Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/AlignmentGridPicker.swift`
    *   **Lines**: 18, 42, 82
    *   **Observation**:
        ```swift
        18: Color(NSColor.secondaryLabelColor)
        42: Color(NSColor.controlBackgroundColor)
        82: Color(NSColor.labelColor)
        ```
    *   **Impact**: Directly imports `NSColor` references.
    *   **Recommendation**: Use design tokens:
        *   Line 18: Replace with `Color.secondaryText` or `StyleGuide.Colors.textSecondary`.
        *   Line 42: Replace with `PanelShellTokens.panelSecondaryBackground` or `Color.secondarySurface`.
        *   Line 82: Replace with `Color.primaryText` or `StyleGuide.Colors.text`.

*   **Raw Numeric Spacings**
    *   **File Path**: `TableElementPropertyEditor.swift`
    *   **Lines**: 32, 33, 43
    *   **Observation**: Spacing values `10`, `2`, and `6` are hardcoded.
    *   **Recommendation**: Map to `StyleGuide.Dimensions.paddingXMedium` (10pt), `StyleGuide.Dimensions.paddingXXSmall` (2pt), and `StyleGuide.Dimensions.paddingSmall` (6pt).

---

### 2. Alignment Mismatches & Grid Layouts

*   **Bypassing the Label Width Alignment System**
    *   **File Path**: `ComponentPropertyEditor+Table.swift`
    *   **Lines**: 309-333
    *   **Observation**:
        ```swift
        InspectorGroupBox(title: "Alignment", icon: "square.grid.3x3.fill") {
            InspectorAlignmentGridRow(label: "Data Cell", ...)
            InspectorAlignmentGridRow(label: "Header", ...)
        }
        ```
    *   **Impact**: `InspectorAlignmentGridRow` is placed directly inside `InspectorGroupBox` without being wrapped in `InspectorGrid` or utilizing `InspectorGridCell`. The labels "Data Cell" and "Header" do not align with other inspector control labels (like "Width", "Height", "Width Mode"), creating a jagged layout grid.
    *   **Recommendation**: Wrap within `InspectorGrid` and make `InspectorAlignmentGridRow` conform to `InspectorGridCell` architecture so that label widths are shared.

*   **Hardcoded Outer Overlays**
    *   **File Path**: `TableElementPropertyEditor+SelectionSection.swift`
    *   **Lines**: 153-160, 182-189
    *   **Observation**:
        ```swift
        .overlay(alignment: .trailing) {
            if rows.count > 1 {
                Text("(\(rows.count))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .offset(x: 24)
            }
        }
        ```
    *   **Impact**: The selection count text has a hardcoded `.offset(x: 24)`. When the inspector width is small (near min width `220`), the text clips or overlaps the right margin/border of the panel.
    *   **Recommendation**: Embed the selection count inside the picker's/text field's leading label or as a sub-caption, keeping all layout items inside the bounds of the hierarchy.

---

### 3. Layout Shifts & Visual Stability

*   **Jarring Vertical Jumps on Selection**
    *   **File Path**: `TableElementPropertyEditor+RowColumnSections.swift`
    *   **Lines**: 23-45, 90-112
    *   **Observation**:
        ```swift
        if !component.style.rowConfiguration(for: row).isFlexible {
            InspectorControl.toggle("autoSize", ...)
            if !component.style.rowConfiguration(for: row).isAutoSized {
                InspectorControl.stepper("height", ...)
            }
        }
        ```
    *   **Impact**: Hiding/showing rows based on toggles causes layout elements to jump vertically when selection state or values change.
    *   **Recommendation**: Instead of hiding, disable the dependent settings (e.g. gray out "Auto Size" and "Height" when "Flexible" is checked). This preserves vertical structural height and matches macOS HIG inspectors.

---

### 4. Accessibility & HIG Compliance

*   **Non-Focusable Grid Button Controls**
    *   **File Path**: `AlignmentGridPicker.swift`
    *   **Lines**: 105-108
    *   **Observation**:
        ```swift
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
        ```
    *   **Impact**: Custom alignment button is a decorative `Image` with a tap gesture. It lacks a native button representation, is not focusable using `Tab`, and cannot be triggered via VoiceOver.
    *   **Recommendation**: Refactor `AlignmentButton` to use a native SwiftUI `Button` with a plain style (`.buttonStyle(.plain)`) so it registers in the keyboard focus ring and supports standard accessibility roles.

*   **Missing VoiceOver Labels on Text Fields**
    *   **File Path**: `Components/InspectorTypographyAndStepper.swift`
    *   **Lines**: 111-114
    *   **Observation**:
        ```swift
        TextField("", text: $textValue)
            .textFieldStyle(.roundedBorder)
        ```
    *   **Impact**: The `TextField` has an empty label string. Applying `.accessibilityLabel(tooltip)` on the parent `InspectorStepper` does not correctly propagate to the focusable `TextField` inside, so VoiceOver users hear "Edit text, blank".
    *   **Recommendation**: Pass the label/tooltip directly into the inner `TextField`'s accessibility label modifier: `.accessibilityLabel(tooltip)`.

*   **Decorative Images Not Hidden**
    *   **File Path**: `Components/InspectorComponents.swift`
    *   **Lines**: 117-122
    *   **Observation**: `InspectorIcon` renders decorative icons using `Image(name, bundle: .module)` without hiding them. VoiceOver reads the asset name redundantly.
    *   **Recommendation**: Add `.accessibilityHidden(true)` to decorative control icons.

*   **Icon Mapping Typo**
    *   **File Path**: `AlignmentGridPicker.swift`
    *   **Lines**: 138-139
    *   **Observation**:
        ```swift
        case (.trailing, .bottom):
            return "fluent-ic_fluent_arrow_down_20_regular"
        ```
    *   **Impact**: Displays center arrow down icon instead of down-right icon.
    *   **Recommendation**: Correct to return `"fluent-ic_fluent_arrow_down_right_20_regular"`.

---

## Proposed Code Replacements

### Proposal 1: Make `AlignmentButton` keyboard focusable & token-compliant
Replace `AlignmentButton` inside `AlignmentGridPicker.swift`:

```swift
// BEFORE
private struct AlignmentButton: View {
    let iconName: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Image(iconName, bundle: .module)
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .font(StyleGuide.Typography.nanoMedium)
            .foregroundColor(isSelected ? .white : Color(NSColor.labelColor))
            .frame(width: StyleGuide.Dimensions.templateToolbarIconSizeSmall, height: StyleGuide.Dimensions.templateToolbarIconSizeSmall)
            .background(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusXSmall - 1)
                    .fill(
                        isSelected ? Color.blue :
                            isPressed ? Color(.systemGray).opacity(0.5) :
                            isHovered ? Color(.systemGray).opacity(0.35) :
                            Color(.systemGray).opacity(0.2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusXSmall - 1)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                    )
            )
            .scaleEffect(
                isSelected ? 1.05 :
                    isPressed ? 0.95 :
                    isHovered ? 1.02 : 1.0
            )
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .animation(.easeInOut(duration: 0.1), value: isHovered)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
            .contentShape(Rectangle())
            .onTapGesture {
                action()
            }
            .onHover { hovering in
                isHovered = hovering
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
                )
    }
}

// AFTER
private struct AlignmentButton: View {
    let iconName: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(iconName, bundle: .module)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .font(StyleGuide.Typography.nanoMedium)
                .foregroundColor(isSelected ? ColorSystem.Neutral.white : ColorSystem.Neutral.black)
                .frame(width: StyleGuide.Dimensions.templateToolbarIconSizeSmall, height: StyleGuide.Dimensions.templateToolbarIconSizeSmall)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusXSmall - 1)
                        .fill(isSelected ? ColorSystem.Primary.blue : 
                              isHovered ? ColorSystem.Neutral.gray300 : ColorSystem.Neutral.gray100)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
```

### Proposal 2: Standardize `AlignmentGridPicker` Layout & Tokens
In `AlignmentGridPicker.swift`:

```swift
// BEFORE
struct AlignmentGridPicker: View {
    let label: String
    @Binding var horizontalAlignment: TextAlignment
    @Binding var verticalAlignment: VerticalAlignment
    var onChange: ((TextAlignment, VerticalAlignment) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(InspectorTypography.label)
                .foregroundColor(Color(NSColor.secondaryLabelColor))

            Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                // grid rows...
            }
            .padding(StyleGuide.Dimensions.templateAlignmentGridPadding)
            .background(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
        }
    }
}

// AFTER
struct AlignmentGridPicker: View {
    let label: String
    @Binding var horizontalAlignment: TextAlignment
    @Binding var verticalAlignment: VerticalAlignment
    var onChange: ((TextAlignment, VerticalAlignment) -> Void)? = nil

    var body: some View {
        InspectorGridCell {
            Text(label)
                .font(InspectorTypography.label)
                .foregroundColor(Color.secondaryText)
        } content: {
            Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                // grid rows...
            }
            .padding(StyleGuide.Dimensions.templateAlignmentGridPadding)
            .background(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact)
                    .fill(PanelShellTokens.panelSecondaryBackground)
            )
        }
    }
}
```
*Note*: By wrapping this in `InspectorGridCell`, `AlignmentGridPicker` aligns its label "Data Cell" or "Header" perfectly with all other inspector grid controls.

### Proposal 3: Resolve Layout Shifts (Disable instead of Hide)
In `TableElementPropertyEditor+RowColumnSections.swift`:

```swift
// BEFORE
struct RowInspectorSectionView: View {
    ...
    var body: some View {
        InspectorGroupBox(title: "Dimensions", icon: "fluent-ic_fluent_ruler_20_regular") {
            InspectorGrid {
                InspectorControl.toggle("flexible", ..., isOn: Binding(...))
                
                if !component.style.rowConfiguration(for: row).isFlexible {
                    InspectorControl.toggle("autoSize", ...)
                    
                    if !component.style.rowConfiguration(for: row).isAutoSized {
                        InspectorControl.stepper("height", ...)
                    }
                }
            }
        }
    }
}

// AFTER
struct RowInspectorSectionView: View {
    ...
    var body: some View {
        let isFlexible = component.style.rowConfiguration(for: row).isFlexible
        let isAutoSized = component.style.rowConfiguration(for: row).isAutoSized
        
        InspectorGroupBox(title: "Dimensions", icon: "fluent-ic_fluent_ruler_20_regular") {
            InspectorGrid {
                InspectorControl.toggle("flexible", ..., isOn: Binding(...))
                
                InspectorControl.toggle("autoSize", ..., isOn: Binding(...))
                    .disabled(isFlexible)
                    .opacity(isFlexible ? 0.5 : 1.0)
                
                InspectorControl.stepper("height", ..., value: Binding(...))
                    .disabled(isFlexible || isAutoSized)
                    .opacity((isFlexible || isAutoSized) ? 0.5 : 1.0)
            }
        }
    }
}
```

### Proposal 4: Fix Accessibility Labels for Interactive Steppers
In `Components/InspectorTypographyAndStepper.swift`:

```swift
// BEFORE
TextField("", text: $textValue)
    .textFieldStyle(.roundedBorder)
    .frame(width: 40)

// AFTER
TextField(suffix, text: $textValue)
    .textFieldStyle(.roundedBorder)
    .frame(width: 40)
    .accessibilityLabel(suffix.isEmpty ? "Value" : "\(suffix) value")
```
