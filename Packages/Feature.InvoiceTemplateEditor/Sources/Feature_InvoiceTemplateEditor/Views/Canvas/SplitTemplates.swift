//
//  SplitTemplates.swift
//  Feature.InvoiceTemplateEditor
//
//  Predefined split templates for common layouts
//

import SwiftUI

struct SplitTemplate {
    let id: String
    let name: String
    let description: String
    let icon: String
    let direction: SectionSplit.SplitDirection
    let splitCount: Int
    let rows: Int?
    let columns: Int?
    let labels: [String]?
    
    init(id: String, name: String, description: String, icon: String, direction: SectionSplit.SplitDirection, splitCount: Int, rows: Int? = nil, columns: Int? = nil, labels: [String]? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.direction = direction
        self.splitCount = splitCount
        self.rows = rows
        self.columns = columns
        self.labels = labels
    }
}

extension SplitTemplate {
    static let commonTemplates: [SplitTemplate] = [
        // Basic splits
        SplitTemplate(
            id: "horizontal-2",
            name: "Two Columns",
            description: "Split into two equal columns",
            icon: "rectangle.split.2x1",
            direction: .horizontal,
            splitCount: 2,
            labels: ["Left", "Right"]
        ),
        
        SplitTemplate(
            id: "horizontal-3",
            name: "Three Columns",
            description: "Split into three equal columns",
            icon: "rectangle.split.3x1",
            direction: .horizontal,
            splitCount: 3,
            labels: ["Left", "Center", "Right"]
        ),
        
        SplitTemplate(
            id: "vertical-2",
            name: "Two Rows",
            description: "Split into two equal rows",
            icon: "rectangle.split.1x2",
            direction: .vertical,
            splitCount: 2,
            labels: ["Top", "Bottom"]
        ),
        
        SplitTemplate(
            id: "vertical-3",
            name: "Three Rows",
            description: "Split into three equal rows",
            icon: "rectangle.split.1x3",
            direction: .vertical,
            splitCount: 3,
            labels: ["Top", "Middle", "Bottom"]
        ),
        
        // Grid layouts
        SplitTemplate(
            id: "grid-2x2",
            name: "2x2 Grid",
            description: "Four equal sections in a grid",
            icon: "grid",
            direction: .grid,
            splitCount: 4,
            rows: 2,
            columns: 2,
            labels: ["Top Left", "Top Right", "Bottom Left", "Bottom Right"]
        ),
        
        SplitTemplate(
            id: "grid-3x2",
            name: "3x2 Grid",
            description: "Six sections in a 3x2 grid",
            icon: "grid.circle",
            direction: .grid,
            splitCount: 6,
            rows: 3,
            columns: 2,
            labels: ["Row 1 Left", "Row 1 Right", "Row 2 Left", "Row 2 Right", "Row 3 Left", "Row 3 Right"]
        ),
        
        SplitTemplate(
            id: "grid-2x3",
            name: "2x3 Grid",
            description: "Six sections in a 2x3 grid",
            icon: "grid.circle.fill",
            direction: .grid,
            splitCount: 6,
            rows: 2,
            columns: 3,
            labels: ["Col 1 Top", "Col 1 Bottom", "Col 2 Top", "Col 2 Bottom", "Col 3 Top", "Col 3 Bottom"]
        ),
        
        // Complex layouts
        SplitTemplate(
            id: "header-content",
            name: "Header + Content",
            description: "Header section with main content area",
            icon: "rectangle.topthird.inset",
            direction: .vertical,
            splitCount: 2,
            labels: ["Header", "Content"]
        ),
        
        SplitTemplate(
            id: "sidebar-content",
            name: "Sidebar + Content",
            description: "Sidebar with main content area",
            icon: "sidebar.left",
            direction: .horizontal,
            splitCount: 2,
            labels: ["Sidebar", "Content"]
        ),
        
        SplitTemplate(
            id: "three-panel",
            name: "Three Panel",
            description: "Sidebar, main content, and details panel",
            icon: "rectangle.split.3x1",
            direction: .horizontal,
            splitCount: 3,
            labels: ["Sidebar", "Main", "Details"]
        )
    ]
    
    static let invoiceTemplates: [SplitTemplate] = [
        SplitTemplate(
            id: "invoice-header",
            name: "Invoice Header",
            description: "Header with company info and invoice details",
            icon: "doc.text",
            direction: .horizontal,
            splitCount: 2,
            labels: ["Company Info", "Invoice Details"]
        ),
        
        SplitTemplate(
            id: "invoice-body",
            name: "Invoice Body",
            description: "Main content area for line items",
            icon: "table",
            direction: .vertical,
            splitCount: 2,
            labels: ["Line Items", "Totals"]
        ),
        
        SplitTemplate(
            id: "invoice-footer",
            name: "Invoice Footer",
            description: "Footer with terms and signature",
            icon: "signature",
            direction: .horizontal,
            splitCount: 2,
            labels: ["Terms", "Signature"]
        )
    ]
}

struct SplitTemplatePicker: View {
    let onTemplateSelected: (SplitTemplate) -> Void
    let onCancel: () -> Void
    
    @State private var selectedCategory = "Common"
    
    private var categories: [String] {
        ["Common", "Invoice Layouts"]
    }
    
    private var templatesForCategory: [SplitTemplate] {
        switch selectedCategory {
        case "Common":
            return SplitTemplate.commonTemplates
        case "Invoice Layouts":
            return SplitTemplate.invoiceTemplates
        default:
            return []
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Choose Split Template")
                .font(.headline)
            
            // Category picker
            Picker("Category", selection: $selectedCategory) {
                ForEach(categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.segmented)
            
            // Template grid
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(templatesForCategory, id: \.id) { template in
                        TemplateCard(template: template) {
                            onTemplateSelected(template)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 300)
            
            // Action buttons
            HStack {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}

struct TemplateCard: View {
    let template: SplitTemplate
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Image(systemName: template.icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text(template.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                
                Text(template.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
