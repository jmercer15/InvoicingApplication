import SwiftUI

struct InvoiceBuilderView: View {
    @EnvironmentObject private var document: InvoiceDocument
    @StateObject private var templateManager = TemplateManager.shared
    
    @State private var showingSaveDialog = false
    @State private var showingBrowserDialog = false
    @State private var showingNewDocumentAlert = false
    @State private var lastAvailableSize: CGSize = .zero
    @State private var showRulers = true
    @State private var showMargins = false
    @State private var snapToGrid = true
    @State private var showGrid = false

    var body: some View {
        CustomHSplitView(
            fraction: 0.22,
            minPFraction: 0.12,
            minSFraction: 0.2,
            isPrimaryVisible: .constant(true)
        ) {
            // Primary: Component palette
            ComponentPaletteView()
        } secondary: {
            // Secondary: Canvas
            InvoiceCanvasView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear { lastAvailableSize = geometry.size }
                            .onChange(of: geometry.size) { lastAvailableSize = $0 }
                    }
                )
        } splitter: { _ in
            // Custom splitter view
            Splitter()
        }
        .inspector(isPresented: .constant(true)) {
            InspectorView()
        }
        .toolbar {
            // File operations - left side
            ToolbarItemGroup(placement: .navigation) {
                Menu {
                    Button("New Template") {
                        showingNewDocumentAlert = true
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    
                    Divider()
                    
                    Button("Save Template As...") {
                        showingSaveDialog = true
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    
                    Button("Browse Templates...") {
                        showingBrowserDialog = true
                    }
                    .keyboardShortcut("o", modifiers: .command)
                    
                    if !templateManager.recentTemplates.isEmpty {
                        Divider()
                        
                        ForEach(templateManager.recentTemplates.prefix(5), id: \.id) { template in
                            Button(template.name) {
                                loadRecentTemplate(template)
                            }
                        }
                    }
                } label: {
                    Label("File", systemImage: "doc.on.doc")
                }
            }
            
            // View controls
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button("Show Rulers") {
                        toggleRulers()
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    
                    Button("Show Margins") {
                        toggleMargins()
                    }
                    .keyboardShortcut("m", modifiers: .command)
                    
                    Divider()
                    
                    Button("Snap to Grid") {
                        toggleSnapping()
                    }
                    .keyboardShortcut("g", modifiers: .command)
                    
                    Button("Show Grid") {
                        toggleGrid()
                    }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                } label: {
                    Label("View", systemImage: "eye")
                }
            }
            
            // Zoom controls - grouped for better organization
            ToolbarItemGroup(placement: .automatic) {
                Button(action: { document.zoom = max(0.25, document.zoom - 0.1) }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .help("Zoom out (⌘-)")
                .keyboardShortcut("-", modifiers: .command)
                
                Text(String(format: "%d%%", Int(document.zoom * 100)))
                    .help("Current zoom level")
                
                Button(action: { document.zoom = 1.0 }) {
                    Image(systemName: "1.magnifyingglass")
                }
                .help("Reset to 100% (⌘0)")
                .keyboardShortcut("0", modifiers: .command)
                
                Button(action: { document.zoom = min(4.0, document.zoom + 0.1) }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .help("Zoom in (⌘=)")
                .keyboardShortcut("=", modifiers: .command)
                
                Menu {
                    Button("Zoom to Fit") {
                        zoomToFit()
                    }
                    .keyboardShortcut("f", modifiers: .command)
                    
                    Button("Zoom to Selection") {
                        zoomToSelection()
                    }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                    
                    Divider()
                    
                    Button("25%") { document.zoom = 0.25 }
                    Button("50%") { document.zoom = 0.5 }
                    Button("75%") { document.zoom = 0.75 }
                    Button("100%") { document.zoom = 1.0 }
                    Button("150%") { document.zoom = 1.5 }
                    Button("200%") { document.zoom = 2.0 }
                } label: {
                    Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                }
                .help("Zoom options")
            }
            
            // Export menu
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button("Export to PDF...") {
                        PDFExporter.export(document: document)
                    }
                    .keyboardShortcut("e", modifiers: .command)
                    
                    Button("Export to Image...") {
                        exportToImage()
                    }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    
                    Divider()
                    
                    Button("Print...") {
                        printDocument()
                    }
                    .keyboardShortcut("p", modifiers: .command)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
            
            // Document info and undo/redo
            ToolbarItemGroup(placement: .secondaryAction) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                    Text("\(document.components.count) components")
                }
                .help("Document statistics")
                
                Button(action: { document.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!document.canUndo)
                .help("Undo (⌘Z)")
                .keyboardShortcut("z", modifiers: .command)
                
                Button(action: { document.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!document.canRedo)
                .help("Redo (⌘⇧Z)")
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }
        }
        .sheet(isPresented: $showingSaveDialog) {
            SaveTemplateDialog()
                .environmentObject(document)
        }
        .sheet(isPresented: $showingBrowserDialog) {
            TemplateBrowserDialog()
                .environmentObject(document)
        }
        .alert("New Template", isPresented: $showingNewDocumentAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Create New") {
                document.createNewDocument()
            }
        } message: {
            Text("This will clear your current template. Are you sure you want to create a new one?")
        }
        .alert("Error", isPresented: .constant(templateManager.lastError != nil)) {
            Button("OK") {
                templateManager.clearError()
            }
        } message: {
            if let error = templateManager.lastError {
                Text(error)
            }
        }
    }
    
    private func loadRecentTemplate(_ template: TemplateMetadata) {
        Task {
            if let templateData = await templateManager.loadTemplate(metadata: template) {
                await MainActor.run {
                    document.loadTemplate(templateData)
                }
            }
        }
    }
    
    private func zoomToFit() {
        guard lastAvailableSize.width > 0 && lastAvailableSize.height > 0 else { return }
        let contentW = lastAvailableSize.width - 40 // Account for rulers
        let contentH = lastAvailableSize.height - 40 // Account for rulers
        let scaleW = contentW / A4.width
        let scaleH = contentH / A4.height
        let fitScale = min(scaleW, scaleH)
        document.zoom = min(max(0.25, fitScale), 4.0)
    }
    
    private func zoomToSelection() {
        // TODO: Implement zoom to selection
        // This would zoom to fit the currently selected component(s)
    }
    
    private func toggleRulers() {
        showRulers.toggle()
    }
    
    private func toggleMargins() {
        showMargins.toggle()
    }
    
    private func toggleSnapping() {
        snapToGrid.toggle()
    }
    
    private func toggleGrid() {
        showGrid.toggle()
    }
    
    private func exportToImage() {
        PDFExporter.exportToImage(document: document)
    }

    private func printDocument() {
        PDFExporter.printDocument(document: document)
    }
}
