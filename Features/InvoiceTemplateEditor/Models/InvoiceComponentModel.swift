
import Foundation
import CoreGraphics
import CoreTransferable
import UniformTypeIdentifiers
import SwiftUI

enum LineDecorator: String, CaseIterable, Codable {
    case none = "None"
    case arrow = "Arrow"
    case circle = "Circle"
    case square = "Square"
}

enum ImageContentMode: String, CaseIterable, Codable {
    case fit = "Fit"
    case fill = "Fill"
}

enum TriangleDirection: String, CaseIterable, Codable {
    case up = "Up"
    case down = "Down"
    case left = "Left"
    case right = "Right"
}

enum InvoiceComponentType: String, CaseIterable, Identifiable, Codable {
    // Invoice Sections
    case invoiceNumberAndDates = "Invoice Number & Dates"
    case billTo = "Bill To"
    case participant = "Participant"
    case servicesTable = "Services Table"
    case totals = "Totals"
    case paymentDetails = "Payment Details"
    
    // Individual Components
    case paymentTerms = "Payment Terms"
    case invoiceTitle = "Invoice Title"
    case companyName = "Company Name"
    case companyABN = "Company ABN"
    case companyEmail = "Company Email"
    case companyLogo = "Company Logo"
    
    // Additional Information
    case notes = "Notes"
    
    // Standard elements
    case textBox = "Text Box"
    case rectangleShape = "Rectangle"
    case ellipseShape = "Ellipse"
    case lineShape = "Line"
    case triangleShape = "Triangle"
    case starShape = "Star"
    case imagePlaceholder = "Image Placeholder"

    var id: String { self.rawValue }
    
    var isSection: Bool {
        switch self {
        case .invoiceNumberAndDates, .billTo, .participant, .servicesTable, .totals, .paymentDetails:
            return true
        default:
            return false
        }
    }
}

enum TextAlignment: String, CaseIterable, Codable {
    case leading = "Leading"
    case center = "Center"
    case trailing = "Trailing"
}

enum SectionLayout: String, CaseIterable, Codable {
    case vertical = "Vertical Stack"
    case horizontal = "Horizontal Stack"
    case grid = "Grid"
    
    var description: String {
        switch self {
        case .vertical:
            return "Stack children vertically"
        case .horizontal:
            return "Stack children horizontally"
        case .grid:
            return "Arrange children in a grid"
        }
    }
}

struct ComponentStyle: Codable {
    // Typography
    var fontSize: CGFloat = 14
    var fontWeight: String = "regular" // regular, medium, semibold, bold
    var fontFamily: String = "system" // system, serif, monospace
    var textColor: String = "000000" // Hex color without #
    var textAlignment: TextAlignment = .leading
    var lineSpacing: CGFloat = 1.0
    var letterSpacing: CGFloat = 0.0
    
    // Background & Border
    var backgroundColor: String = "FFFFFF" // Hex color without #
    var backgroundOpacity: CGFloat = 1.0
    var borderWidth: CGFloat = 1
    var borderColor: String = "CCCCCC"
    var borderStyle: BorderStyle = .solid
    var cornerRadius: CGFloat = 0
    
    // Layout & Spacing
    var padding: CGFloat = 0
    var margin: CGFloat = 0
    
    // Shadow
    var shadowEnabled: Bool = false
    var shadowColor: String = "000000"
    var shadowOpacity: CGFloat = 0.3
    var shadowRadius: CGFloat = 4
    var shadowOffsetX: CGFloat = 0
    var shadowOffsetY: CGFloat = 2
    
    // Text-specific
    var placeholderText: String = ""
    
    // Shape-specific
    var starPoints: Int = 5
    var starSmoothness: CGFloat = 0.38
    var triangleDirection: TriangleDirection = .up
    var lineThickness: CGFloat = 2
    var lineStartDecorator: LineDecorator = .none
    var lineEndDecorator: LineDecorator = .none
    
