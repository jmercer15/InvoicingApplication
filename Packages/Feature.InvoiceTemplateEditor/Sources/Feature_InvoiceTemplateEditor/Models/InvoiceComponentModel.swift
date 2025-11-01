import Foundation
import CoreGraphics
import CoreTransferable
import UniformTypeIdentifiers
import SwiftUI

// MARK: - Alignment Helpers

enum VerticalAlignmentOption: String, CaseIterable, Hashable, Codable {
    case top = "top"
    case center = "center"
    case bottom = "bottom"
    case firstTextBaseline = "firstTextBaseline"
    case lastTextBaseline = "lastTextBaseline"

    var verticalAlignment: VerticalAlignment {
        switch self {
        case .top: return .top
        case .center: return .center
        case .bottom: return .bottom
        case .firstTextBaseline: return .firstTextBaseline
        case .lastTextBaseline: return .lastTextBaseline
        }
    }

    init(verticalAlignment: VerticalAlignment) {
        switch verticalAlignment {
        case .top: self = .top
        case .center: self = .center
        case .bottom: self = .bottom
        case .firstTextBaseline: self = .firstTextBaseline
        case .lastTextBaseline: self = .lastTextBaseline
        default: self = .center
        }
    }
}

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

enum TableDirection: String, CaseIterable, Codable {
    case horizontal = "horizontal"
    case vertical = "vertical"

    var displayName: String {
        switch self {
        case .horizontal: return "Horizontal (Headers as First Row)"
        case .vertical: return "Vertical (Headers as First Column)"
        }
    }
}

enum InvoiceComponentType: String, CaseIterable, Identifiable, Codable {
    case invoiceNumberAndDates = "Invoice Number & Dates"
    case billTo = "Bill To"
    case participant = "Participant"
    case servicesTable = "Services Table"
    case documentGrid = "Document Grid"
    case totals = "Totals"
    case paymentDetails = "Payment Details"

    case paymentTerms = "Payment Terms"
    case invoiceTitle = "Invoice Title"
    case companyName = "Company Name"
    case companyABN = "Company ABN"
    case companyEmail = "Company Email"
    case companyLogo = "Company Logo"

    case notes = "Notes"

    case textBox = "Text Box"
    case rectangleShape = "Rectangle"
    case ellipseShape = "Ellipse"
    case lineShape = "Line"
    case triangleShape = "Triangle"
    case starShape = "Star"
    case imagePlaceholder = "Image Placeholder"

    var id: String { rawValue }

    var isSection: Bool {
        switch self {
        case .invoiceNumberAndDates, .billTo, .participant, .servicesTable, .documentGrid, .totals, .paymentDetails:
            return true
        default:
            return false
        }
    }

    var defaultSize: CGSize {
        switch self {
        case .invoiceNumberAndDates: return CGSize(width: 280, height: 45)
        case .billTo: return CGSize(width: 220, height: 60)
        case .participant: return CGSize(width: 220, height: 45)
        case .servicesTable: return CGSize(width: 380, height: 90)
        case .documentGrid: return CGSize(width: 400, height: 120)
        case .totals: return CGSize(width: 280, height: 70)
        case .paymentDetails: return CGSize(width: 280, height: 70)
        case .paymentTerms: return CGSize(width: 280, height: 45)
        case .invoiceTitle: return CGSize(width: 180, height: 30)
        case .companyName: return CGSize(width: 220, height: 45)
        case .companyABN: return CGSize(width: 180, height: 30)
        case .companyEmail: return CGSize(width: 180, height: 30)
        case .companyLogo: return CGSize(width: 80, height: 80)
        case .notes: return CGSize(width: 280, height: 70)
        case .textBox: return CGSize(width: 180, height: 30)
        case .rectangleShape: return CGSize(width: 160, height: 60)
        case .ellipseShape: return CGSize(width: 120, height: 60)
        case .lineShape: return CGSize(width: 280, height: 6)
        case .triangleShape: return CGSize(width: 100, height: 80)
        case .starShape: return CGSize(width: 100, height: 100)
        case .imagePlaceholder: return CGSize(width: 140, height: 90)
        }
    }
}

