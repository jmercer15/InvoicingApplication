import SwiftUI
import SharedUI

// MARK: - Size Preference Key

struct CanvasSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - Template Editor Toolbar

struct TemplateEditorToolbar: View {
    @ObservedObject private var workspace: TemplateEditorWorkspaceViewModel
    @StateObject private var templateManager = TemplateManager.shared
    @Binding private var isInspectorVisible: Bool

    init(workspace: TemplateEditorWorkspaceViewModel, isInspectorVisible: Binding<Bool>) {
        self._workspace = ObservedObject(wrappedValue: workspace)
        self._isInspectorVisible = isInspectorVisible
    }

    var body: some View {
        HStack(spacing: 0) {
            // View controls toolbar
            viewControlsToolbar

            Spacer()

            // File operations toolbar
            fileOperationsToolbar

            Spacer()

            // Recent templates menu (only show if there are recent templates)
            if !templateManager.recentTemplates.isEmpty {
                recentTemplatesMenu
            }

            // Inspector toggle
            inspectorToggleButton
        }
    }

    private var viewControlsToolbar: some View {
        HStack(spacing: 8) {
            Menu {
                Button("Show Rulers") { workspace.showRulers.toggle() }
                Button("Show Margins") { workspace.showMargins.toggle() }
                Divider()
                Button("Snap to Grid") { workspace.snapToGrid.toggle() }
                Button("Show Grid") { workspace.showGrid.toggle() }
            } label: {
                Label("View", systemImage: "rectangle.3.group")
            }

            Menu {
                Button("Zoom In") { document.zoom = min(document.zoom * 1.2, 4.0) }
                Button("Zoom Out") { document.zoom = max(document.zoom / 1.2, 0.25) }
                Button("Zoom to Fit", action: zoomToFit)
                Button("Actual Size") { document.zoom = 1.0 }
            } label: {
                Label("Zoom", systemImage: "plus.magnifyingglass")
            }

            Menu {
                Button { workspace.showRulers.toggle() } label: {
                    labelForToggle("Show Rulers", isOn: workspace.showRulers)
                }
                Divider()
                Button { workspace.rulerUnit = .points } label: {
                    labelForToggle("Points", isOn: workspace.rulerUnit == .points)
                }
                Button { workspace.rulerUnit = .millimeters } label: {
                    labelForToggle("Millimeters", isOn: workspace.rulerUnit == .millimeters)
                }
                Button { workspace.rulerUnit = .inches } label: {
                    labelForToggle("Inches", isOn: workspace.rulerUnit == .inches)
                }
            } label: {
                Label("Rulers", systemImage: "ruler")
            }
        }
    }

    private var fileOperationsToolbar: some View {
        HStack(spacing: 8) {
            Button(action: { workspace.showingNewDocumentAlert = true }) {
                Label("New", systemImage: "document.badge.plus")
            }
            .keyboardShortcut("n", modifiers: .command)

            Button { workspace.showingSaveDialog = true } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)

            Button { workspace.showingBrowserDialog = true } label: {
                Label("Browse", systemImage: "folder.circle")
            }
            .keyboardShortcut("o", modifiers: .command)

            PDFPreviewButton(document: document)
                .keyboardShortcut("p", modifiers: .command)
        }
    }

    private var recentTemplatesMenu: some View {
        Menu {
            ForEach(templateManager.recentTemplates.prefix(5), id: \.id) { template in
                Button(template.name) { loadRecentTemplate(template) }
            }
        } label: {
            Label("Recent", systemImage: "clock.arrow.circlepath")
        }
    }

    private var inspectorToggleButton: some View {
        Button {
            isInspectorVisible.toggle()
        } label: {
            Label("Inspector", systemImage: isInspectorVisible ? "document.badge.gearshape.fill" : "document.badge.gearshape")
        }
        .keyboardShortcut("i", modifiers: .command)
    }

    private var document: InvoiceDocument { workspace.editorViewModel.document }

    private func labelForToggle(_ title: String, isOn: Bool) -> some View {
        HStack {
            Text(title)
            if isOn { Image(systemName: "checkmark") }
        }
    }

    private func zoomToFit() {
        let pageSize = document.pageSize
        guard workspace.lastAvailableSize.width > 0,
              workspace.lastAvailableSize.height > 0,
              pageSize.width > 0,
              pageSize.height > 0 else { return }

        let padding: CGFloat = 40
        let availableWidth = max(1, workspace.lastAvailableSize.width - padding)
        let availableHeight = max(1, workspace.lastAvailableSize.height - padding)
        let scaleW = availableWidth / pageSize.width
        let scaleH = availableHeight / pageSize.height
        let fitScale = min(scaleW, scaleH)
        document.zoom = min(max(0.25, fitScale), 4.0)
    }

    private func loadRecentTemplate(_ template: TemplateMetadata) {
        Task {
            if let templateData = await templateManager.loadTemplate(metadata: template) {
                await MainActor.run {
                    workspace.editorViewModel.document.loadTemplate(templateData)
                }
            }
        }
    }
}

