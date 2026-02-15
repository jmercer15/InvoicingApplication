import SwiftUI

public struct CellStyle: Equatable, Sendable {
    public var backgroundColor: ColorWrapper?
    public var textAlignment: TextAlignment
    public var isBold: Bool
    public var isItalic: Bool
    public var isUnderline: Bool
    public var isStrikethrough: Bool
    public var verticalAlignment: CellVerticalAlignment
    public var padding: CGFloat
    public var fontSize: CGFloat
    public var textColor: ColorWrapper
    
    public init(
        backgroundColor: ColorWrapper? = nil,
        textAlignment: TextAlignment = .leading,
        verticalAlignment: CellVerticalAlignment = .center,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        isStrikethrough: Bool = false,
        fontSize: CGFloat = 13,
        textColor: ColorWrapper = .black,
        padding: CGFloat = 4
    ) {
        self.backgroundColor = backgroundColor
        self.textAlignment = textAlignment
        self.verticalAlignment = verticalAlignment
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.isStrikethrough = isStrikethrough
        self.fontSize = fontSize
        self.textColor = textColor
        self.padding = padding
    }
    
    public static let standard = CellStyle()
}

public enum CellVerticalAlignment: String, CaseIterable, Codable, Sendable {
    case top = "Top"
    case center = "Center"
    case bottom = "Bottom"
}

// Helper for Codable/Sendable Color
public struct ColorWrapper: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let opacity: Double
    
    public init(red: Double, green: Double, blue: Double, opacity: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }
    
    public static let black = ColorWrapper(red: 0, green: 0, blue: 0)
    public static let white = ColorWrapper(red: 1, green: 1, blue: 1)
    public static let clear = ColorWrapper(red: 0, green: 0, blue: 0, opacity: 0)
    
    public var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

extension Color {
    init(wrapper: ColorWrapper) {
        self.init(red: wrapper.red, green: wrapper.green, blue: wrapper.blue, opacity: wrapper.opacity)
    }
}
