import SwiftUI
import Data
import Core
import SharedUI

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
                    FormField("Category") {
                        Picker("", selection: $viewModel.selectedCategoryId) {
                            Text("All Categories").tag(nil as String?)
                            ForEach(viewModel.cachedCategories, id: \.self) { category in
                                Text(viewModel.categoryLabels[category] ?? category).tag(category as String?)
                            }
                        }
                        .pickerStyle(.menu)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.selectedCategoryId)
                    }
                    FormField("Registration Group") {
                        Picker("", selection: $viewModel.selectedRegistrationGroup) {
                            Text("All Groups").tag(nil as String?)
                            ForEach(viewModel.cachedRegistrationGroups, id: \.self) { group in
                                Text(viewModel.registrationGroupLabels[group] ?? group).tag(group as String?)
                            }
                        }
                        .pickerStyle(.menu)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.selectedRegistrationGroup)
                    }
                    FormField("Features") {
                        ScrollView {
                            LazyVStack(alignment: .leading) {
                                ForEach(viewModel.cachedFeatures, id: \.self) { feature in
                                    HStack {
                                        Button(action: {
                                            if viewModel.currentSelectedFeatures.contains(feature) {
                                                viewModel.currentSelectedFeatures.removeAll { $0 == feature }
                                            } else {
                                                viewModel.currentSelectedFeatures.append(feature)
                                            }
                                        }) {
                                            Image(systemName: viewModel.currentSelectedFeatures.contains(feature) ? "checkmark.square.fill" : "square")
                                                .foregroundColor(viewModel.currentSelectedFeatures.contains(feature) ? .blue : .gray)
                                        }
                                        .buttonStyle(.plain)
                                        Text(feature)
                                        Spacer()
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                        .frame(maxHeight: 100)
                    }
                }
                Text("Sorting")
                    .font(.headline)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 12) {
                    FormField("Sort By") {
                        Picker("", selection: $viewModel.sortOrder) {
                            ForEach(NDISContainerViewModel.SortOrder.allCases, id: \.self) { order in
                                Text(viewModel.sortOptionLabels[order] ?? String(describing: order)).tag(order)
                            }
                        }
                        .pickerStyle(.menu)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.sortOrder)
                    }
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
