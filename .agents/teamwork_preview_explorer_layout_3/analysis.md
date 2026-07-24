# Layout Remediation Plan — InvoicingApplication

This report details structural layout fixes for four high-priority UI bottlenecks in the `InvoicingApplication` codebase. The proposed fixes resolve layout-time stuttering, scroll-gesture conflicts, and undo-history pollution caused by automated size-measurement updates.

---

## 1. Executive Summary

- **Eager rendering stacks in scroll views**: Replacing eager `VStack` wrappers inside `ScrollView` with `LazyVStack` in `DocumentOutlinePanel` and `NativeAddressSearchField` defers the initialization of off-screen rows. This prevents main-thread stalls when rendering lists of template outline nodes or dynamic map search results.
- **Nested scroll views on the same axis**: Extracting the nested vertical scroll area in `ImportExportView` into a dedicated modal/sheet sheet eliminates touch gesture conflicts and layout engine double-passes.
- **Layout-driven undo history pollution**: Removing `saveStateForUndo` calls from automated layout calculations inside `DocumentGridComponent+Layout` keeps the user's undo stack clean of layout-triggered resize checkpoints, restoring normal Command-Z functionality for explicit user edits.

---

## 2. Remediation Details

### 2.1. Document Outline Panel (Eager VStack in ScrollView)
- **Target File**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/TemplateEditor/DocumentOutlinePanel.swift`
  *(Note: The global scan report referenced `Views/Outline/DocumentOutlinePanel.swift`; the correct repository path is under `Views/TemplateEditor/DocumentOutlinePanel.swift`)*
- **Problem**: `VStack` on line 15 is nested inside `ScrollView` and wraps a `ForEach` loop that renders document layout nodes. This causes immediate eager rendering of all outline items, including children/sub-items that are collapsed or off-screen, affecting canvas frame-rate when loading large documents.
- **Line Numbers**: 14-16

#### Code Snippet (Before):
```swift
14:             ScrollView {
15:                 VStack(alignment: .leading, spacing: 2) {
16:                     ForEach(outline) { node in
```

#### Proposed Code Change (After):
Replace `VStack` on line 15 with `LazyVStack`:
```swift
14:             ScrollView {
15:                 LazyVStack(alignment: .leading, spacing: 2) {
16:                     ForEach(outline) { node in
```

---

### 2.2. Address Search Field (Eager VStack in ScrollView)
- **Target File**: `Packages/WorkspaceUI/Sources/WorkspaceUI/NativeAddressSearchField.swift`
- **Problem**: Eager `VStack` on line 110 inside `ScrollView` renders MKLocalSearch completions immediately. With large autocomplete result sets, this causes brief main-thread blocking as all result panels and dividers are constructed at once.
- **Line Numbers**: 109-111

#### Code Snippet (Before):
```swift
109:         ScrollView {
110:             VStack(alignment: .leading, spacing: 0) {
111:                 ForEach(0..<service.searchResults.count, id: \.self) { index in
```

#### Proposed Code Change (After):
Replace `VStack` on line 110 with `LazyVStack`:
```swift
109:         ScrollView {
110:             LazyVStack(alignment: .leading, spacing: 0) {
111:                 ForEach(0..<service.searchResults.count, id: \.self) { index in
```

---

### 2.3. Import/Export View (Nested ScrollViews on same vertical axis)
- **Target File**: `Packages/Feature.Settings/Sources/Feature_Settings/Views/ImportExport/ImportExportView.swift`
- **Problem**: The view features a vertical `ScrollView` as its main wrapper. Inside this, the "Import Results Detail View" card embeds a nested vertical `ScrollView` (line 351) showing the import log messages. Even with a height constraint of 150pt, nesting scroll views on the same axis triggers layout engine ambiguity, causes double-layout passes, and breaks inertia-scrolling gestures.
- **Line Numbers**: 350-362

#### Proposed Remediation:
Introduce a state variable to control log visibility and display the log messages within a modal sheet, removing the nested scrolling area from the settings panel entirely.

#### Step 1: Add state variable to `ImportExportView`
```swift
@State private var showingImportDetails = false
```

#### Step 2: Replace nested ScrollView in the details card (Lines 350-361)
**Before:**
```swift
350:                         SettingsCard(title: "Details") {
351:                             ScrollView {
352:                                 LazyVStack(alignment: .leading, spacing: 4) {
353:                                     ForEach(Array(results.messages.enumerated()), id: \.offset) { index, message in
354:                                         Text(message).font(.caption).foregroundColor(Color("TextSecondary", bundle: .sharedUI)).padding(.vertical, 2)
355:                                     }
356:                                 }
357:                                 .frame(maxWidth: .infinity, alignment: .leading)
358:                             }
359:                             .frame(height: 150)
360:                             .border(Color.secondary.opacity(0.2))
361:                         }
```

**After:**
```swift
                        SettingsCard(title: "Details") {
                            HStack {
                                Text("\(results.messages.count) log messages generated.")
                                    .font(.caption)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                Spacer()
                                Button(action: { showingImportDetails = true }) {
                                    Label("View Log Details", systemImage: "doc.plaintext")
                                }
                                .pointerStyle(.link)
                                .buttonStyle(.glass)
                            }
                            .padding(.vertical, 4)
                        }
```

#### Step 3: Append sheet modifier to the bottom of the main view body (e.g., after line 461)
```swift
        .sheet(isPresented: $showingImportDetails) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Import Detailed Log")
                        .font(.headline)
                    Spacer()
                    Button("Close") {
                        showingImportDetails = false
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                Divider()
                
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
                .padding(.horizontal)
                .frame(minWidth: 500, minHeight: 400)
            }
            .presentationDetents([.medium, .large])
        }
```

---

### 2.4. Document Grid Component (Undo Stack Pollution on Auto-Layout)
- **Target File**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridComponent+Layout.swift`
- **Problem**: When rendering layout nodes or sizing columns, preference key changes and `GeometryReader` passes trigger automated sizing methods: `updateColumnWidths(_:)`, `updateComponentWidth(_:)`, and `updateComponentHeight(_:)`. Inside these methods, `document.saveStateForUndo` is called. Because layout calculations run repeatedly on render and window resize, this pollutes the user's undo stack with automatic "Resize Table" and "Resize Column" states. The user cannot perform standard undos on actual text edits.
- **Line Numbers**: 24, 40, and 55

#### Proposed Remediation:
Remove `saveStateForUndo` from these automatic measurement-driven methods. Manual resizing (via inspector properties and user drags) already registers undo checkpoints via dedicated actions on `InvoiceDocument`.

#### Changes in `DocumentGridComponent+Layout.swift`:

**1. Line 24 (`updateColumnWidths`):**
```swift
// Remove line 24
23:         if updated {
24:             document.saveStateForUndo(actionName: "Resize Column") // <--- REMOVE
25:             document.updateComponent(id: currentComponent.id) { component in
```

**2. Line 40 (`updateComponentWidth`):**
```swift
// Remove line 40
38:         guard abs(width - currentWidth) > 0.5, !currentComponent.isResizing else { return }
39:         
40:         document.saveStateForUndo(actionName: "Resize Table") // <--- REMOVE
41:         document.updateComponent(id: currentComponent.id) { component in
```

**3. Line 55 (`updateComponentHeight`):**
```swift
// Remove line 55
53:         guard abs(height - currentHeight) > 0.5, !currentComponent.isResizing else { return }
54:         
55:         document.saveStateForUndo(actionName: "Resize Table") // <--- REMOVE
56:         document.updateComponent(id: currentComponent.id) { component in
```
