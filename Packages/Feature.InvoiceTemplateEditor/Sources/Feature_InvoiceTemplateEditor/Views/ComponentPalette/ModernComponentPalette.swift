//
//  ModernComponentPalette.swift
//  Feature.InvoiceTemplateEditor
//
//  Component palette with searchable sections and draggable items
//

import SwiftUI
import Core

struct ModernComponentPalette: View {
    @EnvironmentObject private var editorViewModel: InvoiceTemplateEditorViewModel
    @EnvironmentObject private var document: InvoiceDocument
    @State private var expandedSections: Set<String> = ["Basic Elements", "Invoice Sections", "Company Info", "Additional Elements"]
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 12) {
            // Palette header
            VStack(alignment: .leading, spacing: 10) {
                Label {
                    Text("Component Library")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(Color.primaryText)
                } icon: {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 24, height: 24)
                    Image(systemName: "square.grid.3x2")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .labelStyle(.titleAndIcon)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.secondaryText)

                    TextField("Search components", text: $searchText)
                        .pointerStyle(.horizontalText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(Color.primaryText)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 2)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondaryFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.primaryOutline.opacity(0.15),
                                            Color.primaryOutline.opacity(0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        )
                )
                .shadow(color: Color.primaryShadow.opacity(0.04), radius: 2, x: 0, y: 1)
                .shadow(color: Color.accentColor.opacity(0.02), radius: 4, x: 0, y: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Palette content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(paletteSections) { section in
                        let items = filteredItems(for: section.items)
                        if !isFiltering || !items.isEmpty {
                            // Section header
                            VStack(alignment: .leading, spacing: 8) {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        toggleSection(section.title)
                                    }
                                }) {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.accentColor.opacity(0.08))
                                                .frame(width: 20, height: 20)
                                        Image(systemName: expandedSections.contains(section.title) ? "chevron.up" : "chevron.down")
                                                .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.accentColor)
                                        }

                                        Text(section.title)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundColor(Color.primaryText)

                                        Spacer()
                                        
                                        if expandedSections.contains(section.title) {
                                            Text("\(items.count)")
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .foregroundColor(Color.secondaryText)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.accentColor.opacity(0.08))
                                                )
                                                .transition(.scale.combined(with: .opacity))
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                                .pointerStyle(.link)
                                .buttonStyle(.plain)

                                if expandedSections.contains(section.title) {
                                    VStack(spacing: 6) {
                                        ForEach(items) { descriptor in
                                            // Palette item
                                            PaletteItemView(descriptor: descriptor)
                                                .transition(.asymmetric(
                                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                                    removal: .opacity.combined(with: .move(edge: .top))
                                                ))
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.primarySurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        Color.primaryOutline.opacity(0.1),
                                                        Color.primaryOutline.opacity(0.05)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 0.5
                                            )
                                    )
                            )
                            .shadow(color: Color.primaryShadow.opacity(0.04), radius: 3, x: 0, y: 1.5)
                            .shadow(color: Color.accentColor.opacity(0.01), radius: 6, x: 0, y: 3)
                        }
                    }

                    if isFiltering && !hasSearchResults {
                        Text("No components match \"\(searchQuery)\".")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 4)
            }
            .simultaneousGesture(
                DragGesture()
                    .onChanged { _ in }
                    .onEnded { _ in }
            )
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .foregroundColor(Color.primaryText)
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
            PaletteItemDescriptor(type: .documentGrid, name: "Document Grid", icon: "tablecells.fill", description: "Advanced document-style table"),
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
    
    // MARK: - Palette Item View
    
    private struct PaletteItemView: View {
        let descriptor: PaletteItemDescriptor
        @State private var isHovered = false
        
        var body: some View {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            isHovered 
                                ? LinearGradient(
                                    colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(
                                    isHovered ? Color.accentColor.opacity(0.3) : Color.accentColor.opacity(0.15),
                                    lineWidth: isHovered ? 1 : 0.5
                                )
                        )
                    Image(systemName: descriptor.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            isHovered
                                ? LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .scaleEffect(isHovered ? 1.1 : 1.0)
                }
                
                Text(descriptor.name)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(Color.primaryText)
                
                Spacer()
                
                if isHovered {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.accentColor.opacity(0.6))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isHovered 
                            ? LinearGradient(
                                colors: [
                                    Color.hoverHighlight,
                                    Color.hoverHighlight.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.primarySurface,
                                    Color.primarySurface.opacity(0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isHovered 
                                    ? LinearGradient(
                                        colors: [
                                            Color.accentColor.opacity(0.4),
                                            Color.accentColor.opacity(0.25)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [
                                            Color.primaryOutline.opacity(0.6),
                                            Color.primaryOutline.opacity(0.4)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                lineWidth: isHovered ? 0.75 : 0.5
                            )
                    )
            )
            .shadow(color: Color.primaryShadow.opacity(isHovered ? 0.12 : 0), radius: isHovered ? 8 : 0, x: 0, y: isHovered ? 4 : 0)
            .shadow(color: Color.accentColor.opacity(isHovered ? 0.08 : 0), radius: isHovered ? 12 : 0, x: 0, y: isHovered ? 6 : 0)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .pointerStyle(.link)
            .help(descriptor.description)
            .onHover { hovering in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    isHovered = hovering
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .draggable(createDraggableComponent()) {
                // Drag preview
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
                        .fill(Color.primarySurface)
                        .shadow(color: Color.primaryShadow.opacity(0.12), radius: 6, x: 0, y: 3)
                )
            }
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
