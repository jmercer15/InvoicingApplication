import SwiftUI
import AppKit
import SharedUI
import UniformTypeIdentifiers
import Foundation

private enum ModernTheme {
    static let background = LinearGradient(
        colors: [
            Color(red: 0.07, green: 0.08, blue: 0.12),
            Color(red: 0.03, green: 0.04, blue: 0.07)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let surface = Color(red: 0.13, green: 0.15, blue: 0.21)
    static let surfaceElevated = Color(red: 0.18, green: 0.2, blue: 0.27)
    static let surfaceActive = Color(red: 0.23, green: 0.26, blue: 0.33)
    static let outline = Color.white.opacity(0.08)
    static let outlineStrong = Color.white.opacity(0.16)
    static let textPrimary = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.72)
    static let chipSelectedBackground = Color.accentColor
    static let chipUnselectedBackground = Color.white.opacity(0.08)
    static let chipText = Color.white.opacity(0.9)
    static let hoverHighlight = Color.accentColor.opacity(0.18)
    static let warning = Color(red: 0.96, green: 0.45, blue: 0.32)
}



// MARK: - Template Categories

enum TemplateCategory: String, CaseIterable {
    case all = "All"
    case business = "Business"
    case creative = "Creative"
    case minimal = "Minimal"
    case professional = "Professional"
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .business: return "building.2"
        case .creative: return "paintbrush"
        case .minimal: return "circle.grid.2x2"
        case .professional: return "briefcase"
        }
    }
}

extension TemplateCategory {
    init(metadataTags tags: [String]) {
        let normalized = Set(tags.map { $0.lowercased() })
        if normalized.contains("business") {
            self = .business
        } else if normalized.contains("creative") {
            self = .creative
        } else if normalized.contains("minimal") {
            self = .minimal
        } else if normalized.contains("professional") {
            self = .professional
        } else {
            self = .all
        }
    }
}

private extension InvoiceComponentType {
    var supportsTypography: Bool {
        switch self {
        case .rectangleShape, .ellipseShape, .lineShape, .triangleShape, .starShape, .imagePlaceholder, .companyLogo:
            return false
        default:
            return true
        }
    }
    
    var supportsPlaceholderText: Bool {
        switch self {
        case .textBox, .notes, .invoiceTitle, .companyName, .companyABN, .companyEmail, .paymentTerms:
            return true
        default:
            return false
        }
    }
    
    var supportsBackgroundFill: Bool {
        switch self {
        case .lineShape:
            return false
        default:
            return true
        }
    }
    
    var supportsBorderControls: Bool {
        switch self {
        case .lineShape:
            return false
        default:
            return true
        }
    }
    
    var supportsCornerRadius: Bool {
        switch self {
        case .lineShape, .triangleShape, .starShape:
            return false
        default:
            return true
        }
    }
    
    var supportsFillOrBorder: Bool {
        supportsBackgroundFill || supportsBorderControls
    }
    
    var supportsShadow: Bool {
        switch self {
        case .lineShape:
            return false
        default:
            return true
        }
    }
    
    var supportsLayoutControls: Bool {
        switch self {
        case .rectangleShape, .ellipseShape, .lineShape, .triangleShape, .starShape:
            return false
        default:
            return true
        }
    }
    
    var isImageComponent: Bool {
        self == .imagePlaceholder || self == .companyLogo
    }
}

// MARK: - Template Item Model

struct TemplateItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let category: TemplateCategory
    let previewImage: String
    let isPremium: Bool
    let lastModified: Date
    let tags: [String]
    let thumbnailData: Data?
    let metadata: TemplateMetadata?

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        category: TemplateCategory,
        previewImage: String,
        isPremium: Bool,
        lastModified: Date,
        tags: [String] = [],
        thumbnailData: Data? = nil,
        metadata: TemplateMetadata? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.previewImage = previewImage
        self.isPremium = isPremium
        self.lastModified = lastModified
        self.tags = tags
        self.thumbnailData = thumbnailData
        self.metadata = metadata
    }

    init(metadata: TemplateMetadata) {
        self.id = metadata.id
        self.name = metadata.name
        self.description = metadata.description
        self.category = TemplateCategory(metadataTags: metadata.tags)
        self.previewImage = "doc.richtext"
        self.isPremium = metadata.tags.contains { $0.lowercased() == "premium" }
        self.lastModified = metadata.modifiedAt
        self.tags = metadata.tags
        self.thumbnailData = metadata.thumbnailData
        self.metadata = metadata
    }
    
    static let sampleTemplates = [
        TemplateItem(
            id: UUID(),
            name: "Modern Invoice",
            description: "Clean, professional invoice template",
            category: .professional,
            previewImage: "doc.richtext",
            isPremium: false,
            lastModified: Date(),
            tags: ["professional"]
        ),
        TemplateItem(
            id: UUID(),
            name: "Creative Portfolio",
            description: "Eye-catching design for creative professionals",
            category: .creative,
            previewImage: "paintbrush.pointed",
            isPremium: true,
            lastModified: Date().addingTimeInterval(-86400),
            tags: ["creative", "premium"]
        ),
        TemplateItem(
            id: UUID(),
            name: "Business Report",
            description: "Corporate-style business document",
            category: .business,
            previewImage: "chart.bar.doc.horizontal",
            isPremium: false,
            lastModified: Date().addingTimeInterval(-172800),
            tags: ["business"]
        ),
        TemplateItem(
            id: UUID(),
            name: "Minimal Quote",
            description: "Simple, elegant quote template",
            category: .minimal,
            previewImage: "quote.bubble",
            isPremium: false,
            lastModified: Date().addingTimeInterval(-259200),
            tags: ["minimal"]
        )
    ]

    static func == (lhs: TemplateItem, rhs: TemplateItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var isPersisted: Bool {
        metadata != nil
    }
}

/// Modern template editor with a fresh, intuitive design
public struct ModernTemplateEditorView: View {
    @StateObject private var workspace = TemplateEditorWorkspaceViewModel()
    @State private var highlightedTemplateID: UUID? = nil
    @State private var isInspectorVisible = true
    @State private var showingNewTemplateSheet = false
    
    public init() {}
    
    public var body: some View {
        ModernTemplateManagementView(
            workspace: workspace,
            highlightedTemplateID: $highlightedTemplateID,
            isInspectorVisible: $isInspectorVisible,
            showingNewTemplateSheet: $showingNewTemplateSheet
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ModernTheme.background.ignoresSafeArea())
        .environmentObject(workspace)
        .environmentObject(workspace.editorViewModel)
        .environmentObject(workspace.editorViewModel.document)
        .sheet(isPresented: $showingNewTemplateSheet) {
            ModernTemplateCreatorSheet(onCreateTemplate: handleCreateTemplate)
                .environmentObject(workspace)
                .environmentObject(workspace.editorViewModel)
                .environmentObject(workspace.editorViewModel.document)
        }
    }

    private func handleCreateTemplate(from draft: TemplateMetadataDraft) {
        let newTemplate = workspace.beginNewTemplate(
            name: draft.name,
            description: draft.description,
            tags: draft.tags
        )
        highlightedTemplateID = newTemplate.id
        isInspectorVisible = true
        showingNewTemplateSheet = false
    }
     
    // MARK: - Adaptive Sizing Functions
    
}

// MARK: - Template Management


struct ModernTemplateManagementView: View {
    @ObservedObject var workspace: TemplateEditorWorkspaceViewModel
    @Binding var highlightedTemplateID: UUID?
    @Binding var isInspectorVisible: Bool
    @Binding var showingNewTemplateSheet: Bool
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
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    header(for: geometry.size)

                    ScrollView {
                        LazyVGrid(
                            columns: adaptiveGridColumns(for: geometry.size.width),
                            spacing: adaptiveGridSpacing(for: geometry.size.width)
                        ) {
                            ForEach(filteredTemplates, id: \.id) { template in
                                ModernTemplateCard(
                                    template: template,
                                    isSelected: highlightedTemplateID == template.id,
                                    onSelect: { highlightedTemplateID = template.id },
                                    onOpen: { handleTemplateSelection(template) },
                                    onDuplicate: template.isPersisted ? { duplicateTemplate(template) } : nil,
                                    onEdit: template.isPersisted ? { beginEditingTemplate(template) } : nil,
                                    onDelete: template.isPersisted ? { promptDeleteTemplate(template) } : nil,
                                    isDisabled: isProcessingAction
                                )
                            }
                        }
                        .padding(adaptivePadding(for: geometry.size.width))

                        VStack(spacing: 8) {
                            if workspace.isLoadingTemplates {
                                ProgressView("Loading templates...")
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 12)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                    .tint(Color.accentColor)
                            }

                            if workspace.isOpeningTemplate {
                                ProgressView("Opening template...")
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 12)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                    .tint(Color.accentColor)
                            }

                            if let error = workspace.templateLoadError {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundColor(ModernTheme.warning)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, adaptivePadding(for: geometry.size.width))
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            if isProcessingAction {
                                ProgressView("Working...")
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 12)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                    .tint(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .clipped()
                    }
                }
                .foregroundColor(ModernTheme.textPrimary)
            }
            .navigationDestination(for: TemplateItem.self) { template in
                ModernTemplateEditor(
                    template: template,
                    workspace: workspace,
                    onBackToTemplates: handleBackToTemplates,
                    isInspectorVisible: $isInspectorVisible
                )
                .onAppear { highlightedTemplateID = workspace.activeTemplate?.id ?? template.id }
                .onDisappear { highlightedTemplateID = nil }
                .environmentObject(workspace)
                .environmentObject(workspace.editorViewModel)
                .environmentObject(workspace.editorViewModel.document)
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
    private func header(for size: CGSize) -> some View {
        let horizontalPadding = adaptivePadding(for: size.width)

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Template Library")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernTheme.textPrimary)
                        Text("Manage, create, and organise your templates")
                            .font(.footnote)
                            .foregroundColor(ModernTheme.textSecondary)
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
                        .foregroundColor(Color.white)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
                .controlSize(.large)
                .disabled(isProcessingAction)
            }

            VStack(alignment: .leading, spacing: 14) {
                // Search field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ModernTheme.textSecondary)
                    TextField("Search templates", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .foregroundColor(ModernTheme.textPrimary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(ModernTheme.surfaceElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(ModernTheme.outline)
                        )
                )

                // Category chips
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
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(ModernTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(ModernTheme.outline)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 18, x: 0, y: 12)
        )
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 18)
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

    // MARK: - Adaptive Layout Functions
    
    private func adaptiveSpacing(for width: CGFloat) -> CGFloat {
        switch width {
        case 0..<300: return 8
        case 300..<400: return 12
        default: return 16
        }
    }
    
    private func adaptivePadding(for width: CGFloat) -> CGFloat {
        switch width {
        case 0..<300: return 8
        case 300..<400: return 12
        default: return 16
        }
    }
    
    private func adaptiveGridColumns(for width: CGFloat) -> [GridItem] {
        let columnCount: Int
        switch width {
        case 0..<300: columnCount = 1
        case 300..<500: columnCount = 2
        default: columnCount = 3
        }
        
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount)
    }
    
    private func adaptiveGridSpacing(for width: CGFloat) -> CGFloat {
        switch width {
        case 0..<300: return 6
        case 300..<400: return 8
        default: return 12
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

// MARK: - Modern Component Palette

struct ModernComponentPalette: View {
    @EnvironmentObject private var editorViewModel: InvoiceTemplateEditorViewModel
    @EnvironmentObject private var document: InvoiceDocument
    @State private var expandedSections: Set<String> = ["Basic Elements", "Invoice Sections", "Company Info", "Additional Elements"]
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 16) {
            paletteHeader

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(paletteSections) { section in
                        let items = filteredItems(for: section.items)
                        if !isFiltering || !items.isEmpty {
                            ModernPaletteSection(
                                title: section.title,
                                isExpanded: expandedSections.contains(section.title),
                                onToggle: { toggleSection(section.title) }
                            ) {
                                VStack(spacing: 8) {
                                    ForEach(items) { descriptor in
                                        ModernPaletteItem(
                                            name: descriptor.name,
                                            icon: descriptor.icon,
                                            description: descriptor.description,
                                            componentType: descriptor.type
                                        ) {
                                            createComponent(descriptor.type)
                                        }
                                    }
                                }
                                .padding(.top, 6)
                            }
                        }
                    }

                    if isFiltering && !hasSearchResults {
                        Text("No components match \"\(searchQuery)\".")
                            .font(.caption)
                            .foregroundColor(ModernTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            }
            .simultaneousGesture(
                DragGesture()
                    .onChanged { _ in }
                    .onEnded { _ in }
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(ModernTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(ModernTheme.outline)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 14, x: 0, y: 10)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .foregroundColor(ModernTheme.textPrimary)
    }

    private var paletteHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Component Library")
                    .font(.headline)
                    .fontWeight(.semibold)
            } icon: {
                Image(systemName: "square.grid.3x2")
                    .foregroundStyle(Color.accentColor)
            }
            .labelStyle(.titleAndIcon)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ModernTheme.textSecondary)

                TextField("Search components", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ModernTheme.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.05))
                    )
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func createComponent(_ type: InvoiceComponentType) {
        let defaultSize = type.defaultSize
        let centerPosition = CGPoint(
            x: document.pageSize.width / 2,
            y: document.pageSize.height / 2
        )
        
        var component = InvoiceComponent(
            type: type,
            position: centerPosition,
            size: defaultSize
        )
        
        if type.supportsPlaceholderText && component.style.placeholderText.isEmpty {
            component.style.placeholderText = type.rawValue
        }
        
        editorViewModel.addComponent(component)
    }
    
    private func toggleSection(_ name: String) {
        if expandedSections.contains(name) {
            expandedSections.remove(name)
        } else {
            expandedSections.insert(name)
        }
    }
    
    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isFiltering: Bool {
        !searchQuery.isEmpty
    }
    
    private var hasSearchResults: Bool {
        paletteSections.contains { !filteredItems(for: $0.items).isEmpty }
    }
    
    private func filteredItems(for items: [PaletteItemDescriptor]) -> [PaletteItemDescriptor] {
        guard isFiltering else { return items }
        let query = searchQuery.lowercased()
        return items.filter { descriptor in
            descriptor.name.lowercased().contains(query) ||
            descriptor.description.lowercased().contains(query) ||
            descriptor.type.rawValue.lowercased().contains(query)
        }
    }
    
    private var paletteSections: [PaletteSection] {
        [
            PaletteSection(title: "Basic Elements", items: basicElementItems),
            PaletteSection(title: "Invoice Sections", items: invoiceSectionItems),
            PaletteSection(title: "Company Info", items: companyInfoItems),
            PaletteSection(title: "Additional Elements", items: additionalElementItems)
        ]
    }
    
    private var basicElementItems: [PaletteItemDescriptor] {
        [
            PaletteItemDescriptor(type: .textBox, name: "Text Box", icon: "textformat", description: "Add editable text"),
            PaletteItemDescriptor(type: .rectangleShape, name: "Rectangle", icon: "square", description: "Add rectangle shape"),
            PaletteItemDescriptor(type: .ellipseShape, name: "Ellipse", icon: "circle", description: "Add ellipse shape"),
            PaletteItemDescriptor(type: .lineShape, name: "Line", icon: "line.horizontal.3", description: "Add divider line"),
            PaletteItemDescriptor(type: .triangleShape, name: "Triangle", icon: "triangle", description: "Add triangle shape"),
            PaletteItemDescriptor(type: .starShape, name: "Star", icon: "star", description: "Add star shape"),
            PaletteItemDescriptor(type: .imagePlaceholder, name: "Image Placeholder", icon: "photo", description: "Add image placeholder")
        ]
    }
    
    private var invoiceSectionItems: [PaletteItemDescriptor] {
        [
            PaletteItemDescriptor(type: .invoiceNumberAndDates, name: "Invoice Number & Dates", icon: "number", description: "Invoice number and dates"),
            PaletteItemDescriptor(type: .billTo, name: "Bill To", icon: "person.2", description: "Customer information"),
            PaletteItemDescriptor(type: .participant, name: "Participant", icon: "person.3", description: "Participant information"),
            PaletteItemDescriptor(type: .servicesTable, name: "Services Table", icon: "table", description: "Services and pricing"),
            PaletteItemDescriptor(type: .totals, name: "Totals", icon: "sum", description: "Invoice totals"),
            PaletteItemDescriptor(type: .paymentDetails, name: "Payment Details", icon: "creditcard", description: "Payment information"),
            PaletteItemDescriptor(type: .paymentTerms, name: "Payment Terms", icon: "doc.text", description: "Payment terms and conditions")
        ]
    }
    
    private var companyInfoItems: [PaletteItemDescriptor] {
        [
            PaletteItemDescriptor(type: .invoiceTitle, name: "Invoice Title", icon: "doc.text", description: "Invoice title"),
            PaletteItemDescriptor(type: .companyName, name: "Company Name", icon: "building.2", description: "Company name"),
            PaletteItemDescriptor(type: .companyABN, name: "Company ABN", icon: "number.circle", description: "Company ABN"),
            PaletteItemDescriptor(type: .companyEmail, name: "Company Email", icon: "envelope", description: "Company email"),
            PaletteItemDescriptor(type: .companyLogo, name: "Company Logo", icon: "photo", description: "Company logo placeholder")
        ]
    }
    
    private var additionalElementItems: [PaletteItemDescriptor] {
        [
            PaletteItemDescriptor(type: .notes, name: "Notes", icon: "note.text", description: "Additional notes")
        ]
    }
    
    private struct PaletteItemDescriptor: Identifiable {
        let type: InvoiceComponentType
        let name: String
        let icon: String
        let description: String
        
        var id: InvoiceComponentType { type }
    }
    
    private struct PaletteSection: Identifiable {
        let title: String
        let items: [PaletteItemDescriptor]
        
        var id: String { title }
    }
}

