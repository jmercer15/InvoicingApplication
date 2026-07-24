import SwiftUI
import Core

public enum DetailSectionTokens {
    public static let contentPadding: CGFloat = StyleGuide.Dimensions.paddingMediumLarge
    public static let listMinHeight: CGFloat = 200
    public static let listFooterHeight: CGFloat = 28
    public static let listMaxHeight: CGFloat = listMinHeight + listFooterHeight
    public static let listRowSpacing: CGFloat = StyleGuide.Dimensions.paddingXSmall
    public static let listRowInsets = EdgeInsets(
        top: 2,
        leading: StyleGuide.Dimensions.paddingXSmall / 2,
        bottom: 2,
        trailing: StyleGuide.Dimensions.paddingXSmall / 2
    )
    public static let sortPickerWidth: CGFloat = 120
    public static let detailCardMinimumWidth: CGFloat = 420
    public static let priceChipMinWidth: CGFloat = 170
    public static let catalogueChipMinWidth: CGFloat = 180
    public static let headerSpacing: CGFloat = StyleGuide.Dimensions.paddingMedium
    public static let formStackSpacing: CGFloat = StyleGuide.Dimensions.paddingLarge
    public static let formRowSpacing: CGFloat = StyleGuide.Dimensions.paddingSmall
    public static let sectionListSpacing: CGFloat = StyleGuide.Dimensions.paddingMediumLarge
    public static let sectionListRowSpacing: CGFloat = StyleGuide.Dimensions.paddingMedium
}

public enum DetailToolbarTokens {
    public static let titleBadgeSpacing: CGFloat = StyleGuide.Dimensions.toolbarTitleStackSpacing
    public static let titleSubtitleSpacing: CGFloat = StyleGuide.Dimensions.toolbarTitleSubtitleSpacing
}

public enum EmptyStateTokens {
    public static let iconTitleSpacing: CGFloat = StyleGuide.Dimensions.paddingXMedium + 5
    public static let titleMessageSpacing: CGFloat = StyleGuide.Dimensions.paddingXSmall + 1
}

public enum FormSectionTokens {
    public static let labelFieldSpacing: CGFloat = StyleGuide.Dimensions.paddingXSmall
    public static let fieldStackSpacing: CGFloat = StyleGuide.Dimensions.paddingMedium
    public static let sectionStackSpacing: CGFloat = StyleGuide.Dimensions.paddingMediumLarge
    public static let formGroupSpacing: CGFloat = StyleGuide.Dimensions.paddingLarge
    public static let pageStackSpacing: CGFloat = StyleGuide.Dimensions.paddingXXLarge
}

public enum ListRowTokens {
    public static let titleSubtitleSpacing: CGFloat = StyleGuide.Dimensions.paddingXXSmall
    public static let rowContentSpacing: CGFloat = StyleGuide.Dimensions.paddingMediumLarge
    public static let rowPadding: CGFloat = StyleGuide.Dimensions.paddingMediumLarge
    public static let rowCornerRadius: CGFloat = StyleGuide.Dimensions.cornerRadiusMedium
    public static let entityDotSize: CGFloat = StyleGuide.Dimensions.statusDotSize + 4
    public static let metadataSpacing: CGFloat = StyleGuide.Dimensions.paddingXXSmall
    public static let hoverStrokeOpacity: CGFloat = 0.7
    public static let defaultStrokeOpacity: CGFloat = 0.45
    public static let selectedStrokeWidth: CGFloat = 1.5
    public static let defaultStrokeWidth: CGFloat = 0.8
}

public protocol DetailSectionSortOption: CaseIterable, Hashable {
    var displayName: String { get }
}

extension ServicesSortOrder: DetailSectionSortOption {}
extension ClientsSortOrder: DetailSectionSortOption {}
extension InvoicesSortOrder: DetailSectionSortOption {}

public struct DetailSectionHeader<Trailing: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    public init(
        icon: String,
        title: String,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.trailing = trailing
    }

    public init(icon: String, title: String) where Trailing == EmptyView {
        self.icon = icon
        self.title = title
        self.trailing = { EmptyView() }
    }

    public var body: some View {
        HStack(spacing: DetailSectionTokens.headerSpacing) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(StyleGuide.Typography.sectionTitle)
                .foregroundStyle(StyleGuide.Colors.text)
            Spacer()
            trailing()
        }
    }
}

public struct DetailSectionSortPicker<Option: DetailSectionSortOption>: View {
    @Binding var selection: Option

    public init(selection: Binding<Option>) {
        self._selection = selection
    }

    public var body: some View {
        Picker("Sort", selection: $selection) {
            ForEach(Array(Option.allCases), id: \.self) { option in
                Text(option.displayName).tag(option)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: DetailSectionTokens.sortPickerWidth)
    }
}

public struct DetailListBody<Rows: View>: View {
    let isEmpty: Bool
    let emptyMessage: String
    let maxHeight: CGFloat
    @ViewBuilder let rows: () -> Rows

    public init(
        isEmpty: Bool,
        emptyMessage: String,
        maxHeight: CGFloat = DetailSectionTokens.listMaxHeight,
        @ViewBuilder rows: @escaping () -> Rows
    ) {
        self.isEmpty = isEmpty
        self.emptyMessage = emptyMessage
        self.maxHeight = maxHeight
        self.rows = rows
    }

    public var body: some View {
        Group {
            if isEmpty {
                Text(emptyMessage)
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: DetailSectionTokens.listMinHeight, alignment: .center)
                    .padding(DetailSectionTokens.listRowInsets)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DetailSectionTokens.listRowSpacing) {
                        rows()
                    }
                }
            }
        }
        .frame(maxHeight: maxHeight)
    }
}

