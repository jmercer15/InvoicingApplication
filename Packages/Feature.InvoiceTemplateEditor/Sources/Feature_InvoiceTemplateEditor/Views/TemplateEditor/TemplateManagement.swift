//
//  TemplateManagement.swift
//  Feature.InvoiceTemplateEditor
//
//  Template library management with search, categories, and actions
//

import SwiftUI
import Core


struct ModernTemplateManagementView: View {
    @ObservedObject var workspace: TemplateEditorWorkspaceViewModel
    @Binding var highlightedTemplateID: UUID?
    @Binding var isInspectorVisible: Bool
    @Binding var showingNewTemplateSheet: Bool
    @EnvironmentObject private var templateDataService: TemplateDataService
    @State private var navigationPath = NavigationPath()
    @State private var searchText = ""
    @State private var selectedCategory: TemplateCategory = .all
    @State private var templatePendingDelete: TemplateItem?
    @State private var editingTemplate: TemplateItem?
    @State private var isProcessingAction = false
    @State private var actionErrorMessage: String?

    private var selectedTemplate: TemplateItem? {
        guard let highlightedTemplateID else { return nil }
        return workspace.templates.first(where: { $0.id == highlightedTemplateID })
    }

    private var isEditorActive: Bool {
        workspace.activeTemplate != nil || !navigationPath.isEmpty
    }
    
    var body: some View {
        ZStack {
            AppMeshBackdrop()
            NavigationStack(path: $navigationPath) {
                VStack(alignment: .leading, spacing: 18) {
                    headerView
                    TemplateLibraryGrid(
                        templates: filteredTemplates,
                        selectedID: $highlightedTemplateID,
                        isProcessingAction: isProcessingAction,
                        isLoadingTemplates: workspace.isLoadingTemplates,
                        isOpeningTemplate: workspace.isOpeningTemplate,
                        loadError: workspace.templateLoadError,
                        onOpen: handleTemplateSelection,
                        onDuplicate: duplicateTemplate,
                        onEdit: beginEditingTemplate,
                        onDelete: promptDeleteTemplate
                    )
                }
                .foregroundColor(Color.primaryText)
                .padding(.horizontal, 24)
                .padding(.top, 18)
            }
            .navigationDestination(for: TemplateItem.self) { template in
                ZStack {
                    AppMeshBackdrop()
                    ModernTemplateEditor(
                        template: template,
                        workspace: workspace,
                        onBackToTemplates: handleBackToTemplates,
                        isInspectorVisible: $isInspectorVisible
                    )
                    .environmentObject(workspace)
                    .environmentObject(workspace.editorViewModel)
                    .environmentObject(workspace.editorViewModel.document)
                    .environmentObject(templateDataService)
                }
                .onAppear { highlightedTemplateID = workspace.activeTemplate?.id ?? template.id }
                .onDisappear { highlightedTemplateID = nil }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: navigationPath)
        .task {
            workspace.loadTemplates()
        }
        .onChange(of: workspace.activeTemplate?.id) { _, newValue in
            highlightedTemplateID = newValue
        }
        .alert(item: $templatePendingDelete) { template in
            Alert(
                title: Text("Delete \(template.name)?"),
                message: Text("This will remove the template from your library."),
                primaryButton: .destructive(Text("Delete")) {
                    performDelete(template)
                },
                secondaryButton: .cancel {
                    templatePendingDelete = nil
                }
            )
        }
        .alert("Template Action Failed", isPresented: Binding(
            get: { actionErrorMessage != nil },
            set: { if !$0 { actionErrorMessage = nil } }
        ), actions: {
            Button("OK", role: .cancel) {}
                .pointerStyle(.link)
        }, message: {
            Text(actionErrorMessage ?? "")
        })
        .sheet(item: $editingTemplate) { template in
            TemplateMetadataEditorSheet(
                template: template,
                isProcessing: $isProcessingAction,
                onCancel: { editingTemplate = nil },
                onSave: { draft in
                    saveEditedMetadata(draft, for: template)
                }
            )
        }
    }

    // MARK: - Navigation Helpers

    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerTopBar

            VStack(alignment: .leading, spacing: 14) {
                searchField
                categoryPicker
            }

            if let currentSelection = selectedTemplate {
                TemplateSelectionToolbar(
                    template: currentSelection,
                    isPersisted: currentSelection.isPersisted,
                    isProcessing: isProcessingAction,
                    onOpen: { handleTemplateSelection(currentSelection) },
                    onEdit: currentSelection.isPersisted ? { beginEditingTemplate(currentSelection) } : nil,
                    onDuplicate: currentSelection.isPersisted ? { duplicateTemplate(currentSelection) } : nil,
                    onDelete: currentSelection.isPersisted ? { promptDeleteTemplate(currentSelection) } : nil
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .contentShape(Rectangle())
                .clipped()
            }
        }
        .padding(.vertical, 16)
        .animation(.easeInOut(duration: 0.25), value: highlightedTemplateID)
        .animation(.easeInOut(duration: 0.25), value: workspace.isLoadingTemplates)
        .animation(.easeInOut(duration: 0.25), value: workspace.isOpeningTemplate)
        .animation(.easeInOut(duration: 0.2), value: workspace.templateLoadError)
        .animation(.easeInOut(duration: 0.2), value: isProcessingAction)
    }