// MARK: - Modern Palette Section

struct ModernPaletteSection<Content: View>: View {
    let title: String
    let isExpanded: Bool
    let onToggle: () -> Void
    let content: Content
    
    init(title: String, isExpanded: Bool, onToggle: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.accentColor)

                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernTheme.textPrimary)

                    Spacer()
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ModernTheme.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(ModernTheme.outline)
                )
        )
    }
}

// MARK: - Modern Palette Item

struct ModernPaletteItem: View {
    let name: String
    let icon: String
    let description: String
    let componentType: InvoiceComponentType
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ModernTheme.textPrimary)
                    Text(description)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(ModernTheme.textSecondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isHovered ? ModernTheme.hoverHighlight : ModernTheme.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isHovered ? Color.accentColor.opacity(0.45) : ModernTheme.outline)
                    )
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.12 : 0), radius: 8, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .draggable(createDraggableComponent()) {
            // Drag preview
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
                
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ModernTheme.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ModernTheme.surfaceElevated)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
        }
    }
    
    private func createDraggableComponent() -> InvoiceComponent {
        InvoiceComponent(
            type: componentType,
            position: .zero,
            size: componentType.defaultSize
        )
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let category: TemplateCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                action()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)

                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? ModernTheme.chipSelectedBackground : ModernTheme.chipUnselectedBackground)
            )
            .foregroundColor(isSelected ? Color.white : ModernTheme.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Template Card

struct ModernTemplateCard: View {
    let template: TemplateItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onDuplicate: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let isDisabled: Bool

    @ViewBuilder
    private var managementMenuContent: some View {
        if let onEdit {
            Button(action: onEdit) {
                Label("Edit Details", systemImage: "pencil")
            }
        }
        if let onDuplicate {
            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "square.on.square")
            }
        }
        if let onDelete {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        if onEdit == nil && onDuplicate == nil && onDelete == nil {
            Text("Save template to access management actions")
                .font(.footnote)
        }
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                onSelect()
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Preview
                RoundedRectangle(cornerRadius: 8)
                    .fill(ModernTheme.surfaceElevated)
                    .frame(height: 120)
                    .overlay(
                        Group {
                            if let data = template.thumbnailData,
                               let image = NSImage(data: data) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(12)
                            } else {
                               Image(systemName: template.previewImage)
                                   .font(.system(size: 32))
                                    .foregroundColor(ModernTheme.textSecondary)
                            }
                        }
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(template.name)
                            .font(.headline)
                            .foregroundColor(ModernTheme.textPrimary)
                        
                        Spacer()
                        
                        if template.isPremium {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                   Text(template.description)
                       .font(.caption)
                        .foregroundColor(ModernTheme.textSecondary)
                        .lineLimit(2)

                    if !template.tags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(template.tags.prefix(3), id: \.self) { tag in
                                TagView(text: tag)
                            }

                       if template.tags.count > 3 {
                            Text("+\(template.tags.count - 3)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(ModernTheme.textSecondary)
                        }
                        }
                    }
                    
                    HStack {
                        Text(template.category.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.22))
                            .foregroundColor(Color.white)
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Text(template.lastModified, style: .relative)
                            .font(.caption2)
                            .foregroundColor(ModernTheme.textSecondary)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? ModernTheme.surfaceActive : ModernTheme.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isSelected ? Color.accentColor.opacity(0.6) : ModernTheme.outline, lineWidth: isSelected ? 2 : 1)
                    )
            )
            .shadow(color: isSelected ? Color.accentColor.opacity(0.35) : Color.black.opacity(0.18), radius: isSelected ? 12 : 8, x: 0, y: isSelected ? 10 : 6)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .contextMenu {
            managementMenuContent
        }
        .overlay(alignment: .topTrailing) {
            if (onEdit != nil || onDuplicate != nil || onDelete != nil) && !isDisabled {
                Menu {
                    managementMenuContent
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.medium)
                        .padding(6)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: onOpen) {
                Label("Open", systemImage: "arrow.forward.circle")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .controlSize(.mini)
            .padding(10)
        }
    }
}

// MARK: - Welcome View

struct ModernTemplateWelcome: View {
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: adaptiveWelcomeSpacing(for: geometry.size)) {
                Spacer()
                
                VStack(spacing: adaptiveWelcomeContentSpacing(for: geometry.size)) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: adaptiveWelcomeIconSize(for: geometry.size)))
                        .foregroundColor(.accentColor)
                    
                    Text("Welcome to Modern Templates")
                        .font(adaptiveWelcomeTitleFont(for: geometry.size))
                        .fontWeight(.bold)
                    
                    Text("Select a template from the sidebar to start editing, or create a new one from scratch.")
                        .font(adaptiveWelcomeBodyFont(for: geometry.size))
                        .foregroundColor(ModernTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, adaptiveWelcomeHorizontalPadding(for: geometry.size.width))
                }
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ModernTheme.surfaceElevated)
    }
    
    // MARK: - Adaptive Welcome Functions
    
    private func adaptiveWelcomeSpacing(for size: CGSize) -> CGFloat {
        let minDimension = min(size.width, size.height)
        switch minDimension {
        case 0..<600: return 20
        case 600..<800: return 24
        default: return 32
        }
    }
    
    private func adaptiveWelcomeContentSpacing(for size: CGSize) -> CGFloat {
        let minDimension = min(size.width, size.height)
        switch minDimension {
        case 0..<600: return 12
        case 600..<800: return 14
        default: return 16
        }
    }
    
    private func adaptiveWelcomeIconSize(for size: CGSize) -> CGFloat {
        let minDimension = min(size.width, size.height)
        switch minDimension {
        case 0..<600: return 48
        case 600..<800: return 56
        default: return 64
        }
    }
    
    private func adaptiveWelcomeTitleFont(for size: CGSize) -> Font {
        let minDimension = min(size.width, size.height)
        switch minDimension {
        case 0..<600: return .title2
        case 600..<800: return .title
        default: return .largeTitle
        }
    }
    
    private func adaptiveWelcomeBodyFont(for size: CGSize) -> Font {
        let minDimension = min(size.width, size.height)
        switch minDimension {
        case 0..<600: return .callout
        case 600..<800: return .body
        default: return .title3
        }
    }
    
    private func adaptiveWelcomeHorizontalPadding(for width: CGFloat) -> CGFloat {
        switch width {
        case 0..<600: return 20
        case 600..<800: return 30
        default: return 40
        }
    }
}

// MARK: - Template Creator

struct ModernTemplateCreatorSheet: View {
    let onCreateTemplate: (TemplateMetadataDraft) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft = TemplateMetadataDraft()
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case tags
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Name"), footer: Text("Choose a descriptive title so you can recognise the template later.")) {
                    TextField("Template Name", text: $draft.name)
                        .focused($focusedField, equals: .name)
                }

                Section(header: Text("Description")) {
                    TextEditor(text: $draft.description)
                        .frame(minHeight: 100)
                }

                Section(header: Text("Tags"), footer: Text("Enter comma-separated tags to help categorise your template.")) {
                    TextField("e.g. professional, business", text: $draft.tagsText)
                        .focused($focusedField, equals: .tags)
                        .disableAutocorrection(true)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ModernTheme.surface)
            .navigationTitle("New Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreateTemplate(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 360)
        .background(ModernTheme.background.ignoresSafeArea())
        .onAppear {
            if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft.name = "Untitled Template"
            }
            focusedField = .name
        }
    }
}

// MARK: - Template Editor

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

        HStack(spacing: 0) {
            if workspace.isPaletteVisible {
                ModernComponentPalette()
                    .frame(width: 260)
                    .frame(maxHeight: .infinity)
                    .background(ModernTheme.surfaceElevated)
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
                    .background(ModernTheme.surfaceElevated)
                    .contentShape(Rectangle())
                    .clipped()
                    .transition(inspectorTransition)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .animation(panelAnimation, value: workspace.isPaletteVisible)
        .animation(panelAnimation, value: isInspectorVisible)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(editorViewModel.currentTemplateName.isEmpty ? "Untitled Template" : editorViewModel.currentTemplateName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    if let category = workspace.activeTemplate?.category ?? template.category as TemplateCategory? {
                        Text(category.rawValue)
                            .font(.caption)
                            .foregroundColor(ModernTheme.textSecondary)
                    }
                }
            }

            ToolbarItemGroup(placement: .status) {
                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(ModernTheme.textSecondary)
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
                ToggleToolbarButton(isOn: editorViewModel.showGrid, systemImage: "square.grid.3x3", help: "Toggle Canvas Grid") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        editorViewModel.toggleGrid()
                    }
                }
                ToggleToolbarButton(isOn: workspace.showMargins, systemImage: "rectangle.dashed", help: "Toggle Margins Overlay") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        workspace.showMargins.toggle()
                    }
                }
                ToggleToolbarButton(isOn: editorViewModel.snapToGrid, systemImage: "target", help: "Toggle Snap to Grid") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        editorViewModel.toggleSnapToGrid()
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

private struct TemplateSelectionToolbar: View {
    let template: TemplateItem
    let isPersisted: Bool
    let isProcessing: Bool
    let onOpen: () -> Void
    let onEdit: (() -> Void)?
    let onDuplicate: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundColor(ModernTheme.textPrimary)
                        .lineLimit(1)

                    if !template.description.isEmpty {
                        Text(template.description)
                            .font(.caption)
                            .foregroundColor(ModernTheme.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button(action: onOpen) {
                    Label("Open", systemImage: "arrow.forward.square")
                }
                .buttonStyle(.bordered)
                .disabled(isProcessing)
            }

            if isPersisted {
                HStack(spacing: 8) {
                    if let onEdit {
                        Button(action: onEdit) {
                            Label("Edit Details", systemImage: "pencil")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isProcessing)
                    }

                    if let onDuplicate {
                        Button(action: onDuplicate) {
                            Label("Duplicate", systemImage: "square.on.square")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isProcessing)
                    }

                    if let onDelete {
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isProcessing)
                    }
                }
            } else {
                Text("Save the template from the editor to manage its details.")
                    .font(.caption)
                    .foregroundColor(ModernTheme.textSecondary)
            }
        }
        .padding(12)
        .background(ModernTheme.surfaceElevated)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.15))
        )
    }
}

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
                }

                Section(header: Text("Description")) {
                    TextEditor(text: $form.description)
                        .frame(minHeight: 120)
                }

                Section(header: Text("Tags"), footer: Text("Enter comma-separated tags.")) {
                    TextField("Comma separated tags", text: $form.tagsText)
                        .disableAutocorrection(true)
                }
            }
            .disabled(isProcessing)
            .scrollContentBackground(.hidden)
            .background(ModernTheme.surface)
            .navigationTitle("Edit Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(form)
                    }
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
        .background(ModernTheme.background.ignoresSafeArea())
    }
}

private struct CanvasGridOverlay: View {
    let gridSize: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let spacing = max(gridSize, 10)
            Path { path in
                var x: CGFloat = 0
                while x <= geometry.size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    x += spacing
                }

                var y: CGFloat = 0
                while y <= geometry.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    y += spacing
                }
            }
            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Modern Canvas View

private struct PageFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero || value == .zero {
            value = next
        }
    }
}

struct ModernCanvasView: View {
    @EnvironmentObject private var workspace: TemplateEditorWorkspaceViewModel
    @EnvironmentObject private var editorViewModel: InvoiceTemplateEditorViewModel
    @EnvironmentObject private var document: InvoiceDocument
    @State private var scrollOffset: CGPoint = .zero
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    @State private var isDropTargeted = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var viewportOffset: CGSize = .zero
    @State private var lastMagnificationValue: CGFloat = 1.0
    @State private var gestureVelocity: CGFloat = 0.0
    @State private var lastGestureTime: Date = Date()
    @State private var isPanning: Bool = false
    @State private var panStartOffset: CGSize = .zero
    @State private var panStartTranslation: CGSize = .zero
    @State private var panVelocity: CGSize = .zero
    @State private var lastPanTime: Date = Date()
    @State private var lastPanTranslation: CGSize = .zero
    @State private var pageFrame: CGRect = .zero
    
    // Helper function for smooth boundary resistance with exponential decay
    nonisolated private func constrainWithResistance(_ value: CGFloat, min: CGFloat, max: CGFloat, resistance: CGFloat) -> CGFloat {
        if value < min {
            let excess = min - value
            // Exponential resistance curve for more natural feel
            let resistanceFactor = 1.0 - pow(resistance, excess / 50.0)
            return min - excess * resistanceFactor
        } else if value > max {
            let excess = value - max
            // Exponential resistance curve for more natural feel
            let resistanceFactor = 1.0 - pow(resistance, excess / 50.0)
            return max + excess * resistanceFactor
        }
        return value
    }
    
    // Helper function to calculate optimal pan boundaries
    nonisolated private func calculatePanBoundaries(geometrySize: CGSize, zoomScale: CGFloat) -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        let canvasSize = CGSize(width: A4.width, height: A4.height)
        let scaledCanvasSize = CGSize(
            width: canvasSize.width * zoomScale,
            height: canvasSize.height * zoomScale
        )
        
        // Only apply boundaries when zoomed in enough to have overflow
        let hasOverflowX = scaledCanvasSize.width > geometrySize.width
        let hasOverflowY = scaledCanvasSize.height > geometrySize.height
        
        let maxOffsetX = hasOverflowX ? (scaledCanvasSize.width - geometrySize.width) / 2 : 0
        let maxOffsetY = hasOverflowY ? (scaledCanvasSize.height - geometrySize.height) / 2 : 0
        
