//
//  TemplateEditor.swift
//  Feature.InvoiceTemplateEditor
//
//  Template editor with toolbar, palette, and inspector
//

import SwiftUI
import Core
import SharedUI

/// Tab selection for the left side panel
private enum LeftPanelTab: String, CaseIterable {
    case sections = "Sections"
    case components = "Components"
    
    var icon: String {
        switch self {
        case .sections: return "list.bullet.indent"
        case .components: return "square.grid.2x2"
        }
    }
}

// MARK: - Glass Tab Bar Components

private struct GlassTabBar: View {
    @Binding var selection: LeftPanelTab
    let namespace: Namespace.ID
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(LeftPanelTab.allCases, id: \.self) { tab in
                HStack(spacing: 6) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 14, weight: .medium))
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(selection == tab ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(selection == tab ? Color.accentColor : Color.clear)
                .contentShape(.rect(cornerRadius: 10))
                .clipShape(.rect(cornerRadius: 10))
                .glassEffect(
                    .regular.interactive(),
                    in: .rect(cornerRadius: 10)
                )
                .glassEffectUnion(id: "tabBar", namespace: namespace)
                .onTapGesture {
                    withAnimation(.smooth) {
                        selection = tab
                    }
                }
            }
        }
    }
}

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
    @State private var zoomScale: CGFloat = 1.0
    @State private var viewportOffset: CGSize = .zero
    @State private var leftPanelTab: LeftPanelTab = .sections
    @Namespace private var leftPanelNamespace

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
        ModernCanvasView(
            zoomScale: $zoomScale,
            viewportOffset: $viewportOffset,
            showPalette: workspace.isPaletteVisible,
            showInspector: isInspectorVisible,
            paletteContent: { leftPanelContent },
            inspectorContent: { inspectorContent }
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
        .background(PanelShellTokens.panelBackground.ignoresSafeArea())
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
        editorViewModel.validateDocument(force: true)
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

    private var leftPanelContent: some View {
        SidePanel(configuration: .palette, useGlassEffect: false, fixedVerticalSize: false) {
            // GlassEffectContainer enables morphing between tab bar and panel
            GlassEffectContainer(spacing: 20) {
                VStack(alignment: .center, spacing: 0) {
                    // Tab bar - buttons use glassEffectUnion with "tabBar" ID
                    GlassTabBar(selection: $leftPanelTab, namespace: leftPanelNamespace)
                        .padding(.top, 8)
                    
                    // Panel content with glass effect
                    Group {
                        switch leftPanelTab {
                        case .sections:
                            ScrollView {
                                DocumentOutlinePanel()
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        case .components:
                            ModernComponentPalette()
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .glassEffect(.regular, in: .rect(cornerRadius: TemplateEditorPanelStyle.cornerRadius))
                    .glassEffectUnion(id: "tabBar", namespace: leftPanelNamespace)
                }
            }
            .padding(TemplateEditorPanelStyle.outerPadding)
        }
        .contentShape(Rectangle())
        .clipped()
        .toolbarBackgroundVisibility(.hidden)
    }

    private var hasSelection: Bool {
        editorViewModel.document.selectedComponentID != nil || editorViewModel.document.selectedSplitSelection != nil
    }
    
    private var inspectorContent: some View {
        SidePanel(configuration: .inspector, useGlassEffect: false, fixedVerticalSize: false) {
            // GlassEffectContainer enables morphing between header and panel
            GlassEffectContainer(spacing: 20) {
                VStack(alignment: .center, spacing: 0) {
                    // Header bar - only shown when something is selected
                    if hasSelection {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 14, weight: .medium))
                            Text("Inspector")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .glassEffect(
                            .regular.interactive(),
                            in: .rect(cornerRadius: 10)
                        )
                        .glassEffectUnion(id: "inspectorBar", namespace: leftPanelNamespace)
                        .padding(.top, 8)
                    }
                    
                    // Panel content with glass effect
                    ScrollView {
                        ModernInspectorView()
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .glassEffect(.regular, in: .rect(cornerRadius: TemplateEditorPanelStyle.cornerRadius))
                    .glassEffectUnion(id: hasSelection ? "inspectorBar" : nil, namespace: leftPanelNamespace)
                }
            }
            .padding(TemplateEditorPanelStyle.outerPadding)
        }
        .contentShape(Rectangle())
        .clipped()
        .toolbarBackgroundVisibility(.hidden)
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
