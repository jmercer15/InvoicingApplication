import SwiftUI

/// Configuration for the font picker, supporting ALL native CoreText attributes.
struct FontPickerConfiguration: Equatable {
    
    // MARK: - Font (kCTFontAttributeName)
    var fontFamily: String = "Helvetica"
    var fontSize: CGFloat = 12
    var fontWeight: String = "regular"  // ultralight, thin, light, regular, medium, semibold, bold, heavy, black
    var fontWidth: String = "standard"  // compressed, condensed, standard, expanded
    var italic: Bool = false
    var monospaced: Bool = false
    
    // MARK: - Color (kCTForegroundColorAttributeName, kCTForegroundColorFromContextAttributeName)
    var foregroundColor: String = "#000000"
    var useContextColor: Bool = false
    
    // MARK: - Paragraph (kCTParagraphStyleAttributeName)
    var alignment: TextAlignment = .leading
    var lineSpacing: CGFloat = 1.0  // Line height multiple
    
    // MARK: - Character Spacing (kCTKernAttributeName)
    var kerning: CGFloat = 0
    
    // MARK: - Ligatures (kCTLigatureAttributeName)
    /// 0 = no ligatures, 1 = default ligatures, 2 = all ligatures
    var ligatures: Int = 1
    
    // MARK: - Stroke (kCTStrokeWidthAttributeName, kCTStrokeColorAttributeName)
    /// Positive = stroke only, Negative = stroke + fill, 0 = no stroke
    var strokeWidth: CGFloat = 0
    var strokeColor: String = "#000000"
    
    // MARK: - Underline (kCTUnderlineStyleAttributeName, kCTUnderlineColorAttributeName)
    /// Style: 0=none, 1=single, 2=thick, 9=double
    var underlineStyle: Int = 0
    /// Pattern: 0x0000=solid, 0x0100=dot, 0x0200=dash, 0x0300=dashDot, 0x0400=dashDotDot
    var underlinePattern: Int = 0
    var underlineColor: String = ""
    
    // MARK: - Vertical Position (kCTSuperscriptAttributeName, kCTBaselineOffsetAttributeName)
    /// -1 = subscript, 0 = normal, 1 = superscript
    var superscript: Int = 0
    var baselineOffset: CGFloat = 0
    
    // MARK: - Writing Direction (kCTWritingDirectionAttributeName)
    /// 0 = natural, 1 = leftToRight, 2 = rightToLeft
    var writingDirection: Int = 0
    
    // MARK: - Layout (non-CoreText, for UI purposes)
    var bottomPadding: CGFloat = 0
    var textTransform: TextTransform = .none
    var opacity: CGFloat = 1.0
    
    // MARK: - Static
    
    static let empty = FontPickerConfiguration()
    
    enum Scope {
        case sectionTitle
        case text
    }
}

// MARK: - ComponentStyle Integration

extension FontPickerConfiguration {
    
    init(from style: ComponentStyle, scope: Scope) {
        switch scope {
        case .sectionTitle:
            self.fontFamily = style.sectionTitleFontFamily.isEmpty ? "Helvetica" : style.sectionTitleFontFamily
            self.fontSize = style.sectionTitleFontSize > 0 ? style.sectionTitleFontSize : 18
            self.fontWeight = style.sectionTitleFontWeight
            self.fontWidth = style.sectionTitleFontWidth
            self.italic = style.sectionTitleItalic
            self.monospaced = style.sectionTitleMonospaced
            self.foregroundColor = style.sectionTitleColor
            self.useContextColor = false
            self.alignment = style.sectionTitleAlignment
            self.lineSpacing = 1.0
            self.kerning = style.sectionTitleLetterSpacing
            self.ligatures = style.sectionTitleLigatures
            self.strokeWidth = style.sectionTitleStrokeWidth
            self.strokeColor = style.sectionTitleStrokeColor
            self.underlineStyle = style.sectionTitleUnderline ? style.sectionTitleUnderlineStyle : 0
            self.underlinePattern = style.sectionTitleUnderlinePattern
            self.underlineColor = style.sectionTitleUnderlineColor
            self.superscript = style.sectionTitleSuperscript
            self.baselineOffset = style.sectionTitleBaselineOffset
            self.writingDirection = style.sectionTitleWritingDirection
            self.bottomPadding = style.sectionTitleBottomPadding
            self.textTransform = style.sectionTitleTextTransform
            
        case .text:
            self.fontFamily = style.fontFamily.isEmpty ? "Helvetica" : style.fontFamily
            self.fontSize = max(8, style.fontSize)
            self.fontWeight = style.fontWeight
            self.fontWidth = "standard"
            self.italic = style.italic
            self.monospaced = false
            self.foregroundColor = style.textColor
            self.useContextColor = false
            self.alignment = style.textAlignment
            self.lineSpacing = style.lineSpacing
            self.kerning = style.letterSpacing
            self.ligatures = 1
            self.strokeWidth = 0
            self.strokeColor = "#000000"
            self.underlineStyle = style.textUnderline ? 1 : 0
            self.underlinePattern = 0
            self.underlineColor = ""
            self.superscript = 0
            self.baselineOffset = 0
            self.writingDirection = 0
            self.bottomPadding = 0
            self.textTransform = style.textTransform
            self.opacity = style.textOpacity
        }
    }
    
    func apply(to style: inout ComponentStyle, scope: Scope) {
        switch scope {
        case .sectionTitle:
            style.sectionTitleFontFamily = fontFamily
            style.sectionTitleFontSize = fontSize
            style.sectionTitleFontWeight = fontWeight
            style.sectionTitleFontWidth = fontWidth
            style.sectionTitleItalic = italic
            style.sectionTitleMonospaced = monospaced
            style.sectionTitleColor = foregroundColor
            style.sectionTitleAlignment = alignment
            style.sectionTitleLetterSpacing = kerning
            style.sectionTitleLigatures = ligatures
            style.sectionTitleStrokeWidth = strokeWidth
            style.sectionTitleStrokeColor = strokeColor
            style.sectionTitleUnderline = underlineStyle != 0
            style.sectionTitleUnderlineStyle = underlineStyle != 0 ? underlineStyle : 1
            style.sectionTitleUnderlinePattern = underlinePattern
            style.sectionTitleUnderlineColor = underlineColor
            style.sectionTitleSuperscript = superscript
            style.sectionTitleBaselineOffset = baselineOffset
            style.sectionTitleWritingDirection = writingDirection
            style.sectionTitleBottomPadding = bottomPadding
            style.sectionTitleTextTransform = textTransform
            
        case .text:
            style.fontFamily = fontFamily
            style.fontSize = fontSize
            style.fontWeight = fontWeight
            style.italic = italic
            style.textColor = foregroundColor
            style.textAlignment = alignment
            style.lineSpacing = lineSpacing
            style.letterSpacing = kerning
            style.textUnderline = underlineStyle != 0
            style.textTransform = textTransform
            style.textOpacity = opacity
        }
    }
}
