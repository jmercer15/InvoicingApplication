import SwiftUI
import CoreText
import CoreGraphics

extension ComponentStyle {
    
    // MARK: - Section Title
    
    func sectionTitleNSAttributedString() -> NSAttributedString {
        let text = sectionTitleTextTransform.apply(to: sectionTitle)
        let attributes = coreTextAttributes(
            family: sectionTitleFontFamily.isEmpty ? "Helvetica" : sectionTitleFontFamily,
            size: sectionTitleFontSize > 0 ? sectionTitleFontSize : 18,
            weight: sectionTitleFontWeight,
            width: sectionTitleFontWidth,
            italic: sectionTitleItalic,
            foregroundColor: sectionTitleColor,
            alignment: sectionTitleAlignment,
            kerning: sectionTitleLetterSpacing,
            underlineStyle: sectionTitleUnderline ? sectionTitleUnderlineStyle : 0,
            underlinePattern: sectionTitleUnderlinePattern,
            underlineColor: sectionTitleUnderlineColor
        )
        return NSAttributedString(string: text, attributes: attributes)
    }
    
    // MARK: - Cell Text
    
    func cellTextNSAttributedString(for text: String, isHeader: Bool, alignment: TextAlignment? = nil, override: CellStyle? = nil) -> NSAttributedString {
        // Apply text transform override or default
        let transform = override?.textTransform ?? textTransform
        let transformedText = transform.apply(to: text)
        
        // Resolve attributes with overrides
        let family = fontFamily.isEmpty ? "Helvetica" : fontFamily
        let size = override?.fontSize ?? max(8, fontSize)
        let weight = isHeader ? "bold" : (override?.fontWeight ?? fontWeight)
        let color = isHeader ? tableHeaderTextColor : (override?.textColor ?? tableTextColor)
        let align = override?.alignment ?? alignment ?? textAlignment
        let opacity = textOpacity
        
        let attributes = coreTextAttributes(
            family: family,
            size: size,
            weight: weight,
            width: "standard",
            italic: italic,
            foregroundColor: color, // This expects a hex string
            alignment: align,
            kerning: letterSpacing,
            underlineStyle: textUnderline ? 1 : 0,
            underlinePattern: 0,
            underlineColor: ""
        )
        
        // Apply opacity to foreground color if needed (CoreText raw attributes don't strictly support alpha in hex string easily unless handled in coreTextAttributes helper)
        // Check if coreTextAttributes helper handles hex alpha or if I need to adjust it.
        // The helper uses cgColor(from: string).
        
        return NSAttributedString(string: transformedText, attributes: attributes)
    }
    
    // MARK: - CoreText Attribute Generation
    
    private func coreTextAttributes(
        family: String,
        size: CGFloat,
        weight: String,
        width: String,
        italic: Bool,
        foregroundColor: String,
        alignment: TextAlignment,
        kerning: CGFloat,
        underlineStyle: Int,
        underlinePattern: Int,
        underlineColor: String
    ) -> [NSAttributedString.Key: Any] {
        
        var attributes: [NSAttributedString.Key: Any] = [:]
        
        // 1. Font (kCTFontAttributeName)
        let font = resolveCTFont(
            family: family,
            size: size,
            weight: weight,
            width: width,
            italic: italic
        )
        attributes[kCTFontAttributeName as NSAttributedString.Key] = font
        
        // 2. Foreground Color (kCTForegroundColorAttributeName)
        if let cgColor = cgColor(from: foregroundColor) {
            attributes[kCTForegroundColorAttributeName as NSAttributedString.Key] = cgColor
        }
        
        // 3. Paragraph Style (kCTParagraphStyleAttributeName)
        let paragraphStyle = resolveCTParagraphStyle(alignment: alignment)
        attributes[kCTParagraphStyleAttributeName as NSAttributedString.Key] = paragraphStyle
        
        // 4. Kerning (kCTKernAttributeName)
        if kerning != 0 {
            attributes[kCTKernAttributeName as NSAttributedString.Key] = kerning
        }
        
        // 5. Underline (kCTUnderlineStyleAttributeName, kCTUnderlineColorAttributeName)
        if underlineStyle != 0 {
            let combinedStyle = Int32(underlineStyle | underlinePattern)
            attributes[kCTUnderlineStyleAttributeName as NSAttributedString.Key] = NSNumber(value: combinedStyle)
            
            if !underlineColor.isEmpty, let cgColor = cgColor(from: underlineColor) {
                attributes[kCTUnderlineColorAttributeName as NSAttributedString.Key] = cgColor
            }
        }
        
        return attributes
    }
    
    // MARK: - Font Resolution
    
    private func resolveCTFont(
        family: String,
        size: CGFloat,
        weight: String,
        width: String,
        italic: Bool
    ) -> CTFont {
        // Step 1: Create base descriptor with family name
        var fontAttributes: [String: Any] = [
            kCTFontFamilyNameAttribute as String: family
        ]
        
        // Step 2: Build traits dictionary
        var traits: [String: Any] = [:]
        
        // Weight trait (CGFloat, -1.0 to 1.0)
        let weightValue = resolveCoreTextWeight(weight)
        if weightValue != 0.0 {
            traits[kCTFontWeightTrait as String] = weightValue
        }
        
        // Width trait (CGFloat, -1.0 to 1.0)
        let widthValue = resolveCoreTextWidth(width)
        if widthValue != 0.0 {
            traits[kCTFontWidthTrait as String] = widthValue
        }
        
        // Symbolic traits (italic)
        if italic {
            traits[kCTFontSymbolicTrait as String] = CTFontSymbolicTraits.traitItalic.rawValue
        }
        
        if !traits.isEmpty {
            fontAttributes[kCTFontTraitsAttribute as String] = traits
        }
        
        // Step 3: Create descriptor
        let descriptor = CTFontDescriptorCreateWithAttributes(fontAttributes as CFDictionary)
        
        // Step 4: Find matching font descriptor
        let mandatoryKeys: Set<CFString> = [kCTFontFamilyNameAttribute]
        if let matchedDescriptor = CTFontDescriptorCreateMatchingFontDescriptor(descriptor, mandatoryKeys as CFSet) {
            return CTFontCreateWithFontDescriptor(matchedDescriptor, size, nil)
        }
        
        // Fallback: Create font directly from descriptor
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }
    
    private func resolveCoreTextWeight(_ weight: String) -> CGFloat {
        switch weight.lowercased() {
        case "ultralight": return -0.8
        case "thin": return -0.6
        case "light": return -0.4
        case "regular": return 0.0
        case "medium": return 0.23
        case "semibold": return 0.3
        case "bold": return 0.4
        case "heavy": return 0.56
        case "black": return 0.62
        default: return 0.0
        }
    }
    
    private func resolveCoreTextWidth(_ width: String) -> CGFloat {
        switch width.lowercased() {
        case "compressed": return -0.4
        case "condensed": return -0.2
        case "expanded": return 0.2
        default: return 0.0
        }
    }
    
    private func resolveCTParagraphStyle(alignment: TextAlignment) -> CTParagraphStyle {
        var ctAlignment: CTTextAlignment
        switch alignment {
        case .leading: ctAlignment = .left
        case .center: ctAlignment = .center
        case .trailing: ctAlignment = .right
        }
        
        var settings = [CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: &ctAlignment)]
        return CTParagraphStyleCreate(settings, settings.count)
    }
    
    // MARK: - Helpers
    
    private func cgColor(from hex: String) -> CGColor? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r, g, b, a: CGFloat
        let length = hexSanitized.count
        
        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        
        return CGColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
}
