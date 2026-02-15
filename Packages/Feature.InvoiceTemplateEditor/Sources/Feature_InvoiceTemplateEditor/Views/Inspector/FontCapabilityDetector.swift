import Foundation
import CoreText

/// Represents the available typographic capabilities of a font family.
struct FontFamilyCapabilities {
    /// Available weight names for this font family (e.g., ["regular", "bold", "black"])
    var availableWeights: [String] = []
    
    /// Whether the font family has an italic variant
    var hasItalic: Bool = false
    
    /// Whether the font family has a condensed/compressed variant
    var hasCondensed: Bool = false
    
    /// Whether the font family has an expanded variant
    var hasExpanded: Bool = false
    
    /// Whether this is a monospace font family
    var isMonospace: Bool = false
    
    /// Default capabilities (all options available)
    static let `default` = FontFamilyCapabilities(
        availableWeights: ["ultralight", "thin", "light", "regular", "medium", "semibold", "bold", "heavy", "black"],
        hasItalic: true,
        hasCondensed: true,
        hasExpanded: true,
        isMonospace: false
    )
}

/// Utility for querying font family capabilities using CoreText.
enum FontCapabilityDetector {
    
    /// Get the capabilities of a font family by querying all its variants.
    static func getCapabilities(for familyName: String) -> FontFamilyCapabilities {
        var capabilities = FontFamilyCapabilities()
        
        // Create a descriptor for the family
        let familyDescriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontFamilyNameAttribute: familyName
        ] as CFDictionary)
        
        // Get all matching font descriptors in this family
        guard let matchingDescriptors = CTFontDescriptorCreateMatchingFontDescriptors(familyDescriptor, nil) as? [CTFontDescriptor] else {
            return .default
        }
        
        if matchingDescriptors.isEmpty {
            return .default
        }
        
        var foundWeights: Set<String> = []
        
        for descriptor in matchingDescriptors {
            // Get traits dictionary
            guard let traits = CTFontDescriptorCopyAttribute(descriptor, kCTFontTraitsAttribute) as? [String: Any] else {
                continue
            }
            
            // Check symbolic traits
            if let symbolicValue = traits[kCTFontSymbolicTrait as String] as? UInt32 {
                let symbolicTraits = CTFontSymbolicTraits(rawValue: symbolicValue)
                
                if symbolicTraits.contains(.traitItalic) {
                    capabilities.hasItalic = true
                }
                if symbolicTraits.contains(.traitMonoSpace) {
                    capabilities.isMonospace = true
                }
                if symbolicTraits.contains(.traitCondensed) {
                    capabilities.hasCondensed = true
                }
                if symbolicTraits.contains(.traitExpanded) {
                    capabilities.hasExpanded = true
                }
            }
            
            // Check weight trait
            if let weightValue = traits[kCTFontWeightTrait as String] as? CGFloat {
                let weightName = weightNameFromValue(weightValue)
                foundWeights.insert(weightName)
            }
            
            // Check width trait
            if let widthValue = traits[kCTFontWidthTrait as String] as? CGFloat {
                if widthValue < -0.1 {
                    capabilities.hasCondensed = true
                } else if widthValue > 0.1 {
                    capabilities.hasExpanded = true
                }
            }
        }
        
        // Sort weights by their value
        let orderedWeights = ["ultralight", "thin", "light", "regular", "medium", "semibold", "bold", "heavy", "black"]
        capabilities.availableWeights = orderedWeights.filter { foundWeights.contains($0) }
        
        // Ensure at least "regular" is available
        if capabilities.availableWeights.isEmpty {
            capabilities.availableWeights = ["regular"]
        }
        
        return capabilities
    }
    
    /// Map a weight value to a weight name
    private static func weightNameFromValue(_ value: CGFloat) -> String {
        // Weight values from NSFontWeight constants
        switch value {
        case ..<(-0.7): return "ultralight"
        case -0.7..<(-0.5): return "thin"
        case -0.5..<(-0.2): return "light"
        case -0.2..<0.15: return "regular"
        case 0.15..<0.27: return "medium"
        case 0.27..<0.35: return "semibold"
        case 0.35..<0.5: return "bold"
        case 0.5..<0.6: return "heavy"
        default: return "black"
        }
    }
}
