# Structural Layout Remediation Plan

Analysis of four layout issues in the InvoicingApplication.

---

## 1. Document Outline Panel Eager Rendering

### File Path
`Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/TemplateEditor/DocumentOutlinePanel.swift`

### Lines of Code
Lines 14-16

### Before Code Snippet
```swift
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(outline) { node in
```

### Remediation Details
Replace `VStack` with `LazyVStack` to defer rendering of off-screen or collapsed nodes. Improves layout performance for templates with numerous nodes.

### Proposed Code Change
```swift
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(outline) { node in
```

---

## 2. Address Search Eager Dropdown

### File Path
`Packages/WorkspaceUI/Sources/WorkspaceUI/NativeAddressSearchField.swift`

### Lines of Code
Lines 109-111

### Before Code Snippet
```swift
    private var searchResultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<service.searchResults.count, id: \.self) { index in
```

### Remediation Details
Replace `VStack` with `LazyVStack` to avoid immediate allocation and layout of all MKLocalSearch results. Keeps user interface responsive during typing.

### Proposed Code Change
```swift
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(0..<service.searchResults.count, id: \.self) { index in
```

---

## 3. Nested ScrollViews in Import/Export Section

### File Path
`Packages/Feature.Settings/Sources/Feature_Settings/Views/ImportExport/ImportExportView.swift`

### Lines of Code
Lines 351-361 inside vertical scroll container at line 66.

### Before Code Snippet
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

### Remediation Details
Vertical `ScrollView` nested inside parent vertical `ScrollView` breaks inertial scrolling and triggers redundant layout sweeps.
Fix by extracting import logs to a modal sheet that users display via button tap.

### Proposed Code Change
1. Add presentation state to `ImportExportView`:
```swift
    @State private var showingDetailsSheet = false
```

2. Replace the nested `SettingsCard` in view body:
```swift
                        SettingsCard(title: "Details") {
                            HStack {
                                Text("Detailed import messages are available.")
                                    .font(.caption)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                Spacer()
                                Button("View Import Log") {
                                    showingDetailsSheet = true
                                }
                                .buttonStyle(.glass)
                            }
                        }
```

3. Attach `.sheet` modifier to main hierarchy:
```swift
        .sheet(isPresented: $showingDetailsSheet) {
            if let results = viewModel.importResults {
                NavigationStack {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(results.messages.enumerated()), id: \.offset) { index, message in
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                    .padding(.vertical, 2)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .navigationTitle("Import Log Details")
                    #if os(macOS)
                    .frame(minWidth: 500, minHeight: 400)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingDetailsSheet = false
                            }
                        }
                    }
                }
            }
        }
```

---

## 4. Automatic Layout Resizing Undo Pollution

### File Path
`Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridComponent+Layout.swift`

### Lines of Code
Lines 24, 40, and 55.

### Before Code Snippet
```swift
    @MainActor
    func updateColumnWidths(_ widths: [Int: CGFloat]) {
        ...
        if updated {
            document.saveStateForUndo(actionName: "Resize Column")
            document.updateComponent(id: currentComponent.id) { component in
                component.style.columnConfigurations = newConfigs
            }
        }
    }
    
    @MainActor
    func updateComponentWidth(_ width: CGFloat) {
        ...
        document.saveStateForUndo(actionName: "Resize Table")
        document.updateComponent(id: currentComponent.id) { component in
            component.size.width = width
        }
    }
    
    @MainActor
    func updateComponentHeight(_ height: CGFloat) {
        ...
        document.saveStateForUndo(actionName: "Resize Table")
        document.updateComponent(id: currentComponent.id) { component in
            component.size.height = height
        }
    }
```

### Remediation Details
Layout engine calculations trigger `GeometryReader` changes on load or window resize. Performing `saveStateForUndo` in layout measurement loops pollutes the undo stack, making actual document edits impossible to undo.
Remove `saveStateForUndo` from automated sizing flows. Explicit user resizing actions (from inspectors or resize gestures) already save their undo states correctly.

### Proposed Code Change
```swift
    @MainActor
    func updateColumnWidths(_ widths: [Int: CGFloat]) {
        ...
        if updated {
            // REMOVED: document.saveStateForUndo(actionName: "Resize Column")
            document.updateComponent(id: currentComponent.id) { component in
                component.style.columnConfigurations = newConfigs
            }
        }
    }
    
    @MainActor
    func updateComponentWidth(_ width: CGFloat) {
        ...
        guard abs(width - currentWidth) > 0.5, !currentComponent.isResizing else { return }
        
        // REMOVED: document.saveStateForUndo(actionName: "Resize Table")
        document.updateComponent(id: currentComponent.id) { component in
            component.size.width = width
        }
    }
    
    @MainActor
    func updateComponentHeight(_ height: CGFloat) {
        ...
        guard abs(height - currentHeight) > 0.5, !currentComponent.isResizing else { return }
        
        // REMOVED: document.saveStateForUndo(actionName: "Resize Table")
        document.updateComponent(id: currentComponent.id) { component in
            component.size.height = height
        }
    }
```