        return (
            minX: hasOverflowX ? -maxOffsetX : 0,
            maxX: hasOverflowX ? maxOffsetX : 0,
            minY: hasOverflowY ? -maxOffsetY : 0,
            maxY: hasOverflowY ? maxOffsetY : 0
        )
    }
    
    // Helper function to apply momentum-based panning (simplified to avoid concurrency issues)
    private func applyMomentum(geometry: GeometryProxy) {
        // For now, just apply a small momentum offset without complex animation
        // This avoids concurrency issues while still providing some momentum feel
        let momentumFactor: CGFloat = 0.3
        let momentumOffset = CGSize(
            width: panVelocity.width * momentumFactor,
            height: panVelocity.height * momentumFactor
        )
        
        let newOffset = CGSize(
            width: viewportOffset.width + momentumOffset.width,
            height: viewportOffset.height + momentumOffset.height
        )
        
        // Apply boundary constraints
        let boundaries = calculatePanBoundaries(geometrySize: geometry.size, zoomScale: zoomScale)
        let constrainedOffsetX = constrainWithResistance(
            newOffset.width,
            min: boundaries.minX,
            max: boundaries.maxX,
            resistance: 0.1
        )
        
        let constrainedOffsetY = constrainWithResistance(
            newOffset.height,
            min: boundaries.minY,
            max: boundaries.maxY,
            resistance: 0.1
        )
        
        withAnimation(.easeOut(duration: 0.3)) {
            viewportOffset = CGSize(width: constrainedOffsetX, height: constrainedOffsetY)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background
                ModernTheme.surfaceElevated
                
                // Canvas with drop zone and zoom
                ScrollView([.horizontal, .vertical]) {
                    ZStack {
                        // Page background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .frame(width: A4.width, height: A4.height)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

                        if editorViewModel.showGrid {
                            CanvasGridOverlay(gridSize: editorViewModel.gridSize)
                                .frame(width: A4.width, height: A4.height)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .allowsHitTesting(false)
                        }
                        
                        if workspace.showMargins {
                            MarginFillOverlay(
                                pageSize: CGSize(width: A4.width, height: A4.height),
                                margins: document.margins
                            )
                            .frame(width: A4.width, height: A4.height)
                            .allowsHitTesting(false)
                        }
                        
                        // Drop zone overlay
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.clear)
                            .frame(width: A4.width, height: A4.height)
                            .contentShape(Rectangle())
                            .onDrop(of: [UTType.invoiceComponent], isTargeted: $isDropTargeted) { providers, location in
                                handleDrop(providers: providers, at: location)
                            }
                            .onTapGesture {
                                document.selectedComponentID = nil
                            }
                        
                        // Render components with integrated visual states
                        ForEach(document.components, id: \.id) { component in
                            ModernDraggableComponent(component: component)
                                .id(component.id)
                        }
                        
                        if workspace.showMargins {
                            MarginGuideOverlay(
                                pageSize: CGSize(width: A4.width, height: A4.height),
                                margins: document.margins
                            )
                            .allowsHitTesting(false)
                        }
                        
                        // Page outline
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isDropTargeted ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isDropTargeted ? 2 : 1)
                            .animation(.easeInOut(duration: 0.2), value: isDropTargeted)
                    }
                    .frame(width: A4.width, height: A4.height)
                    .scaleEffect(zoomScale, anchor: .center)
                    .offset(viewportOffset)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: PageFramePreferenceKey.self,
                                value: proxy.frame(in: .named("canvasSpace"))
                            )
                        }
                    )
                    .gesture(
                        SimultaneousGesture(
                            // Magnification gesture for zoom
                            MagnificationGesture()
                                .onChanged { value in
                                    let currentTime = Date()
                                    let timeDelta = currentTime.timeIntervalSince(lastGestureTime)
                                    
                                    // Calculate gesture velocity for adaptive dampening
                                    if timeDelta > 0 {
                                        let deltaValue = value - lastMagnificationValue
                                        gestureVelocity = abs(deltaValue) / CGFloat(timeDelta)
                                    }
                                    
                                    // Logarithmic dampening based on current zoom level
                                    let logDampening = log(zoomScale + 0.5) / log(2.0)
                                    let adaptiveDampening = max(0.1, 0.5 - logDampening * 0.2)
                                    
                                    // Velocity-based dampening (faster gestures = less dampening)
                                    let velocityDampening = min(1.0, max(0.3, 1.0 - gestureVelocity * 2.0))
                                    
                                    // Combined dampening factor
                                    let combinedDampening = adaptiveDampening * velocityDampening
                                    
                                    // Apply logarithmic scaling for more natural feel
                                    let rawDelta = value - lastMagnificationValue
                                    let dampenedDelta = rawDelta * combinedDampening
                                    let newScale = zoomScale + dampenedDelta
                                    
                                    // Apply exponential resistance near boundaries
                                    let minScale: CGFloat = 0.25
                                    let maxScale: CGFloat = 4.0
                                    let resistanceFactor: CGFloat = 0.3
                                    
                                    let finalScale: CGFloat
                                    if newScale < minScale {
                                        let excess = minScale - newScale
                                        finalScale = minScale - excess * resistanceFactor
                                    } else if newScale > maxScale {
                                        let excess = newScale - maxScale
                                        finalScale = maxScale + excess * resistanceFactor
                                    } else {
                                        finalScale = newScale
                                    }
                                    
                                    let oldScale = zoomScale
                                    zoomScale = max(minScale, min(finalScale, maxScale))
                                    
                                    // Adjust viewport offset to maintain zoom center point
                                    if zoomScale != oldScale {
                                        let scaleRatio = zoomScale / oldScale
                                        viewportOffset = CGSize(
                                            width: viewportOffset.width * scaleRatio,
                                            height: viewportOffset.height * scaleRatio
                                        )
                                    }
                                    
                                    lastMagnificationValue = value
                                    lastGestureTime = currentTime
                                }
                                .onEnded { _ in
                                    // Smart snapping to common zoom levels with hysteresis
                                    let snapThreshold: CGFloat = 0.1
                                    
                                    if abs(zoomScale - 0.5) < snapThreshold {
                                        zoomScale = 0.5
                                    } else if abs(zoomScale - 1.0) < snapThreshold {
                                        zoomScale = 1.0
                                    } else if abs(zoomScale - 1.5) < snapThreshold {
                                        zoomScale = 1.5
                                    } else if abs(zoomScale - 2.0) < snapThreshold {
                                        zoomScale = 2.0
                                    } else if abs(zoomScale - 3.0) < snapThreshold {
                                        zoomScale = 3.0
                                    }
                                    
                                    // Reset gesture tracking
                                    lastMagnificationValue = 1.0
                                    gestureVelocity = 0.0
                                },
                            
                            // Drag gesture for panning when zoomed
                            DragGesture()
                                .onChanged { value in
                                    let currentTime = Date()
                                    
                                    if !isPanning {
                                        isPanning = true
                                        panStartOffset = viewportOffset
                                        panStartTranslation = value.translation
                                        lastPanTime = currentTime
                                        lastPanTranslation = value.translation
                                        panVelocity = .zero
                                    }
                                    
                                    // Calculate velocity for momentum and feedback
                                    let timeDelta = currentTime.timeIntervalSince(lastPanTime)
                                    if timeDelta > 0 {
                                        let deltaTranslation = CGSize(
                                            width: value.translation.width - lastPanTranslation.width,
                                            height: value.translation.height - lastPanTranslation.height
                                        )
                                        panVelocity = CGSize(
                                            width: deltaTranslation.width / CGFloat(timeDelta),
                                            height: deltaTranslation.height / CGFloat(timeDelta)
                                        )
                                    }
                                    
                                    // Calculate new viewport offset based on drag translation
                                    let deltaTranslation = CGSize(
                                        width: value.translation.width - panStartTranslation.width,
                                        height: value.translation.height - panStartTranslation.height
                                    )
                                    
                                    let newOffset = CGSize(
                                        width: panStartOffset.width + deltaTranslation.width,
                                        height: panStartOffset.height + deltaTranslation.height
                                    )
                                    
                                    // Get optimized pan boundaries
                                    let boundaries = calculatePanBoundaries(geometrySize: geometry.size, zoomScale: zoomScale)
                                    
                                    // Apply constraints with refined resistance
                                    let resistance: CGFloat = 0.2 // Reduced for more responsive feel
                                    let constrainedOffsetX = constrainWithResistance(
                                        newOffset.width,
                                        min: boundaries.minX,
                                        max: boundaries.maxX,
                                        resistance: resistance
                                    )
                                    
                                    let constrainedOffsetY = constrainWithResistance(
                                        newOffset.height,
                                        min: boundaries.minY,
                                        max: boundaries.maxY,
                                        resistance: resistance
                                    )
                                    
                                    viewportOffset = CGSize(width: constrainedOffsetX, height: constrainedOffsetY)
                                    
                                    // Update tracking variables
                                    lastPanTime = currentTime
                                    lastPanTranslation = value.translation
                                }
                                .onEnded { _ in
                                    isPanning = false
                                    
                                    // Apply momentum if velocity is high enough
                                    let momentumThreshold: CGFloat = 100.0
                                    if abs(panVelocity.width) > momentumThreshold || abs(panVelocity.height) > momentumThreshold {
                                        applyMomentum(geometry: geometry)
                                    }
                                    
                                    // Reset velocity tracking
                                    panVelocity = .zero
                                }
                        )
                    )
                }
                .background(ModernTheme.surface)
                
                // Pan indicator overlay (subtle visual feedback)
                if isPanning {
                    VStack {
                        HStack {
                            Spacer()
                            Text("Panning")
                                .font(.caption)
                                .foregroundColor(ModernTheme.textSecondary)
                                .padding(8)
                                .background(ModernTheme.surface.opacity(0.8))
                                .cornerRadius(6)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(.top, 8)
                    .allowsHitTesting(false)
                }
                
                // Zoom and Pan Controls (top-right corner)
                VStack {
                    HStack {
                        Spacer()
                        ZoomPanControlsView(
                            zoomScale: $zoomScale,
                            viewportOffset: $viewportOffset,
                            geometry: geometry
                        )
                    }
                    Spacer()
                }
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                    .allowsHitTesting(true)
                
                if editorViewModel.showRulers && pageFrame != .zero {
                    RulersOverlayView(
                        containerSize: geometry.size,
                        pageFrame: pageFrame,
                        pageSize: CGSize(width: A4.width, height: A4.height),
                        zoomScale: zoomScale,
                        margins: document.margins,
                        showMargins: workspace.showMargins,
                        unit: workspace.rulerUnit
                    )
                    .allowsHitTesting(false)
                    
                    if workspace.showMargins {
                        MarginHandlesOverlay(
                            pageFrame: pageFrame,
                            zoomScale: zoomScale,
                            margins: document.margins,
                            onMarginChange: updateMargin(edge:value:commit:)
                        )
                    }
                }
            }
            .coordinateSpace(name: "canvasSpace")
            .onPreferenceChange(PageFramePreferenceKey.self) { frame in
                self.pageFrame = frame
            }
        }
    }
    
    private func updateMargin(edge: InvoiceDocument.MarginEdge, value: CGFloat, commit: Bool) {
        document.updateMargin(edge: edge, to: value, recordUndo: commit)
        
        let updated = document.margins
        workspace.marginLeftStr = formattedMargin(updated.left)
        workspace.marginRightStr = formattedMargin(updated.right)
        workspace.marginTopStr = formattedMargin(updated.top)
        workspace.marginBottomStr = formattedMargin(updated.bottom)
    }
    
    private func formattedMargin(_ value: CGFloat) -> String {
        String(format: "%.0f", value)
    }
    
    private func handleDrop(providers: [NSItemProvider], at location: CGPoint) -> Bool {
        guard let provider = providers.first else { return false }
        
        // Check if we can load data of the invoice component type
        if provider.hasItemConformingToTypeIdentifier(UTType.invoiceComponent.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.invoiceComponent.identifier) { data, error in
                DispatchQueue.main.async {
                    if let data = data {
                        do {
                            let decoder = JSONDecoder()
                            let component = try decoder.decode(InvoiceComponent.self, from: data)
                            
                            // Create a new component at the drop location
                            var newComponent = component
                            newComponent.id = UUID() // Generate new ID
                            newComponent.position = location // Use actual drop location
                            
                            // Add the component via the editor view model for proper validation/state updates
                            editorViewModel.addComponent(newComponent)
                        } catch {
                            print("Failed to decode component: \(error)")
                        }
                    }
                }
            }
            return true
        }
        
        return false
    }
}

// MARK: - Modern Draggable Component

struct ModernDraggableComponent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var editorViewModel: InvoiceTemplateEditorViewModel
    @EnvironmentObject private var document: InvoiceDocument
    @State private var dragOffset: CGSize = .zero
    @State private var isHovered = false
    
    private var isSelected: Bool {
        document.selectedComponentID == component.id
    }
    
    private var isLocked: Bool {
        component.isLocked
    }
    
    var body: some View {
        Group {
            if component.isVisible {
                ZStack {
                    // Main component content with hover detection
                    ModernComponentView(component: component)
                        .frame(width: component.size.width, height: component.size.height)
                        .contentShape(Rectangle())
                        .position(component.position)
                        .offset(dragOffset)
                        .onHover { hovering in
                            isHovered = hovering
                        }
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                document.selectedComponentID = component.id
                            }
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    guard !isLocked else { return }
                                    dragOffset = value.translation
                                    document.selectedComponentID = component.id
                                }
                                .onEnded { value in
                                    defer { dragOffset = .zero }
                                    guard !isLocked else { return }
                                    
                                    let newPosition = CGPoint(
                                        x: component.position.x + value.translation.width,
                                        y: component.position.y + value.translation.height
                                    )
                                    let snappedPosition = editorViewModel.snappedPosition(
                                        for: component,
                                        proposedPosition: newPosition
                                    )
                                    
                                    document.updateComponent(id: component.id) { comp in
                                        comp.position = snappedPosition
                                    }
                                }
                        )
                    
                    // Hover frame (only when not selected)
                    if isHovered && !isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.blue.opacity(0.6), lineWidth: 1)
                            .frame(width: component.size.width + 2, height: component.size.height + 2)
                            .position(component.position)
                            .offset(dragOffset)
                            .allowsHitTesting(false)
                            .animation(.easeInOut(duration: 0.15), value: isHovered)
                    }
                    
                    // Selection frame and resize handles (only when selected)
                    if isSelected {
                        // Selection frame
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor, lineWidth: 2)
                            .frame(width: component.size.width, height: component.size.height)
                            .position(component.position)
                            .offset(dragOffset)
                            .allowsHitTesting(false)
                            .zIndex(1000)
                        
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.black.opacity(0.6), in: Circle())
                                .position(
                                    x: component.position.x + component.size.width / 2 - 12,
                                    y: component.position.y - component.size.height / 2 + 12
                                )
                                .offset(dragOffset)
                                .allowsHitTesting(false)
                                .zIndex(1001)
                        } else {
                            // Resize handles
                            ResizeHandlesView(component: component)
                                .offset(dragOffset)
                                .zIndex(1001)
                        }
                    }
                }
                .transition(.scale(scale: 0.95, anchor: .center).combined(with: .opacity))
            } else {
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: component.isVisible)
    }
}

private struct MarginFillOverlay: View {
    let pageSize: CGSize
    let margins: InvoiceDocument.DocumentMargins
    
    private var fillColor: Color {
        Color("Cyan", bundle: .sharedUI).opacity(0.08)
    }
    
    var body: some View {
        let left = max(0, min(margins.left, pageSize.width))
        let right = max(0, min(margins.right, pageSize.width))
        let top = max(0, min(margins.top, pageSize.height))
        let bottom = max(0, min(margins.bottom, pageSize.height))
        let contentWidth = max(pageSize.width - left - right, 0)
        let contentHeight = max(pageSize.height - top - bottom, 0)
        
        return Path { path in
            if left > 0 {
                path.addRect(CGRect(x: 0, y: 0, width: left, height: pageSize.height))
            }
            if right > 0 {
                path.addRect(CGRect(x: pageSize.width - right, y: 0, width: right, height: pageSize.height))
            }
            if top > 0 && contentWidth > 0 {
                path.addRect(CGRect(x: left, y: 0, width: contentWidth, height: top))
            }
            if bottom > 0 && contentWidth > 0 {
                path.addRect(CGRect(x: left, y: pageSize.height - bottom, width: contentWidth, height: bottom))
            }
        }
        .fill(fillColor)
    }
}

private struct MarginGuideOverlay: View {
    let pageSize: CGSize
    let margins: InvoiceDocument.DocumentMargins
    
    private var guideColor: Color {
        Color("Cyan", bundle: .sharedUI).opacity(0.65)
    }
    
    var body: some View {
        Path { path in
            let left = max(0, min(margins.left, pageSize.width))
            let right = max(0, min(margins.right, pageSize.width))
            let top = max(0, min(margins.top, pageSize.height))
            let bottom = max(0, min(margins.bottom, pageSize.height))
            
            path.move(to: CGPoint(x: left, y: 0))
            path.addLine(to: CGPoint(x: left, y: pageSize.height))
            
            path.move(to: CGPoint(x: pageSize.width - right, y: 0))
            path.addLine(to: CGPoint(x: pageSize.width - right, y: pageSize.height))
            
            path.move(to: CGPoint(x: 0, y: top))
            path.addLine(to: CGPoint(x: pageSize.width, y: top))
            
            path.move(to: CGPoint(x: 0, y: pageSize.height - bottom))
            path.addLine(to: CGPoint(x: pageSize.width, y: pageSize.height - bottom))
        }
        .stroke(guideColor, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        .overlay(
            Group {
                marker(at: CGPoint(x: max(0, min(margins.left, pageSize.width)), y: max(0, min(margins.top, pageSize.height))))
                marker(at: CGPoint(x: max(0, min(margins.left, pageSize.width)), y: pageSize.height - max(0, min(margins.bottom, pageSize.height))))
                marker(at: CGPoint(x: pageSize.width - max(0, min(margins.right, pageSize.width)), y: max(0, min(margins.top, pageSize.height))))
                marker(at: CGPoint(x: pageSize.width - max(0, min(margins.right, pageSize.width)), y: pageSize.height - max(0, min(margins.bottom, pageSize.height))))
            }
        )
    }
    
    private func marker(at point: CGPoint) -> some View {
        Circle()
            .fill(Color("Cyan", bundle: .sharedUI).opacity(0.5))
            .frame(width: 4, height: 4)
            .position(point)
    }
}

private struct RulersOverlayView: View {
    let containerSize: CGSize
    let pageFrame: CGRect
    let pageSize: CGSize
    let zoomScale: CGFloat
    let margins: InvoiceDocument.DocumentMargins
    let showMargins: Bool
    let unit: RulerUnit
    
