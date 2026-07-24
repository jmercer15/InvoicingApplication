import SwiftUI
import SharedUI

struct ServiceAssignmentFilterBar: View {
    let categoryOptions: [String]
    let registrationGroupOptions: [String]
    let featureOptions: [String]
    let unitOptions: [String]
    let activeFilterChips: [ServiceAssignmentFilterChip]
    let hasActiveFilters: Bool

    @Binding var selectedCategory: String?
    @Binding var selectedRegistrationGroup: String?
    @Binding var selectedQuoteFilter: ServiceAssignmentQuoteFilter
    @Binding var selectedFeatures: Set<String>
    @Binding var selectedUnits: Set<String>
    @Binding var selectedSortOption: ServiceAssignmentSortOption

    let onFiltersChanged: () -> Void
    let onClearAllFilters: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
            HStack {
                categoryMenu
                registrationGroupMenu
                quoteFilterMenu
                Spacer()
            }
            HStack {
                featuresFilterMenu
                unitsFilterMenu
                Spacer()
                if hasActiveFilters {
                    clearAllFiltersButton
                }
                sortMenu
            }

            if hasActiveFilters {
                activeFiltersView.padding(.top, StyleGuide.Dimensions.paddingXSmall)
            }
        }
        .standardCardStyle()
    }

    private var categoryMenu: some View {
        Menu {
            Button("All Categories") {
                selectedCategory = nil
                onFiltersChanged()
            }
            .pointerStyle(.link)
            Divider()
            ForEach(categoryOptions, id: \.self) { category in
                Button(category) {
                    selectedCategory = category
                    onFiltersChanged()
                }
                .pointerStyle(.link)
            }
        } label: {
            Text("Category: \(selectedCategory ?? "All")")
        }
        .pickerStyle(.menu)
    }

    private var registrationGroupMenu: some View {
        Menu {
            Button("All Groups") {
                selectedRegistrationGroup = nil
                onFiltersChanged()
            }
            .pointerStyle(.link)
            Divider()
            ForEach(registrationGroupOptions, id: \.self) { group in
                Button(group) {
                    selectedRegistrationGroup = group
                    onFiltersChanged()
                }
                .pointerStyle(.link)
            }
        } label: {
            Text("Group: \(selectedRegistrationGroup ?? "All")")
        }
        .pickerStyle(.menu)
    }

    private var quoteFilterMenu: some View {
        Picker("Pricing", selection: $selectedQuoteFilter) {
            ForEach(ServiceAssignmentQuoteFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: selectedQuoteFilter) { _, _ in
            onFiltersChanged()
        }
    }

    private var sortMenu: some View {
        Picker("Sort By", selection: $selectedSortOption) {
            ForEach(ServiceAssignmentSortOption.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: selectedSortOption) { _, _ in
            onFiltersChanged()
        }
    }

    private var featuresFilterMenu: some View {
        Menu {
            ForEach(featureOptions, id: \.self) { feature in
                Button {
                    toggleFeature(feature)
                } label: {
                    HStack {
                        Text(feature)
                        Spacer()
                        if selectedFeatures.contains(feature) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .pointerStyle(.link)
            }
        } label: {
            Text("Features (\(selectedFeatures.count))")
        }
        .pickerStyle(.menu)
    }

    private var unitsFilterMenu: some View {
        Menu {
            ForEach(unitOptions, id: \.self) { unit in
                Button {
                    toggleUnit(unit)
                } label: {
                    HStack {
                        Text(unit)
                        Spacer()
                        if selectedUnits.contains(unit) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .pointerStyle(.link)
            }
        } label: {
            Text("Units (\(selectedUnits.count))")
        }
        .pickerStyle(.menu)
    }

    private var clearAllFiltersButton: some View {
        Button(action: onClearAllFilters) {
            Label("Clear All Filters", systemImage: "xmark.circle.fill")
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundColor(ColorSystem.Status.error)
        .pointerStyle(.link)
    }

    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(activeFilterChips, id: \.id) { filter in
                    HStack(spacing: StyleGuide.Dimensions.paddingXSmall) {
                        Text(filter.label)
                        Button(action: filter.remove) {
                            Image(systemName: "xmark.circle.fill")
                                .contentShape(Circle())
                        }
                        .accessibilityLabel("Remove filter \(filter.label)")
                        .accessibilityHint("Removes this active filter from search criteria")
                        .pointerStyle(.link)
                    }
                    .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                    .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
                    .background(ColorSystem.Primary.blue.opacity(StyleGuide.Opacity.medium))
                    .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall))
                    .buttonStyle(.plain)
                    .foregroundColor(StyleGuide.Colors.text)
                }
            }
        }
    }

    private func toggleFeature(_ feature: String) {
        if selectedFeatures.contains(feature) {
            selectedFeatures.remove(feature)
        } else {
            selectedFeatures.insert(feature)
        }
        onFiltersChanged()
    }

    private func toggleUnit(_ unit: String) {
        if selectedUnits.contains(unit) {
            selectedUnits.remove(unit)
        } else {
            selectedUnits.insert(unit)
        }
        onFiltersChanged()
    }
}

struct ServiceAssignmentFilterChip: Identifiable {
    let id: String
    let label: String
    let remove: () -> Void
}

enum ServiceAssignmentQuoteFilter: String, CaseIterable, Identifiable {
    case all
    case quoteRequired
    case noQuoteRequired

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Pricing: All"
        case .quoteRequired: return "Pricing: Quote Required"
        case .noQuoteRequired: return "Pricing: No Quote"
        }
    }
}

enum ServiceAssignmentSortOption: String, CaseIterable, Identifiable {
    case defaultOrder
    case nameAZ
    case nameZA
    case codeAZ
    case priceLowToHigh
    case priceHighToLow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaultOrder: return "Sort: Default"
        case .nameAZ: return "Sort: Name A-Z"
        case .nameZA: return "Sort: Name Z-A"
        case .codeAZ: return "Sort: Code A-Z"
        case .priceLowToHigh: return "Sort: Price Low-High"
        case .priceHighToLow: return "Sort: Price High-Low"
        }
    }
}
