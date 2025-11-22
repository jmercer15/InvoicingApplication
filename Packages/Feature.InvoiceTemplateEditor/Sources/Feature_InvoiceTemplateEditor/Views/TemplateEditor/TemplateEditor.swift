//
//  TemplateEditor.swift
//  Feature.InvoiceTemplateEditor
//
//  Template editor with toolbar, palette, and inspector
//

import SwiftUI
import Core

struct ModernTemplateEditor: View {
    let template: TemplateItem
    @ObservedObject var workspace: TemplateEditorWorkspaceViewModel
    let onBackToTemplates: () -> Void
    @Binding var isInspectorVisible: Bool

    @State private var statusMessage: String?
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var statusWorkItem: DispatchWorkItem?

    private var editorViewModel: InvoiceTemplateEditorViewModel {
        workspace.editorViewModel
    }

    private var selectedComponent: InvoiceComponent? {
        editorViewModel.document.component(editorViewModel.document.selectedComponentID)
    }

    private var canUndo: Bool {
        editorViewModel.document.canUndo
    }

    private var canRedo: Bool {
        editorViewModel.document.canRedo
    }

    private var isBusy: Bool {
        editorViewModel.isLoading || workspace.isOpeningTemplate
    }

    var body: some View {
        editorLayout
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
                .pointerStyle(.link)
        } message: {
            Text(alertMessage)
        }
        .onChange(of: editorViewModel.currentTemplateName) { _, newValue in
            workspace.updateActiveTemplateMetadata(name: newValue)
        }
        .onChange(of: editorViewModel.templateDescription) { _, newValue in
            workspace.updateActiveTemplateMetadata(description: newValue)
        }
        .onChange(of: editorViewModel.templateTags) { _, newValue in
            workspace.updateActiveTemplateMetadata(tags: newValue)
        }
        .onDisappear {
            statusWorkItem?.cancel()
            statusWorkItem = nil
        }
    }

    private var editorLayout: some View {
        HSplitView {
            palettePanel
            canvasPanel
            inspectorPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbarBackgroundVisibility(.hidden)
        .background { 
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
            AppMeshBackdrop() 
                .ignoresSafeArea()
        }
    }

    private func saveTemplate() {
        Task { @MainActor in
            if let metadata = await editorViewModel.saveTemplate() {
                workspace.applySavedTemplateMetadata(metadata)
                workspace.refreshTemplates()
                showStatus("Saved \"\(metadata.name.isEmpty ? "Untitled Template" : metadata.name)\"")
            } else {
                presentError(title: "Save Failed", message: editorViewModel.lastError ?? "An unknown error occurred while saving the template.")
            }
        }
    }

    private func export(_ action: TemplateExportAction) {
        Task { @MainActor in
            let success: Bool
            switch action {
            case .pdf:
                success = await editorViewModel.exportToPDF(fileName: sanitizedFileName())
            case .image(let format):
                success = await editorViewModel.exportToImage(format: format, fileName: sanitizedFileName())
            }

            if success {
                showStatus("\(action.displayName) exported")
            } else {
                let fallback = "Unable to export the template as \(action.displayName)."
                presentError(title: "Export Failed", message: editorViewModel.lastError ?? fallback)
            }
        }
    }

    private func runValidation() {
        editorViewModel.validateDocument()
        let errorCount = editorViewModel.validationErrors.count
        if errorCount == 0 {
            showStatus("No validation issues found")
        } else {
            showStatus("\(errorCount) validation issue\(errorCount == 1 ? "" : "s") detected")
        }
    }

    private func undo() {
        guard canUndo else { return }
        editorViewModel.document.undo()
        showStatus("Undo")
    }

    private func redo() {
        guard canRedo else { return }
        editorViewModel.document.redo()
        showStatus("Redo")
    }

    private func duplicateSelectedComponent() {
        guard let component = selectedComponent else { return }
        editorViewModel.duplicateComponent(component)
        showStatus("Component duplicated")
    }

    private func copySelectedComponent() {
        guard let component = selectedComponent else { return }
        editorViewModel.copyComponent(component)
        showStatus("Component copied")
    }

    private func pasteComponent() {
        guard editorViewModel.clipboardComponent != nil else { return }
        editorViewModel.pasteComponent()
        showStatus("Component pasted")
    }

    private func bringToFront() {
        guard let component = selectedComponent else { return }
        editorViewModel.bringToFront(component)
        showStatus("Brought to front")
    }

    private func sendToBack() {
        guard let component = selectedComponent else { return }
        editorViewModel.sendToBack(component)
        showStatus("Sent to back")
    }

    private func showStatus(_ message: String) {
        statusWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.15)) {
            statusMessage = message
        }

        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.15)) {
                statusMessage = nil
            }
        }
        statusWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
    }

    private func presentError(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }

    private func sanitizedFileName() -> String {
        let rawName = editorViewModel.currentTemplateName.isEmpty ? "Template" : editorViewModel.currentTemplateName
        return rawName
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
    }

    private enum TemplateExportAction {
        case pdf
        case image(ExportService.ImageFormat)

        var displayName: String {
            switch self {
            case .pdf:
                return "PDF"
            case .image(let format):
                return format.displayName
            }
        }
    }

}