    private func handleTemplateSelection(_ template: TemplateItem) {
        Task {
            let didOpen = await workspace.openTemplate(template)
            if didOpen {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        highlightedTemplateID = template.id
                        isInspectorVisible = true
                        navigationPath = NavigationPath()
                        navigationPath.append(template)
                    }
                }
            }
        }
    }
    
    private func handleCreateNewSelection() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showingNewTemplateSheet = true
        }
    }

    private func handleBackToTemplates() {
        withAnimation(.easeInOut(duration: 0.3)) {
            navigationPath = NavigationPath()
            highlightedTemplateID = nil
            isInspectorVisible = false
        }
        workspace.closeTemplate()
        workspace.refreshTemplates()
    }

    private func promptDeleteTemplate(_ template: TemplateItem) {
        templatePendingDelete = template
    }

    private func performDelete(_ template: TemplateItem) {
        guard !isProcessingAction else { return }
        isProcessingAction = true
        Task {
            let success = await workspace.deleteTemplate(template)
            await MainActor.run {
                if !success {
                    actionErrorMessage = "Failed to delete template."
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if highlightedTemplateID == template.id {
                            highlightedTemplateID = nil
                        }
                        navigationPath = NavigationPath()
                        isInspectorVisible = false
                    }
                    workspace.refreshTemplates()
                }
                templatePendingDelete = nil
                isProcessingAction = false
            }
        }
    }

    private func duplicateTemplate(_ template: TemplateItem) {
        guard !isProcessingAction else { return }
        isProcessingAction = true
        Task {
            let result = await workspace.duplicateTemplate(template)
            await MainActor.run {
                if let result {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        highlightedTemplateID = result.id
                    }
                    workspace.refreshTemplates()
                    handleTemplateSelection(result)
                } else {
                    actionErrorMessage = "Failed to duplicate template."
                }
                isProcessingAction = false
            }
        }
    }

    private func beginEditingTemplate(_ template: TemplateItem) {
        guard template.isPersisted else {
            actionErrorMessage = "Save this template before editing its details."
            return
        }
        editingTemplate = template
    }

    private func saveEditedMetadata(_ draft: TemplateMetadataDraft, for template: TemplateItem) {
        guard !isProcessingAction else { return }
        isProcessingAction = true
        Task {
            let result = await workspace.updateTemplateMetadata(
                for: template,
                name: draft.name,
                description: draft.description,
                tags: draft.tags
            )
            await MainActor.run {
                if let result {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        highlightedTemplateID = result.id
                        editingTemplate = nil
                    }
                    workspace.refreshTemplates()
                } else {
                    actionErrorMessage = "Failed to update template details."
                }
                isProcessingAction = false
            }
        }
    }


    private var headerTopBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Template Library")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.primaryText)
                    Text("Manage, create, and organise your templates")
                        .font(.footnote)
                        .foregroundColor(Color.secondary)
                }
            } icon: {
                Image(systemName: "square.grid.2x2")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .labelStyle(.titleAndIcon)

            Spacer()

            Button(action: handleCreateNewSelection) {
                Label("New Template", systemImage: "plus")
                    .foregroundColor(Color.accentText)
            }
            .pointerStyle(.link)
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .controlSize(.large)
            .disabled(isProcessingAction)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .fontWeight(.semibold)
                .foregroundColor(Color.secondary)
            TextField("Search templates", text: $searchText)
                .pointerStyle(.horizontalText)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundColor(Color.primaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.primarySurface.opacity(0.95),
                            Color.secondarySurface.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.primaryOutline.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
        )
        .shadow(color: Color.primaryShadow.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TemplateCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var filteredTemplates: [TemplateItem] {
        let templates = workspace.templates
        
        let categoryFiltered = selectedCategory == .all ?
            templates :
            templates.filter { $0.category == selectedCategory }
        
        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }

}

private struct TemplateLibraryGrid: View {
    let templates: [TemplateItem]
    @Binding var selectedID: UUID?
    let isProcessingAction: Bool
    let isLoadingTemplates: Bool
    let isOpeningTemplate: Bool
    let loadError: String?
    let onOpen: (TemplateItem) -> Void
    let onDuplicate: (TemplateItem) -> Void
    let onEdit: (TemplateItem) -> Void
    let onDelete: (TemplateItem) -> Void

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 260, maximum: 380), spacing: 18, alignment: .top)]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(templates, id: \.id) { template in
                    ModernTemplateCard(
                        template: template,
                        isSelected: selectedID == template.id,
                        onSelect: { selectedID = template.id },
                        onOpen: { onOpen(template) },
                        onDuplicate: template.isPersisted ? { onDuplicate(template) } : nil,
                        onEdit: template.isPersisted ? { onEdit(template) } : nil,
                        onDelete: template.isPersisted ? { onDelete(template) } : nil,
                        isDisabled: isProcessingAction
                    )
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)

            VStack(spacing: 10) {
                if isLoadingTemplates {
                    statusProgress("Loading templates…")
                }
                if isOpeningTemplate {
                    statusProgress("Opening template…")
                }
                if let error = loadError {
                    statusMessage(error)
                }
                if isProcessingAction {
                    statusProgress("Working…")
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func statusProgress(_ text: String) -> some View {
        ProgressView(text)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
            .tint(Color.accentColor)
    }

    private func statusMessage(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(Color.warningColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

}


// MARK: - Template Selection Toolbar
private struct TemplateSelectionToolbar: View {
    let template: TemplateItem
    let isPersisted: Bool
    let isProcessing: Bool
    let onOpen: () -> Void
    let onEdit: (() -> Void)?
    let onDuplicate: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name)
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(Color.primaryText)
                        .lineLimit(1)

                    if !template.description.isEmpty {
                        Text(template.description)
                            .font(.system(size: 13, weight: .regular, design: .default))
                    .fontWeight(.semibold)
                .foregroundColor(Color.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Button(action: onOpen) {
                    Label("Open", systemImage: "arrow.forward.square")
                        .font(.system(size: 13, weight: .medium))
                }
                .pointerStyle(.link)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isProcessing)
            }

            if isPersisted {
                HStack(spacing: 10) {
                    if let onEdit {
                        Button(action: onEdit) {
                            Label("Edit Details", systemImage: "pencil")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .pointerStyle(.link)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isProcessing)
                    }

                    if let onDuplicate {
                        Button(action: onDuplicate) {
                            Label("Duplicate", systemImage: "square.on.square")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .pointerStyle(.link)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isProcessing)
                    }

                    if let onDelete {
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .pointerStyle(.link)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isProcessing)
                    }
                }
            } else {
                Text("Save the template from the editor to manage its details.")
                    .font(.caption)
                    .foregroundColor(Color.secondaryText)
            }
        }
        .padding(14)
        .background(Color.clear)
    }
}