    private let rulerThickness: CGFloat = 20
    
    var body: some View {
        let width = max(containerSize.width, 0)
        let height = max(containerSize.height, 0)
        let topY = rulerThickness / 2
        let bottomY = height - rulerThickness / 2
        let leftX = rulerThickness / 2
        let rightX = width - rulerThickness / 2
        let horizontalZeroOffset = pageFrame.minX
        let verticalZeroOffset = pageFrame.minY
        let horizontalMarginEnd = pageSize.width - margins.right
        let verticalMarginEnd = pageSize.height - margins.bottom
        
        return ZStack {
            // Top ruler
            RulerView(
                orientation: .horizontal,
                length: width,
                unit: unit,
                cursorPosition: nil,
                showCursorIndicator: false,
                zeroOffset: horizontalZeroOffset,
                selectionStart: nil,
                selectionEnd: nil,
                marginStart: showMargins ? margins.left : nil,
                marginEnd: showMargins ? horizontalMarginEnd : nil,
                zoom: zoomScale,
                scrollOffset: 0
            )
            .frame(width: width, height: rulerThickness)
            .position(
                x: width / 2,
                y: topY
            )
            
            // Bottom ruler
            RulerView(
                orientation: .horizontal,
                length: width,
                unit: unit,
                cursorPosition: nil,
                showCursorIndicator: false,
                zeroOffset: horizontalZeroOffset,
                selectionStart: nil,
                selectionEnd: nil,
                marginStart: showMargins ? margins.left : nil,
                marginEnd: showMargins ? horizontalMarginEnd : nil,
                zoom: zoomScale,
                scrollOffset: 0
            )
            .frame(width: width, height: rulerThickness)
            .position(
                x: width / 2,
                y: bottomY
            )
            
            // Left ruler
            RulerView(
                orientation: .vertical,
                length: height,
                unit: unit,
                cursorPosition: nil,
                showCursorIndicator: false,
                zeroOffset: verticalZeroOffset,
                selectionStart: nil,
                selectionEnd: nil,
                marginStart: showMargins ? margins.top : nil,
                marginEnd: showMargins ? verticalMarginEnd : nil,
                zoom: zoomScale,
                scrollOffset: 0
            )
            .frame(width: rulerThickness, height: height)
            .position(
                x: leftX,
                y: height / 2
            )
            
            // Right ruler
            RulerView(
                orientation: .vertical,
                length: height,
                unit: unit,
                cursorPosition: nil,
                showCursorIndicator: false,
                zeroOffset: verticalZeroOffset,
                selectionStart: nil,
                selectionEnd: nil,
                marginStart: showMargins ? margins.top : nil,
                marginEnd: showMargins ? verticalMarginEnd : nil,
                zoom: zoomScale,
                scrollOffset: 0
            )
            .frame(width: rulerThickness, height: height)
            .position(
                x: rightX,
                y: height / 2
            )
            
            // Corner squares
            Rectangle()
                .fill(Color("Black30", bundle: .sharedUI))
                .frame(width: rulerThickness, height: rulerThickness)
                .overlay(
                    Rectangle()
                        .stroke(ModernTheme.outlineStrong, lineWidth: 0.6)
                )
                .overlay(
                    Rectangle()
                        .stroke(Color("Border", bundle: .sharedUI).opacity(0.6), lineWidth: 1)
                        .padding(2)
                )
                .position(
                    x: leftX,
                    y: topY
                )
            
            Rectangle()
                .fill(Color("Black30", bundle: .sharedUI))
                .frame(width: rulerThickness, height: rulerThickness)
                .overlay(
                    Rectangle()
                        .stroke(ModernTheme.outlineStrong, lineWidth: 0.6)
                )
                .position(
                    x: rightX,
                    y: topY
                )
            
            Rectangle()
                .fill(Color("Black30", bundle: .sharedUI))
                .frame(width: rulerThickness, height: rulerThickness)
                .overlay(
                    Rectangle()
                        .stroke(ModernTheme.outlineStrong, lineWidth: 0.6)
                )
                .position(
                    x: leftX,
                    y: bottomY
                )
            
            Rectangle()
                .fill(Color("Black30", bundle: .sharedUI))
                .frame(width: rulerThickness, height: rulerThickness)
                .overlay(
                    Rectangle()
                        .stroke(ModernTheme.outlineStrong, lineWidth: 0.6)
                )
                .position(
                    x: rightX,
                    y: bottomY
                )
        }
    }
}

private struct MarginHandlesOverlay: View {
    let pageFrame: CGRect
    let zoomScale: CGFloat
    let margins: InvoiceDocument.DocumentMargins
    let onMarginChange: (InvoiceDocument.MarginEdge, CGFloat, Bool) -> Void
    
    @State private var leftStart: CGFloat?
    @State private var rightStart: CGFloat?
    @State private var topStart: CGFloat?
    @State private var bottomStart: CGFloat?
    
    private let handleSize: CGFloat = 14
    
    var body: some View {
        ZStack {
            horizontalHandles
            verticalHandles
        }
        .allowsHitTesting(true)
    }
    
    private var horizontalHandles: some View {
        let leftPosition = pageFrame.minX + margins.left * zoomScale
        let rightPosition = pageFrame.maxX - margins.right * zoomScale
        let yPosition = pageFrame.minY - handleSize / 2 - 2
        
        return ZStack {
            MarginHandle(direction: .down)
                .frame(width: handleSize, height: handleSize)
                .position(x: leftPosition, y: yPosition)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if leftStart == nil {
                                leftStart = margins.left
                            }
                            
                            let initial = leftStart ?? margins.left
                            let delta = value.translation.width / zoomScale
                            onMarginChange(.left, initial + delta, false)
                        }
                        .onEnded { value in
                            let initial = leftStart ?? margins.left
                            let delta = value.translation.width / zoomScale
                            onMarginChange(.left, initial + delta, true)
                            leftStart = nil
                        }
                )
            
            MarginHandle(direction: .down)
                .frame(width: handleSize, height: handleSize)
                .position(x: rightPosition, y: yPosition)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if rightStart == nil {
                                rightStart = margins.right
                            }
                            
                            let initial = rightStart ?? margins.right
                            let delta = value.translation.width / zoomScale
                            onMarginChange(.right, initial - delta, false)
                        }
                        .onEnded { value in
                            let initial = rightStart ?? margins.right
                            let delta = value.translation.width / zoomScale
                            onMarginChange(.right, initial - delta, true)
                            rightStart = nil
                        }
                )
        }
    }
    
    private var verticalHandles: some View {
        let xPosition = pageFrame.minX - handleSize / 2 - 2
        let topPosition = pageFrame.minY + margins.top * zoomScale
        let bottomPosition = pageFrame.maxY - margins.bottom * zoomScale
        
        return ZStack {
            MarginHandle(direction: .right)
                .frame(width: handleSize, height: handleSize)
                .position(x: xPosition, y: topPosition)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if topStart == nil {
                                topStart = margins.top
                            }
                            
                            let initial = topStart ?? margins.top
                            let delta = value.translation.height / zoomScale
                            onMarginChange(.top, initial + delta, false)
                        }
                        .onEnded { value in
                            let initial = topStart ?? margins.top
                            let delta = value.translation.height / zoomScale
                            onMarginChange(.top, initial + delta, true)
                            topStart = nil
                        }
                )
            
            MarginHandle(direction: .right)
                .frame(width: handleSize, height: handleSize)
                .position(x: xPosition, y: bottomPosition)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if bottomStart == nil {
                                bottomStart = margins.bottom
                            }
                            
                            let initial = bottomStart ?? margins.bottom
                            let delta = value.translation.height / zoomScale
                            onMarginChange(.bottom, initial - delta, false)
                        }
                        .onEnded { value in
                            let initial = bottomStart ?? margins.bottom
                            let delta = value.translation.height / zoomScale
                            onMarginChange(.bottom, initial - delta, true)
                            bottomStart = nil
                        }
                )
        }
    }
}

private struct MarginHandle: View {
    enum Direction {
        case up, down, left, right
        
        var rotation: Angle {
            switch self {
            case .up: return .degrees(180)
            case .down: return .degrees(0)
            case .left: return .degrees(90)
            case .right: return .degrees(-90)
            }
        }
    }
    
    let direction: Direction
    
    var body: some View {
        TriangleHandleShape()
            .fill(Color("Cyan", bundle: .sharedUI))
            .overlay(
                TriangleHandleShape()
                    .stroke(Color("Cyan", bundle: .sharedUI).opacity(0.8), lineWidth: 1)
            )
            .rotationEffect(direction.rotation)
            .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
            .contentShape(Rectangle())
    }
}

private struct TriangleHandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

// MARK: - Modern Component View

struct ModernComponentView: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument
    
    var body: some View {
        Group {
            switch component.type {
            case .companyName:
                ModernCompanyNameView(component: component)
            case .companyLogo:
                ModernLogoView(component: component)
            case .companyABN:
                ModernCompanyABNView(component: component)
            case .companyEmail:
                ModernCompanyEmailView(component: component)
            case .invoiceNumberAndDates:
                if component.children.isEmpty {
                    ModernInvoiceNumberView(component: component)
                } else {
                    ModernSectionWithChildrenView(component: component, title: "Invoice Number & Dates")
                }
            case .billTo:
                if component.children.isEmpty {
                    ModernBillToView(component: component)
                } else {
                    ModernSectionWithChildrenView(component: component, title: "Bill To")
                }
            case .participant:
                if component.children.isEmpty {
                    ModernParticipantView(component: component)
                } else {
                    ModernSectionWithChildrenView(component: component, title: "Participant")
                }
            case .servicesTable:
                if component.children.isEmpty {
                    ModernServicesTableView(component: component)
                } else {
                    ModernSectionWithChildrenView(component: component, title: "Services Table")
                }
            case .totals:
                if component.children.isEmpty {
                    ModernTotalsView(component: component)
                } else {
                    ModernSectionWithChildrenView(component: component, title: "Totals")
                }
            case .paymentDetails:
                if component.children.isEmpty {
                    ModernPaymentDetailsView(component: component)
                } else {
                    ModernSectionWithChildrenView(component: component, title: "Payment Details")
                }
            case .paymentTerms:
                ModernPaymentTermsView(component: component)
            case .invoiceTitle:
                ModernInvoiceTitleView(component: component)
            case .notes:
                ModernNotesView(component: component)
            case .textBox:
                ModernStyledTextView(component: component, defaultText: component.title ?? (component.style.placeholderText.isEmpty ? "Text" : component.style.placeholderText))
            case .rectangleShape:
                ModernRectangleView(component: component)
            case .ellipseShape:
                ModernEllipseView(component: component)
            case .lineShape:
                ModernLineView(component: component)
            case .triangleShape:
                ModernTriangleView(component: component)
            case .starShape:
                ModernStarView(component: component)
            case .imagePlaceholder:
                ModernImagePlaceholderView(component: component)
            }
        }
        .frame(width: component.size.width, height: component.size.height)
    }
}

// MARK: - Component Style Modifier

private struct ComponentStyleModifier: ViewModifier {
    let style: ComponentStyle
    let alignment: Alignment
    let expandHorizontally: Bool
    let expandVertically: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(style.padding)
            .frame(
                maxWidth: expandHorizontally ? .infinity : nil,
                maxHeight: expandVertically ? .infinity : nil,
                alignment: alignment
            )
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(style.backgroundColorSwiftUI)
            )
            .overlay {
                if style.borderWidth > 0 {
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .stroke(style.borderColorSwiftUI, lineWidth: style.borderWidth)
                }
            }
            .shadow(
                color: style.shadowEnabled ? style.shadowColorSwiftUI : .clear,
                radius: style.shadowRadius,
                x: style.shadowOffsetX,
                y: style.shadowOffsetY
            )
            .padding(style.margin)
    }
}

private extension View {
    func applyComponentVisualStyle(
        style: ComponentStyle,
        alignment: Alignment,
        expandHorizontally: Bool = true,
        expandVertically: Bool = true
    ) -> some View {
        modifier(
            ComponentStyleModifier(
                style: style,
                alignment: alignment,
                expandHorizontally: expandHorizontally,
                expandVertically: expandVertically
            )
        )
    }
}

// MARK: - Modern Component Views

/// A reusable component for rendering styled text content (modern version)
struct ModernStyledTextView: View {
    let component: InvoiceComponent
    let defaultText: String
    let label: String?
    let subtitle: String?
    let expandHorizontally: Bool
    let expandVertically: Bool
    
    init(
        component: InvoiceComponent,
        defaultText: String,
        label: String? = nil,
        subtitle: String? = nil,
        expandHorizontally: Bool = true,
        expandVertically: Bool = true
    ) {
        self.component = component
        self.defaultText = defaultText
        self.label = label
        self.subtitle = subtitle
        self.expandHorizontally = expandHorizontally
        self.expandVertically = expandVertically
    }
    
    var body: some View {
        // Use placeholderText if available, otherwise use defaultText
        let displayText = component.style.placeholderText.isEmpty ? defaultText : component.style.placeholderText
        let fontWeight = component.style.fontWeightValue
        let alignment = component.style.textAlignment
        let spacing = component.style.contentSpacing > 0 ? component.style.contentSpacing : 2
        
        return VStack(alignment: alignment.horizontalAlignment, spacing: spacing) {
            if let label = label {
                Text(label)
                    .font(component.style.fontFamily(max(8, component.style.fontSize - 2), .medium))
                    .foregroundColor(component.style.textColorSwiftUI.opacity(0.7))
                    .multilineTextAlignment(alignment.swiftUIAlignment)
                    .lineSpacing(component.style.lineSpacing)
                    .tracking(component.style.letterSpacing)
            }
            
            Text(displayText)
                .font(component.style.fontFamily(component.style.fontSize, fontWeight))
                .foregroundColor(component.style.textColorSwiftUI)
                .multilineTextAlignment(alignment.swiftUIAlignment)
                .lineLimit(nil)
                .lineSpacing(component.style.lineSpacing)
                .tracking(component.style.letterSpacing)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(component.style.fontFamily(max(8, component.style.fontSize - 2), .medium))
                    .foregroundColor(component.style.textColorSwiftUI.opacity(0.7))
                    .multilineTextAlignment(alignment.swiftUIAlignment)
                    .lineSpacing(component.style.lineSpacing)
                    .tracking(component.style.letterSpacing)
            }
        }
        .applyComponentVisualStyle(
            style: component.style,
            alignment: alignment.frameAlignment,
            expandHorizontally: expandHorizontally,
            expandVertically: expandVertically
        )
    }
}

/// A reusable component for rendering section content with children (modern version)
struct ModernSectionWithChildrenView: View {
    let component: InvoiceComponent
    let title: String
    
    var body: some View {
        let alignment = component.style.textAlignment
        let spacing = component.style.contentSpacing > 0 ? component.style.contentSpacing : 8
        
        VStack(alignment: alignment.horizontalAlignment, spacing: spacing) {
            Text(title)
                .font(component.style.fontFamily(component.style.fontSize, .semibold))
                .foregroundColor(component.style.textColorSwiftUI)
                .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
            
            ModernSectionContentArea(
                children: component.children,
                layout: component.style.sectionLayout,
                gridColumns: component.style.gridColumns,
                spacing: spacing
            )
            .padding(component.style.contentPadding)
        }
        .applyComponentVisualStyle(
            style: component.style,
            alignment: .topLeading
        )
    }
}

/// A reusable component for rendering service tables (modern version)
struct ModernServiceTableView: View {
    let component: InvoiceComponent
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            if component.style.showTableHeader {
                HStack {
                    Text("Service").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Quantity").frame(width: 80)
                    Text("Rate").frame(width: 80)
                    Text("Amount").frame(width: 100, alignment: .trailing)
                }
                .font(.system(size: max(8, component.style.fontSize), weight: .bold))
                .padding(8)
                .background(Color("TableBackground", bundle: .sharedUI))
                .foregroundColor(Color("Text", bundle: .sharedUI))
            }

