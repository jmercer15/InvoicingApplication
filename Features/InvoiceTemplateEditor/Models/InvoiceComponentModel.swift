
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

struct ComponentStyle: Codable, Hashable {
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

    // MARK: - Computed Properties for SwiftUI

    var backgroundColorSwiftUI: Color {
        Color(hex: backgroundColor).opacity(backgroundOpacity)
    }

    var borderColorSwiftUI: Color {
        Color(hex: borderColor)
    }

    var textColorSwiftUI: Color {
        Color(hex: textColor)
    }

    var shadowColorSwiftUI: Color {
        Color(hex: shadowColor).opacity(shadowOpacity)
    }

    var tableHeaderColorSwiftUI: Color {
        Color(hex: tableHeaderColor)
    }

    var tableRowColorSwiftUI: Color {
        Color(hex: tableRowColor)
    }

    var tableRowAltColorSwiftUI: Color {
        Color(hex: tableRowAltColor)
    }

    var tableTextColorSwiftUI: Color {
        Color(hex: tableTextColor)
    }

    // MARK: - Professional Style Presets

    static var professionalInvoice: ComponentStyle {
        var style = ComponentStyle()
        style.fontFamily = "system"
        style.textColor = "1F2937"
        style.backgroundColor = "FFFFFF"
        style.borderColor = "E5E7EB"
        style.cornerRadius = 6
        style.shadowEnabled = true
        style.shadowColor = "000000"
        style.shadowOpacity = 0.1
        style.shadowRadius = 8
        style.shadowOffsetY = 2
        return style
    }

    static var modernHeader: ComponentStyle {
        var style = ComponentStyle()
        style.fontSize = 24
        style.fontWeight = "bold"
        style.fontFamily = "system"
        style.textColor = "1F2937"
        style.textAlignment = .center
        style.backgroundColor = "FFFFFF"
        style.borderWidth = 0
        return style
    }

    static var cleanTable: ComponentStyle {
        var style = ComponentStyle()
        style.fontSize = 11
        style.fontWeight = "regular"
        style.fontFamily = "system"
        style.textColor = "374151"
        style.backgroundColor = "FFFFFF"
        style.borderColor = "E5E7EB"
        style.borderWidth = 1
        style.tableHeaderColor = "F9FAFB"
        style.tableRowColor = "FFFFFF"
        style.tableRowAltColor = "F9FAFB"
        style.tableTextColor = "374151"
        style.showTableHeader = true
        style.useAlternatingRows = true
        return style
    }

    static var subtleSection: ComponentStyle {
        var style = ComponentStyle()
        style.fontSize = 12
        style.fontWeight = "medium"
        style.fontFamily = "system"
        style.textColor = "6B7280"
        style.backgroundColor = "F9FAFB"
        style.borderColor = "E5E7EB"
        style.borderWidth = 1
        style.borderStyle = .solid
        style.cornerRadius = 8
        style.padding = 12
        style.shadowEnabled = false
        return style
    }

    // MARK: - Validation

    func validate() -> [StyleValidationError] {
        var errors: [StyleValidationError] = []

        // Font size validation
        if fontSize < 6 || fontSize > 72 {
            errors.append(.invalidFontSize(fontSize))
        }

        // Color validation
        if !isValidHexColor(textColor) {
            errors.append(.invalidColor(textColor, "text"))
        }
        if !isValidHexColor(backgroundColor) {
            errors.append(.invalidColor(backgroundColor, "background"))
        }
        if !isValidHexColor(borderColor) {
            errors.append(.invalidColor(borderColor, "border"))
        }

        // Opacity validation
        if backgroundOpacity < 0 || backgroundOpacity > 1 {
            errors.append(.invalidOpacity(backgroundOpacity, "background"))
        }
        if shadowOpacity < 0 || shadowOpacity > 1 {
            errors.append(.invalidOpacity(shadowOpacity, "shadow"))
        }

        // Size validation
        if borderWidth < 0 || borderWidth > 20 {
            errors.append(.invalidBorderWidth(borderWidth))
        }
        if cornerRadius < 0 || cornerRadius > 50 {
            errors.append(.invalidCornerRadius(cornerRadius))
        }

        // Shadow validation
        if shadowRadius < 0 || shadowRadius > 50 {
            errors.append(.invalidShadowRadius(shadowRadius))
        }

        return errors
    }

    private func isValidHexColor(_ hex: String) -> Bool {
        let hexRegex = "^[0-9A-Fa-f]{6}$"
        return NSPredicate(format: "SELF MATCHES %@", hexRegex).evaluate(with: hex)
    }

    // MARK: - Utility Methods

    func withFontSize(_ size: CGFloat) -> ComponentStyle {
        var style = self
        style.fontSize = size
        return style
    }

    func withFontWeight(_ weight: String) -> ComponentStyle {
        var style = self
        style.fontWeight = weight
        return style
    }

    func withTextColor(_ color: String) -> ComponentStyle {
        var style = self
        style.textColor = color
        return style
    }

    func withBackgroundColor(_ color: String) -> ComponentStyle {
        var style = self
        style.backgroundColor = color
        return style
    }