enum TextAlignment: String, CaseIterable, Codable {
    case leading = "Leading"
    case center = "Center"
    case trailing = "Trailing"

    var swiftUIAlignment: SwiftUI.TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .leading: return .topLeading
        case .center: return .top
        case .trailing: return .topTrailing
        }
    }
}

enum TextTransform: String, CaseIterable, Codable {
    case none = "None"
    case uppercase = "Uppercase"
    case lowercase = "Lowercase"
    case capitalize = "Capitalize"
}

enum SectionLayout: String, CaseIterable, Codable {
    case vertical = "Vertical Stack"
    case horizontal = "Horizontal Stack"
    case grid = "Grid"

    var description: String {
        switch self {
        case .vertical: return "Stack children vertically"
        case .horizontal: return "Stack children horizontally"
        case .grid: return "Arrange children in a grid"
        }
    }
}

enum LineStyle: String, CaseIterable, Codable {
    case solid = "Solid"
    case dashed = "Dashed"
    case dotted = "Dotted"
}

// MARK: - Invoice Component

struct InvoiceComponent: Identifiable, Codable, Transferable,
    TypographyStylable, BackgroundStylable, BorderStylable, LayoutStylable,
    ShadowStylable, ContentStylable, ImageStylable, ShapeStylable,
    TableStylable, SectionStylable, EffectsStylable {

    var id: UUID
    let type: InvoiceComponentType
    var position: CGPoint
    var size: CGSize
    var isResizing: Bool
    var isVisible: Bool
    var isLocked: Bool

    var typographyStyle: TypographyStyle?
    var backgroundStyle: BackgroundStyle?
    var borderStyle: BorderStyle?
    var layoutStyle: LayoutStyle?
    var shadowStyle: ShadowStyle?
    var contentStyle: ContentStyle?
    var imageStyle: ImageStyle?
    var shapeStyle: ShapeStyle?
    var tableStyle: TableStyle?
    var sectionStyle: SectionStyle?
    var effectsStyle: EffectsStyle?

    init(
        id: UUID = UUID(),
        type: InvoiceComponentType,
        position: CGPoint = .zero,
        size: CGSize? = nil,
        typographyStyle: TypographyStyle? = nil,
        backgroundStyle: BackgroundStyle? = nil,
        borderStyle: BorderStyle? = nil,
        layoutStyle: LayoutStyle? = nil,
        shadowStyle: ShadowStyle? = nil,
        contentStyle: ContentStyle? = nil,
        imageStyle: ImageStyle? = nil,
        shapeStyle: ShapeStyle? = nil,
        tableStyle: TableStyle? = nil,
        sectionStyle: SectionStyle? = nil,
        effectsStyle: EffectsStyle? = nil,
        isVisible: Bool = true,
        isLocked: Bool = false
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.size = size ?? type.defaultSize
        self.isResizing = false
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.typographyStyle = typographyStyle
        self.backgroundStyle = backgroundStyle
        self.borderStyle = borderStyle
        self.layoutStyle = layoutStyle
        self.shadowStyle = shadowStyle
        self.contentStyle = contentStyle
        self.imageStyle = imageStyle
        self.shapeStyle = shapeStyle
        self.tableStyle = tableStyle
        self.sectionStyle = sectionStyle
        self.effectsStyle = effectsStyle

        applyDefaultStyles()
    }

    private mutating func applyDefaultStyles() {
        switch type {
        case .companyName:
            typographyStyle = typographyStyle ?? TypographyStyle(
                fontSize: 20,
                fontWeight: "bold",
                fontFamily: "system",
                textColor: "1F2937",
                textAlignment: .leading
            )
            backgroundStyle = backgroundStyle ?? BackgroundStyle(color: "FFFFFF", opacity: 1.0)
            borderStyle = borderStyle ?? BorderStyle(width: 0, color: "000000", cornerRadius: 0)
            layoutStyle = layoutStyle ?? LayoutStyle(padding: 8, margin: 0)

        case .companyABN, .companyEmail:
            typographyStyle = typographyStyle ?? TypographyStyle(
                fontSize: 10,
                fontWeight: "regular",
                fontFamily: "system",
                textColor: "6B7280",
                textAlignment: .leading
            )
            backgroundStyle = backgroundStyle ?? BackgroundStyle(color: "FFFFFF", opacity: 1.0)
            borderStyle = borderStyle ?? BorderStyle(width: 0, color: "000000", cornerRadius: 0)
            layoutStyle = layoutStyle ?? LayoutStyle(padding: 8, margin: 0)

        case .invoiceTitle:
            typographyStyle = typographyStyle ?? TypographyStyle(
                fontSize: 22,
                fontWeight: "bold",
                fontFamily: "system",
                textColor: "1F2937",
                textAlignment: .center
            )
            contentStyle = contentStyle ?? ContentStyle(placeholderText: "TAX INVOICE")
            backgroundStyle = backgroundStyle ?? BackgroundStyle(color: "FFFFFF", opacity: 1.0)
            borderStyle = borderStyle ?? BorderStyle(width: 0, color: "000000", cornerRadius: 0)
            layoutStyle = layoutStyle ?? LayoutStyle(padding: 10, margin: 0)

        case .paymentTerms:
            typographyStyle = typographyStyle ?? TypographyStyle(
                fontSize: 9,
                fontWeight: "regular",
                fontFamily: "system",
                textColor: "6B7280",
                textAlignment: .leading
            )
            contentStyle = contentStyle ?? ContentStyle(placeholderText: "Payment due within 30 days of invoice date")
            layoutStyle = layoutStyle ?? LayoutStyle(padding: 10, margin: 0)

        case .notes:
            typographyStyle = typographyStyle ?? TypographyStyle(
                fontSize: 9,
                fontWeight: "regular",
                fontFamily: "system",
                textColor: "6B7280",
                textAlignment: .leading
            )
            contentStyle = contentStyle ?? ContentStyle(placeholderText: "Notes or additional information...")
            layoutStyle = layoutStyle ?? LayoutStyle(padding: 10, margin: 0)

        case .textBox:
            typographyStyle = typographyStyle ?? TypographyStyle(
                fontSize: 11,
                fontWeight: "regular",
                fontFamily: "system",
                textColor: "374151",
                textAlignment: .leading
            )
            contentStyle = contentStyle ?? ContentStyle(placeholderText: "Enter text here...")
            backgroundStyle = backgroundStyle ?? BackgroundStyle(color: "FFFFFF", opacity: 0.05)
            borderStyle = borderStyle ?? BorderStyle(width: 0, color: "000000", cornerRadius: 4)
            layoutStyle = layoutStyle ?? LayoutStyle(padding: 8, margin: 0)

        case .companyLogo, .imagePlaceholder:
            backgroundStyle = backgroundStyle ?? BackgroundStyle(color: "F9FAFB", opacity: 1.0)
            borderStyle = borderStyle ?? BorderStyle(width: type == .imagePlaceholder ? 2 : 1, color: "E5E7EB", cornerRadius: 8)
            imageStyle = imageStyle ?? ImageStyle(contentMode: .fit, opacity: 1.0)
            shadowStyle = shadowStyle ?? ShadowStyle(isEnabled: true, color: "000000", opacity: 0.05, radius: 4, offsetX: 0, offsetY: 2)

        case .rectangleShape, .ellipseShape, .triangleShape, .starShape:
            backgroundStyle = backgroundStyle ?? BackgroundStyle(color: "E5E7EB", opacity: 1.0)
            borderStyle = borderStyle ?? BorderStyle(width: 1, color: "D1D5DB", cornerRadius: type == .rectangleShape ? 8 : 0)
            shadowStyle = shadowStyle ?? ShadowStyle(isEnabled: true, color: "000000", opacity: 0.1, radius: 4, offsetX: 0, offsetY: 2)
            shapeStyle = shapeStyle ?? ShapeStyle()

        case .lineShape:
            backgroundStyle = backgroundStyle ?? BackgroundStyle(color: "000000", opacity: 0)
            borderStyle = borderStyle ?? BorderStyle(width: 0, color: "374151", cornerRadius: 0)
            shapeStyle = shapeStyle ?? ShapeStyle(lineThickness: 2, lineStyle: .solid, lineStartDecorator: .none, lineEndDecorator: .none)

        case .invoiceNumberAndDates, .billTo, .participant, .totals, .paymentDetails:
            typographyStyle = typographyStyle ?? TypographyStyle(
                fontSize: 10,
                fontWeight: "regular",
                fontFamily: "system",
                textColor: "374151",
                textAlignment: .leading
            )
            tableStyle = tableStyle ?? TableStyle(
                headerColor: "F9FAFB",
                rowColor: "FFFFFF",
                alternateRowColor: "F9FAFB",
                textColor: "374151",
                showHeader: true,
                useAlternatingRows: false,
                direction: .vertical
            )
            sectionStyle = sectionStyle ?? SectionStyle(layout: .grid, gridColumns: type == .totals ? 2 : 2, contentSpacing: 0, contentPadding: 8)
            borderStyle = borderStyle ?? BorderStyle(width: 0, color: "000000", cornerRadius: 0)

        case .servicesTable:
            typographyStyle = typographyStyle ?? TypographyStyle(
                fontSize: 10,
                fontWeight: "regular",
                fontFamily: "system",
                textColor: "374151",
                textAlignment: .leading
            )
            tableStyle = tableStyle ?? TableStyle(
                headerColor: "F9FAFB",
                rowColor: "FFFFFF",
                alternateRowColor: "F9FAFB",
                textColor: "374151",
                showHeader: true,
                useAlternatingRows: false,
                direction: .horizontal
            )
            sectionStyle = sectionStyle ?? SectionStyle(layout: .grid, gridColumns: 4, contentSpacing: 0, contentPadding: 8)

        case .documentGrid:
            typographyStyle = typographyStyle ?? TypographyStyle(
                fontSize: 10,
                fontWeight: "regular",
                fontFamily: "system",
                textColor: "374151",
                textAlignment: .leading
            )
            tableStyle = tableStyle ?? TableStyle(
                headerColor: "F9FAFB",
                rowColor: "FFFFFF",
                alternateRowColor: "F9FAFB",
                textColor: "374151",
                showHeader: true,
                useAlternatingRows: false,
                direction: .horizontal,
                borderWidth: 1.0,
                borderColor: "D1D5DB"
            )
            sectionStyle = sectionStyle ?? SectionStyle(layout: .grid, gridColumns: 4, contentSpacing: 0, contentPadding: 8)

        }

        layoutStyle = layoutStyle ?? LayoutStyle()
        shadowStyle = shadowStyle ?? ShadowStyle()
        effectsStyle = effectsStyle ?? EffectsStyle()
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, type, position, size, isResizing, isVisible, isLocked
        case typographyStyle, backgroundStyle, borderStyle, layoutStyle
        case shadowStyle, contentStyle, imageStyle, shapeStyle
        case tableStyle, sectionStyle, effectsStyle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(InvoiceComponentType.self, forKey: .type)
        position = try container.decode(CGPoint.self, forKey: .position)
        size = try container.decode(CGSize.self, forKey: .size)
        isResizing = try container.decodeIfPresent(Bool.self, forKey: .isResizing) ?? false
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        typographyStyle = try container.decodeIfPresent(TypographyStyle.self, forKey: .typographyStyle)
        backgroundStyle = try container.decodeIfPresent(BackgroundStyle.self, forKey: .backgroundStyle)
        borderStyle = try container.decodeIfPresent(BorderStyle.self, forKey: .borderStyle)
        layoutStyle = try container.decodeIfPresent(LayoutStyle.self, forKey: .layoutStyle)
        shadowStyle = try container.decodeIfPresent(ShadowStyle.self, forKey: .shadowStyle)
        contentStyle = try container.decodeIfPresent(ContentStyle.self, forKey: .contentStyle)
        imageStyle = try container.decodeIfPresent(ImageStyle.self, forKey: .imageStyle)
        shapeStyle = try container.decodeIfPresent(ShapeStyle.self, forKey: .shapeStyle)
        tableStyle = try container.decodeIfPresent(TableStyle.self, forKey: .tableStyle)
        sectionStyle = try container.decodeIfPresent(SectionStyle.self, forKey: .sectionStyle)
        effectsStyle = try container.decodeIfPresent(EffectsStyle.self, forKey: .effectsStyle)
        applyDefaultStyles()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(position, forKey: .position)
        try container.encode(size, forKey: .size)
        try container.encode(isResizing, forKey: .isResizing)
        try container.encode(isVisible, forKey: .isVisible)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encodeIfPresent(typographyStyle, forKey: .typographyStyle)
        try container.encodeIfPresent(backgroundStyle, forKey: .backgroundStyle)
        try container.encodeIfPresent(borderStyle, forKey: .borderStyle)
        try container.encodeIfPresent(layoutStyle, forKey: .layoutStyle)
        try container.encodeIfPresent(shadowStyle, forKey: .shadowStyle)
        try container.encodeIfPresent(contentStyle, forKey: .contentStyle)
        try container.encodeIfPresent(imageStyle, forKey: .imageStyle)
        try container.encodeIfPresent(shapeStyle, forKey: .shapeStyle)
        try container.encodeIfPresent(tableStyle, forKey: .tableStyle)
        try container.encodeIfPresent(sectionStyle, forKey: .sectionStyle)
        try container.encodeIfPresent(effectsStyle, forKey: .effectsStyle)
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .invoiceComponent)
    }

    var frame: CGRect {
        CGRect(
            x: position.x - (size.width / 2),
            y: position.y - (size.height / 2),
            width: size.width,
            height: size.height
        )
    }

    var boundingRect: CGRect { frame }
}