    // Image-specific
    var imageData: Data?
    var imageContentMode: ImageContentMode = .fit
    
    // Table-specific
    var tableHeaderColor: String = "E5E7EB"
    var tableRowColor: String = "FFFFFF"
    var tableRowAltColor: String = "F9FAFB"
    var tableTextColor: String = "111827"
    var showTableHeader: Bool = true
    var useAlternatingRows: Bool = false
    
    // Section-specific
    var sectionLayout: SectionLayout = .vertical
    var gridColumns: Int = 2
    var contentSpacing: CGFloat = 0
    var contentPadding: CGFloat = 12
    
    // Computed properties for SwiftUI
    var backgroundColorSwiftUI: Color {
        Color(hex: backgroundColor)
    }
    
    var borderColorSwiftUI: Color {
        Color(hex: borderColor)
    }
    
    var textColorSwiftUI: Color {
        Color(hex: textColor)
    }
    
    var shadowColorSwiftUI: Color {
        Color(hex: shadowColor)
    }
}

enum BorderStyle: String, CaseIterable, Codable {
    case solid = "Solid"
    case dashed = "Dashed"
    case dotted = "Dotted"
}

// MARK: - Section Component



// MARK: - Invoice Component

struct InvoiceComponent: Identifiable, Codable, Transferable {
    var id: UUID
    let type: InvoiceComponentType
    var position: CGPoint
    var size: CGSize
    var style: ComponentStyle
    var isResizing: Bool = false // For resize state
    var parentSectionId: UUID? // Reference to parent section
    var children: [InvoiceComponent] = [] // For section types that can contain other components
    var isExpanded: Bool = true // For section types
    var title: String? // For section types

    enum CodingKeys: String, CodingKey {
        case id, type, position, size, style, isResizing, parentSectionId, children, isExpanded, title
    }