    func withBorder(_ width: CGFloat, color: String) -> ComponentStyle {
        var style = self
        style.borderWidth = width
        style.borderColor = color
        return style
    }

    func withCornerRadius(_ radius: CGFloat) -> ComponentStyle {
        var style = self
        style.cornerRadius = radius
        return style
    }

    func withShadow(enabled: Bool = true, color: String = "000000", radius: CGFloat = 4, opacity: CGFloat = 0.3) -> ComponentStyle {
        var style = self
        style.shadowEnabled = enabled
        style.shadowColor = color
        style.shadowRadius = radius
        style.shadowOpacity = opacity
        return style
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(fontSize)
        hasher.combine(fontWeight)
        hasher.combine(fontFamily)
        hasher.combine(textColor)
        hasher.combine(textAlignment)
        hasher.combine(lineSpacing)
        hasher.combine(letterSpacing)
        hasher.combine(backgroundColor)
        hasher.combine(backgroundOpacity)
        hasher.combine(borderWidth)
        hasher.combine(borderColor)
        hasher.combine(borderStyle)
        hasher.combine(cornerRadius)
        hasher.combine(padding)
        hasher.combine(margin)
        hasher.combine(shadowEnabled)
        hasher.combine(shadowColor)
        hasher.combine(shadowOpacity)
        hasher.combine(shadowRadius)
        hasher.combine(shadowOffsetX)
        hasher.combine(shadowOffsetY)
        hasher.combine(placeholderText)
        hasher.combine(starPoints)
        hasher.combine(starSmoothness)
        hasher.combine(triangleDirection)
        hasher.combine(lineThickness)
        hasher.combine(lineStartDecorator)
        hasher.combine(lineEndDecorator)
        hasher.combine(imageContentMode)
        hasher.combine(tableHeaderColor)
        hasher.combine(tableRowColor)
        hasher.combine(tableRowAltColor)
        hasher.combine(tableTextColor)
        hasher.combine(showTableHeader)
        hasher.combine(useAlternatingRows)
        hasher.combine(sectionLayout)
        hasher.combine(gridColumns)
        hasher.combine(contentSpacing)
        hasher.combine(contentPadding)
    }

    static func == (lhs: ComponentStyle, rhs: ComponentStyle) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

// MARK: - Validation Error

enum StyleValidationError: LocalizedError {
    case invalidFontSize(CGFloat)
    case invalidColor(String, String)
    case invalidOpacity(CGFloat, String)
    case invalidBorderWidth(CGFloat)
    case invalidCornerRadius(CGFloat)
    case invalidShadowRadius(CGFloat)