// MARK: - Table Helpers

extension InvoiceComponent {
    mutating func initializeColumnConfigurations(columnCount: Int) {
        guard var tableStyle else { return }
        for index in 0..<columnCount {
            if tableStyle.columnConfigurations[index] == nil {
                let defaultAlignment: TextAlignment
                switch index {
                case 0: defaultAlignment = .leading
                case 1, 2: defaultAlignment = .center
                default: defaultAlignment = .trailing
                }
                tableStyle.columnConfigurations[index] = TableStyle.ColumnConfiguration(
                    width: 100 + CGFloat(index * 25),
                    isFlexible: true,
                    alignment: defaultAlignment,
                    verticalAlignment: .center,
                    headerAlignment: .center,
                    headerVerticalAlignment: .center,
                    lineLimit: 1
                )
            }
        }
        self.tableStyle = tableStyle
    }

    mutating func initializeRowConfigurations(rowCount: Int) {
        guard var tableStyle else { return }
        for index in 0..<rowCount {
            if tableStyle.rowConfigurations[index] == nil {
                let defaultAlignment: TextAlignment
                switch index {
                case 0: defaultAlignment = .leading
                case 1, 2: defaultAlignment = .center
                default: defaultAlignment = .trailing
                }
                tableStyle.rowConfigurations[index] = TableStyle.RowConfiguration(
                    height: 50 + CGFloat(index * 10),
                    isFlexible: true,
                    alignment: defaultAlignment,
                    verticalAlignment: .center,
                    headerAlignment: .center,
                    headerVerticalAlignment: .center,
                    lineLimit: 1
                )
            }
        }
        self.tableStyle = tableStyle
    }
}

*** End Patch