            // Example Rows
            ForEach(0..<4) { i in
                HStack {
                    Text("Example Service Description \(i + 1)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(i % 2 == 0 ? "1.5 hr" : "45 min")")
                        .frame(width: 80)
                    Text("$\((75.50 + Double(i * 5)).formatted())")
                        .frame(width: 80)
                    Text("$\((113.25 + Double(i * 10)).formatted())")
                        .frame(width: 100, alignment: .trailing)
                }
                .font(.system(size: max(8, component.style.fontSize)))
                .padding(8)
                .background(
                    component.style.useAlternatingRows && i % 2 == 1
                        ? Color("TableBackground", bundle: .sharedUI).opacity(0.5)
                        : Color("TableBackground", bundle: .sharedUI)
                )
                .foregroundColor(Color("Text", bundle: .sharedUI))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// A reusable component for rendering shape views (modern version)
struct ModernShapeView<S: Shape>: View {
    let component: InvoiceComponent
    let shape: S
    
    var body: some View {
        shape
            .fill(component.style.backgroundColorSwiftUI)
            .overlay(shape.stroke(component.style.borderColorSwiftUI, style: component.style.borderStrokeStyle))
            .frame(width: component.size.width, height: component.size.height)
    }
}


/// A reusable component for rendering section content area (modern version)
struct ModernSectionContentArea: View {
    let children: [InvoiceComponent]
    let layout: SectionLayout
    let gridColumns: Int
    let spacing: CGFloat
    
    var body: some View {
        switch layout {
        case .vertical:
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(children) { childComponent in
                    ModernInlineChildComponentView(childComponent: childComponent)
                }
            }
        case .horizontal:
            HStack(alignment: .top, spacing: spacing) {
                ForEach(children) { childComponent in
                    ModernInlineChildComponentView(childComponent: childComponent)
                }
            }
        case .grid:
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: gridColumns), spacing: spacing) {
                ForEach(children) { childComponent in
                    ModernInlineChildComponentView(childComponent: childComponent)
                }
            }
        }
    }
}

/// A reusable component for rendering inline child components (modern version)
struct ModernInlineChildComponentView: View {
    let childComponent: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument
    
    var body: some View {
        Group {
            if childComponent.isVisible {
                inlineContent(for: childComponent)
                    .overlay {
                        if document.selectedComponentID == childComponent.id {
                            RoundedRectangle(cornerRadius: childComponent.style.cornerRadius)
                                .fill(Color("Blue", bundle: .sharedUI).opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: childComponent.style.cornerRadius)
                                        .stroke(Color("Blue", bundle: .sharedUI), lineWidth: 2)
                                        .shadow(color: Color("Blue", bundle: .sharedUI).opacity(0.3), radius: 2)
                                )
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if childComponent.isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.6), in: Circle())
                                .padding(4)
                        }
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            document.selectedComponentID = childComponent.id
                        }
                    }
                    .transition(.scale(scale: 0.96, anchor: .center).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: childComponent.isVisible)
    }
    
    @ViewBuilder
    private func inlineContent(for component: InvoiceComponent) -> some View {
        switch component.type {
        case .companyLogo, .imagePlaceholder, .rectangleShape, .ellipseShape, .lineShape, .triangleShape, .starShape:
            ModernComponentView(component: component)
        default:
            let defaults = defaultContent(for: component)
            ModernStyledTextView(
                component: component,
                defaultText: defaults.text,
                label: defaults.label,
                subtitle: defaults.subtitle,
                expandHorizontally: false,
                expandVertically: false
            )
        }
    }
    
    private func defaultContent(for component: InvoiceComponent) -> (text: String, label: String?, subtitle: String?) {
        switch component.type {
        case .companyName:
            return (component.title ?? "ACME CORPORATION", nil, nil)
        case .companyABN:
            return (component.title ?? "12 345 678 901", "ABN", nil)
        case .companyEmail:
            return (component.title ?? "contact@company.com", "Email", nil)
        case .invoiceTitle:
            return (component.title ?? "Tax Invoice", nil, nil)
        case .paymentTerms:
            return (component.title ?? "Payment is due within 30 days of invoice date.", "Payment Terms", nil)
        case .paymentDetails:
            return (
                component.title ?? "Account Name\nBSB 123-456\nAccount 000 123 456",
                "Payment Details",
                nil
            )
        case .notes:
            return (component.title ?? "Additional notes or special instructions go here.", "Notes", nil)
        case .textBox:
            return (component.title ?? "Text", nil, nil)
        default:
            return (component.title ?? component.type.rawValue, nil, nil)
        }
    }
}


// MARK: - Component Views

// MARK: - Adaptive Layout Helpers

extension View {
    func adaptiveFontSize(for size: CGSize, baseSize: CGFloat = 12) -> CGFloat {
        let minDimension = min(size.width, size.height)
        let scaleFactor = minDimension / 100.0 // Base size for 100x100 component
        return max(baseSize * scaleFactor, 8) // Minimum 8pt font
    }
    
    func adaptivePadding(for size: CGSize, basePadding: CGFloat = 8) -> CGFloat {
        let minDimension = min(size.width, size.height)
        let scaleFactor = minDimension / 100.0
        return max(basePadding * scaleFactor, 4) // Minimum 4pt padding
    }
    
    func adaptiveSpacing(for size: CGSize, baseSpacing: CGFloat = 4) -> CGFloat {
        let minDimension = min(size.width, size.height)
        let scaleFactor = minDimension / 100.0
        return max(baseSpacing * scaleFactor, 2) // Minimum 2pt spacing
    }
    
    func adaptiveCornerRadius(for size: CGSize, baseRadius: CGFloat = 4) -> CGFloat {
        let minDimension = min(size.width, size.height)
        let scaleFactor = minDimension / 100.0
        return max(baseRadius * scaleFactor, 2) // Minimum 2pt radius
    }
}

struct ModernTextView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let adaptiveFontSize = adaptiveFontSize(for: geometry.size, baseSize: component.style.fontSize)
            let adaptiveCornerRadius = adaptiveCornerRadius(for: geometry.size, baseRadius: component.style.cornerRadius)
            
            // Generate sample text based on component size
            let sampleText = generateSampleText(for: geometry.size, fontSize: adaptiveFontSize)
            
            Text(sampleText)
                .font(.system(size: adaptiveFontSize))
                .foregroundColor(Color(hex: component.style.textColor))
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: adaptiveCornerRadius)
                        .fill(Color(hex: component.style.backgroundColor))
                )
        }
    }
    
    private func generateSampleText(for size: CGSize, fontSize: CGFloat) -> String {
        return "Sample text content"
    }
}

struct ModernRectangleView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let adaptiveCornerRadius = adaptiveCornerRadius(for: geometry.size, baseRadius: component.style.cornerRadius)
            let adaptiveBorderWidth = max(component.style.borderWidth * (min(geometry.size.width, geometry.size.height) / 100.0), 1)
            let fillColor = component.style.backgroundColorSwiftUI
            let strokeColor = component.style.borderColorSwiftUI
            
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let path = Path(CGPath(roundedRect: rect, cornerWidth: adaptiveCornerRadius, cornerHeight: adaptiveCornerRadius, transform: nil))
                
                // Fill the shape
                context.fill(path, with: .color(fillColor))
                
                // Stroke the shape
                context.stroke(path, with: .color(strokeColor), lineWidth: adaptiveBorderWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ModernEllipseView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let adaptiveBorderWidth = max(component.style.borderWidth * (min(geometry.size.width, geometry.size.height) / 100.0), 1)
            let fillColor = component.style.backgroundColorSwiftUI
            let strokeColor = component.style.borderColorSwiftUI
            
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let path = Path(CGPath(ellipseIn: rect, transform: nil))
                
                // Fill the shape
                context.fill(path, with: .color(fillColor))
                
                // Stroke the shape
                context.stroke(path, with: .color(strokeColor), lineWidth: adaptiveBorderWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ModernLineView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let adaptiveThickness = max(component.style.lineThickness * (min(geometry.size.width, geometry.size.height) / 100.0), 1)
            let strokeColor = component.style.borderColorSwiftUI
            
            Canvas { context, size in
                let isHorizontal = size.width >= size.height
                let start = isHorizontal ? CGPoint(x: 0, y: size.height / 2) : CGPoint(x: size.width / 2, y: 0)
                let end = isHorizontal ? CGPoint(x: size.width, y: size.height / 2) : CGPoint(x: size.width / 2, y: size.height)
                
                // Create the main line path
                let cgPath = CGMutablePath()
                cgPath.move(to: start)
                cgPath.addLine(to: end)
                let path = Path(cgPath)
                
                // Stroke the main line
                context.stroke(path, with: .color(strokeColor), lineWidth: adaptiveThickness)
                
                // Add decorators if specified
                if component.style.lineStartDecorator != .none {
                    addDecorator(to: context, at: start, from: end, type: component.style.lineStartDecorator, thickness: adaptiveThickness, color: strokeColor)
                }
                if component.style.lineEndDecorator != .none {
                    addDecorator(to: context, at: end, from: start, type: component.style.lineEndDecorator, thickness: adaptiveThickness, color: strokeColor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func addDecorator(to context: GraphicsContext, at point: CGPoint, from otherPoint: CGPoint, type: LineDecorator, thickness: CGFloat, color: Color) {
        let angle = atan2(point.y - otherPoint.y, point.x - otherPoint.x)
        let size = thickness * 4 // Decorator size relative to line thickness
        
        let cgDecoratorPath = CGMutablePath()
        
        switch type {
        case .arrow:
            let angle1 = angle - .pi / 6
            let angle2 = angle + .pi / 6
            let p1 = CGPoint(x: point.x - size * cos(angle1), y: point.y - size * sin(angle1))
            let p2 = CGPoint(x: point.x - size * cos(angle2), y: point.y - size * sin(angle2))
            cgDecoratorPath.move(to: p1)
            cgDecoratorPath.addLine(to: point)
            cgDecoratorPath.addLine(to: p2)
        case .circle:
            let radius = size / 2
            let rect = CGRect(x: point.x - radius, y: point.y - radius, width: size, height: size)
            cgDecoratorPath.addEllipse(in: rect)
        case .square:
            let halfSize = size / 2
            let rect = CGRect(x: point.x - halfSize, y: point.y - halfSize, width: size, height: size)
            cgDecoratorPath.addRect(rect)
        case .none:
            break
        }
        
        let decoratorPath = Path(cgDecoratorPath)
        context.stroke(decoratorPath, with: .color(color), lineWidth: thickness)
    }
}

struct ModernTriangleView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let adaptiveStrokeWidth = max(geometry.size.width * 0.05, 2)
            let fillColor = component.style.backgroundColorSwiftUI
            let strokeColor = component.style.borderColorSwiftUI
            
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let cgPath = CGMutablePath()
                
                // Create triangle path based on direction
                switch component.style.triangleDirection {
                case .up:
                    cgPath.move(to: CGPoint(x: rect.midX, y: rect.minY))
                    cgPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                    cgPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                case .down:
                    cgPath.move(to: CGPoint(x: rect.midX, y: rect.maxY))
                    cgPath.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                    cgPath.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                case .left:
                    cgPath.move(to: CGPoint(x: rect.minX, y: rect.midY))
                    cgPath.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                    cgPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                case .right:
                    cgPath.move(to: CGPoint(x: rect.maxX, y: rect.midY))
                    cgPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                    cgPath.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                }
                cgPath.closeSubpath()
                
                let path = Path(cgPath)
                
                // Fill the shape
                context.fill(path, with: .color(fillColor))
                
                // Stroke the shape
                context.stroke(path, with: .color(strokeColor), lineWidth: adaptiveStrokeWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ModernStarView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let adaptiveStrokeWidth = max(geometry.size.width * 0.05, 2)
            let fillColor = component.style.backgroundColorSwiftUI
            let strokeColor = component.style.borderColorSwiftUI
            
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
                let outerRadius = min(rect.width, rect.height) / 2
                let innerRadius = outerRadius * component.style.starSmoothness
                let points = component.style.starPoints
                
                guard points >= 2 else { return }
                
                let angleIncrement = .pi * 2 / CGFloat(points)
                let rotationOffset = -CGFloat.pi / 2 // Start at the top
                
                let cgPath = CGMutablePath()
                
                for i in 0..<points {
                    let angle = CGFloat(i) * angleIncrement * 2 + rotationOffset
                    let outerPoint = CGPoint(
                        x: center.x + cos(angle) * outerRadius,
                        y: center.y + sin(angle) * outerRadius
                    )
                    let innerAngle = angle + angleIncrement
                    let innerPoint = CGPoint(
                        x: center.x + cos(innerAngle) * innerRadius,
                        y: center.y + sin(innerAngle) * innerRadius
                    )
                    
                    if i == 0 {
                        cgPath.move(to: outerPoint)
                    } else {
                        cgPath.addLine(to: outerPoint)
                    }
                    cgPath.addLine(to: innerPoint)
                }
                cgPath.closeSubpath()
                
                let path = Path(cgPath)
                
                // Fill the shape
                context.fill(path, with: .color(fillColor))
                
                // Stroke the shape
                context.stroke(path, with: .color(strokeColor), lineWidth: adaptiveStrokeWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ModernImagePlaceholderView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let cornerRadius = adaptiveCornerRadius(for: geometry.size, baseRadius: component.style.cornerRadius)
            let strokeWidth = max(component.style.borderWidth, 1)
            let crossColor = component.style.borderColorSwiftUI.opacity(0.8)
            
            ZStack {
                Path { path in
                    let rect = CGRect(origin: .zero, size: geometry.size)
                    path.move(to: CGPoint(x: rect.minX + strokeWidth, y: rect.minY + strokeWidth))
                    path.addLine(to: CGPoint(x: rect.maxX - strokeWidth, y: rect.maxY - strokeWidth))
                    path.move(to: CGPoint(x: rect.maxX - strokeWidth, y: rect.minY + strokeWidth))
                    path.addLine(to: CGPoint(x: rect.minX + strokeWidth, y: rect.maxY - strokeWidth))
                }
                .stroke(crossColor, style: StrokeStyle(lineWidth: max(strokeWidth * 0.75, 1), lineCap: .round))
                
                if !component.style.placeholderText.isEmpty {
                    Text(component.style.placeholderText)
                        .font(component.style.fontFamily(adaptiveFontSize(for: geometry.size, baseSize: component.style.fontSize > 0 ? component.style.fontSize : 12), component.style.fontWeightValue))
                        .foregroundColor(component.style.textColorSwiftUI.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .applyComponentVisualStyle(
                style: component.style,
                alignment: .center
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

struct ModernInvoiceNumberView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let baseFontSize = adaptiveFontSize(for: geometry.size, baseSize: component.style.fontSize > 0 ? component.style.fontSize : 12)
            let headingFontSize = max(8, baseFontSize * 1.1)
            let secondaryFontSize = max(8, baseFontSize * 0.85)
            let spacing = component.style.contentSpacing > 0 ? component.style.contentSpacing : adaptiveSpacing(for: geometry.size, baseSpacing: 6)
            let alignment = component.style.textAlignment
            let primaryColor = component.style.textColorSwiftUI
            let mutedColor = primaryColor.opacity(0.75)
            
            VStack(alignment: alignment.horizontalAlignment, spacing: spacing) {
                HStack {
                    Text("Invoice #")
                        .font(component.style.fontFamily(secondaryFontSize, .medium))
                        .foregroundColor(mutedColor)
                    Spacer()
                    Text("INV-2024-001")
                        .font(component.style.fontFamily(headingFontSize, .semibold))
                        .foregroundColor(primaryColor)
                }
                
                Divider()
                    .background(component.style.borderColorSwiftUI.opacity(0.2))
                
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: spacing * 0.4) {
                        Text("Issued")
                            .font(component.style.fontFamily(secondaryFontSize, .medium))
                            .foregroundColor(mutedColor)
                        Text("15 Jan 2024")
                            .font(component.style.fontFamily(baseFontSize, component.style.fontWeightValue))
                            .foregroundColor(primaryColor)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: spacing * 0.4) {
                        Text("Due")
                            .font(component.style.fontFamily(secondaryFontSize, .medium))
                            .foregroundColor(mutedColor)
                        Text("15 Feb 2024")
                            .font(component.style.fontFamily(baseFontSize, component.style.fontWeightValue))
                            .foregroundColor(primaryColor)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
            .applyComponentVisualStyle(
                style: component.style,
                alignment: alignment.frameAlignment
            )
        }
    }
}

struct ModernBillToView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let baseFontSize = adaptiveFontSize(for: geometry.size, baseSize: component.style.fontSize > 0 ? component.style.fontSize : 12)
            let headingFontSize = baseFontSize * 1.05
            let secondaryFontSize = max(8, baseFontSize * 0.85)
            let spacing = component.style.contentSpacing > 0 ? component.style.contentSpacing : adaptiveSpacing(for: geometry.size, baseSpacing: 8)
            let alignment = component.style.textAlignment
            let primaryColor = component.style.textColorSwiftUI
            let secondaryColor = primaryColor.opacity(0.7)
            
            VStack(alignment: alignment.horizontalAlignment, spacing: spacing) {
                Text("Bill To:")
                    .font(component.style.fontFamily(headingFontSize, .semibold))
                    .foregroundColor(primaryColor)
                    .multilineTextAlignment(alignment.swiftUIAlignment)
                
                VStack(alignment: .leading, spacing: spacing * 0.4) {
                    Text("Acme Corporation")
                        .font(component.style.fontFamily(baseFontSize, .medium))
                        .foregroundColor(primaryColor)
                    
                    Text("123 Business Street")
                        .font(component.style.fontFamily(secondaryFontSize, .regular))
                    Text("Suite 456")
                        .font(component.style.fontFamily(secondaryFontSize, .regular))
                    Text("New York, NY 10001")
                        .font(component.style.fontFamily(secondaryFontSize, .regular))
                }
                .foregroundColor(secondaryColor)
            }
            .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
            .applyComponentVisualStyle(
                style: component.style,
                alignment: alignment.frameAlignment
            )
        }
    }
}

struct ModernServicesTableView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let baseFontSize = adaptiveFontSize(for: geometry.size, baseSize: component.style.fontSize > 0 ? component.style.fontSize : 11)
            let headerColor = component.style.tableHeaderColorSwiftUI
            let rowColor = component.style.tableRowColorSwiftUI
            let alternateRowColor = component.style.tableRowAltColorSwiftUI
            let textColor = component.style.tableTextColorSwiftUI
            let cellPadding = adaptivePadding(for: geometry.size, basePadding: max(6, component.style.contentPadding * 0.75))
            let estimatedRowHeight = max(28, baseFontSize * 2.6)
            let availableHeight = max(geometry.size.height - (component.style.showTableHeader ? estimatedRowHeight : 0), estimatedRowHeight * 2)
            let maxRows = max(3, min(6, Int(availableHeight / estimatedRowHeight)))
            
            VStack(spacing: 0) {
                if component.style.showTableHeader {
                    HStack(spacing: 0) {
                        Text("Description")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Qty")
                            .frame(width: 60, alignment: .center)
                        Text("Rate")
                            .frame(width: 70, alignment: .trailing)
                        Text("Amount")
                            .frame(width: 90, alignment: .trailing)
                    }
                    .font(component.style.fontFamily(baseFontSize, .semibold))
                    .foregroundColor(textColor)
                    .padding(.horizontal, cellPadding)
                    .padding(.vertical, cellPadding * 0.8)
                    .background(headerColor)
                }
                
                ForEach(0..<maxRows, id: \.self) { index in
                    let isAlternate = component.style.useAlternatingRows && index % 2 == 1
                    
                    HStack {
                        Text(sampleDescription(for: index))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(sampleQuantity(for: index))
                            .frame(width: 60, alignment: .center)
                        Text(sampleRate(for: index))
                            .frame(width: 70, alignment: .trailing)
                        Text(sampleAmount(for: index))
                            .frame(width: 90, alignment: .trailing)
                    }
                    .font(component.style.fontFamily(baseFontSize * 0.95, .regular))
                    .foregroundColor(textColor)
                    .padding(.horizontal, cellPadding)
                    .padding(.vertical, cellPadding * 0.65)
                    .background(isAlternate ? alternateRowColor : rowColor)
                    
                    if index < maxRows - 1 {
                        Rectangle()
                            .fill(component.style.borderColorSwiftUI.opacity(0.15))
                            .frame(height: 1)
                    }
                }
            }
            .padding(component.style.contentPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .applyComponentVisualStyle(
                style: component.style,
                alignment: .topLeading
            )
            .clipShape(RoundedRectangle(cornerRadius: component.style.cornerRadius))
        }
    }
    
    private func sampleDescription(for index: Int) -> String {
        let samples = [
            "Initial Consultation",
            "Therapy Session",
            "Plan Review Meeting",
            "Progress Report",
            "Travel Time"
        ]
        return samples[index % samples.count]
    }
    
    private func sampleQuantity(for index: Int) -> String {
        let quantities = ["1.0 hr", "0.5 hr", "2.0 hr", "1.5 hr", "45 min"]
        return quantities[index % quantities.count]
    }
    
    private func sampleRate(for index: Int) -> String {
        let rates = ["$145.00", "$110.00", "$98.00", "$150.00", "$85.00"]
        return rates[index % rates.count]
    }
    
    private func sampleAmount(for index: Int) -> String {
        let amounts = ["$145.00", "$55.00", "$196.00", "$225.00", "$63.75"]
        return amounts[index % amounts.count]
    }
}

struct ModernTotalsView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let baseFontSize = adaptiveFontSize(for: geometry.size, baseSize: component.style.fontSize > 0 ? component.style.fontSize : 12)
            let spacing = component.style.contentSpacing > 0 ? component.style.contentSpacing : adaptiveSpacing(for: geometry.size, baseSpacing: 6)
            let alignment = component.style.textAlignment
            let primaryColor = component.style.textColorSwiftUI
            let mutedColor = primaryColor.opacity(0.75)
            let emphasizeColor = primaryColor
            
            VStack(alignment: alignment.horizontalAlignment, spacing: spacing) {
                HStack {
                    Text("Subtotal:")
                        .font(component.style.fontFamily(baseFontSize * 0.9, .regular))
                        .foregroundColor(mutedColor)
                    Spacer()
                    Text("$325.00")
                        .font(component.style.fontFamily(baseFontSize * 0.9, .regular))
                        .foregroundColor(primaryColor)
                }
                
                HStack {
                    Text("Tax (8.5%):")
                        .font(component.style.fontFamily(baseFontSize * 0.9, .regular))
                        .foregroundColor(mutedColor)
                    Spacer()
                    Text("$26.26")
                        .font(component.style.fontFamily(baseFontSize * 0.9, .regular))
                        .foregroundColor(primaryColor)
                }
                
                Rectangle()
                    .fill(component.style.borderColorSwiftUI.opacity(0.25))
                    .frame(height: 1)
                
                HStack {
                    Text("Total:")
                        .font(component.style.fontFamily(baseFontSize * 1.1, .semibold))
                        .foregroundColor(emphasizeColor)
                    Spacer()
                    Text("$350.01")
                        .font(component.style.fontFamily(baseFontSize * 1.1, .semibold))
                        .foregroundColor(emphasizeColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
            .applyComponentVisualStyle(
                style: component.style,
                alignment: alignment.frameAlignment
            )
        }
    }
}

struct ModernLogoView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let iconSize = min(geometry.size.width, geometry.size.height) * 0.3
            let textSize = adaptiveFontSize(for: geometry.size, baseSize: component.style.fontSize > 0 ? component.style.fontSize : 12)
            let textColor = component.style.textColorSwiftUI
            
            VStack(spacing: 4) {
                Image(systemName: "photo")
                    .font(.system(size: iconSize))
                    .foregroundColor(textColor.opacity(0.6))
                
                Text(component.style.placeholderText.isEmpty ? "Company Logo" : component.style.placeholderText)
                    .font(component.style.fontFamily(textSize, component.style.fontWeightValue))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .applyComponentVisualStyle(
                style: component.style,
                alignment: .center
            )
        }
    }
}

struct ModernGenericView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let iconSize = min(geometry.size.width, geometry.size.height) * 0.25
            let textSize = adaptiveFontSize(for: geometry.size, baseSize: max(10, component.style.fontSize))
            let alignment = component.style.textAlignment
            
            VStack(spacing: 6) {
                Image(systemName: component.type.iconName)
                    .font(.system(size: iconSize))
                    .foregroundColor(component.style.textColorSwiftUI.opacity(0.7))
                
                Text(component.type.rawValue)
                    .font(component.style.fontFamily(textSize, component.style.fontWeightValue))
                    .foregroundColor(component.style.textColorSwiftUI)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment.frameAlignment)
            .applyComponentVisualStyle(
                style: component.style,
                alignment: alignment.frameAlignment
            )
        }
    }
}


