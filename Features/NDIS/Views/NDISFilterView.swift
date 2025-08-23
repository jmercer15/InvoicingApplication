import SwiftUI

struct IdentifiableString: Identifiable, Hashable {
    let id: String
    var value: String { id }
    init(_ id: String) { self.id = id }
}

struct NDISFilterView: View {
    @ObservedObject var viewModel: NDISContainerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("Filters & Sorting")
                .font(.title2.bold())
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)

            VStack(alignment: .leading, spacing: 20) {
                Text("Filters")
                    .font(.headline)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 12) {
                    FormDropdown(
                        label: "Category",
                        options: viewModel.cachedCategories,
                        optionLabels: viewModel.categoryLabels,
                        selection: $viewModel.selectedCategoryId
                    )
                    FormDropdown(
                        label: "Registration Group",
                        options: viewModel.cachedRegistrationGroups,
                        optionLabels: viewModel.registrationGroupLabels,
                        selection: $viewModel.selectedRegistrationGroup
                    )
                    FormMultiSelect(
                        label: "Features",
                        options: viewModel.cachedFeatures.map(IdentifiableString.init),
                        optionLabels: Dictionary(uniqueKeysWithValues: viewModel.cachedFeatures.map { (IdentifiableString($0), $0) }),
                        selectedOptions: Binding(
                            get: { Set(viewModel.currentSelectedFeatures.map(IdentifiableString.init)) },
                            set: { viewModel.currentSelectedFeatures = Array($0.map { $0.id }) }
                        )
                    )
                    

                }
                Text("Sorting")
                    .font(.headline)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 12) {
                    FormDropdown(
                        label: "Sort By",
                        options: NDISContainerViewModel.SortOrder.allCases,
                        optionLabels: viewModel.sortOptionLabels,
                        selection: Binding<NDISContainerViewModel.SortOrder?>(
                            get: { viewModel.sortOrder },
                            set: { newValue in
                                if let value = newValue { viewModel.sortOrder = value }
                            }
                        )
                    )
                }
            }
            .padding(.horizontal)
            HStack {
                Button("Reset") {
                    viewModel.clearAllFilters()
                    dismiss()
                }
                .buttonStyle(StandardToolbarButtonStyle(tintColor: .red))
                .appInteractiveCursor()
                Spacer()
                Button("Apply") {
                    dismiss()
                }
                .buttonStyle(StandardToolbarButtonStyle())
                .appInteractiveCursor()
            }
            .padding()
        }
        .frame(minWidth: 350, idealWidth: 400)
    }
} 