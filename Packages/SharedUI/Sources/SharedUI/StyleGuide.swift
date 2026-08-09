import SwiftUI

public struct StyleGuide {
    public static let shadowColor = Color("Shadow", bundle: .sharedUI)
    public static let cornerRadius: CGFloat = 12.0
    public static let horizontalPadding: CGFloat = 32.0
    public static let sectionSpacing: CGFloat = 12.0
    
    public struct Header {
        public static let titleFont = Font.headline.weight(.semibold)
    }

    // Text struct removed - empty struct, never instantiated or referenced

    public struct Section {
        public static let titleFont = Font.title3.weight(.bold)
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
        public static let paddingXMedium: CGFloat = 10.0
        public static let paddingLarge: CGFloat = 16.0
        public static let paddingXLarge: CGFloat = 24.0
        public static let paddingMediumLarge: CGFloat = 12.0
        public static let paddingXXLarge: CGFloat = 32.0

        public static let inspectorWidthMin: CGFloat = 220.0
        public static let inspectorWidthIdeal: CGFloat = 280.0
        public static let inspectorWidthMax: CGFloat = 350.0

        // Typography size tokens (pt)
        public static let fontSizeXSmall: CGFloat = 11.0
        public static let fontSizeSmall: CGFloat = 12.0
        public static let fontSizeMedium: CGFloat = 14.0
        public static let fontSizeLarge: CGFloat = 16.0
        public static let fontSizeXLarge: CGFloat = 18.0
        public static let fontSizeXXLarge: CGFloat = 20.0
        public static let fontSizeHero: CGFloat = 24.0

        // Card and navigation layout tokens
        public static let iconCircleSize: CGFloat = 32.0
        public static let cardMinHeightSmall: CGFloat = 110.0
        public static let cardMinHeight: CGFloat = 160.0
        public static let paddingEmptyState: CGFloat = 40.0
        public static let paddingCard: CGFloat = 18.0
        public static let paddingXXSmall: CGFloat = 2.0
        public static let paddingTiny: CGFloat = 3.0

        public static let cornerRadiusCompact: CGFloat = 6.0
        public static let cornerRadiusCardLarge: CGFloat = 20.0

        public static let entityIconCircleSize: CGFloat = 36.0
        public static let entityIconCircleSizeLarge: CGFloat = 40.0
        public static let statusDotSize: CGFloat = 6.0
        public static let accentBarWidth: CGFloat = 3.0
        public static let entityListIconWidth: CGFloat = 24.0
        public static let selectionCheckmarkWidth: CGFloat = 30.0
        public static let indexBadgeSize: CGFloat = 36.0

        public static let sheetMinWidth: CGFloat = 900.0
        public static let sheetIdealWidth: CGFloat = 1000.0
        public static let sheetMinHeight: CGFloat = 700.0
        public static let sheetIdealHeight: CGFloat = 800.0

        public static let fontSizeCompactTitle: CGFloat = 13.0
        public static let fontSizeDetailHeaderIcon: CGFloat = 28.0
        public static let fontSizeMicro: CGFloat = 10.0

        public static let filterPopoverWidth: CGFloat = 300.0
        public static let lineItemEditorWidth: CGFloat = 300.0
        public static let filterAmountFieldWidth: CGFloat = 70.0
        public static let inspectorPercentFieldWidth: CGFloat = 50.0
        public static let inspectorCurrencyFieldWidth: CGFloat = 60.0
        public static let sectionIconWidth: CGFloat = 20.0
        public static let unsavedIndicatorSize: CGFloat = 7.0
        public static let fontSizeRuler: CGFloat = 8.0
        public static let fontSizeNano: CGFloat = 9.0
        public static let fontSizeGridSubtext: CGFloat = 10.0

        // Form and sheet layout
        public static let formLabelWidth: CGFloat = 80.0
        public static let formSupportLabelWidth: CGFloat = 90.0
        public static let sessionSheetMinWidth: CGFloat = 450.0
        public static let sessionSheetMinHeight: CGFloat = 500.0
        public static let travelChargeSheetMinWidth: CGFloat = 550.0
        public static let travelChargeSheetIdealWidth: CGFloat = 600.0
        public static let travelChargeSheetMinHeight: CGFloat = 600.0
        public static let recurringScopeSheetMinWidth: CGFloat = 460.0
        public static let recurringScopeSheetIdealWidth: CGFloat = 520.0
        public static let recurringScopeSheetMinHeight: CGFloat = 320.0
        public static let recurringScopeSheetIdealHeight: CGFloat = 420.0
        public static let calendarSidebarWidth: CGFloat = 130.0
        public static let calendarPopoverWidth: CGFloat = 320.0
        public static let calendarPopoverHeight: CGFloat = 380.0
        public static let calendarFilterWidth: CGFloat = 300.0
        public static let calendarDayCellSize: CGFloat = 22.0
        public static let calendarDividerWidth: CGFloat = 0.5
        public static let calendarEventAccentWidth: CGFloat = 3.5
        public static let calendarBadgeVerticalPadding: CGFloat = 1.0
        public static let calendarBadgeTopPadding: CGFloat = 1.0
        public static let calendarItemVerticalPadding: CGFloat = 2.0
        public static let calendarItemHorizontalPadding: CGFloat = 5.0
        public static let calendarBadgeCornerRadius: CGFloat = 3.0
        public static let travelProviderIconSize: CGFloat = 44.0
        public static let infoChipIconSize: CGFloat = 24.0

