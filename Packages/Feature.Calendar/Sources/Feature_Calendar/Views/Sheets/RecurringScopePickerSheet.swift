import SwiftUI
import Core
import SharedUI

struct RecurringScopePickerSheet: View {
    let title: String
    let options: [RecurringEditMode]
    let isDestructive: Bool
    let label: (RecurringEditMode) -> String
    let detail: (RecurringEditMode) -> String
    let recommended: RecurringEditMode?
    let onSelect: (RecurringEditMode) -> Void

    @Environment(\.dismiss) private var dismiss

    private var orderedOptions: [RecurringEditMode] {
        guard let recommended, options.contains(recommended) else { return options }
        return [recommended] + options.filter { $0 != recommended }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(isDestructive
                         ? "Choose how broadly this delete should apply."
                         : "Choose how broadly these changes should apply.")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(Color.secondary)
                }

                if orderedOptions.isEmpty {
                    Text("No available actions")
                        .foregroundStyle(Color.secondary)
                } else {
                    ForEach(orderedOptions, id: \.self) { mode in
                        Button(role: isDestructive ? .destructive : nil) {
                            dismiss()
                            Task { @MainActor in
                                onSelect(mode)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: mode.iconName)
                                    .foregroundStyle(isDestructive ? ColorSystem.Status.error : Color.accentColor)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                                    HStack(spacing: 6) {
                                        Text(label(mode))
                                        if recommended == mode {
                                            Text("Recommended")
                                                .font(StyleGuide.Typography.nano)
                                                .foregroundStyle(Color.secondary)
                                        }
                                    }
                                    Text(detail(mode))
                                        .font(StyleGuide.Typography.itemSubtitle)
                                        .foregroundStyle(Color.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
            .navigationTitle(title)
            .toolbar {
                AppToolbarSheetDismissBar { dismiss() }
            }
        }
        .frame(minWidth: StyleGuide.Dimensions.recurringScopeSheetMinWidth, idealWidth: StyleGuide.Dimensions.recurringScopeSheetIdealWidth, minHeight: StyleGuide.Dimensions.recurringScopeSheetMinHeight, idealHeight: StyleGuide.Dimensions.recurringScopeSheetIdealHeight)
    }
}
