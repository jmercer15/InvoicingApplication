# Milestone 6 Investigation Report: UI Refinement Analysis
*Feature.Settings & Feature.InvoiceTemplateEditor UI/UX, Keyboard Navigation, and Accessibility Review*

## Summary of Core Findings
1. **Unrendered Validation States**: Both packages implement background validation logic (`ProfileViewModel.validate()`, `InvoiceTemplateEditorViewModel.validateDocument()`), but their respective views never display these validation errors to the user.
2. **Missing Empty States**:
   - The **Property Inspector** panel displays `EmptyView()` (complete blank space) when no component/split is selected on the canvas.
   - The **Template Library Grid** displays a completely blank page when the template list is empty or search returns no matches.
3. **Static Label Sizing (Accessibility Bug)**: Settings panels (`SettingsRow`) calculate label frame widths using static text dimensions derived from the default system font size. If a user scales their text size via Dynamic Type, the label width does not adjust, causing text clipping or overlaps.
4. **Complete Absence of Keyboard Shortcuts & Custom Focus**: There are no keyboard focus states or shortcuts (e.g., Undo, Redo, Save, Delete, or grid/canvas keyboard traversal) inside either package, with the exception of a single default button shortcut in `CreateCalendarSheet`.
5. **Screen Reader (VoiceOver) Trailing Gaps**: Multiple interactive components (picker fields, color pickers, and steppers in the property inspector) hide default labels using `.labelsHidden()` but fail to define `.accessibilityLabel()` or `.accessibilityHint()`, leaving VoiceOver users with unlabelled inputs.

---

## 1. Views & ViewModels Analysis

### Feature.Settings
*   **Structure**: 
    *   `SettingsColumns` serves as the entry point, defining two columns: a sidebar selector (`SettingsView` selecting `SettingsSection` cases) and a detail panel (`SettingsDetailColumn`).
    *   `SettingsWorkspaceViewModel` manages the active selection state.
*   **Sub-Section Data Flows**:
    *   **Profile**: Wires `ProfileViewModel` (`@Observable` class). Edits to local fields (`name`, `email`, `phone`, `role`) write back to `UserDefaults` (via a KVO-like wrapper `defaults.observedValue(forKey:...)`). Saves on `onDisappear`.
    *   **Company**: Wires `CompanyViewModel` (`@Observable` class). Interacts with `Business` models via SwiftData. Triggers geocoding queries when an address is committed.
    *   **Calendar**: Wires `CalendarSettingsViewModel` (`@Observable` class). Manages permissions, available calendars, and recurrence rules. Mediates between `CalendarPreferencesStore` and EventKit sync services.
    *   **Import/Export**: Wires `ImportExportViewModel` (`@Observable` class). Coordinates SwiftData import/export operations and NDIS claims export/reconciliation.
    *   **Travel Charge**: Wires `TravelChargeAutomationViewModel` / `TravelChargeReviewViewModel` to trigger calculations and review compliant violations.
    *   **Inconsistencies**: `InvoiceSettingsView` and `NDISBillingSettingsView` do not have ViewModels. Instead, they use `@AppStorage` directly in the view body. This violates the architectural pattern established in the rest of the settings module.

### Feature.InvoiceTemplateEditor
*   **Structure**: 
    *   `ModernTemplateManagementView` coordinates between a template browsing/library screen (`TemplateLibraryGrid`) and the canvas-based editor (`ModernTemplateEditor`).
    *   `TemplateEditorWorkspaceViewModel` handles template metadata, creation of drafts, template duplication/deletion, and file operations.
    *   `InvoiceTemplateEditorViewModel` manages the current document state (an `@Observable` `InvoiceDocument` instance) and validation rules.
*   **Interactive Design & Canvas**:
    *   Layouts are represented hierarchically using `RatioBasedLayout` (for vertical section splits) and `SplittableRectangleView` (for grid-based subdivisions).
    *   The property inspector (`PropertyInspector` / `ModernInspectorView`) displays the appropriate editor panel (`ComponentPropertyEditor`, `LayoutPropertyEditor`, or `TableElementPropertyEditor`) based on the active selection in the document.
    *   Changes on the canvas update the components in the document, which propagates updates reactively.

---

## 2. UI Refinement Areas

