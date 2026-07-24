# Plan: Milestone 6 — Feature.Settings & Feature.InvoiceTemplateEditor UI Refinement

We will implement the following tasks using a `teamwork_preview_worker` agent, then run builds and tests, review the design, and finally run the forensic auditor.

## Steps
1. **Dynamic Type & Label Refinement**:
   - Refactor `SettingsRow.swift` to wrap the passed-in `labelWidth` in a `@ScaledMetric` binding or variable relative to `.body`. Update alignment if needed.
2. **Property Inspector & Selection State**:
   - In `PropertyInspector.swift`, replace `EmptyView()` inside `.empty` display mode with an info/metadata editor panel and a list of all validation errors in the document.
3. **Empty States**:
   - In `TemplateLibraryGrid.swift`, if `templates.isEmpty` and `!isLoadingTemplates`, render a placeholder view with an icon, title, and descriptive message.
4. **Validation States**:
   - In `ProfileView.swift`, bind the text field values to trigger validation and render red validation error captions under the text fields if `viewModel.validationErrors` contains errors for `"name"` or `"email"`.
5. **Keyboard Focus & Shortcuts**:
   - In `TemplateEditor.swift` (or the editor main view), register invisible buttons with `.keyboardShortcut` modifiers for:
     - Undo: Cmd+Z
     - Redo: Cmd+Shift+Z
     - Save: Cmd+S
     - Delete selected component: Delete/Backspace
6. **Accessibility Compliance**:
   - In `InspectorControlDescriptor.swift`, attach `.accessibilityLabel(tooltip)` and `.accessibilityHint` to the custom picker, color picker, stepper, and toggle controls inside the factory methods.
7. **SharedUI Conformance**:
   - Refactor manual background shapes/overlays in `CalendarSettingsView.swift`, `SystemHealthView.swift`, `InvoiceSettingsView.swift`, `TravelChargeAutomationTestView.swift`, and `TravelChargeReviewView.swift` to use `.standardCardStyle()` or `.standardSectionStyle()`.
