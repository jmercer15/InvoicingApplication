import SwiftUI

/// Typography helpers for calendar week/month grid views.
/// Sizes remain dynamic (layout-derived) but font construction is centralized here.
public enum CalendarTypography {
    public static func gridScaled(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    public static func headerWeekday(size: CGFloat, isToday: Bool) -> Font {
        gridScaled(size, weight: isToday ? .bold : .semibold)
    }

    public static func headerDayNumber(size: CGFloat, isToday: Bool) -> Font {
        gridScaled(size, weight: isToday ? .bold : .regular)
    }

    public static func timeLabel(size: CGFloat, isMajor: Bool) -> Font {
        gridScaled(size, weight: isMajor ? .medium : .regular)
    }

    public static func blockTitle(size: CGFloat) -> Font {
        gridScaled(size, weight: .semibold)
    }

    public static func inlineLabel(size: CGFloat) -> Font {
        gridScaled(size)
    }

    public static func inlineIcon(size: CGFloat) -> Font {
        gridScaled(max(StyleGuide.Dimensions.paddingMedium, size - 1))
    }
}