### Visual Depth & Styling Compliance
*   **SharedUI Conformance**: The project provides `.standardSectionStyle()` and `.standardCardStyle()` in `SharedUI` to handle borders, backgrounds, and standard corner radii.
*   **Raw Overrides (Bypassing SharedUI)**:
    *   `CalendarSettingsView`: Sync visibility rows (`monitoredCalendarsSection` at line 372-378) use manual backgrounds and borders:
        ```swift
        .background(Color.accentColor.opacity(0.05))
        .cornerRadius(cornerRadiusLarge)
        .overlay(RoundedRectangle(cornerRadius: cornerRadiusLarge).stroke(...))
        ```
    *   `SystemHealthView`: Row items (line 99-101) use custom overlays/backgrounds instead of cards.
    *   `InvoiceSettingsView`: The text editors use manual border styling (lines 47-53 and lines 92-98).
    *   `TravelChargeAutomationTestView`: Uses manual `RoundedRectangle` borders/backgrounds (lines 63-70, 77-84, 91-98, 104-111) instead of `SharedUI` modifiers.
    *   `TravelChargeReviewView`: The header (lines 66-74), status filter (lines 96-104), and `ReviewItemCard` (lines 195-201) use manual card background/stroke logic.

### Empty, Error, and Loading States
*   **Property Inspector Empty State**: When `displayMode` resolves to `.empty` (line 61 in `PropertyInspector.swift`), it returns `EmptyView()`. The inspector panel goes entirely blank, missing a placeholder instruction.
*   **Template Library Empty State**: If no templates exist or search filters result in an empty list, `TemplateLibraryGrid` displays an empty ScrollView without any graphic or "No templates found" message.
*   **Validation Errors (Silent Failures)**:
    *   `ProfileViewModel` validates name/email formats and populates `validationErrors` but the view never reads it.
    *   `InvoiceTemplateEditorViewModel` performs full layout/component validation and populates `validationErrors` but the editor view does not display them.
*   **Loading States**:
    *   `ImportExportView` uses custom loading wrappers.
    *   `CompanyView` and `CalendarSettingsView` use standard loading overlays with a dimmed background and `ProgressView`.

---

## 3. Keyboard Focus & Shortcuts

*   **Keyboard Shortcuts**:
    *   **Feature.Settings**: No custom keyboard shortcuts are registered (e.g. Cmd+S to save Company details, Esc to discard/cancel changes).
    *   **Feature.InvoiceTemplateEditor**: There are no keyboard shortcuts in the editor. Common shortcuts such as Cmd+Z (Undo), Cmd+Shift+Z (Redo), Cmd+S (Save), and Backspace/Delete (Delete active element) are completely absent.
*   **Focus State & Traversal**:
    *   No custom `@FocusState` structures are defined in Settings views to manage tab sequence or submit transitions.
    *   Canvas components do not support keyboard selection traversal (e.g., using arrow keys to move focus between components).

---

## 4. Accessibility Compliance

### Label Sizing and Clipping (Crucial Bug)
`SettingsRow` layout and label sizing logic:
```swift
HStack(alignment: .firstTextBaseline) {
    Text(label)
        .foregroundColor(Color("Text", bundle: .sharedUI))
        .frame(width: labelWidth, alignment: .trailing)
        .lineLimit(1)
    content
}
```
*   `labelWidth` is a fixed `CGFloat` computed by checking the text length using standard font sizes (`width(for:)` in `SettingsRow.swift`).
*   Because `labelWidth` is hardcoded as a fixed frame constraint and does not scale dynamically with `@ScaledMetric`, when a user increases their system text size (Dynamic Type), the label text scales but is clipped by the narrow frame width constraint.

### Screen Reader (VoiceOver) Compatibility
*   **Hidden Labels on Controls**: Inspector controls (`InspectorControlDescriptor.swift`) such as steppers, color pickers, text fields, and dropdowns use `.labelsHidden()`. The visual labels are provided by a separate `InspectorIcon` or text column. Because these controls do not set an explicit `.accessibilityLabel()`, screen readers read the control without identifying its purpose (e.g., "stepper, 12 pt" without stating it controls "Font Size").
*   **Button/Tap Gesture Redundancy**:
    *   `CalendarRowView` uses a nested button for checking visibility, a separate circle button for color selection, and `onTapGesture` on the row wrapper. This creates duplicate focus targets and confusing behaviors.
    *   `RecursiveNodeView` (Document Outline) uses custom tap gestures for row selection and nested buttons for expand/collapse chevrons without marking the row as an accessibility element.
*   **Missing Icon Descriptions**: Premium badge icons and status checks in the template cards and health check panels lack alternative text descriptions.

---

## 5. Architectural Quality and Technical Debt

1. **Inconsistent ViewModel Usage**: Settings is split between MVVM (`ProfileViewModel`, `CompanyViewModel`) and view-local `@AppStorage` configurations.
2. **Duplicated Inspector Headers**: The `PropertyInspector` and sub-editors have overlapping header configurations.
3. **Hardcoded Fonts in Size Calculation**: The `String.width(for:)` utility relies on standard AppKit font representations rather than supporting adaptive system font metrics.