public struct TemplateEditorContentColumn: View {
    @ObservedObject private var workspace: TemplateEditorWorkspaceViewModel

    public init(workspace: TemplateEditorWorkspaceViewModel) {
        self._workspace = ObservedObject(wrappedValue: workspace)
    }

    public var body: some View {
        Group {
            if workspace.isPaletteVisible {
                ComponentPaletteView()
                    .environmentObject(workspace.editorViewModel.document)
            } else {
                EmptyStateView(
                    icon: "rectangle.stack.badge.plus",
                    title: "Palette Hidden",
                    message: "Use the toggle to show component palette."
                )
            }
        }
        .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
        .toolbar { primaryToolbar }
    }

    @ToolbarContentBuilder
    private var primaryToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    workspace.isPaletteVisible.toggle()
                }
            } label: {
                Label(workspace.isPaletteVisible ? "Hide Components" : "Show Components",
                      systemImage: workspace.isPaletteVisible ? "rectangle.stack.fill.badge.plus" : "rectangle.stack.badge.plus")
            }
            .help("Toggle component palette")
        }
    }

}

public struct TemplateEditorDetailColumn: View {
    @ObservedObject private var workspace: TemplateEditorWorkspaceViewModel
    @StateObject private var templateManager = TemplateManager.shared
    @Binding private var isInspectorVisible: Bool

    public init(workspace: TemplateEditorWorkspaceViewModel, isInspectorVisible: Binding<Bool>) {
        self._workspace = ObservedObject(wrappedValue: workspace)
        self._isInspectorVisible = isInspectorVisible
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            TemplateEditorToolbar(workspace: workspace, isInspectorVisible: $isInspectorVisible)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))

            // Canvas
            InvoiceCanvasView(
                showRulers: workspaceBinding(\.showRulers),
                rulerUnit: workspaceBinding(\.rulerUnit),
                showMarginsOverlay: workspaceBinding(\.showMarginsOverlay)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: CanvasSizePreferenceKey.self, value: geometry.size)
                }
            )
            .onPreferenceChange(CanvasSizePreferenceKey.self) { newSize in
                // Only update if the size has changed significantly (more than 1 point)
                // This prevents excessive updates during animations/layout
                let currentSize = workspace.lastAvailableSize
                let sizeDifference = abs(currentSize.width - newSize.width) + abs(currentSize.height - newSize.height)

                if sizeDifference > 1.0 {
                    workspace.lastAvailableSize = newSize
                }
            }
        }
        .sheet(isPresented: workspaceBinding(\.showingSaveDialog)) {
            SaveTemplateDialog()
                .environmentObject(document)
        }
        .sheet(isPresented: workspaceBinding(\.showingBrowserDialog)) {
            TemplateBrowserDialog()
                .environmentObject(document)
        }
        .alert("Create New Template", isPresented: workspaceBinding(\.showingNewDocumentAlert)) {
            Button("Cancel", role: .cancel) {}
            Button("Create New") {
                workspace.editorViewModel.createNewDocument()
            }
        } message: {
            Text("This will clear your current template. Are you sure?")
        }
        .alert("Error", isPresented: Binding(
            get: { templateManager.lastError != nil },
            set: { _ in templateManager.clearError() }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(templateManager.lastError ?? "")
        }
        .environmentObject(workspace.editorViewModel.document)
        .preference(
            key: InspectorContentPreferenceKey.self,
            value: InspectorContent(
                id: "TemplateEditorInspector",
                view: AnyView(
                    InspectorView()
                        .environmentObject(workspace.editorViewModel.document)
                        .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
                )
            )
        )
    }

    private var document: InvoiceDocument { workspace.editorViewModel.document }

    private func workspaceBinding<T>(_ keyPath: ReferenceWritableKeyPath<TemplateEditorWorkspaceViewModel, T>) -> Binding<T> {
        Binding(
            get: { workspace[keyPath: keyPath] },
            set: { workspace[keyPath: keyPath] = $0 }
        )
    }
}
