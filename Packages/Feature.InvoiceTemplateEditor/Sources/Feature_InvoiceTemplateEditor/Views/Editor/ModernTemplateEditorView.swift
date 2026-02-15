import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Foundation
import Core
import SharedUI

// MARK: - Template Categories

enum TemplateCategory: String, CaseIterable {
    case all = "All"
    case business = "Business"
    case creative = "Creative"
    case minimal = "Minimal"
    case professional = "Professional"
    
    var icon: String {
        switch self {
        case .all: return "fluent-ic_fluent_grid_20_regular"
        case .business: return "fluent-ic_fluent_building_20_regular"
        case .creative: return "fluent-ic_fluent_paint_brush_20_regular"
        case .minimal: return "fluent-ic_fluent_more_circle_20_regular"
        case .professional: return "fluent-ic_fluent_toolbox_20_regular"
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
        self.previewImage = "fluent-ic_fluent_document_text_20_regular"
        self.isPremium = metadata.tags.contains { $0.lowercased() == "premium" }
        self.lastModified = metadata.modifiedAt
        self.tags = metadata.tags
        self.thumbnailData = metadata.thumbnailData
        self.metadata = metadata
    }
    

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
    @StateObject private var workspace: TemplateEditorWorkspaceViewModel
    @State private var highlightedTemplateID: UUID? = nil
    @State private var isInspectorVisible = true
    @State private var showingNewTemplateSheet = false
    
    public init(workspace: TemplateEditorWorkspaceViewModel) {
        self._workspace = StateObject(wrappedValue: workspace)
    }
    
    @EnvironmentObject private var templateDataService: TemplateDataService
    @Environment(\.undoManager) private var undoManager
    
    public var body: some View {
        ModernTemplateManagementView(
            workspace: workspace,
            highlightedTemplateID: $highlightedTemplateID,
            isInspectorVisible: $isInspectorVisible,
            showingNewTemplateSheet: $showingNewTemplateSheet
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .loadingOverlay(
            isLoading: workspace.editorViewModel.isLoading || workspace.isLoadingTemplates || workspace.isOpeningTemplate,
            message: workspace.isLoadingTemplates ? "Loading templates..." : workspace.isOpeningTemplate ? "Opening template..." : "Processing..."
        )
        .environmentObject(workspace)
        .environmentObject(workspace.editorViewModel)
        .environmentObject(workspace.editorViewModel.document)
        .environmentObject(templateDataService)
        .sheet(isPresented: $showingNewTemplateSheet) {
            ModernTemplateCreatorSheet(onCreateTemplate: handleCreateTemplate)
                .environmentObject(workspace)
                .environmentObject(workspace.editorViewModel)
                .environmentObject(workspace.editorViewModel.document)
                .environmentObject(templateDataService)
        }
        .task {
            // Inject undo manager
            workspace.editorViewModel.document.undoManager = undoManager
            await templateDataService.loadRandomInvoice()
        }
        .onChange(of: undoManager) { _, newManager in
            workspace.editorViewModel.document.undoManager = newManager
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
                Image(category.icon, bundle: .module)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)

                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.selectedChipBackground : Color.unselectedChipBackground)
            )
            .foregroundColor(isSelected ? Color.accentText : Color.secondaryText)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .pointerStyle(.link)
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
                Label {
                    Text("Edit Details")
                } icon: {
                    Image("fluent-ic_fluent_edit_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                }
            }
            .pointerStyle(.link)
        }
        if let onDuplicate {
            Button(action: onDuplicate) {
                Label {
                    Text("Duplicate")
                } icon: {
                    Image("fluent-ic_fluent_document_copy_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                }
            }
            .pointerStyle(.link)
        }
        if let onDelete {
            Button(role: .destructive, action: onDelete) {
                Label {
                    Text("Delete")
                } icon: {
                    Image("fluent-ic_fluent_delete_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                }
            }
            .pointerStyle(.link)
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
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
            VStack(alignment: .leading, spacing: 12) {
                // Preview
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.elevatedSurface)
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
                                Image(template.previewImage, bundle: .module)
                                    .resizable()
                                    .renderingMode(.template)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 32, height: 32)
                                    .foregroundColor(Color.secondary)
                            }
                        }
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(template.name)
                            .font(.headline)
                            .foregroundColor(Color.primaryText)
                        
                        Spacer()
                        
                        if template.isPremium {
                            Image("fluent-ic_fluent_premium_20_regular", bundle: .module)
                                .resizable()
                                .renderingMode(.template)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 12, height: 12)
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                   Text(template.description)
                       .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Color.secondary)
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
                        .fontWeight(.semibold)
                .foregroundColor(Color.secondary)
                        }
                        }
                    }
                    
                    HStack {
                        Text(template.category.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.hoverHighlight)
                            .foregroundColor(Color.accentText)
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Text(template.lastModified, style: .relative)
                            .font(.caption2)
                    .fontWeight(.semibold)
                .foregroundColor(Color.secondary)
                    }
                }
            }
            .padding(14)
            .background(
                shape
                    .fill(isSelected ? Color.activeSurface : Color.elevatedSurface)
                    .overlay(shape.stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.primaryOutline, lineWidth: isSelected ? 2 : 1))
            )
            .contentShape(shape)
            .shadow(color: isSelected ? Color.accentColor.opacity(0.35) : Color.primaryShadow.opacity(0.18), radius: isSelected ? 12 : 8, x: 0, y: isSelected ? 10 : 6)
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
                    Image("fluent-ic_fluent_more_circle_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .imageScale(.medium)
                        .padding(6)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: onOpen) {
                Label {
                    Text("Open")
                } icon: {
                    Image("fluent-ic_fluent_arrow_right_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                }
            }
            .pointerStyle(.link)
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .controlSize(.mini)
            .padding(10)
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
                        .pointerStyle(.horizontalText)
                        .focused($focusedField, equals: .name)
                }

                Section(header: Text("Description")) {
                    TextEditor(text: $draft.description)
                        .pointerStyle(.horizontalText)
                        .frame(minHeight: 100)
                }

                Section(header: Text("Tags"), footer: Text("Enter comma-separated tags to help categorise your template.")) {
                    TextField("e.g. professional, business", text: $draft.tagsText)
                        .pointerStyle(.horizontalText)
                        .focused($focusedField, equals: .tags)
                        .disableAutocorrection(true)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PanelShellTokens.panelBackground)
            .navigationTitle("New Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                        .pointerStyle(.link)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreateTemplate(draft)
                        dismiss()
                    }
                    .pointerStyle(.link)
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 360)
        .background(PanelShellTokens.panelBackground.ignoresSafeArea())
        .onAppear {
            if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft.name = "Untitled Template"
            }
            focusedField = .name
        }
    }
}