private extension ExportService.ImageFormat {
    var displayName: String {
        switch self {
        case .png:
            return "PNG"
        case .jpeg:
            return "JPEG"
        }
    }
}


private extension ModernTemplateEditor {
    private var undoRedoControls: some View {
        HStack(spacing: 10) {
            toolbarIconButton("arrow.uturn.backward", help: "Undo", isDisabled: !canUndo, action: undo)
            toolbarIconButton("arrow.uturn.forward", help: "Redo", isDisabled: !canRedo, action: redo)
        }
    }

    private var saveControl: some View {
        toolbarIconButton("square.and.arrow.down", help: "Save Template", action: saveTemplate)
    }

    private var viewControls: some View {
        HStack(spacing: 10) {
            toolbarToggleButton(systemName: "square.grid.2x2", isOn: workspace.isPaletteVisible, help: "Toggle Component Palette") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    workspace.isPaletteVisible.toggle()
                }
            }
            toolbarToggleButton(systemName: "sidebar.right", isOn: isInspectorVisible, help: "Toggle Inspector") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isInspectorVisible.toggle()
                }
            }
            toolbarToggleButton(systemName: "rectangle.dashed", isOn: workspace.showMargins, help: "Toggle Margins Overlay") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    workspace.showMargins.toggle()
                }
            }
            toolbarToggleButton(systemName: "ruler", isOn: editorViewModel.showRulers, help: "Toggle Rulers") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    editorViewModel.showRulers.toggle()
                }
            }
        }
    }

    @ViewBuilder
    var palettePanel: some View {
        if workspace.isPaletteVisible {
            sidePanel(defaultWidth: 340, minWidth: 300, maxWidth: 480) {
                ModernComponentPalette()
            }
            .toolbarBackgroundVisibility(.hidden)
        }
    }

    private var canvasPanel: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: TemplateEditorPanelStyle.cornerRadius,
                style: .continuous
            )
                .fill(Color.clear)
                .glassEffect(
                    .regular,
                    in: .rect(cornerRadius: TemplateEditorPanelStyle.cornerRadius)
                )

            ModernCanvasView()
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: TemplateEditorPanelStyle.cornerRadius,
                        style: .continuous
                    )
                )
                .toolbar {
                    ToolbarSpacer(.flexible)
                    ToolbarItemGroup {
                        saveControl
                        undoRedoControls
                        viewControls
                    }
                    ToolbarSpacer(.flexible)
                }
                .toolbarBackgroundVisibility(.hidden)
        }
        .padding(TemplateEditorPanelStyle.outerPadding)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .layoutPriority(1)
    }

    @ViewBuilder
    var inspectorPanel: some View {
        if isInspectorVisible {
            sidePanel(defaultWidth: 340, minWidth: 300, maxWidth: 480) {
                ModernInspectorView()
            }
            .toolbarBackgroundVisibility(.hidden)
        }
    }

    private func sidePanel<Content: View>(defaultWidth: CGFloat, minWidth: CGFloat, maxWidth: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(minWidth: minWidth, idealWidth: defaultWidth, maxWidth: maxWidth, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .clipped()
    }

}

@ViewBuilder
private func toolbarIconButton(_ systemName: String, help: String? = nil, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
    let button = Button(action: action) {
        Image(systemName: systemName)
            .foregroundColor(isDisabled ? Color.secondaryText.opacity(0.5) : Color.primaryText)
    }
    .disabled(isDisabled)
    .pointerStyle(.link)

    if let help {
        button.help(help)
    } else {
        button
    }
}

@ViewBuilder
private func toolbarToggleButton(systemName: String, isOn: Bool, help: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: systemName)
            .symbolVariant(isOn ? .fill : .none)
            .foregroundStyle(isOn ? Color.accentColor : Color.secondaryText)
    }
    .pointerStyle(.link)
    .help(help)
}
