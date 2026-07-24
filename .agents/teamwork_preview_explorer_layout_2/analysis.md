# Layout Remediation Plan for InvoicingApplication

This document details the layout issues found in the codebase and provides a step-by-step remediation plan to optimize performance, prevent nested vertical scrolling, and eliminate undo/redo pollution caused by layout measurements.

---

## 1. Eager VStack in Document Outline List

### File Location
`Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/TemplateEditor/DocumentOutlinePanel.swift`

### Original Code (Lines 14-17)
```swift
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(outline) { node in
```

### Problem
The `VStack` eagerly instantiates and lays out all elements of the document outline upon rendering, even those that are off-screen. As a document's template outline grows to include many sections and components, this causes significant performance degradation and frame drops.

### Remediation
Replace `VStack` with `LazyVStack` on line 15.
```swift
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(outline) { node in
```

---

## 2. Eager VStack in Address Search Dropdown

### File Location
`Packages/WorkspaceUI/Sources/WorkspaceUI/NativeAddressSearchField.swift`

### Original Code (Lines 109-111)
```swift
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<service.searchResults.count, id: \.self) { index in
```

### Problem
Like the outline list, the eager `VStack` within the dropdown scroll view instantiates and renders all autocomplete suggestions simultaneously. This can cause UI hiccups during fast keyboard typing and search result refreshes.

### Remediation
Replace `VStack` with `LazyVStack` on line 110.
```swift
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(0..<service.searchResults.count, id: \.self) { index in
```

---

## 3. Nested ScrollViews in Import/Export Screen

### File Location
`Packages/Feature.Settings/Sources/Feature_Settings/Views/ImportExport/ImportExportView.swift`

### Original Code (Lines 350-361 nested inside the main vertical ScrollView at line 66)
```swift
                        SettingsCard(title: "Details") {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(results.messages.enumerated()), id: \.offset) { index, message in
                                        Text(message).font(.caption).foregroundColor(Color("TextSecondary", bundle: .sharedUI)).padding(.vertical, 2)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 150)
                            .border(Color.secondary.opacity(0.2))
                        }
```

### Problem
A vertical scroll area is nested inside the main vertical `ScrollView` wrapping the screen. This breaks scroll inertia, introduces scroll target ambiguity, and causes double-layout passes, degrading overall scroll performance.

### Remediation
Introduce a sheet view to display import log messages, replacing the inline scroll view details card with a button that triggers the sheet.

1. Add a `@State` property to `ImportExportView` (e.g., around line 26) to manage the presentation state:
   ```swift
   @State private var showingDetailsSheet = false
   ```

2. Replace the nested `ScrollView` inside the "Details" `SettingsCard` (Lines 350-361) with a button that toggles `showingDetailsSheet`:
   ```swift
                           SettingsCard(title: "Details") {
                               Button("View Detailed Log") {
                                   showingDetailsSheet = true
                               }
                               .buttonStyle(.glass)
                           }
   ```

3. Bind a `.sheet` modifier to the root view hierarchy (e.g., appended to the `.loadingOverlay` modifier around line 461) to present the details log container:
   ```swift
           .sheet(isPresented: $showingDetailsSheet) {
               if let results = viewModel.importResults {
                   VStack(alignment: .leading, spacing: 16) {
                       HStack {
                           Text("Import Details")
                               .font(.title2)
                               .fontWeight(.semibold)
                           Spacer()
                           Button("Close") {
                               showingDetailsSheet = false
                           }
                           .buttonStyle(.glassProminent)
                       }
                       
                       ScrollView {
                           LazyVStack(alignment: .leading, spacing: 4) {
                               ForEach(Array(results.messages.enumerated()), id: \.offset) { index, message in
                                   Text(message)
                                       .font(.caption)
                                       .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                       .padding(.vertical, 2)
                               }
                           }
                           .frame(maxWidth: .infinity, alignment: .leading)
                       }
                       .padding(8)
                       .background(Color.secondary.opacity(0.05))
                       .cornerRadius(8)
                   }
                   .padding()
                   .frame(minWidth: 500, minHeight: 400)
               }
           }
   ```

---

## 4. GeometryReader Undo Pollution in Document Grid Layout

### File Location
`Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridComponent+Layout.swift`

### Original Code (Lines 24, 40, and 55)
```swift
// Line 24 in updateColumnWidths:
document.saveStateForUndo(actionName: "Resize Column")

// Line 40 in updateComponentWidth:
document.saveStateForUndo(actionName: "Resize Table")

// Line 55 in updateComponentHeight:
document.saveStateForUndo(actionName: "Resize Table")
```

### Problem
These layout update functions are automatically executed during layout passes when `GeometryReader` preference changes measure the columns/grid dimensions. By registering undo states during auto-layout recalculations, the user's undo stack gets polluted with automated sizing adjustments, making it impossible for users to perform regular undos cleanly. Furthermore, registering undo operations can trigger extra view updates, causing infinite measurement loops.

### Remediation
Delete the `document.saveStateForUndo(actionName: ...)` calls from these methods to keep model-driven layout sizing updates quiet and out of the user's undo queue.

1. **Delete Line 24** inside `updateColumnWidths`:
   ```swift
   // Delete: document.saveStateForUndo(actionName: "Resize Column")
   ```

2. **Delete Line 40** inside `updateComponentWidth`:
   ```swift
   // Delete: document.saveStateForUndo(actionName: "Resize Table")
   ```

3. **Delete Line 55** inside `updateComponentHeight`:
   ```swift
   // Delete: document.saveStateForUndo(actionName: "Resize Table")
   ```