    init(id: UUID = UUID(), type: InvoiceComponentType, position: CGPoint = .zero, size: CGSize, style: ComponentStyle? = nil, parentSectionId: UUID? = nil, children: [InvoiceComponent] = [], isExpanded: Bool = true, title: String? = nil) {
        self.id = id
        self.type = type
        self.position = position
        self.size = size
        self.style = style ?? ComponentStyle.defaultStyle(for: type)
        self.isResizing = false
        self.parentSectionId = parentSectionId
        self.children = children.isEmpty && type.isSection ? Self.defaultChildren(for: type, parentId: id) : children
        self.isExpanded = isExpanded
        self.title = title ?? (type.isSection ? type.rawValue.capitalized : nil)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(InvoiceComponentType.self, forKey: .type)
        position = try container.decode(CGPoint.self, forKey: .position)
        size = try container.decode(CGSize.self, forKey: .size)
        style = try container.decodeIfPresent(ComponentStyle.self, forKey: .style) ?? ComponentStyle.defaultStyle(for: type)
        isResizing = try container.decodeIfPresent(Bool.self, forKey: .isResizing) ?? false
        parentSectionId = try container.decodeIfPresent(UUID.self, forKey: .parentSectionId)
        children = try container.decodeIfPresent([InvoiceComponent].self, forKey: .children) ?? []
        isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? (type.isSection ? type.rawValue.capitalized : nil)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(position, forKey: .position)
        try container.encode(size, forKey: .size)
        try container.encode(style, forKey: .style)
        try container.encode(isResizing, forKey: .isResizing)
        try container.encodeIfPresent(parentSectionId, forKey: .parentSectionId)
        try container.encode(children, forKey: .children)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encodeIfPresent(title, forKey: .title)
    }
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .invoiceComponent)
    }
    
    // MARK: - Default Children for Sections
    
    static func defaultChildren(for sectionType: InvoiceComponentType, parentId: UUID) -> [InvoiceComponent] {
        switch sectionType {
        case .invoiceNumberAndDates:
            return [
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 80, height: 30),
                    parentSectionId: parentId,
                    title: "Invoice #"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 80, height: 30),
                    parentSectionId: parentId,
                    title: "Date"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 80, height: 30),
                    parentSectionId: parentId,
                    title: "Due Date"
                )
            ]
            
        case .billTo:
            return [
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 200, height: 25),
                    parentSectionId: parentId,
                    title: "Customer Name"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 200, height: 25),
                    parentSectionId: parentId,
                    title: "Address Line 1"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 200, height: 25),
                    parentSectionId: parentId,
                    title: "Address Line 2"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 200, height: 25),
                    parentSectionId: parentId,
                    title: "Contact Info"
                )
            ]
            
        case .participant:
            return [
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 200, height: 25),
                    parentSectionId: parentId,
                    title: "Participant Name"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 200, height: 25),
                    parentSectionId: parentId,
                    title: "Participant ID"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 200, height: 25),
                    parentSectionId: parentId,
                    title: "Additional Info"
                )
            ]
            
        case .servicesTable:
            return [
                // Header row
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 60, height: 25),
                    parentSectionId: parentId,
                    title: "Qty"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 120, height: 25),
                    parentSectionId: parentId,
                    title: "Description"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 60, height: 25),
                    parentSectionId: parentId,
                    title: "Rate"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 70, height: 25),
                    parentSectionId: parentId,
                    title: "Amount"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 70, height: 25),
                    parentSectionId: parentId,
                    title: "Total"
                ),
                // Data row
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 60, height: 25),
                    parentSectionId: parentId,
                    title: "1"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 120, height: 25),
                    parentSectionId: parentId,
                    title: "Service Description"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 60, height: 25),
                    parentSectionId: parentId,
                    title: "$100"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 70, height: 25),
                    parentSectionId: parentId,
                    title: "$100"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 70, height: 25),
                    parentSectionId: parentId,
                    title: "$100"
                )
            ]
            
        case .totals:
            return [
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 100, height: 25),
                    parentSectionId: parentId,
                    title: "Subtotal"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 80, height: 25),
                    parentSectionId: parentId,
                    title: "$100.00"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 100, height: 25),
                    parentSectionId: parentId,
                    title: "Tax (10%)"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 80, height: 25),
                    parentSectionId: parentId,
                    title: "$10.00"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 100, height: 25),
                    parentSectionId: parentId,
                    title: "Total"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 80, height: 25),
                    parentSectionId: parentId,
                    title: "$110.00"
                )
            ]
            
        case .paymentDetails:
            return [
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 200, height: 25),
                    parentSectionId: parentId,
                    title: "Bank Name"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 200, height: 25),
                    parentSectionId: parentId,
                    title: "BSB & Account"
                ),
                InvoiceComponent(
                    type: .textBox,
                    size: CGSize(width: 200, height: 25),
                    parentSectionId: parentId,
                    title: "Account Name"
                )
            ]
            
        default:
            return []
        }
    }
}