// MARK: - Component Size Preference Key



private struct IdealComponentSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

struct ModernComponentView: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument
    @State private var isHovered = false
    
    var body: some View {
        let currentComponent = document.components.first { $0.id == component.id } ?? component
        let usesTableProperties = currentComponent.type.usesTableProperties
        let hasFlexibleColumns = usesTableProperties && componentHasFlexibleColumns(currentComponent)
        
        componentView
            .overlay(selectionIndicator)
            .background(measurementLayer)
            .background(
                Group {
                    if !usesTableProperties {
                        idealMeasurementLayer
                    }
                }
            )
            .frame(width: usesTableProperties ? nil : max(0, currentComponent.size.width - shadowExtension.width))
            .fixedSize(horizontal: usesTableProperties && !hasFlexibleColumns, vertical: !usesTableProperties)
            .onPreferenceChange(ComponentSizePreferenceKey.self) { measuredSize in
                updateComponentSizeIfNeeded(measuredSize)
            }
            .onPreferenceChange(IdealComponentSizePreferenceKey.self) { measuredSize in
                updateComponentIdealSizeIfNeeded(measuredSize)
            }
            .onHover { isHovered = $0 }
    }
    
    private var selectionIndicator: some View {
        StateOverlay(
            elementType: .component,
            isHovered: isHovered,
            isSelected: document.selectedComponentID == component.id,
            isDropTarget: false
        )
    }
    
    /// Check if this component has any flexible columns (for table components)
    private func componentHasFlexibleColumns(_ componentToCheck: InvoiceComponent? = nil) -> Bool {
        let comp = componentToCheck ?? component
        guard comp.type.usesTableProperties else { return false }
        
        // Check column configurations
        let configs: [ComponentStyle.ColumnConfiguration]
        if comp.style.tableDirection == .horizontal {
            configs = Array(comp.style.columnConfigurations.values)
        } else {
            configs = Array(comp.style.rowConfigurations.values).map { row in
                ComponentStyle.ColumnConfiguration(
                    width: row.height,
                    isFlexible: row.isFlexible,
                    alignment: row.alignment,
                    verticalAlignment: row.verticalAlignment,
                    headerAlignment: row.headerAlignment,
                    headerVerticalAlignment: row.headerVerticalAlignment,
                    lineLimit: row.lineLimit
                )
            }
        }
        
        // If no configurations yet, assume flexible (default behavior)
        guard !configs.isEmpty else { return true }
        
        // Check if any column is flexible
        return configs.contains { $0.isFlexible }
    }
    
    @ViewBuilder
    private var componentView: some View {
        switch component.type {
        case .companyName: CompanyNameComponent(component: component)
        case .companyLogo: ImageComponent(component: component)
        case .companyABN: CompanyABNComponent(component: component)
        case .companyEmail: CompanyEmailComponent(component: component)
        case .invoiceNumberAndDates: InvoiceNumberAndDatesComponent(component: component)
        case .billTo: BillToComponent(component: component)
        case .participant: ParticipantComponent(component: component)
        case .servicesTable: TableComponent(component: component)
        case .documentGrid: DocumentGridComponent(component: component)
        case .totals: TotalsComponent(component: component)
        case .paymentDetails: PaymentDetailsComponent(component: component)
        case .paymentTerms: PaymentTermsComponent(component: component)
        case .invoiceTitle: InvoiceTitleComponent(component: component)
        case .notes: NotesComponent(component: component)
        case .textBox: TextBoxComponent(component: component)
        case .rectangleShape: RectangleShapeComponent(component: component)
        case .ellipseShape: EllipseShapeComponent(component: component)
        case .lineShape: LineShapeComponent(component: component)
        case .triangleShape: TriangleShapeComponent(component: component)
        case .starShape: StarShapeComponent(component: component)
        case .imagePlaceholder: ImagePlaceholderComponent(component: component)
        }
    }
    
    private var measurementLayer: some View {
        GeometryReader { geometry in
            Color.clear.preference(
                key: ComponentSizePreferenceKey.self,
                value: geometry.size
            )
        }
        .allowsHitTesting(false)
    }
    
    private var idealMeasurementLayer: some View {
        componentView
            .environment(\.isMeasuringIdealSize, true)
            .fixedSize(horizontal: true, vertical: true)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: IdealComponentSizePreferenceKey.self,
                        value: geometry.size
                    )
                }
            )
            .hidden()
            .allowsHitTesting(false)
    }
    
    private func updateComponentSizeIfNeeded(_ measuredSize: CGSize) {
        guard measuredSize != .zero && measuredSize.width > 0 && measuredSize.height > 0 else { return }
        
        // Account for additional pixels introduced by shadows
        var adjustedSize = CGSize(
            width: measuredSize.width + shadowExtension.width,
            height: measuredSize.height + shadowExtension.height
        )
        
        // If component has flexible columns, its width is determined by the container,
        // so we shouldn't update the component's stored size based on this expanded width.
        // Doing so would lock the component into a large size, preventing "Fit" split mode from working.
        if component.type.usesTableProperties {
            if componentHasFlexibleColumns() {
                adjustedSize.width = component.size.width
            }
            if componentHasFlexibleRows() {
                adjustedSize.height = component.size.height
            }
        }
        
        let currentSize = component.size
        let widthDiff = abs(adjustedSize.width - currentSize.width)
        let heightDiff = abs(adjustedSize.height - currentSize.height)
        
        // Only update if size changed significantly (more than 0.5pt difference)
        guard widthDiff > 0.5 || heightDiff > 0.5 else { return }
        
        document.updateComponent(id: component.id) { component in
            component.size = adjustedSize
        }
    }
    
    private func updateComponentIdealSizeIfNeeded(_ measuredSize: CGSize) {
        guard measuredSize != .zero && measuredSize.width > 0 && measuredSize.height > 0 else { return }
        
        // Account for additional pixels introduced by shadows
        let adjustedSize = CGSize(
            width: measuredSize.width + shadowExtension.width,
            height: measuredSize.height + shadowExtension.height
        )
        
        let currentIdealSize = component.idealSize ?? .zero
        let widthDiff = abs(adjustedSize.width - currentIdealSize.width)
        let heightDiff = abs(adjustedSize.height - currentIdealSize.height)
        
        // Only update if size changed significantly
        guard widthDiff > 0.5 || heightDiff > 0.5 else { return }
        
        document.updateComponent(id: component.id) { component in
            component.idealSize = adjustedSize
        }
    }
    
    private var shadowExtension: CGSize {
        guard component.style.shadowEnabled else { return .zero }
        
        let radius = component.style.shadowRadius
        let offsetX = component.style.shadowOffsetX
        let offsetY = component.style.shadowOffsetY
        
        // Shadow extends by its radius on each side plus the absolute offset
        return CGSize(
            width: radius * 2 + abs(offsetX),
            height: radius * 2 + abs(offsetY)
        )
    }
    
    /// Check if this component has any flexible rows (for table components)
    private func componentHasFlexibleRows() -> Bool {
        guard component.type.usesTableProperties else { return false }
        
        let configs: [ComponentStyle.RowConfiguration]
        if component.style.tableDirection == .horizontal {
            configs = Array(component.style.rowConfigurations.values)
        } else {
            configs = Array(component.style.columnConfigurations.values).map { col in
                var config = ComponentStyle.RowConfiguration()
                config.height = col.width
                config.isFlexible = col.isFlexible
                return config
            }
        }
        
        // If no configurations, assume content-driven (not flexible in the sense of expanding)
        guard !configs.isEmpty else { return false }
        
        return configs.contains { $0.isFlexible }
    }
}

// MARK: - View Style Extensions

private extension View {
    func applyTextStyle(
        _ style: ComponentStyle,
        alignment: TextAlignment
    ) -> some View {
        self
            .font(style.fontFamily(style.fontSize, style.fontWeightValue))
            .foregroundColor(style.textColorSwiftUI.opacity(style.textOpacity))
            .multilineTextAlignment(alignment.swiftUIAlignment)
            .lineSpacing(style.lineSpacing)
            .tracking(style.letterSpacing)
            .underline(style.textUnderline)
            .strikethrough(style.textStrikethrough)
    }
}


// MARK: - Modern Inspector View


private struct TagView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .default))
            .foregroundColor(Color.accentColor)
            .textCase(.uppercase)
            .tracking(0.3)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 0.5)
                    )
            )
    }
}


// MARK: - Zoom and Pan Controls
// Toolbar components moved to Views/Editor/Components/ToolbarButtons.swift