        // Settings sheets and layout
        public static let paddingSheetContent: CGFloat = 20.0
        public static let settingsSheetMinWidth: CGFloat = 480.0
        public static let settingsSheetMinHeight: CGFloat = 360.0
        public static let settingsSheetStandardMinWidth: CGFloat = 500.0
        public static let settingsSheetStandardMinHeight: CGFloat = 400.0
        public static let settingsSheetLargeMinWidth: CGFloat = 600.0
        public static let settingsSheetLargeMinHeight: CGFloat = 500.0
        public static let settingsSheetReviewMinHeight: CGFloat = 600.0
        public static let settingsTravelReviewMinHeight: CGFloat = 450.0
        public static let settingsReconcileMinWidth: CGFloat = 520.0
        public static let settingsReconcileMinHeight: CGFloat = 320.0
        public static let settingsCreateCalendarWidth: CGFloat = 400.0
        public static let settingsFormLabelOffset: CGFloat = 120.0
        public static let settingsEmptyStateIconSize: CGFloat = 48.0
        public static let settingsCalendarColorPickerSize: CGFloat = 200.0
        public static let settingsCalendarPopoverWidth: CGFloat = 250.0
        public static let settingsCalendarPopoverHeight: CGFloat = 300.0

        // Invoice template editor chrome
        public static let templateMetadataSheetMinWidth: CGFloat = 420.0
        public static let templateMetadataSheetMinHeight: CGFloat = 360.0
        public static let templateSplitDialogWidth: CGFloat = 320.0
        public static let templateToolbarPadding: CGFloat = 14.0
        public static let templateToolbarControlPadding: CGFloat = 6.0
        public static let templateOutlineBadgeWidth: CGFloat = 12.0
        public static let templateToolbarIconSize: CGFloat = 14.0
        public static let templateToolbarIconSizeLarge: CGFloat = 16.0
        public static let templateToolbarIconSizeSmall: CGFloat = 12.0
        public static let templateToolbarActionIconSize: CGFloat = 20.0
        public static let templateHeaderIconSize: CGFloat = 16.0
        public static let templateHeaderBadgeSize: CGFloat = 20.0
        public static let templateCanvasChromePadding: CGFloat = 8.0
        public static let templateCanvasChromeRadius: CGFloat = 12.0
        public static let templateToolbarCornerRadius: CGFloat = 18.0
        public static let templateBadgePadding: CGFloat = 3.0
        public static let templateInspectorPanelWidth: CGFloat = 250.0
        public static let templateInspectorPanelWidthWide: CGFloat = 260.0
        public static let templateAlignmentGridPadding: CGFloat = 1.0
        public static let templateTabCornerRadius: CGFloat = 10.0
        public static let templateTabHorizontalPadding: CGFloat = 12.0
        public static let templateTabVerticalPadding: CGFloat = 10.0
        public static let templateImagePreviewWidth: CGFloat = 100.0
        public static let templateImagePreviewHeight: CGFloat = 75.0

        // AppShell workspace scenes
        public static let workspaceActivityMinWidth: CGFloat = 900.0
        public static let workspaceActivityMinHeight: CGFloat = 560.0
        public static let workspaceActivityLoadingMinWidth: CGFloat = 320.0
        public static let workspaceActivityLoadingMinHeight: CGFloat = 180.0
        public static let workspaceInspectorColumnMin: CGFloat = 260.0
        public static let workspaceInspectorColumnIdeal: CGFloat = 400.0
        public static let workspaceSettingsSceneMinWidth: CGFloat = 600.0
        public static let workspaceSettingsSceneMinHeight: CGFloat = 400.0
        public static let workspaceInspectorPlaceholderMinWidth: CGFloat = 420.0
        public static let workspaceInspectorPlaceholderMinHeight: CGFloat = 500.0
        public static let workspaceContentColumnMin: CGFloat = 260.0
        public static let workspaceContentColumnIdeal: CGFloat = 360.0

