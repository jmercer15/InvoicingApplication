import Foundation
import SwiftUI
import SharedUI

/// Layout helper for the all‑day strip.
struct AllDayLayoutEngine {
    // Display configuration
    let maxItemsToShow: Int
    let itemSpacing: CGFloat
    let columnHorizontalPadding: CGFloat
    let columnVerticalPadding: CGFloat
    let moreBadgeHorizontalPadding: CGFloat
    let moreBadgeVerticalPadding: CGFloat
    let stripHeight: CGFloat

    init(maxItemsToShow: Int = 3,
         itemSpacing: CGFloat = StyleGuide.Dimensions.paddingXSmall,
         columnHorizontalPadding: CGFloat = StyleGuide.Dimensions.paddingMedium,
         columnVerticalPadding: CGFloat = StyleGuide.Dimensions.paddingSmall,
         moreBadgeHorizontalPadding: CGFloat = StyleGuide.Dimensions.paddingSmall,
         moreBadgeVerticalPadding: CGFloat = StyleGuide.Dimensions.paddingXSmall,
         stripHeight: CGFloat = 40) {
        self.maxItemsToShow = maxItemsToShow
        self.itemSpacing = itemSpacing
        self.columnHorizontalPadding = columnHorizontalPadding
        self.columnVerticalPadding = columnVerticalPadding
        self.moreBadgeHorizontalPadding = moreBadgeHorizontalPadding
        self.moreBadgeVerticalPadding = moreBadgeVerticalPadding
        self.stripHeight = stripHeight
    }

    func visibleItems<T: RandomAccessCollection>(from items: T) -> Array<T.Element> where T.Element: Identifiable {
        Array(items.prefix(maxItemsToShow))
    }

    func moreCount<T: Collection>(for items: T) -> Int { max(0, items.count - maxItemsToShow) }
}


