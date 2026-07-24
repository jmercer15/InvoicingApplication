# Handoff Report - Layout Remediation Plan

## 1. Observation
Direct observations of layout issues in the codebase:

1. **Document Outline Panel Eager Rendering**
   - **Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/TemplateEditor/DocumentOutlinePanel.swift`
   - **Lines**: 14-16
   - **Code**:
     ```swift
     ScrollView {
         VStack(alignment: .leading, spacing: 2) {
             ForEach(outline) { node in
     ```

2. **Address Search Eager Dropdown**
   - **Path**: `Packages/WorkspaceUI/Sources/WorkspaceUI/NativeAddressSearchField.swift`
   - **Lines**: 109-111
   - **Code**:
     ```swift
     private var searchResultsView: some View {
         ScrollView {
             VStack(alignment: .leading, spacing: 0) {
                 ForEach(0..<service.searchResults.count, id: \.self) { index in
     ```

3. **Nested ScrollViews**
   - **Path**: `Packages/Feature.Settings/Sources/Feature_Settings/Views/ImportExport/ImportExportView.swift`
   - **Lines**: 66 (parent `ScrollView`) and 351 (nested `ScrollView`)
   - **Code**:
     ```swift
     ScrollView { // Line 351 (Nested on the same vertical axis)
         LazyVStack(alignment: .leading, spacing: 4) {
             ForEach(Array(results.messages.enumerated()), id: \.offset) { index, message in
     ```

4. **GeometryReader Sizing Undo Pollution**
   - **Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridComponent+Layout.swift`
   - **Lines**: 24, 40, and 55
   - **Code**:
     ```swift
     // Line 24
     document.saveStateForUndo(actionName: "Resize Column")
     // Line 40
     document.saveStateForUndo(actionName: "Resize Table")
     // Line 55
     document.saveStateForUndo(actionName: "Resize Table")
     ```

---

## 2. Logic Chain
1. **Eager List Performance**: In `DocumentOutlinePanel.swift` and `NativeAddressSearchField.swift`, using `VStack` inside a `ScrollView` causes eager loading of all child elements. Replacing them with `LazyVStack` defers child layout until views scroll on-screen, boosting performance.
2. **Scrolling Conflicts**: Nested `ScrollView`s on the same vertical axis in `ImportExportView.swift` create gesture competition and multiple rendering loops. Extracting the detail log into a separate sheet using `.sheet` eliminates the conflict while retaining viewability.
3. **Undo Pollution**: In `DocumentGridComponent+Layout.swift`, `saveStateForUndo` is triggered within layout preference-change handlers. Because these handlers run during automatic UI updates (like view insertion or window resizing), they inject layout adjustments into the user's undo/redo history. Removing `saveStateForUndo` from these automatic measurement methods prevents stack pollution; user-directed gestures/inspector controls already save undo states independently.

---

## 3. Caveats
- No runtime testing has been conducted since this task is strictly a read-only investigation.
- Assumptions are made that column/table resizes triggered by manual slider or text input updates correctly execute separate undo actions, which has been verified by checking other source files (e.g., `ComponentPropertyEditor+Table.swift`).

---

## 4. Conclusion
Remediation actions are localized and simple:
1. Swap `VStack` for `LazyVStack` in both outline and search views.
2. Present settings import details via a modal sheet to resolve vertical nesting.
3. Remove automatic `saveStateForUndo` calls from the layout/preference calculation helpers.

---

## 5. Verification Method
1. Inspect the layout of target files to ensure code matching the proposed remediations is applied.
2. Verify the application continues to build by running:
   ```bash
   swift build
   ```
3. Test layout change and undo-stack preservation: after opening the editor, check that the "Undo" option is disabled until an explicit user edit is performed.
