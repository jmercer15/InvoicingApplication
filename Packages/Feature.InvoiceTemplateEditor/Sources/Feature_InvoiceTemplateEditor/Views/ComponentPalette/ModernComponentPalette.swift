//
//  ModernComponentPalette.swift
//  Feature.InvoiceTemplateEditor
//
//  Component palette with searchable sections and draggable items
//

import SwiftUI
import Core
import SharedUI
import AppKit

struct ModernComponentPalette: View {
    @EnvironmentObject private var editorViewModel: InvoiceTemplateEditorViewModel
    @EnvironmentObject private var document: InvoiceDocument
    @State private var expandedSection: String? = "Basic Elements"
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Component Library")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.primaryText)

                    Text("Browse available components and drag them into your design.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.secondaryText)
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))

                    TextField("Search components", text: $searchText)
                        .pointerStyle(.horizontalText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .regular))

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Palette content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(paletteSections) { section in
                        let items = filteredItems(for: section.items)
                        if !isFiltering || !items.isEmpty {
                            HierarchySectionCard(
                                title: section.title,
                                isExpanded: binding(for: section),
                                childSpacing: 8
                            ) {
                                VStack(spacing: 8) {
                                    ForEach(items) { descriptor in
                                        PaletteItemView(descriptor: descriptor)
                                            .environmentObject(document)
                                    }
                                }
                                .padding(.top, 2)
                            }
                            .transition(.opacity.combined(with: .scale))
                        }
                    }

                    if isFiltering && !hasSearchResults {
                        Text("No components match \"\(searchQuery)\".")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(NSColor.secondaryLabelColor))
                            .padding(.top, 12)
                    }
                }
                .padding(.bottom, 6)
            }
            .simultaneousGesture(
                DragGesture()
                    .onChanged { _ in }
                    .onEnded { _ in }
            )
        }
        .padding(16)
        .glassEffect(
            .regular,
            in: .rect(cornerRadius: TemplateEditorPanelStyle.cornerRadius)
        )
        .padding(TemplateEditorPanelStyle.outerPadding)
    }

    private func binding(for section: PaletteSection) -> Binding<Bool> {
        Binding(
            get: { expandedSection == section.title },
            set: { isExpanded in
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedSection = isExpanded ? section.title : nil
                }
            }
        )
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
        Dictionary(grouping: paletteItems, by: \.group)
            .sorted { $0.key.sortOrder < $1.key.sortOrder }
            .map { PaletteSection(title: $0.key.title, items: $0.value) }
    }
    
    private var paletteItems: [PaletteItemDescriptor] {
        [
            PaletteItemDescriptor(group: .basicElements, type: .textBox, name: "Text Box", icon: "textformat", description: "Add editable text"),
            PaletteItemDescriptor(group: .basicElements, type: .rectangleShape, name: "Rectangle", icon: "square", description: "Add rectangle shape"),
            PaletteItemDescriptor(group: .basicElements, type: .ellipseShape, name: "Ellipse", icon: "circle", description: "Add ellipse shape"),
            PaletteItemDescriptor(group: .basicElements, type: .lineShape, name: "Line", icon: "line.horizontal.3", description: "Add divider line"),
            PaletteItemDescriptor(group: .basicElements, type: .triangleShape, name: "Triangle", icon: "triangle", description: "Add triangle shape"),
            PaletteItemDescriptor(group: .basicElements, type: .starShape, name: "Star", icon: "star", description: "Add star shape"),
            PaletteItemDescriptor(group: .basicElements, type: .imagePlaceholder, name: "Image Placeholder", icon: "photo", description: "Add image placeholder"),
            PaletteItemDescriptor(group: .invoiceSections, type: .invoiceNumberAndDates, name: "Invoice Number & Dates", icon: "number", description: "Invoice number and dates"),
            PaletteItemDescriptor(group: .invoiceSections, type: .billTo, name: "Bill To", icon: "person.2", description: "Customer information"),
            PaletteItemDescriptor(group: .invoiceSections, type: .participant, name: "Participant", icon: "person.3", description: "Participant information"),
            PaletteItemDescriptor(group: .invoiceSections, type: .servicesTable, name: "Services Table", icon: "table", description: "Services and pricing"),
            PaletteItemDescriptor(group: .invoiceSections, type: .documentGrid, name: "Document Grid", icon: "tablecells.fill", description: "Advanced document-style table"),
            PaletteItemDescriptor(group: .invoiceSections, type: .totals, name: "Totals", icon: "sum", description: "Invoice totals"),
            PaletteItemDescriptor(group: .invoiceSections, type: .paymentDetails, name: "Payment Details", icon: "creditcard", description: "Payment information"),
            PaletteItemDescriptor(group: .invoiceSections, type: .paymentTerms, name: "Payment Terms", icon: "doc.text", description: "Payment terms and conditions"),
            PaletteItemDescriptor(group: .companyInfo, type: .invoiceTitle, name: "Invoice Title", icon: "doc.text", description: "Invoice title"),
            PaletteItemDescriptor(group: .companyInfo, type: .companyName, name: "Company Name", icon: "building.2", description: "Company name"),
            PaletteItemDescriptor(group: .companyInfo, type: .companyABN, name: "Company ABN", icon: "number.circle", description: "Company ABN"),
            PaletteItemDescriptor(group: .companyInfo, type: .companyEmail, name: "Company Email", icon: "envelope", description: "Company email"),
            PaletteItemDescriptor(group: .companyInfo, type: .companyLogo, name: "Company Logo", icon: "photo", description: "Company logo placeholder"),
            PaletteItemDescriptor(group: .additionalElements, type: .notes, name: "Notes", icon: "note.text", description: "Additional notes")
        ]
    }
    
    private enum PaletteGroup: Int, CaseIterable {
        case basicElements
        case invoiceSections
        case companyInfo
        case additionalElements

        var title: String {
            switch self {
            case .basicElements:
                return "Basic Elements"
            case .invoiceSections:
                return "Invoice Sections"
            case .companyInfo:
                return "Company Info"
            case .additionalElements:
                return "Additional Elements"
            }
        }

        var sortOrder: Int { rawValue }
    }
    
    private struct PaletteItemDescriptor: Identifiable {
        let group: PaletteGroup
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
    
    // MARK: - Palette Item View
    
    private struct PaletteItemView: View {
        let descriptor: PaletteItemDescriptor
        @EnvironmentObject private var document: InvoiceDocument
        
        var body: some View {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.18))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                        )
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: descriptor.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
                
                Text(descriptor.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(NSColor.labelColor))
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(
                .regular.interactive(true).tint(Color(NSColor.windowBackgroundColor)),
                in: .rect(cornerRadius: 12)
            )
            .glassEffectTransition(.materialize)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.6)
            )
            .pointerStyle(.link)
            .help(descriptor.description)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .draggable(createDraggableComponent()) {
                HStack(spacing: 8) {
                    Image(systemName: descriptor.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.accentColor)
                    
                    Text(descriptor.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.primaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.windowBackgroundColor))
                        .shadow(color: Color.primaryShadow.opacity(0.12), radius: 6, x: 0, y: 3)
                )
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if document.isDraggingPaletteComponent == false {
                            document.isDraggingPaletteComponent = true
                        }
                    }
                    .onEnded { _ in
                        document.isDraggingPaletteComponent = false
                    }
            )
        }
        
        private func createDraggableComponent() -> InvoiceComponent {
            InvoiceComponent(
                type: descriptor.type,
                position: .zero,
                size: descriptor.type.defaultSize
            )
        }
    }
}
