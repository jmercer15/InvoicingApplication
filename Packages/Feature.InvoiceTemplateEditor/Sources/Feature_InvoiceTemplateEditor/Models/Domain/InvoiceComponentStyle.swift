import Foundation
import CoreGraphics
import SwiftUI
import SharedUI

public enum VerticalAlignmentOption: String, CaseIterable, Hashable, RawRepresentable, Codable, Sendable {
    case top = "top"
    case center = "center"
    case bottom = "bottom"
    case firstTextBaseline = "firstTextBaseline"
    case lastTextBaseline = "lastTextBaseline"
    public var verticalAlignment: VerticalAlignment {
        switch self {
        case .top: return .top
        case .center: return .center
        case .bottom: return .bottom
        case .firstTextBaseline: return .firstTextBaseline
        case .lastTextBaseline: return .lastTextBaseline
        }
    }
    public init(verticalAlignment: VerticalAlignment) {
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
public enum LineDecorator: String, CaseIterable, Codable, Sendable {
    case none = "None"
    case arrow = "Arrow"
    case circle = "Circle"
    case square = "Square"
}
public enum ImageContentMode: String, CaseIterable, Codable, Sendable {
    case fit = "Fit"
    case fill = "Fill"
    
    /// Converts to SwiftUI's ContentMode
    public var swiftUIContentMode: ContentMode {
        switch self {
        case .fit: return .fit
        case .fill: return .fill
        }
    }
}
public enum ComponentSizingMode: String, CaseIterable, Codable, Sendable {
    case fixed = "Fixed"
    case fill = "Fill"
    case auto = "Auto"
}
public enum TriangleDirection: String, CaseIterable, Codable, Sendable {
    case up = "Up"
    case down = "Down"
    case left = "Left"
    case right = "Right"
}
public enum TableDirection: String, CaseIterable, Codable, Sendable {
    case horizontal = "horizontal"
    case vertical = "vertical"
    public var displayName: String {
        switch self {
        case .horizontal: return "Horizontal (Headers as First Row)"
        case .vertical: return "Vertical (Headers as First Column)"
        }
    }
}
public enum TextTransform: String, CaseIterable, Codable, Sendable {
    case none = "None"
    case uppercase = "Uppercase"
    case lowercase = "Lowercase"
    case capitalize = "Capitalize"
    
    /// Applies this text transformation to the given string.
    public func apply(to text: String) -> String {
        switch self {
        case .none: return text
        case .uppercase: return text.uppercased()
        case .lowercase: return text.lowercased()
        case .capitalize: return text.capitalized
        }
    }
}
public enum SectionLayout: String, CaseIterable, Codable, Sendable {
    case vertical = "Vertical Stack"
    case horizontal = "Horizontal Stack"
    case grid = "Grid"
    public var description: String {
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
public enum LineStyle: String, CaseIterable, Codable, Sendable {
    case solid = "Solid"
    case dashed = "Dashed"
    case dotted = "Dotted"
}
public enum TextAlignment: String, CaseIterable, Codable, Sendable {
    case leading = "Leading"
    case center = "Center"
    case trailing = "Trailing"
}
public struct ComponentStyle: Codable, Hashable, Sendable {
    public var fontSize: CGFloat = 14
    public var fontWeight: String = "regular" 
    public var fontFamily: String = "system" 
    public var textColor: String = "000000" 
    public var textAlignment: TextAlignment = .leading
    public var lineSpacing: CGFloat = 1.0
    public var letterSpacing: CGFloat = 0.0
    public var backgroundColor: String = "FFFFFF" 
    public var backgroundOpacity: CGFloat = 1.0
    public var borderWidth: CGFloat = 1
    public var borderColor: String = "CCCCCC"
    public var cornerRadius: CGFloat = 0
    public var padding: CGFloat = 0
    public var margin: CGFloat = 0
    public var shadowEnabled: Bool = false
    public var shadowColor: String = "000000"
    public var shadowOpacity: CGFloat = 0.3
    public var shadowRadius: CGFloat = 4
    public var shadowOffsetX: CGFloat = 0
    public var shadowOffsetY: CGFloat = 2
    public var placeholderText: String = ""
    public var starPoints: Int = 5
    public var starSmoothness: CGFloat = 0.38
    public var starInnerRatio: CGFloat = 0.4
    public var triangleDirection: TriangleDirection = .up
    public var lineThickness: CGFloat = 2
    public var lineStyle: LineStyle = .solid
    public var lineStartDecorator: LineDecorator = .none
    public var lineEndDecorator: LineDecorator = .none
    public var imageData: Data?
    public var imageContentMode: ImageContentMode = .fit
    public var imageWidth: CGFloat = 0
    public var imageHeight: CGFloat = 0
    public var imageWidthMode: ComponentSizingMode? = .auto
    public var imageHeightMode: ComponentSizingMode? = .auto
    public var imageMinWidth: CGFloat?
    public var imageMaxWidth: CGFloat?
    public var imageMinHeight: CGFloat?
    public var imageMaxHeight: CGFloat?
    public var imageOpacity: CGFloat = 1.0
    public var tableHeaderColor: String = "E5E7EB"
    public var tableRowColor: String = "FFFFFF"
    public var tableRowAltColor: String = "F9FAFB"
    public var tableTextColor: String = "111827"
    /// Empty string indicates the header should inherit the regular table text color
    public var tableHeaderTextColor: String = ""
    public var showTableHeader: Bool = true
    public var useAlternatingRows: Bool = false
    public var tableDirection: TableDirection = .horizontal
    public var tableBorderWidth: CGFloat = 1.0
    public var tableBorderColor: String = "D1D5DB"
    public var tableHeaderBorderWidth: CGFloat = 1.0
    public var tableHeaderBorderColor: String = "D1D5DB"
    public var tableRowBorderWidth: CGFloat = 0.5
    public var tableRowBorderColor: String = "E5E7EB"
    public var tableCellPadding: CGFloat = 8.0
    public var tableHeaderPadding: CGFloat = 8.0
    public var showTableBorders: Bool = true
    public var showHeaderBorder: Bool = true
    public var showRowBorders: Bool = true
    public var showCellBorders: Bool = false
    public var sectionLayout: SectionLayout = .vertical
    public var gridColumns: Int = 2
    public var contentSpacing: CGFloat = 0
    public var contentPadding: CGFloat = 12
    public var columnConfigurations: [Int: ColumnConfiguration] = [:]
    public var rowConfigurations: [Int: RowConfiguration] = [:]
    public var sectionTitle: String = ""
    public var sectionTitleFontSize: CGFloat = 18
    public var sectionTitleColor: String = "000000"
    public var sectionTitleAlignment: TextAlignment = .leading
    public var sectionTitleFontWeight: String = "bold"
    public var sectionTitleItalic: Bool = false
    public var sectionTitleFontFamily: String = "system"
    public var sectionTitleBottomPadding: CGFloat = 4
    public var sectionTitleLetterSpacing: CGFloat = 0
    public var sectionTitleTextTransform: TextTransform = .none
    public var sectionTitleUnderline: Bool = false
    public var sectionTitleUnderlineStyle: Int = 1  // 1=single, 2=thick, 9=double
    public var sectionTitleStrikethrough: Bool = false
    
    // CoreText Typography
    public var sectionTitleFontDesign: String = "default" // default, serif, rounded, monospaced
    public var sectionTitleFontWidth: String = "standard" // compressed, condensed, standard, expanded
    public var sectionTitleMonospaced: Bool = false
    public var sectionTitleMonospacedDigit: Bool = false
    public var sectionTitleTracking: CGFloat = 0
    public var sectionTitleBaselineOffset: CGFloat = 0
    public var sectionTitleTextScale: String = "default" // default, secondary
    
    // CoreText Ligatures (kCTLigatureAttributeName)
    public var sectionTitleLigatures: Int = 1  // 0=none, 1=default, 2=all
    
    // CoreText Stroke (kCTStrokeWidthAttributeName, kCTStrokeColorAttributeName)
    public var sectionTitleStrokeWidth: CGFloat = 0
    public var sectionTitleStrokeColor: String = "#000000"
    
    // CoreText Superscript (kCTSuperscriptAttributeName)
    public var sectionTitleSuperscript: Int = 0  // -1=subscript, 0=normal, 1=superscript
    
    // CoreText Writing Direction (kCTWritingDirectionAttributeName)
    public var sectionTitleWritingDirection: Int = 0  // 0=natural, 1=LTR, 2=RTL
    
    // Underline (CoreText native)
    public var sectionTitleUnderlineColor: String = "" // Empty means inherit text color
    public var sectionTitleUnderlinePattern: Int = 0 // 0=solid, 0x0100=dot, 0x0200=dash, 0x0300=dashDot
    
    // Visibility Control
    public var hiddenFields: Set<String> = []
    
    public enum TableAxis: String, Codable, Sendable {
        case column
        case row
    }

    public struct TableAxisConfiguration: Codable, Hashable, Sendable {
        public var size: CGFloat = 100
        public var isFlexible: Bool = true
        public var isAutoSized: Bool = false
        public var alignment: TextAlignment = .leading
        public var verticalAlignmentOption: VerticalAlignmentOption = .center
        public var headerAlignment: TextAlignment = .center
        public var headerVerticalAlignmentOption: VerticalAlignmentOption = .center
        public var lineLimit: Int = 1
        
        public init(size: CGFloat = 100, isFlexible: Bool = true, alignment: TextAlignment = .leading, verticalAlignment: VerticalAlignment = .center, headerAlignment: TextAlignment = .center, headerVerticalAlignment: VerticalAlignment = .center, lineLimit: Int = 1) {
            self.size = size
            self.isFlexible = isFlexible
            self.alignment = alignment
            self.verticalAlignmentOption = VerticalAlignmentOption(verticalAlignment: verticalAlignment)
            self.headerAlignment = headerAlignment
            self.headerVerticalAlignmentOption = VerticalAlignmentOption(verticalAlignment: headerVerticalAlignment)
            self.lineLimit = lineLimit
        }
        
        // Legacy support for 'width' (ColumnConfiguration)
        public init(width: CGFloat, isFlexible: Bool = true, alignment: TextAlignment = .leading, verticalAlignment: VerticalAlignment = .center, headerAlignment: TextAlignment = .center, headerVerticalAlignment: VerticalAlignment = .center, lineLimit: Int = 1) {
            self.init(size: width, isFlexible: isFlexible, alignment: alignment, verticalAlignment: verticalAlignment, headerAlignment: headerAlignment, headerVerticalAlignment: headerVerticalAlignment, lineLimit: lineLimit)
        }

        // Legacy support for 'height' (RowConfiguration)
        public init(height: CGFloat, isFlexible: Bool = true, alignment: TextAlignment = .leading, verticalAlignment: VerticalAlignment = .center, headerAlignment: TextAlignment = .center, headerVerticalAlignment: VerticalAlignment = .center, lineLimit: Int = 1) {
            self.init(size: height, isFlexible: isFlexible, alignment: alignment, verticalAlignment: verticalAlignment, headerAlignment: headerAlignment, headerVerticalAlignment: headerVerticalAlignment, lineLimit: lineLimit)
        }
        
        // Backward compatibility for JSON decoding
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // Try decoding 'size' first
            if let size = try? container.decode(CGFloat.self, forKey: .size) {
                self.size = size
            } else if let width = try? container.decode(CGFloat.self, forKey: .width) {
                 // Fallback: try decoding 'width' (old ColumnConfiguration)
                self.size = width
            } else if let height = try? container.decode(CGFloat.self, forKey: .height) {
                // Fallback: try decoding 'height' (old RowConfiguration)
                self.size = height
            } else {
                self.size = 100 // Default
            }
            
            self.isFlexible = try container.decodeIfPresent(Bool.self, forKey: .isFlexible) ?? true
            self.isAutoSized = try container.decodeIfPresent(Bool.self, forKey: .isAutoSized) ?? false
            self.alignment = try container.decodeIfPresent(TextAlignment.self, forKey: .alignment) ?? .leading
            self.verticalAlignmentOption = try container.decodeIfPresent(VerticalAlignmentOption.self, forKey: .verticalAlignmentOption) ?? .center
            self.headerAlignment = try container.decodeIfPresent(TextAlignment.self, forKey: .headerAlignment) ?? .center
            self.headerVerticalAlignmentOption = try container.decodeIfPresent(VerticalAlignmentOption.self, forKey: .headerVerticalAlignmentOption) ?? .center
            self.lineLimit = try container.decodeIfPresent(Int.self, forKey: .lineLimit) ?? 1
        }
        
        // Manual encoding to ensure we write 'size' going forward, 
        // OR we could write both for safety, but let's stick to 'size'.
        // The default encode implementation is fine as it uses the property names.
        
        // Custom CodingKeys to support legacy keys
        enum CodingKeys: String, CodingKey {
            case size, width, height
            case isFlexible, isAutoSized, alignment, verticalAlignmentOption, headerAlignment, headerVerticalAlignmentOption, lineLimit
        }
        
        public var verticalAlignment: VerticalAlignment {
            return verticalAlignmentOption.verticalAlignment
        }
        public var headerVerticalAlignment: VerticalAlignment {
            return headerVerticalAlignmentOption.verticalAlignment
        }
        
        // Compatibility computed properties for ease of refactoring (optional, but helpful)
        public var width: CGFloat {
            get { size }
            set { size = newValue }
        }
        public var height: CGFloat {
            get { size }
            set { size = newValue }
        }
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(size, forKey: .size)
            try container.encode(isFlexible, forKey: .isFlexible)
            try container.encode(isAutoSized, forKey: .isAutoSized)
            try container.encode(alignment, forKey: .alignment)
            try container.encode(verticalAlignmentOption, forKey: .verticalAlignmentOption)
            try container.encode(headerAlignment, forKey: .headerAlignment)
            try container.encode(headerVerticalAlignmentOption, forKey: .headerVerticalAlignmentOption)
            try container.encode(lineLimit, forKey: .lineLimit)
        }
    }
    
    // Typealiases for backward compatibility in other files (temporarily)
    public typealias ColumnConfiguration = TableAxisConfiguration
    public typealias RowConfiguration = TableAxisConfiguration
    
    public struct CellStyle: Codable, Hashable, Sendable {
        public var textColor: String?
        public var backgroundColor: String?
        public var alignment: TextAlignment?
        public var verticalAlignmentOption: VerticalAlignmentOption?
        public var fontSize: CGFloat?
        public var fontWeight: String?
        public var textTransform: TextTransform?
    
        public var lineLimit: Int?
        
        public var verticalAlignment: VerticalAlignment? {
            verticalAlignmentOption?.verticalAlignment
        }
        
        public init(
            textColor: String? = nil,
            backgroundColor: String? = nil,
            alignment: TextAlignment? = nil,
            verticalAlignmentOption: VerticalAlignmentOption? = nil,
            fontSize: CGFloat? = nil,
            fontWeight: String? = nil,
            textTransform: TextTransform? = nil,
            lineLimit: Int? = nil
        ) {
            self.textColor = textColor
            self.backgroundColor = backgroundColor
            self.alignment = alignment
            self.verticalAlignmentOption = verticalAlignmentOption
            self.fontSize = fontSize
            self.fontWeight = fontWeight
            self.textTransform = textTransform
            self.lineLimit = lineLimit
        }
    }
    
    public init() {}
    
    public func configuration(for axis: TableAxis, at index: Int) -> TableAxisConfiguration {
        switch axis {
        case .column:
            return columnConfigurations[index] ?? TableAxisConfiguration(size: 100)
        case .row:
            return rowConfigurations[index] ?? TableAxisConfiguration(size: 50)
        }
    }
    
    mutating func setConfiguration(_ config: TableAxisConfiguration, for axis: TableAxis, at index: Int) {
        switch axis {
        case .column:
            columnConfigurations[index] = config
        case .row:
            rowConfigurations[index] = config
        }
    }
    
    // Generic Mutators
    mutating func updateAxisConfiguration(for axis: TableAxis, at index: Int, keyPath: WritableKeyPath<TableAxisConfiguration, some Any>, value: some Any) {
        var config = configuration(for: axis, at: index)
        
        // This helper is tricky with generics and keypaths in Swift inside a mutating func without direct enforcement.
        // Instead, let's keep specific helpers but generalized implementation.
        // Actually, we can just expose specific updates that call setConfiguration.
    }
    
    mutating func updateAxisSize(for axis: TableAxis, at index: Int, size: CGFloat) {
        var config = configuration(for: axis, at: index)
        config.size = size
        setConfiguration(config, for: axis, at: index)
    }
    
    mutating func updateAxisIsFlexible(for axis: TableAxis, at index: Int, isFlexible: Bool) {
        var config = configuration(for: axis, at: index)
        config.isFlexible = isFlexible
        if isFlexible { config.isAutoSized = false }
        setConfiguration(config, for: axis, at: index)
    }
    
    mutating func updateAxisAutoSizing(for axis: TableAxis, at index: Int, isAutoSized: Bool) {
        var config = configuration(for: axis, at: index)
        config.isAutoSized = isAutoSized
        if isAutoSized { config.isFlexible = false }
        setConfiguration(config, for: axis, at: index)
    }
    
    mutating func updateAxisAlignment(for axis: TableAxis, at index: Int, alignment: TextAlignment) {
        var config = configuration(for: axis, at: index)
        config.alignment = alignment
        setConfiguration(config, for: axis, at: index)
    }

    mutating func updateAxisVerticalAlignment(for axis: TableAxis, at index: Int, verticalAlignment: VerticalAlignment) {
        var config = configuration(for: axis, at: index)
        config.verticalAlignmentOption = VerticalAlignmentOption(verticalAlignment: verticalAlignment)
        setConfiguration(config, for: axis, at: index)
    }
    
    mutating func updateAxisHeaderAlignment(for axis: TableAxis, at index: Int, alignment: TextAlignment) {
        var config = configuration(for: axis, at: index)
        config.headerAlignment = alignment
        setConfiguration(config, for: axis, at: index)
    }

    mutating func updateAxisHeaderVerticalAlignment(for axis: TableAxis, at index: Int, verticalAlignment: VerticalAlignment) {
        var config = configuration(for: axis, at: index)
        config.headerVerticalAlignmentOption = VerticalAlignmentOption(verticalAlignment: verticalAlignment)
        setConfiguration(config, for: axis, at: index)
    }
    
    mutating func updateAxisLineLimit(for axis: TableAxis, at index: Int, lineLimit: Int) {
        var config = configuration(for: axis, at: index)
        config.lineLimit = lineLimit
        setConfiguration(config, for: axis, at: index)
    }

    // Deprecated helpers to maintain some call site compatibility or easily refactor
    func columnConfiguration(for index: Int) -> TableAxisConfiguration {
        return configuration(for: .column, at: index)
    }
    mutating func setColumnConfiguration(for index: Int, configuration: TableAxisConfiguration) {
        setConfiguration(configuration, for: .column, at: index)
    }
    func rowConfiguration(for index: Int) -> TableAxisConfiguration {
        return configuration(for: .row, at: index)
    }
    mutating func setRowConfiguration(for index: Int, configuration: TableAxisConfiguration) {
        setConfiguration(configuration, for: .row, at: index)
    }

    mutating func initializeColumnConfigurations(for columnCount: Int) {
        for i in 0..<columnCount {
            if columnConfigurations[i] == nil {
                let defaultAlignment: TextAlignment = (i == 0) ? .leading : (i < 3) ? .center : .trailing
                let config = TableAxisConfiguration(
                    size: 100 + CGFloat(i * 25),
                    isFlexible: true,
                    alignment: defaultAlignment,
                    verticalAlignment: .center,
                    lineLimit: 1
                )
                setConfiguration(config, for: .column, at: i)
            }
        }
    }
    
    mutating func initializeRowConfigurations(for rowCount: Int) {
        for i in 0..<rowCount {
            if rowConfigurations[i] == nil {
                let defaultAlignment: TextAlignment = (i == 0) ? .leading : (i < 3) ? .center : .trailing
                let config = TableAxisConfiguration(
                    size: 50 + CGFloat(i * 10),
                    isFlexible: true,
                    alignment: defaultAlignment,
                    verticalAlignment: .center,
                    lineLimit: 1
                )
                setConfiguration(config, for: .row, at: i)
            }
        }
    }
    
    var cellStyles: [String: CellStyle] = [:]
    
    func cellStyle(row: Int, column: Int) -> CellStyle? {
        return cellStyles["\(row):\(column)"]
    }
    
    mutating func updateCellStyle(row: Int, column: Int, style: CellStyle) {
        cellStyles["\(row):\(column)"] = style
    }
    
    mutating func updateCellTextColor(row: Int, column: Int, color: String?) {
        var style = cellStyles["\(row):\(column)"] ?? CellStyle()
        style.textColor = color
        cellStyles["\(row):\(column)"] = style
    }
    
    mutating func updateCellBackgroundColor(row: Int, column: Int, color: String?) {
        var style = cellStyles["\(row):\(column)"] ?? CellStyle()
        style.backgroundColor = color
        cellStyles["\(row):\(column)"] = style
    }
    
    mutating func updateCellAlignment(row: Int, column: Int, alignment: TextAlignment?) {
        var style = cellStyles["\(row):\(column)"] ?? CellStyle()
        style.alignment = alignment
        cellStyles["\(row):\(column)"] = style
    }
    
    mutating func updateCellStyles(rows: ClosedRange<Int>, columns: ClosedRange<Int>, update: (inout CellStyle) -> Void) {
        for row in rows {
            for col in columns {
                var style = cellStyles["\(row):\(col)"] ?? CellStyle()
                update(&style)
                cellStyles["\(row):\(col)"] = style
            }
        }
    }
    var cellPadding: CGFloat = 4
    var textUnderline: Bool = false
    var textStrikethrough: Bool = false
    var textTransform: TextTransform = .none
    var textOpacity: CGFloat = 1.0
    var italic: Bool = false
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
    var tableHeaderTextColorSwiftUI: Color {
        Color(hex: tableHeaderTextColor.isEmpty ? tableTextColor : tableHeaderTextColor)
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
    // MARK: - Generic Builder Method
    
    /// Generic builder method that replaces 50+ individual withX() methods.
    /// Usage: style.with(\.fontSize, 16).with(\.fontWeight, "bold")
    func with<T>(_ keyPath: WritableKeyPath<ComponentStyle, T>, _ value: T) -> ComponentStyle {
        var style = self
        style[keyPath: keyPath] = value
        return style
    }
    
    // MARK: - Multi-Property Convenience Builders
    
    /// Sets both border width and color in one call
    func withBorder(_ width: CGFloat, color: String) -> ComponentStyle {
        with(\.borderWidth, width).with(\.borderColor, color)
    }
    
    /// Configures shadow with multiple properties at once
    func withShadow(enabled: Bool = true, color: String = "000000", radius: CGFloat = 4, opacity: CGFloat = 0.3) -> ComponentStyle {
        with(\.shadowEnabled, enabled)
            .with(\.shadowColor, color)
            .with(\.shadowRadius, radius)
            .with(\.shadowOpacity, opacity)
    }
    
    /// Sets both shadow offset X and Y
    func withShadowOffset(_ x: CGFloat, y: CGFloat) -> ComponentStyle {
        with(\.shadowOffsetX, x).with(\.shadowOffsetY, y)
    }

    /// Sets hidden fields
    func withHiddenFields(_ fields: Set<String>) -> ComponentStyle {
        with(\.hiddenFields, fields)
    }

    public func hash(into hasher: inout Hasher) {
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
        hasher.combine(imageWidth)
        hasher.combine(imageHeight)
        hasher.combine(imageWidthMode)
        hasher.combine(imageHeightMode)
        hasher.combine(imageMinWidth)
        hasher.combine(imageMaxWidth)
        hasher.combine(imageMinHeight)
        hasher.combine(imageMaxHeight)
        hasher.combine(tableHeaderColor)
        hasher.combine(tableRowColor)
        hasher.combine(tableRowAltColor)
        hasher.combine(tableTextColor)
        hasher.combine(tableHeaderTextColor)
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
        hasher.combine(sectionTitle)
        hasher.combine(sectionTitleFontSize)
        hasher.combine(sectionTitleColor)
        hasher.combine(sectionTitleAlignment)
        hasher.combine(sectionTitleFontWeight)
        hasher.combine(sectionTitleFontFamily)
        hasher.combine(sectionTitleBottomPadding)
        hasher.combine(sectionTitleLetterSpacing)
        hasher.combine(sectionTitleTextTransform)
        hasher.combine(hiddenFields)
    }
    public static func == (lhs: ComponentStyle, rhs: ComponentStyle) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

extension ComponentStyle {
    static func defaultStyle(for type: InvoiceComponentType) -> ComponentStyle {
        switch type {
        case .companyName:
            return modernHeader
                .with(\.fontSize, 20)
                .with(\.textColor, "1F2937")
                .with(\.fontWeight, "bold")
                .with(\.textAlignment, .leading)
                .withBorder(0, color: "000000")
                .with(\.padding, 8)
        case .companyLogo:
            return ComponentStyle()
                .with(\.backgroundColor, "F9FAFB")
                .withBorder(1, color: "E5E7EB")
                .with(\.cornerRadius, 8)
                .with(\.imageContentMode, .fit)
        case .companyABN, .companyEmail:
            return ComponentStyle()
                .with(\.fontSize, 10)
                .with(\.fontWeight, "regular")
                .with(\.textColor, "6B7280")
                .with(\.textAlignment, .leading)
                .withBorder(0, color: "000000")
                .with(\.padding, 8)
        case .invoiceNumberAndDates:
            return cleanTable
                .with(\.fontSize, 10)
                .with(\.fontWeight, "regular")
                .with(\.textColor, "374151")
                .with(\.sectionLayout, .grid)
                .with(\.gridColumns, 2)
                .with(\.contentSpacing, 0)
                .with(\.contentPadding, 8)
                .with(\.tableDirection, .vertical)
                .withUseAlternatingRows(false)
        case .billTo, .participant:
            return cleanTable
                .with(\.fontSize, 10)
                .with(\.fontWeight, "regular")
                .with(\.textColor, "374151")
                .with(\.sectionLayout, .grid)
                .with(\.gridColumns, 2)
                .with(\.contentSpacing, 0)
                .with(\.contentPadding, 8)
                .with(\.tableDirection, .vertical)
                .withUseAlternatingRows(false)
        case .servicesTable:
            return cleanTable
                .with(\.fontSize, 10)
                .with(\.fontWeight, "regular")
                .with(\.textColor, "374151")
                .with(\.sectionLayout, .grid)
                .with(\.gridColumns, 4)
                .with(\.contentSpacing, 0)
                .with(\.contentPadding, 8)
                .with(\.tableDirection, .horizontal)

                .withUseAlternatingRows(false)
        case .documentGrid:
            return cleanTable
                .with(\.fontSize, 10)
                .with(\.fontWeight, "regular")
                .with(\.textColor, "374151")
                .with(\.sectionLayout, .grid)
                .with(\.gridColumns, 4)
                .with(\.contentSpacing, 0)
                .with(\.contentPadding, 8)
                .withBorder(1.0, color: "D1D5DB")

                .withUseAlternatingRows(false)
        case .totals:
            return cleanTable
                .with(\.fontSize, 10)
                .with(\.fontWeight, "regular")
                .with(\.textColor, "374151")
                .with(\.sectionLayout, .grid)
                .with(\.gridColumns, 2)
                .with(\.contentSpacing, 0)
                .with(\.contentPadding, 8)
                .with(\.tableDirection, .vertical)
                .withUseAlternatingRows(false)
        case .paymentDetails:
            return cleanTable
                .with(\.fontSize, 10)
                .with(\.fontWeight, "regular")
                .with(\.textColor, "374151")
                .with(\.sectionLayout, .grid)
                .with(\.gridColumns, 2)
                .with(\.contentSpacing, 0)
                .with(\.contentPadding, 8)
                .with(\.tableDirection, .vertical)
                .withUseAlternatingRows(false)
        case .paymentTerms:
            return ComponentStyle()
                .with(\.fontSize, 9)
                .with(\.fontWeight, "regular")
                .with(\.textColor, "6B7280")
                .with(\.textAlignment, .leading)
                .withBorder(0, color: "000000")
                .with(\.padding, 10)
        case .invoiceTitle:
            return modernHeader
                .with(\.fontSize, 22)
                .with(\.textColor, "1F2937")
                .with(\.textAlignment, .center)
                .with(\.placeholderText, "TAX INVOICE")
                .withBorder(0, color: "000000")
                .with(\.padding, 10)
        case .notes:
            return ComponentStyle()
                .with(\.fontSize, 9)
                .with(\.fontWeight, "regular")
                .with(\.textColor, "6B7280")
                .with(\.textAlignment, .leading)
                .withBorder(0, color: "000000")
                .with(\.placeholderText, "Notes or additional information...")
                .with(\.padding, 10)
        case .textBox:
            return ComponentStyle()
                .with(\.fontSize, 11)
                .with(\.fontWeight, "regular")
                .with(\.textColor, "374151")
                .with(\.placeholderText, "Enter text here...")
                .with(\.padding, 8)
                .with(\.backgroundColor, "FFFFFF")
                .with(\.backgroundOpacity, 0.05)
                .withBorder(0, color: "000000")
                .with(\.cornerRadius, 4)
        case .rectangleShape:
            return ComponentStyle()
                .with(\.backgroundColor, "E5E7EB")
                .with(\.backgroundOpacity, 1.0)
                .withBorder(1, color: "D1D5DB")
                .with(\.cornerRadius, 8)
                .withShadow(enabled: true, color: "000000", radius: 4, opacity: 0.1)
        case .ellipseShape:
            return ComponentStyle()
                .with(\.backgroundColor, "E5E7EB")
                .with(\.backgroundOpacity, 1.0)
                .withBorder(1, color: "D1D5DB")
                .withShadow(enabled: true, color: "000000", radius: 4, opacity: 0.1)
        case .lineShape:
            return ComponentStyle()
                .with(\.backgroundColor, "000000")
                .with(\.backgroundOpacity, 0.0)
                .withBorder(0, color: "374151")
                .with(\.padding, 0)
                .with(\.lineThickness, 2)
                .with(\.lineStartDecorator, LineDecorator.none)
                .with(\.lineEndDecorator, LineDecorator.none)
        case .triangleShape:
            return ComponentStyle()
                .with(\.backgroundColor, "E5E7EB")
                .with(\.backgroundOpacity, 1.0)
                .withBorder(1, color: "D1D5DB")
                .with(\.triangleDirection, TriangleDirection.up)
                .withShadow(enabled: true, color: "000000", radius: 4, opacity: 0.1)
        case .starShape:
            return ComponentStyle()
                .with(\.backgroundColor, "E5E7EB")
                .with(\.backgroundOpacity, 1.0)
                .withBorder(1, color: "D1D5DB")
                .with(\.starPoints, 5)
                .with(\.starSmoothness, 0.38)
                .withShadow(enabled: true, color: "000000", radius: 4, opacity: 0.1)
        case .imagePlaceholder:
            return ComponentStyle()
                .with(\.backgroundColor, "F9FAFB")
                .withBorder(2, color: "E5E7EB")
                .with(\.cornerRadius, 8)
                .with(\.imageContentMode, ImageContentMode.fit)
                .withShadow(enabled: true, color: "000000", radius: 4, opacity: 0.05)
        }
    }

    func withUseAlternatingRows(_ enabled: Bool) -> ComponentStyle {
        var style = self
        style.useAlternatingRows = enabled
        return style
    }
}
