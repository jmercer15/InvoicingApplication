import Foundation
import CoreGraphics
import SwiftUI
import SharedUI

enum VerticalAlignmentOption: String, CaseIterable, Hashable, RawRepresentable, Codable {
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
enum TextAlignment: String, CaseIterable, Codable {
    case leading = "Leading"
    case center = "Center"
    case trailing = "Trailing"
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
        case .vertical:
            return "Stack children vertically"
        case .horizontal:
            return "Stack children horizontally"
        case .grid:
            return "Arrange children in a grid"
        }
    }
}
enum LineStyle: String, CaseIterable, Codable {
    case solid = "Solid"
    case dashed = "Dashed"
    case dotted = "Dotted"
}
struct ComponentStyle: Codable, Hashable {
    var fontSize: CGFloat = 14
    var fontWeight: String = "regular" 
    var fontFamily: String = "system" 
    var textColor: String = "000000" 
    var textAlignment: TextAlignment = .leading
    var lineSpacing: CGFloat = 1.0
    var letterSpacing: CGFloat = 0.0
    var backgroundColor: String = "FFFFFF" 
    var backgroundOpacity: CGFloat = 1.0
    var borderWidth: CGFloat = 1
    var borderColor: String = "CCCCCC"
    var cornerRadius: CGFloat = 0
    var padding: CGFloat = 0
    var margin: CGFloat = 0
    var shadowEnabled: Bool = false
    var shadowColor: String = "000000"
    var shadowOpacity: CGFloat = 0.3
    var shadowRadius: CGFloat = 4
    var shadowOffsetX: CGFloat = 0
    var shadowOffsetY: CGFloat = 2
    var placeholderText: String = ""
    var starPoints: Int = 5
    var starSmoothness: CGFloat = 0.38
    var starInnerRatio: CGFloat = 0.4
    var triangleDirection: TriangleDirection = .up
    var lineThickness: CGFloat = 2
    var lineStyle: LineStyle = .solid
    var lineStartDecorator: LineDecorator = .none
    var lineEndDecorator: LineDecorator = .none
    var imageData: Data?
    var imageContentMode: ImageContentMode = .fit
    var imageOpacity: CGFloat = 1.0
    var tableHeaderColor: String = "E5E7EB"
    var tableRowColor: String = "FFFFFF"
    var tableRowAltColor: String = "F9FAFB"
    var tableTextColor: String = "111827"
    var showTableHeader: Bool = true
    var useAlternatingRows: Bool = false
    var tableDirection: TableDirection = .horizontal
    var tableBorderWidth: CGFloat = 1.0
    var tableBorderColor: String = "D1D5DB"
    var tableHeaderBorderWidth: CGFloat = 1.0
    var tableHeaderBorderColor: String = "D1D5DB"
    var tableRowBorderWidth: CGFloat = 0.5
    var tableRowBorderColor: String = "E5E7EB"
    var tableCellPadding: CGFloat = 8.0
    var tableHeaderPadding: CGFloat = 8.0
    var showTableBorders: Bool = true
    var showHeaderBorder: Bool = true
    var showRowBorders: Bool = true
    var showCellBorders: Bool = false
    var sectionLayout: SectionLayout = .vertical
    var gridColumns: Int = 2
    var contentSpacing: CGFloat = 0
    var contentPadding: CGFloat = 12
    var columnConfigurations: [Int: ColumnConfiguration] = [:]
    var rowConfigurations: [Int: RowConfiguration] = [:]
    struct ColumnConfiguration: Codable, Hashable {
        var width: CGFloat = 100
        var isFlexible: Bool = true
        var isAutoSized: Bool = false
        var alignment: TextAlignment = .leading
        var verticalAlignmentOption: VerticalAlignmentOption = .center
        var headerAlignment: TextAlignment = .center
        var headerVerticalAlignmentOption: VerticalAlignmentOption = .center
        var lineLimit: Int = 1
        init(width: CGFloat = 100, isFlexible: Bool = true, alignment: TextAlignment = .leading, verticalAlignment: VerticalAlignment = .center, headerAlignment: TextAlignment = .center, headerVerticalAlignment: VerticalAlignment = .center, lineLimit: Int = 1) {
            self.width = width
            self.isFlexible = isFlexible
            self.alignment = alignment
            self.verticalAlignmentOption = VerticalAlignmentOption(verticalAlignment: verticalAlignment)
            self.headerAlignment = headerAlignment
            self.headerVerticalAlignmentOption = VerticalAlignmentOption(verticalAlignment: headerVerticalAlignment)
            self.lineLimit = lineLimit
        }
        var verticalAlignment: VerticalAlignment {
            return verticalAlignmentOption.verticalAlignment
        }
        var headerVerticalAlignment: VerticalAlignment {
            return headerVerticalAlignmentOption.verticalAlignment
        }
    }
    struct RowConfiguration: Codable, Hashable {
        var height: CGFloat = 50
        var isFlexible: Bool = true
        var isAutoSized: Bool = false
        var alignment: TextAlignment = .leading
        var verticalAlignmentOption: VerticalAlignmentOption = .center
        var headerAlignment: TextAlignment = .center
        var headerVerticalAlignmentOption: VerticalAlignmentOption = .center
        var lineLimit: Int = 1
        init(height: CGFloat = 50, isFlexible: Bool = true, alignment: TextAlignment = .leading, verticalAlignment: VerticalAlignment = .center, headerAlignment: TextAlignment = .center, headerVerticalAlignment: VerticalAlignment = .center, lineLimit: Int = 1) {
            self.height = height
            self.isFlexible = isFlexible
            self.alignment = alignment
            self.verticalAlignmentOption = VerticalAlignmentOption(verticalAlignment: verticalAlignment)
            self.headerAlignment = headerAlignment
            self.headerVerticalAlignmentOption = VerticalAlignmentOption(verticalAlignment: headerVerticalAlignment)
            self.lineLimit = lineLimit
        }
        var verticalAlignment: VerticalAlignment {
            return verticalAlignmentOption.verticalAlignment
        }
        var headerVerticalAlignment: VerticalAlignment {
            return headerVerticalAlignmentOption.verticalAlignment
        }
    }
    func columnConfiguration(for index: Int) -> ColumnConfiguration {
        return columnConfigurations[index] ?? ColumnConfiguration()
    }
    mutating func setColumnConfiguration(for index: Int, configuration: ColumnConfiguration) {
        columnConfigurations[index] = configuration
    }
    mutating func updateColumnWidth(for index: Int, width: CGFloat) {
        var config = columnConfiguration(for: index)
        config.width = width
        setColumnConfiguration(for: index, configuration: config)
    }
    mutating func updateColumnIsFlexible(for index: Int, isFlexible: Bool) {
        var config = columnConfiguration(for: index)
        config.isFlexible = isFlexible
        setColumnConfiguration(for: index, configuration: config)
    }
    mutating func updateColumnAutoSizing(for index: Int, isAutoSized: Bool) {
        var config = columnConfiguration(for: index)
        config.isAutoSized = isAutoSized
        setColumnConfiguration(for: index, configuration: config)
    }
    mutating func updateColumnAlignment(for index: Int, alignment: TextAlignment) {
        var config = columnConfiguration(for: index)
        config.alignment = alignment
        setColumnConfiguration(for: index, configuration: config)
    }
    mutating func updateColumnVerticalAlignment(for index: Int, verticalAlignment: VerticalAlignment) {
        var config = columnConfiguration(for: index)
        config.verticalAlignmentOption = VerticalAlignmentOption(verticalAlignment: verticalAlignment)
        setColumnConfiguration(for: index, configuration: config)
    }
    mutating func updateColumnHeaderAlignment(for index: Int, alignment: TextAlignment) {
        var config = columnConfiguration(for: index)
        config.headerAlignment = alignment
        setColumnConfiguration(for: index, configuration: config)
    }
    mutating func updateColumnHeaderVerticalAlignment(for index: Int, verticalAlignment: VerticalAlignment) {
        var config = columnConfiguration(for: index)
        config.headerVerticalAlignmentOption = VerticalAlignmentOption(verticalAlignment: verticalAlignment)
        setColumnConfiguration(for: index, configuration: config)
    }
    mutating func updateColumnLineLimit(for index: Int, lineLimit: Int) {
        var config = columnConfiguration(for: index)
        config.lineLimit = lineLimit
        setColumnConfiguration(for: index, configuration: config)
    }
    mutating func initializeColumnConfigurations(for columnCount: Int) {
        for i in 0..<columnCount {
            if columnConfigurations[i] == nil {
                let defaultAlignment: TextAlignment
                switch i {
                case 0: defaultAlignment = .leading
                case 1: defaultAlignment = .center
                case 2: defaultAlignment = .center
                default: defaultAlignment = .trailing
                }
                columnConfigurations[i] = ColumnConfiguration(
                    width: 100 + CGFloat(i * 25),
                    isFlexible: true,
                    alignment: defaultAlignment,
                    verticalAlignment: .center,
                    lineLimit: 1
                )
            }
        }
    }
    func rowConfiguration(for index: Int) -> RowConfiguration {
        return rowConfigurations[index] ?? RowConfiguration()
    }
    mutating func setRowConfiguration(for index: Int, configuration: RowConfiguration) {
        rowConfigurations[index] = configuration
    }
    mutating func updateRowHeight(for index: Int, height: CGFloat) {
        var config = rowConfiguration(for: index)
        config.height = height
        setRowConfiguration(for: index, configuration: config)
    }
    mutating func updateRowIsFlexible(for index: Int, isFlexible: Bool) {
        var config = rowConfiguration(for: index)
        config.isFlexible = isFlexible
        setRowConfiguration(for: index, configuration: config)
    }
    mutating func updateRowAutoSizing(for index: Int, isAutoSized: Bool) {
        var config = rowConfiguration(for: index)
        config.isAutoSized = isAutoSized
        setRowConfiguration(for: index, configuration: config)
    }
    mutating func updateRowAlignment(for index: Int, alignment: TextAlignment) {
        var config = rowConfiguration(for: index)
        config.alignment = alignment
        setRowConfiguration(for: index, configuration: config)
    }
    mutating func updateRowVerticalAlignment(for index: Int, verticalAlignment: VerticalAlignment) {
        var config = rowConfiguration(for: index)
        config.verticalAlignmentOption = VerticalAlignmentOption(verticalAlignment: verticalAlignment)
        setRowConfiguration(for: index, configuration: config)
    }
    mutating func updateRowHeaderAlignment(for index: Int, alignment: TextAlignment) {
        var config = rowConfiguration(for: index)
        config.headerAlignment = alignment
        setRowConfiguration(for: index, configuration: config)
    }
    mutating func updateRowHeaderVerticalAlignment(for index: Int, verticalAlignment: VerticalAlignment) {
        var config = rowConfiguration(for: index)
        config.headerVerticalAlignmentOption = VerticalAlignmentOption(verticalAlignment: verticalAlignment)
        setRowConfiguration(for: index, configuration: config)
    }
    mutating func updateRowLineLimit(for index: Int, lineLimit: Int) {
        var config = rowConfiguration(for: index)
        config.lineLimit = lineLimit
        setRowConfiguration(for: index, configuration: config)
    }
    mutating func initializeRowConfigurations(for rowCount: Int) {
        for i in 0..<rowCount {
            if rowConfigurations[i] == nil {
                let defaultAlignment: TextAlignment
                switch i {
                case 0: defaultAlignment = .leading
                case 1: defaultAlignment = .center
                case 2: defaultAlignment = .center
                default: defaultAlignment = .trailing
                }
                rowConfigurations[i] = RowConfiguration(
                    height: 50 + CGFloat(i * 10),
                    isFlexible: true,
                    alignment: defaultAlignment,
                    verticalAlignment: .center,
                    lineLimit: 1
                )
            }
        }
    }
    var cellPadding: CGFloat = 4
    var textUnderline: Bool = false
    var textStrikethrough: Bool = false
    var textTransform: TextTransform = .none
    var textOpacity: CGFloat = 1.0
    var aspectRatio: CGFloat = 0
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
    var tableBorderColorSwiftUI: Color {
        Color(hex: tableBorderColor)
    }
    var tableHeaderBorderColorSwiftUI: Color {
        Color(hex: tableHeaderBorderColor)
    }
    var tableRowBorderColorSwiftUI: Color {
        Color(hex: tableRowBorderColor)
    }
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
        style.cornerRadius = 8
        style.padding = 12
        style.shadowEnabled = false
        return style
    }
    func validate() -> [StyleValidationError] {
        var errors: [StyleValidationError] = []
        if fontSize < 6 || fontSize > 72 {
            errors.append(.invalidFontSize(fontSize))
        }
        if !isValidHexColor(textColor) {
            errors.append(.invalidColor(textColor, "text"))
        }
        if !isValidHexColor(backgroundColor) {
            errors.append(.invalidColor(backgroundColor, "background"))
        }
        if !isValidHexColor(borderColor) {
            errors.append(.invalidColor(borderColor, "border"))
        }
        if backgroundOpacity < 0 || backgroundOpacity > 1 {
            errors.append(.invalidOpacity(backgroundOpacity, "background"))
        }
        if shadowOpacity < 0 || shadowOpacity > 1 {
            errors.append(.invalidOpacity(shadowOpacity, "shadow"))
        }
        if borderWidth < 0 || borderWidth > 20 {
            errors.append(.invalidBorderWidth(borderWidth))
        }
        if cornerRadius < 0 || cornerRadius > 50 {
            errors.append(.invalidCornerRadius(cornerRadius))
        }
        if shadowRadius < 0 || shadowRadius > 50 {
            errors.append(.invalidShadowRadius(shadowRadius))
        }
        return errors
    }
    private func isValidHexColor(_ hex: String) -> Bool {
        let hexRegex = "^[0-9A-Fa-f]{6}$"
        return NSPredicate(format: "SELF MATCHES %@", hexRegex).evaluate(with: hex)
    }
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
    func withTextAlignment(_ alignment: TextAlignment) -> ComponentStyle {
        var style = self
        style.textAlignment = alignment
        return style
    }
    func withPadding(_ padding: CGFloat) -> ComponentStyle {
        var style = self
        style.padding = padding
        return style
    }
    func withBackgroundOpacity(_ opacity: CGFloat) -> ComponentStyle {
        var style = self
        style.backgroundOpacity = opacity
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
    func withPlaceholderText(_ text: String) -> ComponentStyle {
        var style = self
        style.placeholderText = text
        return style
    }
    func withSectionLayout(_ layout: SectionLayout) -> ComponentStyle {
        var style = self
        style.sectionLayout = layout
        return style
    }
    func withContentSpacing(_ spacing: CGFloat) -> ComponentStyle {
        var style = self
        style.contentSpacing = spacing
        return style
    }
    func withContentPadding(_ padding: CGFloat) -> ComponentStyle {
        var style = self
        style.contentPadding = padding
        return style
    }
    func withFontFamily(_ family: String) -> ComponentStyle {
        var style = self
        style.fontFamily = family
        return style
    }
    func withLineSpacing(_ spacing: CGFloat) -> ComponentStyle {
        var style = self
        style.lineSpacing = spacing
        return style
    }
    func withLetterSpacing(_ spacing: CGFloat) -> ComponentStyle {
        var style = self
        style.letterSpacing = spacing
        return style
    }
    func withTextOpacity(_ opacity: CGFloat) -> ComponentStyle {
        var style = self
        style.textOpacity = opacity
        return style
    }
    func withTextUnderline(_ underline: Bool) -> ComponentStyle {
        var style = self
        style.textUnderline = underline
        return style
    }
    func withTextStrikethrough(_ strikethrough: Bool) -> ComponentStyle {
        var style = self
        style.textStrikethrough = strikethrough
        return style
    }
    func withTextTransform(_ transform: TextTransform) -> ComponentStyle {
        var style = self
        style.textTransform = transform
        return style
    }
    func withBorderWidth(_ width: CGFloat) -> ComponentStyle {
        var style = self
        style.borderWidth = width
        return style
    }
    func withBorderColor(_ color: String) -> ComponentStyle {
        var style = self
        style.borderColor = color
        return style
    }
    func withShadowEnabled(_ enabled: Bool) -> ComponentStyle {
        var style = self
        style.shadowEnabled = enabled
        return style
    }
    func withShadowRadius(_ radius: CGFloat) -> ComponentStyle {
        var style = self
        style.shadowRadius = radius
        return style
    }
    func withShadowOpacity(_ opacity: CGFloat) -> ComponentStyle {
        var style = self
        style.shadowOpacity = opacity
        return style
    }
    func withShadowOffset(_ x: CGFloat, y: CGFloat) -> ComponentStyle {
        var style = self
        style.shadowOffsetX = x
        style.shadowOffsetY = y
        return style
    }
    func withShadowColor(_ color: String) -> ComponentStyle {
        var style = self
        style.shadowColor = color
        return style
    }
    func withGridColumns(_ columns: Int) -> ComponentStyle {
        var style = self
        style.gridColumns = columns
        return style
    }
    func withTableDirection(_ direction: TableDirection) -> ComponentStyle {
        var style = self
        style.tableDirection = direction
        return style
    }
    func withLineThickness(_ thickness: CGFloat) -> ComponentStyle {
        var style = self
        style.lineThickness = thickness
        return style
    }
    func withLineStartDecorator(_ decorator: LineDecorator) -> ComponentStyle {
        var style = self
        style.lineStartDecorator = decorator
        return style
    }
    func withLineEndDecorator(_ decorator: LineDecorator) -> ComponentStyle {
        var style = self
        style.lineEndDecorator = decorator
        return style
    }
    func withTriangleDirection(_ direction: TriangleDirection) -> ComponentStyle {
        var style = self
        style.triangleDirection = direction
        return style
    }
    func withImageContentMode(_ mode: ImageContentMode) -> ComponentStyle {
        var style = self
        style.imageContentMode = mode
        return style
    }
    func withStarPoints(_ points: Int) -> ComponentStyle {
        var style = self
        style.starPoints = points
        return style
    }
    func withStarSmoothness(_ smoothness: CGFloat) -> ComponentStyle {
        var style = self
        style.starSmoothness = smoothness
        return style
    }
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
        hasher.combine(tableDirection)
        hasher.combine(tableBorderWidth)
        hasher.combine(tableBorderColor)
        hasher.combine(tableHeaderBorderWidth)
        hasher.combine(tableHeaderBorderColor)
        hasher.combine(tableRowBorderWidth)
        hasher.combine(tableRowBorderColor)
        hasher.combine(tableCellPadding)
        hasher.combine(tableHeaderPadding)
        hasher.combine(showTableBorders)
        hasher.combine(showHeaderBorder)
        hasher.combine(showRowBorders)
        hasher.combine(showCellBorders)
        hasher.combine(sectionLayout)
        hasher.combine(gridColumns)
        hasher.combine(contentSpacing)
        hasher.combine(contentPadding)
        hasher.combine(columnConfigurations)
        hasher.combine(cellPadding)
    }
    static func == (lhs: ComponentStyle, rhs: ComponentStyle) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}
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
                .withPadding(8)
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
                .withPadding(8)
        case .invoiceNumberAndDates:
            return cleanTable
                .withFontSize(10)
                .withFontWeight("regular")
                .withTextColor("374151")
                .withSectionLayout(.grid)
                .withGridColumns(2)
                .withContentSpacing(0)
                .withContentPadding(8)
                .withTableDirection(.vertical)
                .withUseAlternatingRows(false)
        case .billTo, .participant:
            return cleanTable
                .withFontSize(10)
                .withFontWeight("regular")
                .withTextColor("374151")
                .withSectionLayout(.grid)
                .withGridColumns(2)
                .withContentSpacing(0)
                .withContentPadding(8)
                .withTableDirection(.vertical)
                .withUseAlternatingRows(false)
        case .servicesTable:
            return cleanTable
                .withFontSize(10)
                .withFontWeight("regular")
                .withTextColor("374151")
                .withSectionLayout(.grid)
                .withGridColumns(4)
                .withContentSpacing(0)
                .withContentPadding(8)
                .withTableDirection(.horizontal)
                .withColumnAlignment(.leading, for: 0)
                .withColumnAlignment(.center, for: 1)
                .withColumnAlignment(.center, for: 2)
                .withColumnAlignment(.trailing, for: 3)
                .withUseAlternatingRows(false)
        case .documentGrid:
            return cleanTable
                .withFontSize(10)
                .withFontWeight("regular")
                .withTextColor("374151")
                .withSectionLayout(.grid)
                .withGridColumns(4)
                .withContentSpacing(0)
                .withContentPadding(8)
                .withBorder(1.0, color: "D1D5DB")
                .withColumnAlignment(.leading, for: 0)
                .withColumnAlignment(.center, for: 1)
                .withColumnAlignment(.center, for: 2)
                .withColumnAlignment(.trailing, for: 3)
                .withUseAlternatingRows(false)
        case .totals:
            return cleanTable
                .withFontSize(10)
                .withFontWeight("regular")
                .withTextColor("374151")
                .withSectionLayout(.grid)
                .withGridColumns(2)
                .withContentSpacing(0)
                .withContentPadding(8)
                .withTableDirection(.vertical)
                .withUseAlternatingRows(false)
        case .paymentDetails:
            return cleanTable
                .withFontSize(10)
                .withFontWeight("regular")
                .withTextColor("374151")
                .withSectionLayout(.grid)
                .withGridColumns(2)
                .withContentSpacing(0)
                .withContentPadding(8)
                .withTableDirection(.vertical)
                .withUseAlternatingRows(false)
        case .paymentTerms:
            return ComponentStyle()
                .withFontSize(9)
                .withFontWeight("regular")
                .withTextColor("6B7280")
                .withTextAlignment(.leading)
                .withBorder(0, color: "000000")
                .withPadding(10)
        case .invoiceTitle:
            return modernHeader
                .withFontSize(22)
                .withTextColor("1F2937")
                .withTextAlignment(.center)
                .withPlaceholderText("TAX INVOICE")
                .withBorder(0, color: "000000")
                .withPadding(10)
        case .notes:
            return ComponentStyle()
                .withFontSize(9)
                .withFontWeight("regular")
                .withTextColor("6B7280")
                .withTextAlignment(.leading)
                .withBorder(0, color: "000000")
                .withPlaceholderText("Notes or additional information...")
                .withPadding(10)
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
    func withColumnAlignment(_ alignment: TextAlignment, for columnIndex: Int) -> ComponentStyle {
        var style = self
        style.updateColumnAlignment(for: columnIndex, alignment: alignment)
        return style
    }
    func withUseAlternatingRows(_ enabled: Bool) -> ComponentStyle {
        var style = self
        style.useAlternatingRows = enabled
        return style
    }
}

