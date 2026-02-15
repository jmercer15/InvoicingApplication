import SwiftUI
import SharedUI

struct BillingHubTheme {
    struct Palette {
        static let accentPreparing = Color(hex: "8B7CFF")
        static let accentProcessing = Color(hex: "51A9FF")
        static let accentPayment = Color(hex: "38DFA4")

        static let textPrimary = StyleGuide.Colors.text
        static let textSecondary = StyleGuide.Colors.textSecondary
        static let textMuted = StyleGuide.Colors.textSecondary.opacity(0.7)
    }

    struct Columns {
        static let preparing = Palette.accentPreparing
        static let processing = Palette.accentProcessing
        static let payment = Palette.accentPayment
    }

    struct Surfaces {
        static let subcolumnGap: CGFloat = 8
        static let subcolumnShadowClearance: CGFloat = 3
        static let primaryColumnGap: CGFloat = 2
        static let subcolumnCornerRadius: CGFloat = 10

        static let subcolumnBase = Color(
            nsColor: NSColor.textBackgroundColor.blended(withFraction: 0.06, of: .white) ?? .textBackgroundColor
        )
        static let subcolumnStroke = Color(nsColor: .separatorColor).opacity(0.45)
        static let subcolumnHeaderDividerHeight: CGFloat = 2

        static let cardBase = Color(nsColor: .windowBackgroundColor)
        static let cardStroke = StyleGuide.Colors.border.opacity(0.55)

        static let dropZoneBase = Color(nsColor: .controlBackgroundColor)
        static let dropZoneStroke = StyleGuide.Colors.border.opacity(0.3)

        static func subcolumnHeaderBackground(for accent: Color, hovered: Bool) -> Color {
            hovered ? accent.opacity(0.24) : accent.opacity(0.18)
        }
    }

    struct Animations {
        static let hover = Animation.easeInOut(duration: StyleGuide.Animations.durationShort)
        static let spring = Animation.spring(
            response: StyleGuide.Animations.springResponse,
            dampingFraction: StyleGuide.Animations.springDamping
        )
    }
}