struct ModernParticipantView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let baseFontSize = adaptiveFontSize(for: geometry.size, baseSize: component.style.fontSize > 0 ? component.style.fontSize : 12)
            let headingFontSize = baseFontSize * 1.05
            let secondaryFontSize = max(8, baseFontSize * 0.9)
            let spacing = component.style.contentSpacing > 0 ? component.style.contentSpacing : adaptiveSpacing(for: geometry.size, baseSpacing: 6)
            let alignment = component.style.textAlignment
            let primaryColor = component.style.textColorSwiftUI
            let secondaryColor = primaryColor.opacity(0.7)
            
            VStack(alignment: alignment.horizontalAlignment, spacing: spacing) {
                Text("Participant Information")
                    .font(component.style.fontFamily(headingFontSize, .semibold))
                    .foregroundColor(primaryColor)
                    .multilineTextAlignment(alignment.swiftUIAlignment)
                
                VStack(alignment: .leading, spacing: spacing * 0.5) {
                    Text("Name: Alex Johnson")
                        .font(component.style.fontFamily(secondaryFontSize, .medium))
                        .foregroundColor(primaryColor)
                    Text("NDIS #: 4300123456")
                        .font(component.style.fontFamily(secondaryFontSize, .regular))
                        .foregroundColor(secondaryColor)
                    Text("Support Coordinator: Jane Doe")
                        .font(component.style.fontFamily(secondaryFontSize, .regular))
                        .foregroundColor(secondaryColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
            .applyComponentVisualStyle(
                style: component.style,
                alignment: alignment.frameAlignment
            )
        }
    }
}

struct ModernPaymentDetailsView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let baseFontSize = adaptiveFontSize(for: geometry.size, baseSize: component.style.fontSize > 0 ? component.style.fontSize : 12)
            let headingFontSize = baseFontSize * 1.05
            let secondaryFontSize = max(8, baseFontSize * 0.9)
            let spacing = component.style.contentSpacing > 0 ? component.style.contentSpacing : adaptiveSpacing(for: geometry.size, baseSpacing: 6)
            let alignment = component.style.textAlignment
            let primaryColor = component.style.textColorSwiftUI
            let secondaryColor = primaryColor.opacity(0.7)
            
            VStack(alignment: alignment.horizontalAlignment, spacing: spacing) {
                Text("Payment Details")
                    .font(component.style.fontFamily(headingFontSize, .semibold))
                    .foregroundColor(primaryColor)
                    .multilineTextAlignment(alignment.swiftUIAlignment)
                
                VStack(alignment: .leading, spacing: spacing * 0.5) {
                    Text("Method: [Payment Method]")
                        .font(component.style.fontFamily(secondaryFontSize, .medium))
                        .foregroundColor(primaryColor)
                    
                    Text("Account: [Account Details]")
                        .font(component.style.fontFamily(secondaryFontSize, .regular))
                        .foregroundColor(secondaryColor)
                    
                    Text("Reference: [Payment Ref]")
                        .font(component.style.fontFamily(secondaryFontSize, .regular))
                        .foregroundColor(secondaryColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
            .applyComponentVisualStyle(
                style: component.style,
                alignment: alignment.frameAlignment
            )
        }
    }
}

struct ModernPaymentTermsView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let baseFontSize = adaptiveFontSize(for: geometry.size, baseSize: component.style.fontSize > 0 ? component.style.fontSize : 12)
            let headingFontSize = baseFontSize * 1.05
            let bodyFontSize = max(8, baseFontSize * 0.95)
            let spacing = component.style.contentSpacing > 0 ? component.style.contentSpacing : adaptiveSpacing(for: geometry.size, baseSpacing: 6)
            let alignment = component.style.textAlignment
            let primaryColor = component.style.textColorSwiftUI
            let secondaryColor = primaryColor.opacity(0.75)
            let termsText = component.style.placeholderText.isEmpty
                ? "Payment is due within 30 days of invoice date. Late payments may incur additional charges."
                : component.style.placeholderText
            
            VStack(alignment: alignment.horizontalAlignment, spacing: spacing) {
                Text("Payment Terms")
                    .font(component.style.fontFamily(headingFontSize, .semibold))
                    .foregroundColor(primaryColor)
                    .multilineTextAlignment(alignment.swiftUIAlignment)
                
                Text(termsText)
                    .font(component.style.fontFamily(bodyFontSize, .regular))
                    .foregroundColor(secondaryColor)
                    .multilineTextAlignment(alignment.swiftUIAlignment)
            }
            .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
            .applyComponentVisualStyle(
                style: component.style,
                alignment: alignment.frameAlignment
            )
        }
    }
}

struct ModernInvoiceTitleView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let baseFontSize = adaptiveFontSize(for: geometry.size, baseSize: component.style.fontSize > 0 ? component.style.fontSize : 16)
            let alignment = component.style.textAlignment
            let displayText = component.style.placeholderText.isEmpty ? "TAX INVOICE" : component.style.placeholderText
            
            Text(displayText.uppercased())
                .font(component.style.fontFamily(baseFontSize, .bold))
                .foregroundColor(component.style.textColorSwiftUI)
                .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
                .applyComponentVisualStyle(
                    style: component.style,
                    alignment: alignment.frameAlignment
                )
        }
    }
}

struct ModernCompanyNameView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let baseFontSize = adaptiveFontSize(for: geometry.size, baseSize: component.style.fontSize > 0 ? component.style.fontSize : 14)
            let alignment = component.style.textAlignment
            let displayText = component.style.placeholderText.isEmpty ? "Your Company Name" : component.style.placeholderText
            
            Text(displayText)
                .font(component.style.fontFamily(baseFontSize, .semibold))
                .foregroundColor(component.style.textColorSwiftUI)
                .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
                .applyComponentVisualStyle(
                    style: component.style,
                    alignment: alignment.frameAlignment
                )
        }
    }
}

struct ModernCompanyABNView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let baseFontSize = adaptiveFontSize(for: geometry.size, baseSize: component.style.fontSize > 0 ? component.style.fontSize : 12)
            let alignment = component.style.textAlignment
            let displayText = component.style.placeholderText.isEmpty ? "ABN: 12 345 678 901" : component.style.placeholderText
            
            Text(displayText)
                .font(component.style.fontFamily(baseFontSize, .medium))
                .foregroundColor(component.style.textColorSwiftUI)
                .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
                .applyComponentVisualStyle(
                    style: component.style,
                    alignment: alignment.frameAlignment
                )
        }
    }
}

struct ModernCompanyEmailView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let baseFontSize = adaptiveFontSize(for: geometry.size, baseSize: component.style.fontSize > 0 ? component.style.fontSize : 12)
            let alignment = component.style.textAlignment
            let displayText = component.style.placeholderText.isEmpty ? "contact@yourcompany.com" : component.style.placeholderText
            
            Text(displayText)
                .font(component.style.fontFamily(baseFontSize, .medium))
                .foregroundColor(component.style.textColorSwiftUI)
                .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
                .applyComponentVisualStyle(
                    style: component.style,
                    alignment: alignment.frameAlignment
                )
        }
    }
}

struct ModernNotesView: View {
    let component: InvoiceComponent
    
    var body: some View {
        GeometryReader { geometry in
            let baseFontSize = adaptiveFontSize(for: geometry.size, baseSize: component.style.fontSize > 0 ? component.style.fontSize : 12)
            let headingFontSize = baseFontSize * 1.05
            let bodyFontSize = max(8, baseFontSize * 0.95)
            let spacing = component.style.contentSpacing > 0 ? component.style.contentSpacing : adaptiveSpacing(for: geometry.size, baseSpacing: 6)
            let alignment = component.style.textAlignment
            let primaryColor = component.style.textColorSwiftUI
            let secondaryColor = primaryColor.opacity(0.7)
            let bodyText = component.style.placeholderText.isEmpty
                ? "Additional notes or special instructions can be added here."
                : component.style.placeholderText
            
            VStack(alignment: alignment.horizontalAlignment, spacing: spacing) {
                Text("Notes")
                    .font(component.style.fontFamily(headingFontSize, .semibold))
                    .foregroundColor(primaryColor)
                    .multilineTextAlignment(alignment.swiftUIAlignment)
                
                Text(bodyText)
                    .font(component.style.fontFamily(bodyFontSize, .regular))
                    .foregroundColor(secondaryColor)
                    .multilineTextAlignment(alignment.swiftUIAlignment)
            }
            .frame(maxWidth: .infinity, alignment: alignment.frameAlignment)
            .applyComponentVisualStyle(
                style: component.style,
                alignment: alignment.frameAlignment
            )
        }
    }
}


// MARK: - Resize Handles

struct ResizeHandlesView: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument
    
    var body: some View {
        ForEach(ModernResizeHandle.Position.allCases, id: \.self) { position in
            ModernResizeHandle(position: position, component: component)
        }
    }
}

struct ModernResizeHandle: View {
    enum Position: CaseIterable, Hashable {
        case topLeading, top, topTrailing
        case leading, trailing
        case bottomLeading, bottom, bottomTrailing
    }
    
