import SwiftUI
import Core

public enum DetailSectionTokens {
    public static let contentPadding: CGFloat = 12
    public static let listMinHeight: CGFloat = 200
    public static let listFooterHeight: CGFloat = 28
    public static let listMaxHeight: CGFloat = listMinHeight + listFooterHeight
    public static let listRowSpacing: CGFloat = 4
    public static let listRowInsets = EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
    public static let sortPickerWidth: CGFloat = 120
    public static let detailCardMinimumWidth: CGFloat = 420
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
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
            Text(title)
                .fontWeight(.bold)
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
                    .font(.subheadline)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
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

