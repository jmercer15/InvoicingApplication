# Handoff Report: Feature.Settings & Feature.InvoiceTemplateEditor UI Refinement Explorer

This handoff report summarizes findings from a read-only investigation of the Settings and Invoice Template Editor packages.

## 1. Observation
Below are direct observations from the codebase files:

*   **Static Label Width Bug**: In `SettingsRow.swift` (lines 13-35), the width constraint of row labels is a static `CGFloat`:
    ```swift
    struct SettingsRow<Content: View>: View {
        let label: String
        let content: Content
        let labelWidth: CGFloat
        ...
        var body: some View {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .frame(width: labelWidth, alignment: .trailing)
                    .lineLimit(1)
                content
            }
        }
    }
    ```
    This `labelWidth` is calculated statically in views (e.g., `ProfileView.swift` line 11-14) using:
    ```swift
    private var maxLabelWidth: CGFloat {
        let labels = ["Name:", "Email:", "Phone:", "Role:"]
        return labels.map { $0.width() }.max() ?? 120
    }
    ```
    Where `width(for:)` in `SettingsRow.swift` (lines 4-11) is defined as:
    ```swift
    func width(for _: Font = .body) -> CGFloat {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (self as NSString).size(withAttributes: attributes)
        return size.width
    }
    ```
    This completely ignores dynamic type resizing (Dynamic Type).

*   **Property Inspector Empty State**: In `PropertyInspector.swift` (lines 34-68), the body returns `EmptyView()` when `displayMode` is `.empty`:
    ```swift
    var body: some View {
        Group {
            switch displayMode {
            ...
            case .empty:
                EmptyView()
            }
        }
    }
    ```
    No placeholder view is rendered.

*   **Template Library Empty State**: In `TemplateLibraryGrid.swift` (lines 20-55), the body directly renders a `LazyVGrid`:
    ```swift
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: PanelShellTokens.contentListGridSpacing) {
                ForEach(templates, id: \.id) { template in
                    ...
                }
            }
            ...
        }
    }
    ```
    If `templates` is empty, nothing is shown in the layout.

*   **Unrendered Validation Errors**: 
    *   In `ProfileViewModel.swift` (lines 32, 49-65), validation is computed:
        ```swift
        var validationErrors: [String: String] = [:]
        ...
        public func validate() -> Bool {
            validationErrors = [:]
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                validationErrors["name"] = "Name cannot be empty"
            }
            ...
        }
        ```
        But `ProfileView.swift` has no bindings or view code for `validationErrors`.
    *   In `InvoiceTemplateEditorViewModel.swift` (lines 31, 287-294), `validationErrors` are populated:
        ```swift
        var validationErrors: [ValidationError] = []
        ```
        But no views in `Feature.InvoiceTemplateEditor` read this array.

*   **Missing Keyboard Shortcuts**: In the entire `Feature.InvoiceTemplateEditor` and `Feature.Settings` folders, a grep search for `.keyboardShortcut` shows zero shortcuts implemented (with only one default action mapping inside `CreateCalendarSheet.swift` line 53).

*   **Accessibility Hidden Labels**: In `InspectorControlDescriptor.swift` (lines 71-86, 126-146, 90-104), pickers, toggles, textfields use `.labelsHidden()` but lack `.accessibilityLabel` or `.accessibilityHint`:
    ```swift
    static func toggle(
        _ id: String,
        icon: String,
        tooltip: String,
        isOn: Binding<Bool>
    ) -> InspectorControl {
        InspectorControl(id: id, icon: icon, tooltip: tooltip) {
            AnyView(
                InspectorGridCell {
                    InspectorIcon(icon, tooltip: tooltip)
                } content: {
                    Toggle("", isOn: isOn).labelsHidden()
                }
            )
        }
    }
    ```

*   **SharedUI Conformance Violations**:
    *   `TravelChargeAutomationTestView.swift` (lines 63-70, 77-84, 91-98, 104-111) uses raw `RoundedRectangle` borders:
        ```swift
        .background(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                .fill(StyleGuide.Colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                        .stroke(StyleGuide.Colors.border, lineWidth: 0.6)
                )
        )
        ```
        instead of `SharedUI`'s `.standardSectionStyle()` or `.standardCardStyle()`.

---

## 2. Logic Chain
1. **Observation**: `SettingsRow` relies on a fixed width `labelWidth` calculated via `NSFont.systemFont(ofSize: NSFont.systemFontSize)`.
   **Inference**: When text size is scaled up or down by user accessibility settings, the actual label Text view changes size, but its frame width constraint `labelWidth` remains locked to the default system size.
   **Conclusion**: This will inevitably lead to clipped or truncated text labels on settings pages when Dynamic Type is scaled up.
2. **Observation**: `PropertyInspector` displays `EmptyView()` for `.empty` selection state.
   **Inference**: If a user deselects everything or first opens the editor, the inspector panel shows a completely blank grey/translucent layout.
   **Conclusion**: There is a missing empty state instruction panel in the property inspector.
3. **Observation**: Visual layouts in both `TravelChargeAutomationTestView` and `TravelChargeReviewView` duplicate the background fill and stroke overlay of `standardSectionStyle`.
   **Inference**: Changes to standard styling in `SharedUI` will not apply to these views.
   **Conclusion**: Refinement is needed to replace manual layouts with standard `SharedUI` decorators to ensure design conformity.
4. **Observation**: Custom controls in `InspectorControlDescriptor.swift` hide native labels (`.labelsHidden()`) and provide no alternative accessibility attributes.
   **Inference**: VoiceOver relies on label properties to describe controls.
   **Conclusion**: Blind or low-vision users will hear unlabelled checkboxes, steppers, and text fields without knowing their purpose.

---

## 3. Caveats
No subagent was spawned; all analysis was done directly. We assumed that the standard styles in `SharedUI` are compilation-ready and designed to replace raw rectangles in settings/review panels.

---

## 4. Conclusion
Milestone 6 requires significant UI refinements and accessibility fixes:
1. **Dynamic Type scaling**: Replace static width Calculations in settings panels with flexible grid systems or dynamically scaling frame boundaries (e.g. using `@ScaledMetric`).
2. **Keyboard focus/shortcuts**: Register standard shortcut keys (`Cmd+Z`, `Cmd+Shift+Z`, `Cmd+S`, `Backspace`) in the template editor, and link focus states to form textfields.
3. **Accessibility descriptions**: Map control tooltip strings directly into `.accessibilityLabel()`/`.accessibilityHint()` for all custom inspector controls.
4. **Empty and validation states**: Implement empty state placeholder cards for the template library grid and properties inspector, and show warning banners when layout/form validation fails.
5. **SharedUI alignment**: Standardize borders and backgrounds in `TravelCharge` views, `SystemHealthView`, and `CalendarSettingsView` using `standardCardStyle()` and `standardSectionStyle()`.

---

## 5. Verification Method
1. **Dynamic Type verification**: Build and run the app, then scale Dynamic Type text sizes. Observe settings labels in Profile/Company to check for clipping.
2. **VoiceOver inspection**: Open Xcode Accessibility Inspector (or VoiceOver on macOS) and hover over the inspector panel's font size steppers or alignment pickers. Verify if they read their respective labels.
3. **Empty state inspection**: Deselect all elements on the ITE canvas; verify if the inspector panel goes blank. Open the template manager with no saved templates; verify if the template grid goes blank.
4. **Validation errors verification**: Clear the name field in the Profile section or place overlapping components on the canvas; check if error messages are displayed.