    let position: Position
    let component: InvoiceComponent
    @EnvironmentObject private var editorViewModel: InvoiceTemplateEditorViewModel
    @EnvironmentObject private var document: InvoiceDocument
    @State private var isDragging = false
    @State private var initialSize: CGSize = .zero
    @State private var initialPosition: CGPoint = .zero
    
    private var handleSize: CGFloat { 12 }
    
    private var handlePosition: CGPoint {
        let size = component.size
        let center = component.position
        
        // Calculate exact edge positions for maximum accuracy
        let leftEdge = center.x - size.width / 2
        let rightEdge = center.x + size.width / 2
        let topEdge = center.y - size.height / 2
        let bottomEdge = center.y + size.height / 2
        
        switch position {
        case .topLeading: 
            return CGPoint(x: leftEdge, y: topEdge)
        case .top: 
            return CGPoint(x: center.x, y: topEdge)
        case .topTrailing: 
            return CGPoint(x: rightEdge, y: topEdge)
        case .leading: 
            return CGPoint(x: leftEdge, y: center.y)
        case .trailing: 
            return CGPoint(x: rightEdge, y: center.y)
        case .bottomLeading: 
            return CGPoint(x: leftEdge, y: bottomEdge)
        case .bottom: 
            return CGPoint(x: center.x, y: bottomEdge)
        case .bottomTrailing: 
            return CGPoint(x: rightEdge, y: bottomEdge)
        }
    }
    
    var body: some View {
        Circle()
            .fill(Color.accentColor)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .frame(width: handleSize, height: handleSize)
            .position(handlePosition)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1) // Add shadow for better visibility
            .allowsHitTesting(true) // Ensure handle can receive touch events
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            initialSize = component.size
                            initialPosition = component.position
                        }
                        
                        let newSize: CGSize
                        switch position {
                        case .topLeading:
                            newSize = CGSize(
                                width: max(20, initialSize.width - value.translation.width),
                                height: max(20, initialSize.height - value.translation.height)
                            )
                        case .top:
                            newSize = CGSize(
                                width: initialSize.width,
                                height: max(20, initialSize.height - value.translation.height)
                            )
                        case .topTrailing:
                            newSize = CGSize(
                                width: max(20, initialSize.width + value.translation.width),
                                height: max(20, initialSize.height - value.translation.height)
                            )
                        case .leading:
                            newSize = CGSize(
                                width: max(20, initialSize.width - value.translation.width),
                                height: initialSize.height
                            )
                        case .trailing:
                            newSize = CGSize(
                                width: max(20, initialSize.width + value.translation.width),
                                height: initialSize.height
                            )
                        case .bottomLeading:
                            newSize = CGSize(
                                width: max(20, initialSize.width - value.translation.width),
                                height: max(20, initialSize.height + value.translation.height)
                            )
                        case .bottom:
                            newSize = CGSize(
                                width: initialSize.width,
                                height: max(20, initialSize.height + value.translation.height)
                            )
                        case .bottomTrailing:
                            newSize = CGSize(
                                width: max(20, initialSize.width + value.translation.width),
                                height: max(20, initialSize.height + value.translation.height)
                            )
                        }
                        
                        // Calculate new position based on handle-specific algorithms
                        let newPosition: CGPoint
                        switch position {
                        case .topLeading:
                            // Resize from top-left: keep bottom-right fixed, move center left and up
                            newPosition = CGPoint(
                                x: initialPosition.x - (newSize.width - initialSize.width) / 2,
                                y: initialPosition.y - (newSize.height - initialSize.height) / 2
                            )
                        case .top:
                            // Resize from top: keep bottom edge fixed, move center up only
                            newPosition = CGPoint(
                                x: initialPosition.x,
                                y: initialPosition.y - (newSize.height - initialSize.height) / 2
                            )
                        case .topTrailing:
                            // Resize from top-right: keep bottom-left fixed, move center right and up
                            newPosition = CGPoint(
                                x: initialPosition.x + (newSize.width - initialSize.width) / 2,
                                y: initialPosition.y - (newSize.height - initialSize.height) / 2
                            )
                        case .leading:
                            // Resize from left: keep right edge fixed, move center left only
                            newPosition = CGPoint(
                                x: initialPosition.x - (newSize.width - initialSize.width) / 2,
                                y: initialPosition.y
                            )
                        case .trailing:
                            // Resize from right: keep left edge fixed, move center right only
                            newPosition = CGPoint(
                                x: initialPosition.x + (newSize.width - initialSize.width) / 2,
                                y: initialPosition.y
                            )
                        case .bottomLeading:
                            // Resize from bottom-left: keep top-right fixed, move center left and down
                            newPosition = CGPoint(
                                x: initialPosition.x - (newSize.width - initialSize.width) / 2,
                                y: initialPosition.y + (newSize.height - initialSize.height) / 2
                            )
                        case .bottom:
                            // Resize from bottom: keep top edge fixed, move center down only
                            newPosition = CGPoint(
                                x: initialPosition.x,
                                y: initialPosition.y + (newSize.height - initialSize.height) / 2
                            )
                        case .bottomTrailing:
                            // Resize from bottom-right: keep top-left fixed, move center right and down
                            newPosition = CGPoint(
                                x: initialPosition.x + (newSize.width - initialSize.width) / 2,
                                y: initialPosition.y + (newSize.height - initialSize.height) / 2
                            )
                        }
                        
                        let snapped = editorViewModel.snappedSizeAndPosition(
                            for: component,
                            proposedSize: newSize,
                            proposedPosition: newPosition
                        )
                        
                        document.updateComponent(id: component.id) { comp in
                            comp.size = snapped.size
                            comp.position = snapped.position
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }
}

// MARK: - Modern Inspector View

struct ModernInspectorView: View {
    @EnvironmentObject private var document: InvoiceDocument
    @EnvironmentObject private var editorViewModel: InvoiceTemplateEditorViewModel
    
    var body: some View {
        inspectorContent
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(ModernTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(ModernTheme.outline)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(12)
            .animation(.easeInOut(duration: 0.25), value: document.selectedComponentID != nil)
            .foregroundColor(ModernTheme.textPrimary)
    }
    
    @ViewBuilder
    private var inspectorContent: some View {
        if let selectedComponent = document.component(document.selectedComponentID) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    InspectorHeader(component: selectedComponent)

                    ModernPropertySection(title: "Layout") {
                        ModernPropertyField(
                            title: "X Position",
                            value: String(format: "%.0f", selectedComponent.position.x)
                        )
                        
                        ModernPropertyField(
                            title: "Y Position",
                            value: String(format: "%.0f", selectedComponent.position.y)
                        )
                        
                        ModernPropertyField(
                            title: "Width",
                            value: String(format: "%.0f", selectedComponent.size.width)
                        )
                        
                        ModernPropertyField(
                            title: "Height",
                            value: String(format: "%.0f", selectedComponent.size.height)
                        )
                    }
                    
                    ModernComponentStyleEditor(component: selectedComponent)

                    ModernPropertySection(title: "Actions") {
                        Button(role: .destructive) {
                            document.removeComponent(with: selectedComponent.id)
                        } label: {
                            Text("Delete Component")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .simultaneousGesture(
                // Ensure scrolling gestures have priority over canvas gestures
                DragGesture()
                    .onChanged { _ in }
                    .onEnded { _ in }
            )
            .transition(.move(edge: .trailing).combined(with: .opacity))
        } else {
            ModernLayerManagerView()
                .transition(.move(edge: .leading).combined(with: .opacity))
        }
    }
}

private struct InspectorHeader: View {
    let component: InvoiceComponent

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: component.type.iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(component.type.rawValue)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("ID: \(component.id.uuidString.prefix(8))")
                    .font(.caption)
                    .foregroundColor(ModernTheme.textSecondary)
            }

            Spacer()

            if component.type.supportsTypography {
                TagView(text: "Text")
            }

            if component.type.isSection {
                TagView(text: "Section")
            }

            if component.type.isImageComponent {
                TagView(text: "Image")
            }
        }
    }
}

private struct ModernLayerManagerView: View {
    @EnvironmentObject private var document: InvoiceDocument
    @EnvironmentObject private var editorViewModel: InvoiceTemplateEditorViewModel

    private var orderedComponents: [InvoiceComponent] {
        Array(document.components.reversed())
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                layerManagerHeader

                if orderedComponents.isEmpty {
                    EmptyLayersView()
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .contentShape(Rectangle())
                        .clipped()
                } else {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(orderedComponents, id: \.id) { component in
                            ModernLayerRow(component: component, depth: 0)
                        }
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .contentShape(Rectangle())
                    .clipped()
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(.easeInOut(duration: 0.25), value: document.components.map(\.id))
        .animation(.easeInOut(duration: 0.2), value: orderedComponents.isEmpty)
        .foregroundColor(ModernTheme.textPrimary)
    }

    private var layerManagerHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Layers")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Toggle visibility, lock components, and adjust stacking order.")
                .font(.footnote)
                .foregroundColor(ModernTheme.textSecondary)
        }
    }

    private struct EmptyLayersView: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("No components yet")
                    .font(.headline)
                Text("Add elements from the component palette to build your template.")
                    .font(.subheadline)
                    .foregroundColor(ModernTheme.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ModernTheme.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(ModernTheme.outline, lineWidth: 0.6)
                    )
            )
        }
    }
}

private struct ModernLayerRow: View {
    let component: InvoiceComponent
    let depth: Int

    @EnvironmentObject private var document: InvoiceDocument
    @EnvironmentObject private var editorViewModel: InvoiceTemplateEditorViewModel

    private var currentComponent: InvoiceComponent? {
        if let resolved = document.component(component.id) {
            return resolved
        }
        return document.components.first(where: { $0.id == component.id })
    }

    private var indentation: CGFloat {
        CGFloat(depth) * 18
    }

    var body: some View {
        if let resolved = currentComponent {
            VStack(alignment: .leading, spacing: 6) {
                row(for: resolved)
                    .padding(.leading, indentation)

                if resolved.isExpanded && !resolved.children.isEmpty {
                    let childComponents = Array(resolved.children.reversed())
                    ForEach(childComponents, id: \.id) { child in
                        ModernLayerRow(component: child, depth: depth + 1)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: resolved.isExpanded)
            .contentShape(Rectangle())
            .clipped()
        }
    }

    private func row(for component: InvoiceComponent) -> some View {
        let isSelected = document.selectedComponentID == component.id
        let canMoveUp = editorViewModel.canMoveLayerUp(component)
        let canMoveDown = editorViewModel.canMoveLayerDown(component)
        let label = (component.title?.isEmpty == false ? component.title : component.type.rawValue) ?? component.type.rawValue

        return HStack(spacing: 8) {
            expandButton(for: component)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    editorViewModel.toggleVisibility(for: component)
                }
            } label: {
                Image(systemName: component.isVisible ? "eye" : "eye.slash")
                    .foregroundColor(component.isVisible ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .help(component.isVisible ? "Hide layer" : "Show layer")

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    editorViewModel.toggleLock(for: component)
                }
            } label: {
                Image(systemName: component.isLocked ? "lock.fill" : "lock.open")
                    .foregroundColor(component.isLocked ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(component.isLocked ? "Unlock layer" : "Lock layer")

            Image(systemName: component.type.iconName)
                .foregroundColor(component.type.iconColor)
                .frame(width: 18)

            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(component.isVisible ? .primary : .secondary)
                .lineLimit(1)

            Spacer(minLength: 6)

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    editorViewModel.moveLayerDown(component)
                }
            } label: {
                Image(systemName: "arrow.down")
            }
            .buttonStyle(.plain)
            .disabled(!canMoveDown)
            .help("Move layer backward")

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    editorViewModel.moveLayerUp(component)
                }
            } label: {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.plain)
            .disabled(!canMoveUp)
            .help("Move layer forward")
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? ModernTheme.surfaceActive.opacity(0.9) : Color.clear)
        )
        .overlay(alignment: .topLeading) {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.55), lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                editorViewModel.selectComponent(id: component.id)
            }
        }
        .opacity(component.isVisible ? 1.0 : 0.6)
    }

    @ViewBuilder
    private func expandButton(for component: InvoiceComponent) -> some View {
        if component.children.isEmpty {
            Image(systemName: "chevron.right")
                .foregroundColor(.clear)
                .frame(width: 16)
        } else {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    editorViewModel.toggleExpansion(for: component)
                }
            } label: {
                Image(systemName: component.isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundColor(ModernTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .frame(width: 16)
            .help(component.isExpanded ? "Collapse" : "Expand")
        }
    }
}

private struct TagView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(Color.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
            )
    }
}

private struct ToolbarButton: View {
    let image: String
    let action: () -> Void
    var isDisabled: Bool = false
    var help: String? = nil

    @ViewBuilder
    var body: some View {
        let button = Button(action: action) {
            Image(systemName: image)
                .foregroundColor(ModernTheme.textPrimary)
        }
        //.buttonStyle(.borderless)
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
                .foregroundStyle(isOn ? Color.accentColor : ModernTheme.textSecondary)
        }
        //.buttonStyle(.borderless)
        .help(help)
    }
}

// MARK: - Modern Component Style Editor

struct ModernComponentStyleEditor: View {
    @EnvironmentObject private var document: InvoiceDocument
    let component: InvoiceComponent
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            if component.type.supportsTypography {
                ModernPropertySection(title: "Typography") {
                    SliderPropertyEditor(
                        title: "Font Size",
                        value: component.style.fontSize,
                        range: 8...48,
                        step: 1
                    ) { newValue in
                        document.updateFontSize(for: component.id, fontSize: newValue)
                    }
                    
                    PickerPropertyEditor(title: "Font Weight", selection: FontWeightOption(styleValue: component.style.fontWeight)) { newValue in
                        document.updateFontWeight(for: component.id, weight: newValue.styleValue)
                    }
                    
                    PickerPropertyEditor(title: "Font Style", selection: FontFamilyOption(styleValue: component.style.fontFamily)) { newValue in
                        document.updateFontFamily(for: component.id, family: newValue.styleValue)
                    }
                    
                    PickerPropertyEditor(title: "Alignment", selection: component.style.textAlignment) { newValue in
                        document.updateTextAlignment(for: component.id, alignment: newValue)
                    }
                    
                    SliderPropertyEditor(
                        title: "Line Spacing",
                        value: component.style.lineSpacing,
                        range: 0.8...2.5,
                        step: 0.05,
                        formatter: "%.2f"
                    ) { newValue in
                        document.updateLineSpacing(for: component.id, spacing: newValue)
                    }
                    
                    SliderPropertyEditor(
                        title: "Letter Spacing",
                        value: component.style.letterSpacing,
                        range: -2...10,
                        step: 0.1,
                        formatter: "%.1f"
                    ) { newValue in
                        document.updateLetterSpacing(for: component.id, spacing: newValue)
                    }
                    
                    ColorPropertyEditor(
                        title: "Text Color",
                        color: component.style.textColorSwiftUI,
                        hexColor: component.style.textColor
                    ) { newHex in
                        document.updateTextColor(for: component.id, color: sanitizedHex(newHex))
                    }
                }
            }
            
            if component.type.supportsPlaceholderText {
                ModernPropertySection(title: "Content") {
                    TextFieldPropertyEditor(
                        title: "Placeholder Text",
                        text: component.style.placeholderText,
                        placeholder: "Enter placeholder..."
                    ) { newValue in
                        document.updatePlaceholderText(for: component.id, text: newValue)
                    }
                }
            }
            
            if component.type.isSection {
                ModernPropertySection(title: "Section Layout") {
                    PickerPropertyEditor(title: "Layout", selection: component.style.sectionLayout) { layout in
                        document.updateSectionLayout(for: component.id, layout: layout)
                    }
                    
                    if component.style.sectionLayout == .grid {
                        SliderPropertyEditor(
                            title: "Grid Columns",
                            value: CGFloat(component.style.gridColumns),
                            range: 1...4,
                            step: 1,
                            formatter: "%.0f"
                        ) { newValue in
                            document.updateGridColumns(for: component.id, columns: Int(newValue))
                        }
                    }
                    
                    SliderPropertyEditor(
                        title: "Content Spacing",
                        value: component.style.contentSpacing,
                        range: 0...40,
                        step: 1
                    ) { newValue in
                        document.updateContentSpacing(for: component.id, spacing: newValue)
                    }
                    
                    SliderPropertyEditor(
                        title: "Content Padding",
                        value: component.style.contentPadding,
                        range: 0...40,
                        step: 1
                    ) { newValue in
                        document.updateContentPadding(for: component.id, padding: newValue)
                    }
                }
            }
            