extension ComponentStyle {
    static func defaultStyle(for type: InvoiceComponentType) -> ComponentStyle {
        var style = ComponentStyle()
        
        switch type {
        case .companyName:
            style.fontSize = 18
            style.fontWeight = "bold"
            style.textAlignment = .leading
            style.borderWidth = 0
        case .companyLogo:
            style.backgroundColor = "F5F5F5"
            style.borderWidth = 0
            style.imageContentMode = .fit
        case .companyABN:
            style.fontSize = 11
            style.fontWeight = "regular"
            style.textAlignment = .leading
            style.borderWidth = 0
        case .companyEmail:
            style.fontSize = 11
            style.fontWeight = "regular"
            style.textAlignment = .leading
            style.borderWidth = 0
        case .invoiceNumberAndDates:
            style.fontSize = 12
            style.fontWeight = "medium"
            style.backgroundColor = "F8F9FA"
            style.borderWidth = 1
            style.borderColor = "DEE2E6"
            style.cornerRadius = 4
            style.padding = 8
            style.sectionLayout = .horizontal
            style.contentSpacing = 0
            style.contentPadding = 6
        case .billTo:
            style.fontSize = 11
            style.fontWeight = "medium"
            style.backgroundColor = "F8F9FA"
            style.borderWidth = 1
            style.borderColor = "DEE2E6"
            style.cornerRadius = 4
            style.padding = 6
            style.sectionLayout = .vertical
            style.contentSpacing = 0
            style.contentPadding = 6
        case .participant:
            style.fontSize = 11
            style.fontWeight = "medium"
            style.backgroundColor = "F8F9FA"
            style.borderWidth = 1
            style.borderColor = "DEE2E6"
            style.cornerRadius = 4
            style.padding = 6
            style.sectionLayout = .vertical
            style.contentSpacing = 0
            style.contentPadding = 6
        case .servicesTable:
            style.backgroundColor = "FFFFFF" // Table has its own row colors
            style.borderWidth = 1
            style.borderColor = "D1D5DB"
            style.tableHeaderColor = "E5E7EB"
            style.tableRowColor = "FFFFFF"
            style.tableRowAltColor = "F9FAFB"
            style.tableTextColor = "111827"
            style.showTableHeader = true
            style.useAlternatingRows = false
            style.sectionLayout = .grid
            style.gridColumns = 5
            style.contentSpacing = 0
            style.contentPadding = 8
        case .totals:
            style.fontSize = 11
            style.fontWeight = "medium"
            style.backgroundColor = "F8F9FA"
            style.borderWidth = 1
            style.borderColor = "DEE2E6"
            style.cornerRadius = 4
            style.padding = 6
            style.sectionLayout = .grid
            style.gridColumns = 2
            style.contentSpacing = 0
            style.contentPadding = 6
        case .paymentDetails:
            style.fontSize = 11
            style.fontWeight = "medium"
            style.backgroundColor = "F8F9FA"
            style.borderWidth = 1
            style.borderColor = "DEE2E6"
            style.cornerRadius = 4
            style.padding = 6
            style.sectionLayout = .vertical
            style.contentSpacing = 0
            style.contentPadding = 6
        case .paymentTerms:
            style.fontSize = 9
            style.fontWeight = "regular"
            style.textAlignment = .leading
            style.borderWidth = 0
        case .invoiceTitle:
            style.fontSize = 16
            style.fontWeight = "bold"
            style.textAlignment = .center
            style.placeholderText = "TAX INVOICE"
            style.borderWidth = 0
        case .notes:
            style.fontSize = 9
            style.fontWeight = "regular"
            style.borderWidth = 0
        case .textBox:
            style.fontSize = 11
            style.fontWeight = "regular"
            style.placeholderText = "Text"
            style.padding = 6
            style.backgroundOpacity = 0.03
            style.textColor = "111111"
            style.borderWidth = 0
        case .rectangleShape:
            style.backgroundColor = "F3F4F6"
            style.backgroundOpacity = 1.0
            style.borderWidth = 0
            style.cornerRadius = 6
        case .ellipseShape:
            style.backgroundColor = "F3F4F6"
            style.backgroundOpacity = 1.0
            style.borderWidth = 0
        case .lineShape:
            // For lines, use borderColor for the line color and lineThickness for the width.
            // Background is irrelevant, and border is the line itself.
            style.backgroundColor = "000000"
            style.backgroundOpacity = 0.0 // No background fill
            style.borderWidth = 0 // No separate border
            style.borderColor = "333333"
            style.padding = 0
            style.lineThickness = 2
            style.lineStartDecorator = .none
            style.lineEndDecorator = .none
        case .triangleShape:
            style.backgroundColor = "F3F4F6"
            style.borderWidth = 0
            style.triangleDirection = .up
        case .starShape:
            style.backgroundColor = "F3F4F6"
            style.borderWidth = 0
            style.starPoints = 5
            style.starSmoothness = 0.38
        case .imagePlaceholder:
            style.backgroundColor = "F3F4F6"
            style.borderWidth = 0
            style.imageContentMode = .fit
        }
        
        return style
    }
}
