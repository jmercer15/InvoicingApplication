import SwiftUI
import SharedUI

struct BillingHubTheme {
    struct Palette {
        static let accentPreparing = Color(legacyHex: "8B7CFF")
        static let accentProcessing = Color(legacyHex: "51A9FF")
        static let accentPayment = Color(legacyHex: "38DFA4")

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
        static let boardBase = Color(nsColor: .windowBackgroundColor)
        static let boardUnderpage = Color(nsColor: .underPageBackgroundColor)
        static let panelBase = Color(nsColor: .controlBackgroundColor)

        static let subcolumnBase = Color(
            nsColor: NSColor.textBackgroundColor.blended(withFraction: 0.06, of: .white) ?? .textBackgroundColor
        )
        static let subcolumnStroke = StyleGuide.Colors.border.opacity(0.45)

        static let cardBase = boardBase
        static let cardStroke = StyleGuide.Colors.border.opacity(0.55)
        static let cardHoverStrokeOpacity = ListRowTokens.hoverStrokeOpacity
        static let cardDefaultStrokeOpacity = ListRowTokens.defaultStrokeOpacity
        static let cardSelectedStrokeWidth = ListRowTokens.selectedStrokeWidth
        static let cardDefaultStrokeWidth = ListRowTokens.defaultStrokeWidth

        static let dropZoneBase = panelBase
        static let dropZoneStroke = StyleGuide.Colors.border.opacity(0.3)

        static let dropTargetFill = Color.accentColor.opacity(StyleGuide.Opacity.faint)
        static let dropTargetStroke = Color.accentColor.opacity(0.48)
    }

    struct Typography {
        static let sectionTitle = StyleGuide.Typography.sectionTitle
        static let sectionCount = StyleGuide.Typography.itemSubtitle
        static let cardTitle = StyleGuide.Typography.itemTitle
        static let cardSubtitle = StyleGuide.Typography.itemSubtitle
        static let cardMetadata = StyleGuide.Typography.caption
        static let statusCount = Font.system(size: StyleGuide.Dimensions.fontSizeMedium, weight: .heavy)
        static let statusLabel = Font.system(size: StyleGuide.Dimensions.fontSizeXSmall, weight: .medium)
        static let collapseChevron = Font.system(size: StyleGuide.Dimensions.fontSizeXSmall, weight: .bold)
        static let collapsedBarIcon = Font.system(size: StyleGuide.Dimensions.fontSizeMedium, weight: .semibold)
        static let collapsedBarCount = Font.system(size: StyleGuide.Dimensions.fontSizeMicro, weight: .bold, design: .rounded)
        static let collapsedBarChevron = Font.system(size: StyleGuide.Dimensions.fontSizeMicro, weight: .bold)
        static let laneHeaderIcon = Font.system(size: StyleGuide.Dimensions.fontSizeMedium, weight: .semibold)
        static let sortMenuIcon = Font.system(size: StyleGuide.Dimensions.fontSizeXSmall, weight: .semibold)
        static let dragPreviewTitle = Font.system(size: StyleGuide.Dimensions.fontSizeCompactTitle, weight: .semibold)
        static let dragPreviewSubtitle = Font.system(size: StyleGuide.Dimensions.fontSizeXSmall, weight: .medium)
        static let bulkFeedbackIcon = Font.system(size: StyleGuide.Dimensions.fontSizeXSmall, weight: .bold)
        static let bulkFeedbackText = Font.system(size: StyleGuide.Dimensions.fontSizeXSmall, weight: .medium)
        static let bulkFeedbackDismiss = Font.system(size: StyleGuide.Dimensions.fontSizeNano, weight: .bold)
        static let infoChipIcon = StyleGuide.Typography.itemSubtitle
        static let infoChipLabel = StyleGuide.Typography.infoChipLabel
        static let infoChipValue = StyleGuide.Typography.infoChipValue
    }

    struct Dimensions {
        static let cardCornerRadius = StyleGuide.Dimensions.cornerRadiusSmall
        static let columnCornerRadius = StyleGuide.Dimensions.cornerRadiusMedium
        static let boardPadding = StyleGuide.Dimensions.paddingXLarge
        static let cardPadding = StyleGuide.Dimensions.paddingSmall
        static let laneSpacing = StyleGuide.Dimensions.paddingXMedium

        static let sectionIconSize: CGFloat = 34
        static let collapseButtonSize: CGFloat = 28
        static let laneHeaderIconSize: CGFloat = 36
        static let collapsedBarWidth: CGFloat = 58
        static let laneWidth: CGFloat = 236
        static let dragPreviewWidth: CGFloat = 220
        static let columnShellCornerRadius: CGFloat = 24
        static let collapsedBarCornerRadius: CGFloat = 20
        static let laneHeaderCornerRadius = PanelShellTokens.panelCornerRadius
        static let sortButtonPadding: CGFloat = 7
        static let statusIndicatorOuter: CGFloat = 26
        static let statusIndicatorInner: CGFloat = 14
        static let statusIndicatorDot: CGFloat = 8
        static let dragHandleWidth: CGFloat = 3
        static let clientBadgeSize: CGFloat = 8
        static let groupCardCornerRadius: CGFloat = 7
        static let editingPanelMinWidth: CGFloat = 500
        static let editingPanelMinHeight: CGFloat = 600
        static let draftHomeMinWidth: CGFloat = 440
        static let draftHomeMinHeight: CGFloat = 320
        static let dragPreviewIconSize: CGFloat = 26
    }

    struct Animations {
        static let hover = Animation.easeInOut(duration: StyleGuide.Animations.durationShort)
    }
}
