import SwiftUI
import SharedUI

// MARK: - Intrinsic Content Measurement Utilities

/// Utility for measuring intrinsic content sizes to determine appropriate width constraints
struct IntrinsicContentMeasurer {
    
    /// Measures the intrinsic width needed for readable text content
    static func measureTextWidth(
        text: String,
        font: Font = .headline,
        maxLines: Int = 2,
        padding: CGFloat = 18
    ) -> CGFloat {
        // Use string-based width estimation since we can't measure SwiftUI views directly
        let estimatedWidth = estimateTextWidth(text: text, font: font, maxLines: maxLines)
        
        // Add padding and ensure minimum readable width
        let measuredWidth = estimatedWidth + (padding * 2)
        let minReadableWidth: CGFloat = 200 // Minimum for readable text
        
        return max(measuredWidth, minReadableWidth)
    }
    
    /// Estimates text width based on character count and font size
    private static func estimateTextWidth(text: String, font: Font, maxLines: Int) -> CGFloat {
        // Approximate character width based on font
        let characterWidth: CGFloat
        switch font {
        case .largeTitle: characterWidth = 24
        case .title: characterWidth = 20
        case .title2: characterWidth = 18
        case .title3: characterWidth = 16
        case .headline: characterWidth = 14
        case .subheadline: characterWidth = 12
        case .body: characterWidth = 12
        case .callout: characterWidth = 11
        case .footnote: characterWidth = 10
        case .caption: characterWidth = 9
        case .caption2: characterWidth = 8
        default: characterWidth = 12
        }
        
        // Calculate width based on longest line
        let lines = text.components(separatedBy: .newlines)
        let longestLine = lines.max(by: { $0.count < $1.count }) ?? text
        let estimatedWidth = CGFloat(longestLine.count) * characterWidth
        
        // Apply line limit
        if maxLines > 1 {
            return estimatedWidth // For multi-line, use full width
        } else {
            return estimatedWidth // For single line, use full width
        }
    }
    
    /// Measures the intrinsic width needed for card content
    static func measureCardContentWidth(
        title: String,
        subtitle: String? = nil,
        additionalContent: String? = nil,
        padding: CGFloat = 18
    ) -> CGFloat {
        let titleWidth = measureTextWidth(text: title, font: .headline, maxLines: 2, padding: 0)
        let subtitleWidth = subtitle.map { measureTextWidth(text: $0, font: .subheadline, maxLines: 2, padding: 0) } ?? 0
        let additionalWidth = additionalContent.map { measureTextWidth(text: $0, font: .caption, maxLines: 1, padding: 0) } ?? 0
        
        // Take the maximum width needed for any single line of content
        let maxContentWidth = max(titleWidth, subtitleWidth, additionalWidth)
        
        // Add padding and ensure reasonable bounds
        let totalWidth = maxContentWidth + (padding * 2)
        let minCardWidth: CGFloat = 240 // Minimum for readable cards
        let maxCardWidth: CGFloat = 400 // Maximum to prevent excessive stretching
        
        return max(minCardWidth, min(totalWidth, maxCardWidth))
    }
    
    /// Measures the intrinsic width needed for toolbar content
    static func measureToolbarItemWidth(
        title: String,
        icon: String? = nil,
        padding: CGFloat = 12
    ) -> CGFloat {
        let textWidth = measureTextWidth(text: title, font: .subheadline, maxLines: 1, padding: 0)
        let iconWidth: CGFloat = icon != nil ? 20 : 0 // Approximate icon width
        
        return textWidth + iconWidth + (padding * 2)
    }
}