// MARK: - Template Metadata Editor Sheet
private struct TemplateMetadataEditorSheet: View {
    let template: TemplateItem
    @Binding var isProcessing: Bool
    let onCancel: () -> Void
    let onSave: (TemplateMetadataDraft) -> Void

    @State private var form: TemplateMetadataDraft

    init(template: TemplateItem, isProcessing: Binding<Bool>, onCancel: @escaping () -> Void, onSave: @escaping (TemplateMetadataDraft) -> Void) {
        self.template = template
        self._isProcessing = isProcessing
        self.onCancel = onCancel
        self.onSave = onSave
        _form = State(initialValue: TemplateMetadataDraft(template: template))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Name")) {
                    TextField("Template Name", text: $form.name)
                        .pointerStyle(.horizontalText)
                }

                Section(header: Text("Description")) {
                    TextEditor(text: $form.description)
                        .pointerStyle(.horizontalText)
                        .frame(minHeight: 120)
                }

                Section(header: Text("Tags"), footer: Text("Enter comma-separated tags.")) {
                    TextField("Comma separated tags", text: $form.tagsText)
                        .pointerStyle(.horizontalText)
                        .disableAutocorrection(true)
                }
            }
            .disabled(isProcessing)
            .scrollContentBackground(.hidden)
            .background(Color.primarySurface)
            .navigationTitle("Edit Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: onCancel)
                        .pointerStyle(.link)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(form)
                    }
                    .pointerStyle(.link)
                    .disabled(isProcessing || form.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .overlay {
                if isProcessing {
                    ProgressView()
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .frame(minWidth: 420, minHeight: 360)
        .background(Color.primaryBackground.ignoresSafeArea())
    }
}

// MARK: - Template Metadata Draft
struct TemplateMetadataDraft {
    var name: String = ""
    var description: String = ""
    var tagsText: String = ""

    init() {}

    init(template: TemplateItem) {
        self.name = template.name
        self.description = template.description
        self.tagsText = template.tags.joined(separator: ", ")
    }

    var tags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
