import SwiftUI

public struct StyleGuide {
    public static let shadowColor = Color("Shadow", bundle: .sharedUI)
    public static let cornerRadius: CGFloat = 12.0
    public static let horizontalPadding: CGFloat = 32.0
    public static let sectionSpacing: CGFloat = 12.0
    
    public struct Header {
        public static let titleFont = Font.system(size: 18, weight: .semibold)
    }

    // Text struct removed - empty struct, never instantiated or referenced

    public struct Section {
        public static let titleFont = Font.system(size: 20, weight: .bold)
    }
    
    public struct Colors {
        public static let primary = Color("Primary", bundle: .sharedUI)
        public static let secondary = Color("Gray20", bundle: .sharedUI)
        public static let background = Color("Background", bundle: .sharedUI)
        // surface color removed - unused property
        public static let border = Color("Border", bundle: .sharedUI)
        public static let text = Color("Text", bundle: .sharedUI)
        public static let textSecondary = Color("TextSecondary", bundle: .sharedUI)
    }

    // Shadow struct removed - empty struct, never instantiated or referenced

    // MARK: - Design Tokens
    public struct Dimensions {
        public static let cornerRadiusXSmall: CGFloat = 4.0
        public static let cornerRadiusSmall: CGFloat = 8.0
        public static let cornerRadiusMedium: CGFloat = 12.0
        public static let cornerRadiusLarge: CGFloat = 16.0

        public static let paddingXSmall: CGFloat = 4.0
        public static let paddingSmall: CGFloat = 6.0
        public static let paddingMedium: CGFloat = 8.0
        public static let paddingLarge: CGFloat = 16.0
        public static let paddingXLarge: CGFloat = 24.0
        public static let paddingMediumLarge: CGFloat = 12.0
        public static let paddingXXLarge: CGFloat = 32.0

        public static let inspectorWidthMin: CGFloat = 220.0
        public static let inspectorWidthIdeal: CGFloat = 280.0
        public static let inspectorWidthMax: CGFloat = 350.0
    }

    public struct Animations {
        public static let durationShort: TimeInterval = 0.1
        public static let durationMedium: TimeInterval = 0.3
        public static let durationLong: TimeInterval = 0.6
        public static let springResponse: TimeInterval = 0.6
        public static let springDamping: CGFloat = 0.7
    }

    public struct Shadows {
        public static let lightRadius: CGFloat = 4.0
        public static let lightOffsetY: CGFloat = 2.0
        public static let darkRadius: CGFloat = 8.0
        public static let darkOffsetY: CGFloat = 4.0
    }

    public struct Opacity {
        public static let subtle: Double = 0.05
        public static let faint: Double = 0.08
        public static let light: Double = 0.1
        public static let medium: Double = 0.2
        public static let strong: Double = 0.3
    }
}
