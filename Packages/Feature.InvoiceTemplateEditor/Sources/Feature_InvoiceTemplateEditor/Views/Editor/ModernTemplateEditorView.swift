import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Foundation
import Core

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

extension InvoiceComponentType {
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
        // All components support shadow
        return true
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
    
    var isShape: Bool {
        switch self {
        case .rectangleShape, .ellipseShape, .lineShape, .triangleShape, .starShape:
            return true
        default:
            return false
        }
    }
    
    /// Returns true if this component type uses table/grid properties (uses DocumentGridComponent)
    var usesTableProperties: Bool {
        switch self {
        case .documentGrid, .servicesTable, .billTo, .participant, 
             .invoiceNumberAndDates, .paymentDetails, .totals:
            return true
        default:
            return false
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
        self.previewImage = "doc.richtext"
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
    
    public var body: some View {
        ModernTemplateManagementView(
            workspace: workspace,
            highlightedTemplateID: $highlightedTemplateID,
            isInspectorVisible: $isInspectorVisible,
            showingNewTemplateSheet: $showingNewTemplateSheet
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
        }
        .background { AppMeshBackdrop() }
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
                    .fill(isSelected ? Color.selectedChipBackground : Color.unselectedChipBackground)
            )
            .foregroundColor(isSelected ? Color.accentText : Color.secondaryText)
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
                Label("Edit Details", systemImage: "pencil")
            }
            .pointerStyle(.link)
        }
        if let onDuplicate {
            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "square.on.square")
            }
            .pointerStyle(.link)
        }
        if let onDelete {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
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
                               Image(systemName: template.previewImage)
                                   .font(.system(size: 32))
                            .fontWeight(.semibold)
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
                            Image(systemName: "crown.fill")
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
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.activeSurface : Color.elevatedSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.primaryOutline, lineWidth: isSelected ? 2 : 1)
                    )
            )
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
            .background(Color.primarySurface)
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
        .background(Color.primaryBackground.ignoresSafeArea())
        .onAppear {
            if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft.name = "Untitled Template"
            }
            focusedField = .name
        }
    }
}


// MARK: - Component Size Preference Key

private struct ComponentSizePreferenceKey: PreferenceKey {
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
    
    var body: some View {
        componentView
            .background(measurementLayer)
            .frame(width: component.size.width)
            .onPreferenceChange(ComponentSizePreferenceKey.self) { measuredSize in
                updateComponentSizeIfNeeded(measuredSize)
            }
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
    
    private func updateComponentSizeIfNeeded(_ measuredSize: CGSize) {
        guard measuredSize != .zero && measuredSize.width > 0 && measuredSize.height > 0 else { return }
        
        // Account for additional pixels introduced by shadows
        let adjustedSize = CGSize(
            width: measuredSize.width + shadowExtension.width,
            height: measuredSize.height + shadowExtension.height
        )
        
        let currentSize = component.size
        let widthDiff = abs(adjustedSize.width - currentSize.width)
        let heightDiff = abs(adjustedSize.height - currentSize.height)
        
        // Only update if size changed significantly (more than 0.5pt difference)
        guard widthDiff > 0.5 || heightDiff > 0.5 else { return }
        
        document.updateComponent(id: component.id) { component in
            component.size = adjustedSize
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