        // Detail toolbar title stacks
        public static let toolbarTitleStackSpacing: CGFloat = paddingMedium
        public static let toolbarTitleSubtitleSpacing: CGFloat = paddingXXSmall

        // Inspector chrome
        public static let inspectorHeaderIconBox: CGFloat = 28.0
        public static let inspectorCommandButtonSize: CGFloat = 24.0
        public static let inspectorStatIconSize: CGFloat = 9.0
        public static let inlineFontPickerHeight: CGFloat = 500.0

        // Layout sentinels (documented zero/hairline values)
        public static let hiddenFrameWidth: CGFloat = 0.0
        public static let hiddenFrameHeight: CGFloat = 0.0
        public static let hairlineWidth: CGFloat = 0.5
        public static let zeroPadding: CGFloat = 0.0

        // Calendar grid layout
        public static let calendarHeaderCornerRadiusExtra: CGFloat = 4.0
        public static let calendarHeaderWeekFontSize: CGFloat = 13.0
        public static let calendarHeaderDayFontSize: CGFloat = 15.0
        public static let calendarHeaderDayCircleSize: CGFloat = 24.0
        public static let calendarHeaderHeight: CGFloat = 42.0
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

    public struct Typography {
        // Semantic font definitions
        public static let hero = Font.system(size: Dimensions.fontSizeHero, weight: .bold)
        public static let sectionTitle = Font.system(size: Dimensions.fontSizeLarge, weight: .semibold)
        public static let itemTitle = Font.system(size: Dimensions.fontSizeMedium, weight: .semibold)
        public static let itemSubtitle = Font.system(size: Dimensions.fontSizeSmall, weight: .regular)
        public static let label = Font.system(size: Dimensions.fontSizeSmall, weight: .semibold)
        public static let caption = Font.system(size: Dimensions.fontSizeXSmall, weight: .semibold)
        public static let bodyMedium = Font.system(size: Dimensions.fontSizeMedium, weight: .medium)
        public static let bodyLarge = Font.system(size: Dimensions.fontSizeLarge, weight: .medium)
        public static let breadcrumb = Font.system(.subheadline, design: .rounded).weight(.semibold)
        public static let breadcrumbIcon = Font.system(size: Dimensions.fontSizeLarge, weight: .semibold, design: .rounded)
        public static let compactRowTitle = Font.system(size: Dimensions.fontSizeCompactTitle, weight: .medium)
        public static let detailHeaderIcon = Font.system(size: Dimensions.fontSizeDetailHeaderIcon, weight: .medium)
        public static let entityCardIcon = Font.system(size: Dimensions.fontSizeLarge, weight: .semibold)
        public static let entityGridIcon = Font.system(size: Dimensions.fontSizeXLarge, weight: .semibold)
        public static let micro = Font.system(size: Dimensions.fontSizeMicro)
        public static let nano = Font.system(size: Dimensions.fontSizeNano, weight: .bold)
        public static let nanoMedium = Font.system(size: Dimensions.fontSizeNano, weight: .medium)
        public static let infoChipLabel = Font.system(size: Dimensions.fontSizeNano, weight: .bold)
        public static let infoChipValue = Font.system(size: Dimensions.fontSizeCompactTitle, weight: .semibold)
        public static let emptyStateIcon = Font.system(size: Dimensions.settingsEmptyStateIconSize)
        public static let outlineNodeTitle = Font.system(size: Dimensions.fontSizeCompactTitle)
        public static let outlineNodeBadge = Font.system(size: Dimensions.fontSizeMicro, weight: .bold)
        public static let tabBarIcon = Font.system(size: Dimensions.fontSizeMedium, weight: .medium)
        public static let tabBarTitle = Font.system(size: Dimensions.fontSizeCompactTitle, weight: .semibold)
        public static let gridDayNumber = Font.system(size: Dimensions.fontSizeSmall)
        public static let gridSubtext = Font.system(size: Dimensions.fontSizeGridSubtext, weight: .medium)
        public static let gridSubtextRegular = Font.system(size: Dimensions.fontSizeGridSubtext)
        public static let gridWeekday = Font.system(size: Dimensions.fontSizeMedium - 1, weight: .semibold)
        public static let monoCaption = Font.system(size: Dimensions.fontSizeNano, weight: .semibold, design: .monospaced)
        public static let rulerLabel = Font.system(size: Dimensions.fontSizeRuler, weight: .semibold, design: .monospaced)
        public static let inspectorHeaderIcon = Font.system(size: Dimensions.templateHeaderIconSize)
        public static let inspectorCommandIcon = Font.system(size: Dimensions.templateToolbarIconSize)
    }
}