            if component.type.supportsLayoutControls {
                ModernPropertySection(title: "Spacing & Layout") {
                    SliderPropertyEditor(
                        title: "Padding",
                        value: component.style.padding,
                        range: 0...60,
                        step: 1
                    ) { newValue in
                        document.updatePadding(for: component.id, padding: newValue)
                    }
                    
                    SliderPropertyEditor(
                        title: "Margin",
                        value: component.style.margin,
                        range: 0...60,
                        step: 1
                    ) { newValue in
                        document.updateMargin(for: component.id, margin: newValue)
                    }
                }
            }
            
            if component.type.supportsFillOrBorder {
                ModernPropertySection(title: "Background & Border") {
                    if component.type.supportsBackgroundFill {
                        ColorPropertyEditor(
                            title: "Background Color",
                            color: component.style.backgroundColorSwiftUI,
                            hexColor: component.style.backgroundColor
                        ) { newHex in
                            document.updateBackgroundColor(for: component.id, color: sanitizedHex(newHex))
                        }
                        
                        SliderPropertyEditor(
                            title: "Background Opacity",
                            value: component.style.backgroundOpacity,
                            range: 0...1,
                            step: 0.05,
                            formatter: "%.2f"
                        ) { newValue in
                            document.updateBackgroundOpacity(for: component.id, opacity: newValue)
                        }
                    }
                    
                    if component.type.supportsBorderControls {
                        SliderPropertyEditor(
                            title: "Border Width",
                            value: component.style.borderWidth,
                            range: 0...12,
                            step: 0.5,
                            formatter: "%.1f"
                        ) { newValue in
                            document.updateBorderWidth(for: component.id, width: newValue)
                        }
                        
                        ColorPropertyEditor(
                            title: "Border Color",
                            color: component.style.borderColorSwiftUI,
                            hexColor: component.style.borderColor
                        ) { newHex in
                            document.updateBorderColor(for: component.id, color: sanitizedHex(newHex))
                        }
                    }
                    
                    if component.type.supportsCornerRadius {
                        SliderPropertyEditor(
                            title: "Corner Radius",
                            value: component.style.cornerRadius,
                            range: 0...60,
                            step: 1
                        ) { newValue in
                            document.updateCornerRadius(for: component.id, radius: newValue)
                        }
                    }
                }
            }
            
            if component.type.supportsShadow {
                ModernPropertySection(title: "Shadow") {
                    TogglePropertyEditor(
                        title: "Shadow Enabled",
                        isOn: component.style.shadowEnabled
                    ) { newValue in
                        document.updateShadowEnabled(for: component.id, enabled: newValue)
                    }
                    
                    if component.style.shadowEnabled {
                        SliderPropertyEditor(
                            title: "Shadow Radius",
                            value: component.style.shadowRadius,
                            range: 0...25,
                            step: 1
                        ) { newValue in
                            document.updateShadowRadius(for: component.id, radius: newValue)
                        }
                        
                        SliderPropertyEditor(
                            title: "Shadow Opacity",
                            value: component.style.shadowOpacity,
                            range: 0...1,
                            step: 0.05,
                            formatter: "%.2f"
                        ) { newValue in
                            document.updateShadowOpacity(for: component.id, opacity: newValue)
                        }
                        
                        ShadowOffsetEditor(
                            offsetX: component.style.shadowOffsetX,
                            offsetY: component.style.shadowOffsetY
                        ) { x, y in
                            document.updateShadowOffset(for: component.id, x: x, y: y)
                        }
                        
                        ColorPropertyEditor(
                            title: "Shadow Color",
                            color: component.style.shadowColorSwiftUI,
                            hexColor: component.style.shadowColor
                        ) { newHex in
                            document.updateShadowColor(for: component.id, color: sanitizedHex(newHex))
                        }
                    }
                }
            }
            
            if component.type == .servicesTable {
                ModernPropertySection(title: "Table Styling") {
                    TogglePropertyEditor(
                        title: "Show Header",
                        isOn: component.style.showTableHeader
                    ) { newValue in
                        document.updateShowTableHeader(for: component.id, show: newValue)
                    }
                    
                    TogglePropertyEditor(
                        title: "Alternating Rows",
                        isOn: component.style.useAlternatingRows
                    ) { newValue in
                        document.updateUseAlternatingRows(for: component.id, use: newValue)
                    }
                    
                    ColorPropertyEditor(
                        title: "Header Color",
                        color: component.style.tableHeaderColorSwiftUI,
                        hexColor: component.style.tableHeaderColor
                    ) { newHex in
                        document.updateTableHeaderColor(for: component.id, color: sanitizedHex(newHex))
                    }
                    
                    ColorPropertyEditor(
                        title: "Row Color",
                        color: component.style.tableRowColorSwiftUI,
                        hexColor: component.style.tableRowColor
                    ) { newHex in
                        document.updateTableRowColor(for: component.id, color: sanitizedHex(newHex))
                    }
                    
                    ColorPropertyEditor(
                        title: "Alternate Row Color",
                        color: component.style.tableRowAltColorSwiftUI,
                        hexColor: component.style.tableRowAltColor
                    ) { newHex in
                        document.updateTableRowAltColor(for: component.id, color: sanitizedHex(newHex))
                    }
                    
                    ColorPropertyEditor(
                        title: "Text Color",
                        color: component.style.tableTextColorSwiftUI,
                        hexColor: component.style.tableTextColor
                    ) { newHex in
                        document.updateTableTextColor(for: component.id, color: sanitizedHex(newHex))
                    }
                }
            }
            
            if component.type == .lineShape {
                ModernPropertySection(title: "Line Styling") {
                    SliderPropertyEditor(
                        title: "Line Thickness",
                        value: component.style.lineThickness,
                        range: 1...12,
                        step: 0.5,
                        formatter: "%.1f"
                    ) { newValue in
                        document.updateLineThickness(for: component.id, thickness: newValue)
                    }
                    
                    PickerPropertyEditor(title: "Start Decorator", selection: component.style.lineStartDecorator) { decorator in
                        document.updateLineStartDecorator(for: component.id, decorator: decorator)
                    }
                    
                    PickerPropertyEditor(title: "End Decorator", selection: component.style.lineEndDecorator) { decorator in
                        document.updateLineEndDecorator(for: component.id, decorator: decorator)
                    }
                    
                    ColorPropertyEditor(
                        title: "Line Color",
                        color: component.style.borderColorSwiftUI,
                        hexColor: component.style.borderColor
                    ) { newHex in
                        document.updateBorderColor(for: component.id, color: sanitizedHex(newHex))
                    }
                }
            }
            
            if component.type == .triangleShape {
                ModernPropertySection(title: "Triangle") {
                    PickerPropertyEditor(title: "Direction", selection: component.style.triangleDirection) { direction in
                        document.updateTriangleDirection(for: component.id, direction: direction)
                    }
                }
            }
            
            if component.type == .starShape {
                ModernPropertySection(title: "Star") {
                    SliderPropertyEditor(
                        title: "Points",
                        value: CGFloat(component.style.starPoints),
                        range: 3...12,
                        step: 1,
                        formatter: "%.0f"
                    ) { newValue in
                        document.updateStarPoints(for: component.id, points: Int(newValue))
                    }
                    
                    SliderPropertyEditor(
                        title: "Smoothness",
                        value: component.style.starSmoothness,
                        range: 0.05...0.9,
                        step: 0.05,
                        formatter: "%.2f"
                    ) { newValue in
                        document.updateStarSmoothness(for: component.id, smoothness: newValue)
                    }
                }
            }
            
            if component.type.isImageComponent {
                ModernPropertySection(title: "Image") {
                    PickerPropertyEditor(title: "Content Mode", selection: component.style.imageContentMode) { mode in
                        document.updateImageContentMode(for: component.id, mode: mode)
                    }
                    
                    Button("Clear Image") {
                        document.updateImageData(for: component.id, data: nil)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func sanitizedHex(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
    }
    
    private enum FontWeightOption: String, CaseIterable {
        case regular = "Regular"
        case medium = "Medium"
        case semibold = "Semibold"
        case bold = "Bold"
        
        var styleValue: String {
            rawValue.lowercased()
        }
        
        init(styleValue: String) {
            self = FontWeightOption(rawValue: styleValue.capitalized) ?? .regular
        }
    }
    
    private enum FontFamilyOption: String, CaseIterable {
        case system = "System"
        case serif = "Serif"
        case monospace = "Monospace"
        
        var styleValue: String {
            rawValue.lowercased()
        }
        
        init(styleValue: String) {
            self = FontFamilyOption(rawValue: styleValue.capitalized) ?? .system
        }
    }
}

// MARK: - Modern Property Section

struct ModernPropertySection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(ModernTheme.textSecondary)

            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ModernTheme.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(ModernTheme.outline)
                )
        )
    }
}

// MARK: - Modern Property Field

struct ModernPropertyField: View {
    let title: String
    let value: String
    let onValueChange: ((String) -> Void)?
    
    init(title: String, value: String, onValueChange: ((String) -> Void)? = nil) {
        self.title = title
        self.value = value
        self.onValueChange = onValueChange
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption2)
                .foregroundColor(ModernTheme.textSecondary)
            
            Spacer()
            
            if let onValueChange = onValueChange {
                TextField("", text: .constant(value))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .onSubmit {
                        onValueChange(value)
                    }
            } else {
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Modern Text Field

struct ModernTextField: View {
    let title: String
    let value: String
    let onValueChange: (String) -> Void
    @State private var text: String
    
    init(title: String, value: String, onValueChange: @escaping (String) -> Void) {
        self.title = title
        self.value = value
        self.onValueChange = onValueChange
        self._text = State(initialValue: value)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(ModernTheme.textSecondary)
            
            TextField("Enter text...", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    onValueChange(text)
                }
                .onChange(of: text) { _, newValue in
                    onValueChange(newValue)
                }
        }
    }
}

// MARK: - Modern Color Picker

struct ModernColorPicker: View {
    let title: String
    let color: Color
    let onColorChange: (Color) -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(ModernTheme.textSecondary)
            
            Spacer()
            
            ColorPicker("", selection: .constant(color))
                .labelsHidden()
                .onChange(of: color) { _, newColor in
                    onColorChange(newColor)
                }
        }
    }
}

// MARK: - Modern Color Field

struct ModernColorField: View {
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(ModernTheme.textSecondary)
            
            Spacer()
            
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

// MARK: - Zoom and Pan Controls

struct ZoomPanControlsView: View {
    @Binding var zoomScale: CGFloat
    @Binding var viewportOffset: CGSize
    let geometry: GeometryProxy
    
    private let minZoom: CGFloat = 0.25
    private let maxZoom: CGFloat = 4.0
    
    var body: some View {
        VStack(spacing: 8) {
            // Zoom Level Indicator
            Text("\(Int(zoomScale * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(ModernTheme.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ModernTheme.surface.opacity(0.9))
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            // Zoom Controls
            HStack(spacing: 4) {
                // Zoom Out Button
                Button(action: zoomOut) {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ModernTheme.textPrimary)
                        .frame(width: 24, height: 24)
                        .background(ModernTheme.surface.opacity(0.9))
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(zoomScale <= minZoom)
                
                // Zoom to Fit Button
                Button(action: zoomToFit) {
                    Image(systemName: "arrow.down.left.and.arrow.up.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(ModernTheme.textPrimary)
                        .frame(width: 24, height: 24)
                        .background(ModernTheme.surface.opacity(0.9))
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Zoom In Button
                Button(action: zoomIn) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ModernTheme.textPrimary)
                        .frame(width: 24, height: 24)
                        .background(ModernTheme.surface.opacity(0.9))
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(zoomScale >= maxZoom)
            }
            
            // Pan Controls
            VStack(spacing: 2) {
                // Up Pan Button
                Button(action: { panUp() }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(ModernTheme.textPrimary)
                        .frame(width: 24, height: 16)
                        .background(ModernTheme.surface.opacity(0.9))
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                
                HStack(spacing: 2) {
                    // Left Pan Button
                    Button(action: { panLeft() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(ModernTheme.textPrimary)
                            .frame(width: 16, height: 24)
                            .background(ModernTheme.surface.opacity(0.9))
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Center Button
                    Button(action: centerView) {
                        Image(systemName: "dot.circle")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(ModernTheme.textPrimary)
                            .frame(width: 16, height: 24)
                            .background(ModernTheme.surface.opacity(0.9))
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Right Pan Button
                    Button(action: { panRight() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(ModernTheme.textPrimary)
                            .frame(width: 16, height: 24)
                            .background(ModernTheme.surface.opacity(0.9))
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Down Pan Button
                Button(action: { panDown() }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(ModernTheme.textPrimary)
                        .frame(width: 24, height: 16)
                        .background(ModernTheme.surface.opacity(0.9))
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(8)
        .background(ModernTheme.surface.opacity(0.8))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Zoom Actions
    
    private func zoomIn() {
        let newScale = min(zoomScale * 1.2, maxZoom)
        updateZoom(newScale)
    }
    
    private func zoomOut() {
        let newScale = max(zoomScale / 1.2, minZoom)
        updateZoom(newScale)
    }
    
    private func zoomToFit() {
        let canvasSize = CGSize(width: A4.width, height: A4.height)
        let scaleX = geometry.size.width / canvasSize.width
        let scaleY = geometry.size.height / canvasSize.height
        let fitScale = min(scaleX, scaleY) * 0.9 // 90% to leave some margin
        
        let newScale = max(min(fitScale, maxZoom), minZoom)
        updateZoom(newScale)
        centerView()
    }
    
    private func updateZoom(_ newScale: CGFloat) {
        withAnimation(.easeInOut(duration: 0.2)) {
            let oldScale = zoomScale
            zoomScale = newScale
            
            // Adjust viewport offset to maintain zoom center point
            if zoomScale != oldScale {
                let scaleRatio = zoomScale / oldScale
                viewportOffset = CGSize(
                    width: viewportOffset.width * scaleRatio,
                    height: viewportOffset.height * scaleRatio
                )
            }
        }
    }
    
    // MARK: - Pan Actions
    
    private func panUp() {
        panBy(CGSize(width: 0, height: 50))
    }
    
    private func panDown() {
        panBy(CGSize(width: 0, height: -50))
    }
    
    private func panLeft() {
        panBy(CGSize(width: 50, height: 0))
    }
    
    private func panRight() {
        panBy(CGSize(width: -50, height: 0))
    }
    
    private func centerView() {
        withAnimation(.easeInOut(duration: 0.3)) {
            viewportOffset = .zero
        }
    }
    
    private func panBy(_ delta: CGSize) {
        let newOffset = CGSize(
            width: viewportOffset.width + delta.width,
            height: viewportOffset.height + delta.height
        )
        
        // Apply boundary constraints
        let boundaries = calculatePanBoundaries(geometrySize: geometry.size, zoomScale: zoomScale)
        let constrainedOffsetX = constrainWithResistance(
            newOffset.width,
            min: boundaries.minX,
            max: boundaries.maxX,
            resistance: 0.1
        )
        
        let constrainedOffsetY = constrainWithResistance(
            newOffset.height,
            min: boundaries.minY,
            max: boundaries.maxY,
            resistance: 0.1
        )
        
        withAnimation(.easeInOut(duration: 0.2)) {
            viewportOffset = CGSize(width: constrainedOffsetX, height: constrainedOffsetY)
        }
    }
    
    // MARK: - Helper Functions
    
    private func calculatePanBoundaries(geometrySize: CGSize, zoomScale: CGFloat) -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        let canvasSize = CGSize(width: A4.width, height: A4.height)
        let scaledCanvasSize = CGSize(
            width: canvasSize.width * zoomScale,
            height: canvasSize.height * zoomScale
        )
        
        let hasOverflowX = scaledCanvasSize.width > geometrySize.width
        let hasOverflowY = scaledCanvasSize.height > geometrySize.height
        
        let maxOffsetX = hasOverflowX ? (scaledCanvasSize.width - geometrySize.width) / 2 : 0
        let maxOffsetY = hasOverflowY ? (scaledCanvasSize.height - geometrySize.height) / 2 : 0
        
        return (
            minX: hasOverflowX ? -maxOffsetX : 0,
            maxX: hasOverflowX ? maxOffsetX : 0,
            minY: hasOverflowY ? -maxOffsetY : 0,
            maxY: hasOverflowY ? maxOffsetY : 0
        )
    }
    
    private func constrainWithResistance(_ value: CGFloat, min: CGFloat, max: CGFloat, resistance: CGFloat) -> CGFloat {
        if value < min {
            let excess = min - value
            let resistanceFactor = 1.0 - pow(resistance, excess / 50.0)
            return min - excess * resistanceFactor
        } else if value > max {
            let excess = value - max
            let resistanceFactor = 1.0 - pow(resistance, excess / 50.0)
            return max + excess * resistanceFactor
        }
        return value
    }
}
