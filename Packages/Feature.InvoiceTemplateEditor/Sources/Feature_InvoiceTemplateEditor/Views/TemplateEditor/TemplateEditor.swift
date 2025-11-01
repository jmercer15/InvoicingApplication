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
        let paletteTransition = AnyTransition.move(edge: .leading).combined(with: .opacity)
        let inspectorTransition = AnyTransition.move(edge: .trailing).combined(with: .opacity)
        let panelAnimation = Animation.easeInOut(duration: 0.25)

                HStack(alignment: .top, spacing: 0) {
            if workspace.isPaletteVisible {
                ModernComponentPalette()
                    .frame(width: 260)
                    .frame(maxHeight: .infinity)
                    .background(Color("Background", bundle: .sharedUI))
                    .contentShape(Rectangle())
                    .clipped()
                    .transition(paletteTransition)

                Divider()
                    .transition(.opacity)
            }

            ModernCanvasView()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)

            if isInspectorVisible {
                Divider()
                    .transition(.opacity)

                ModernInspectorView()
                    .frame(width: 320)
                    .frame(maxHeight: .infinity)
                    .background(Color("Background", bundle: .sharedUI))
                    .contentShape(Rectangle())
                    .clipped()
                    .transition(inspectorTransition)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .animation(panelAnimation, value: workspace.isPaletteVisible)
        .animation(panelAnimation, value: isInspectorVisible)
        .toolbar {

            ToolbarItemGroup(placement: .status) {
                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 11, weight: .medium, design: .default))
                .fontWeight(.semibold)
                .foregroundColor(Color.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.secondaryText.opacity(0.08))
                        )
                }
            }

            ToolbarItemGroup(placement: .automatic) {
                ToolbarButton(image: "arrow.uturn.backward", action: undo, isDisabled: !canUndo, help: "Undo")
                ToolbarButton(image: "arrow.uturn.forward", action: redo, isDisabled: !canRedo, help: "Redo")
            }

            ToolbarItemGroup(placement: .automatic) {
                ToolbarButton(image: "square.and.arrow.down", action: saveTemplate, isDisabled: isBusy, help: "Save Template")
                    .keyboardShortcut("s", modifiers: [.command])

                ToolbarButton(image: "doc.richtext", action: exportAsPDF, isDisabled: isBusy, help: "Export as PDF…")
                ToolbarButton(image: "photo", action: exportAsPNG, isDisabled: isBusy, help: "Export as PNG…")
                ToolbarButton(image: "photo.on.rectangle", action: exportAsJPEG, isDisabled: isBusy, help: "Export as JPEG…")
                ToolbarButton(image: "checkmark.seal", action: runValidation, help: "Validate Template")
            }

            ToolbarItemGroup(placement: .automatic) {
                ToolbarButton(image: "square.on.square", action: duplicateSelectedComponent, isDisabled: selectedComponent == nil, help: "Duplicate Component")
                ToolbarButton(image: "doc.on.doc", action: copySelectedComponent, isDisabled: selectedComponent == nil, help: "Copy Component")
                ToolbarButton(image: "arrow.down.doc.fill", action: pasteComponent, isDisabled: editorViewModel.clipboardComponent == nil, help: "Paste Component")
                ToolbarButton(image: "arrow.up.to.line", action: bringToFront, isDisabled: selectedComponent == nil, help: "Bring to Front")
                ToolbarButton(image: "arrow.down.to.line", action: sendToBack, isDisabled: selectedComponent == nil, help: "Send to Back")
            }

            ToolbarItemGroup(placement: .automatic) {
                ToggleToolbarButton(isOn: workspace.isPaletteVisible, systemImage: "square.grid.2x2", help: "Toggle Component Palette") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        workspace.isPaletteVisible.toggle()
                    }
                }
                ToggleToolbarButton(isOn: isInspectorVisible, systemImage: "sidebar.right", help: "Toggle Inspector") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isInspectorVisible.toggle()
                    }
                }
                ToggleToolbarButton(isOn: workspace.showMargins, systemImage: "rectangle.dashed", help: "Toggle Margins Overlay") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        workspace.showMargins.toggle()
                    }
                }
                ToggleToolbarButton(isOn: editorViewModel.showRulers, systemImage: "ruler", help: "Toggle Rulers") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        editorViewModel.showRulers.toggle()
                    }
                }
            }
        }
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

    private func exportAsPDF() {
        Task { @MainActor in
            let success = await editorViewModel.exportToPDF(fileName: sanitizedFileName())
            if success {
                showStatus("PDF exported")
            } else {
                presentError(title: "Export Failed", message: editorViewModel.lastError ?? "Unable to export the template as PDF.")
            }
        }
    }

    private func exportAsPNG() {
        Task { @MainActor in
            let success = await editorViewModel.exportToImage(format: .png, fileName: sanitizedFileName())
            if success {
                showStatus("PNG exported")
            } else {
                presentError(title: "Export Failed", message: editorViewModel.lastError ?? "Unable to export the template as PNG.")
            }
        }
    }

    private func exportAsJPEG() {
        Task { @MainActor in
            let success = await editorViewModel.exportToImage(format: .jpeg, fileName: sanitizedFileName())
            if success {
                showStatus("JPEG exported")
            } else {
                presentError(title: "Export Failed", message: editorViewModel.lastError ?? "Unable to export the template as JPEG.")
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

}




// MARK: - Toolbar Button Components
private struct ToolbarButton: View {
    let image: String
    let action: () -> Void
    var isDisabled: Bool = false
    var help: String? = nil
    
    @ViewBuilder
    var body: some View {
        let button = Button(action: action) {
            Image(systemName: image)
                .foregroundColor(isDisabled ? Color.secondaryText.opacity(0.5) : Color.primaryText)
        }
        .pointerStyle(.link)
        //.buttonStyle(.plain)
        .disabled(isDisabled)

        if let help {
            button.help(help)
        } else {
            button
        }
    }
}

private struct ToggleToolbarButton: View {
    var isOn: Bool
    var systemImage: String
    var help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .symbolVariant(isOn ? .fill : .none)
                .foregroundStyle(isOn ? Color.accentColor : Color.secondaryText)
        }
        .pointerStyle(.link)
        //.buttonStyle(.plain)
        .help(help)
    }
}