    var errorDescription: String? {
        switch self {
        case .invalidFontSize(let size):
            return "Font size \(size)pt is not valid (must be between 6-72pt)"
        case .invalidColor(let color, let type):
            return "Invalid \(type) color: \(color) (must be 6-digit hex)"
        case .invalidOpacity(let opacity, let type):
            return "Invalid \(type) opacity: \(opacity) (must be between 0-1)"
        case .invalidBorderWidth(let width):
            return "Border width \(width)pt is not valid (must be between 0-20pt)"
        case .invalidCornerRadius(let radius):
            return "Corner radius \(radius)pt is not valid (must be between 0-50pt)"
        case .invalidShadowRadius(let radius):
            return "Shadow radius \(radius)pt is not valid (must be between 0-50pt)"
        }
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
        switch type {
        case .companyName:
            return modernHeader
                .withFontSize(20)
                .withTextColor("1F2937")
                .withFontWeight("bold")
                .withTextAlignment(.leading)
                .withBorder(0, color: "000000")

        case .companyLogo:
            return ComponentStyle()
                .withBackgroundColor("F9FAFB")
                .withBorder(1, color: "E5E7EB")
                .withCornerRadius(8)
                .withImageContentMode(.fit)

        case .companyABN, .companyEmail:
            return ComponentStyle()
                .withFontSize(10)
                .withFontWeight("regular")
                .withTextColor("6B7280")
                .withTextAlignment(.leading)
                .withBorder(0, color: "000000")

        case .invoiceNumberAndDates:
            return subtleSection
                .withFontSize(11)
                .withFontWeight("medium")
                .withTextColor("374151")
                .withSectionLayout(.horizontal)
                .withContentSpacing(12)
                .withContentPadding(10)

        case .billTo, .participant:
            return subtleSection
                .withFontSize(10)
                .withFontWeight("medium")
                .withTextColor("374151")
                .withSectionLayout(.vertical)
                .withContentSpacing(4)
                .withContentPadding(8)

        case .servicesTable:
            return cleanTable
                .withFontSize(10)
                .withFontWeight("regular")
                .withTextColor("374151")
                .withSectionLayout(.grid)
                .withGridColumns(5)
                .withContentSpacing(0)
                .withContentPadding(8)

        case .totals:
            return subtleSection
                .withFontSize(10)
                .withFontWeight("semibold")
                .withTextColor("1F2937")
                .withBackgroundColor("F3F4F6")
                .withSectionLayout(.grid)
                .withGridColumns(2)
                .withContentSpacing(8)
                .withContentPadding(10)

        case .paymentDetails:
            return subtleSection
                .withFontSize(10)
                .withFontWeight("medium")
                .withTextColor("374151")
                .withSectionLayout(.vertical)
                .withContentSpacing(4)
                .withContentPadding(8)

        case .paymentTerms:
            return ComponentStyle()
                .withFontSize(9)
                .withFontWeight("regular")
                .withTextColor("6B7280")
                .withTextAlignment(.leading)
                .withBorder(0, color: "000000")

        case .invoiceTitle:
            return modernHeader
                .withFontSize(22)
                .withTextColor("1F2937")
                .withTextAlignment(.center)
                .withPlaceholderText("TAX INVOICE")
                .withBorder(0, color: "000000")

        case .notes:
            return ComponentStyle()
                .withFontSize(9)
                .withFontWeight("regular")
                .withTextColor("6B7280")
                .withTextAlignment(.leading)
                .withBorder(0, color: "000000")
                .withPlaceholderText("Notes or additional information...")

        case .textBox:
            return ComponentStyle()
                .withFontSize(11)
                .withFontWeight("regular")
                .withTextColor("374151")
                .withPlaceholderText("Enter text here...")
                .withPadding(8)
                .withBackgroundColor("FFFFFF")
                .withBackgroundOpacity(0.05)
                .withBorder(0, color: "000000")
                .withCornerRadius(4)

        case .rectangleShape:
            return ComponentStyle()
                .withBackgroundColor("E5E7EB")
                .withBackgroundOpacity(1.0)
                .withBorder(1, color: "D1D5DB")
                .withCornerRadius(8)
                .withShadow(enabled: true, color: "000000", radius: 4, opacity: 0.1)

        case .ellipseShape:
            return ComponentStyle()
                .withBackgroundColor("E5E7EB")
                .withBackgroundOpacity(1.0)
                .withBorder(1, color: "D1D5DB")
                .withShadow(enabled: true, color: "000000", radius: 4, opacity: 0.1)

        case .lineShape:
            return ComponentStyle()
                .withBackgroundColor("000000")
                .withBackgroundOpacity(0.0)
                .withBorder(0, color: "374151")
                .withPadding(0)
                .withLineThickness(2)
                .withLineStartDecorator(.none)
                .withLineEndDecorator(.none)

        case .triangleShape:
            return ComponentStyle()
                .withBackgroundColor("E5E7EB")
                .withBackgroundOpacity(1.0)
                .withBorder(1, color: "D1D5DB")
                .withTriangleDirection(.up)
                .withShadow(enabled: true, color: "000000", radius: 4, opacity: 0.1)

        case .starShape:
            return ComponentStyle()
                .withBackgroundColor("E5E7EB")
                .withBackgroundOpacity(1.0)
                .withBorder(1, color: "D1D5DB")
                .withStarPoints(5)
                .withStarSmoothness(0.38)
                .withShadow(enabled: true, color: "000000", radius: 4, opacity: 0.1)

        case .imagePlaceholder:
            return ComponentStyle()
                .withBackgroundColor("F9FAFB")
                .withBorder(2, color: "E5E7EB")
                .withCornerRadius(8)
                .withImageContentMode(.fit)
                .withShadow(enabled: true, color: "000000", radius: 4, opacity: 0.05)
        }
    }

    // MARK: - Helper Methods for Chainable Style Creation

    private func withPlaceholderText(_ text: String) -> ComponentStyle {
        var style = self
        style.placeholderText = text
        return style
    }

    private func withTextAlignment(_ alignment: TextAlignment) -> ComponentStyle {
        var style = self
        style.textAlignment = alignment
        return style
    }

    private func withImageContentMode(_ mode: ImageContentMode) -> ComponentStyle {
        var style = self
        style.imageContentMode = mode
        return style
    }

    private func withSectionLayout(_ layout: SectionLayout) -> ComponentStyle {
        var style = self
        style.sectionLayout = layout
        return style
    }

    private func withGridColumns(_ columns: Int) -> ComponentStyle {
        var style = self
        style.gridColumns = columns
        return style
    }

    private func withLineThickness(_ thickness: CGFloat) -> ComponentStyle {
        var style = self
        style.lineThickness = thickness
        return style
    }

    private func withLineStartDecorator(_ decorator: LineDecorator) -> ComponentStyle {
        var style = self
        style.lineStartDecorator = decorator
        return style
    }

    private func withLineEndDecorator(_ decorator: LineDecorator) -> ComponentStyle {
        var style = self
        style.lineEndDecorator = decorator
        return style
    }

    private func withTriangleDirection(_ direction: TriangleDirection) -> ComponentStyle {
        var style = self
        style.triangleDirection = direction
        return style
    }

    private func withStarPoints(_ points: Int) -> ComponentStyle {
        var style = self
        style.starPoints = points
        return style
    }

    private func withStarSmoothness(_ smoothness: CGFloat) -> ComponentStyle {
        var style = self
        style.starSmoothness = smoothness
        return style
    }
}
