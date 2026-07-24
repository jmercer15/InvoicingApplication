import SwiftUI
import MapKit
import Core
import Data
import SharedUI

// MARK: - NativeAddressSearchField Component

public struct NativeAddressSearchField: View {
    @Binding var searchText: String
    @Binding var selectedAddress: AddressData?

    // Address field bindings
    @Binding var unitNumber: String
    @Binding var streetNumber: String
    @Binding var streetName: String
    @Binding var suburb: String
    @Binding var postcode: String
    @Binding var state: String
    @Binding var country: String
    @Binding var poBox: String

    // Search state managed by service
    @State private var service = AddressSearchService()
    @State private var showResults = false
    @State private var suppressedSearchTextChangeCount = 0

    public init(
        searchText: Binding<String>,
        selectedAddress: Binding<AddressData?>,
        unitNumber: Binding<String>,
        streetNumber: Binding<String>,
        streetName: Binding<String>,
        suburb: Binding<String>,
        postcode: Binding<String>,
        state: Binding<String>,
        country: Binding<String>,
        poBox: Binding<String>
    ) {
        self._searchText = searchText
        self._selectedAddress = selectedAddress
        self._unitNumber = unitNumber
        self._streetNumber = streetNumber
        self._streetName = streetName
        self._suburb = suburb
        self._postcode = postcode
        self._state = state
        self._country = country
        self._poBox = poBox
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Find:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("White", bundle: .sharedUI))

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        TextField("Street, suburb, or place", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(Color("White", bundle: .sharedUI))
                            .accessibilityLabel("Address search")
                            .accessibilityHint("Type to search. Pick a result to fill address fields.")
                            .accentColor(service.errorMessage != nil ? Color("Cancelled", bundle: .sharedUI) : Color("Draft", bundle: .sharedUI))
                            .onChange(of: searchText) { _, newValue in
                                if suppressedSearchTextChangeCount > 0 {
                                    suppressedSearchTextChangeCount -= 1
                                    return
                                }
                                performSearch(query: newValue)
                            }
                            .onAppear {
                                if searchText.isEmpty && hasExistingAddressData {
                                    setSearchTextWithoutTriggeringSearch(formatExistingAddress())
                                }
                            }

                        // Loading indicator
                        if service.isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(Color("White", bundle: .sharedUI))
                        }
                    }

                    // Error message
                    if let error = service.errorMessage {
                        Text(error)
                            .foregroundColor(Color("Cancelled", bundle: .sharedUI))
                            .font(.caption)
                            .padding(.top, StyleGuide.Dimensions.paddingXSmall)
                    }

                    // Search Results Dropdown
                    if showResults && !service.searchResults.isEmpty {
                        searchResultsView
                    }
                }
            }
        }
        .onChange(of: service.searchResults) { _, newValue in
            showResults = !newValue.isEmpty && !searchText.isEmpty
        }
    }

    private var searchResultsView: some View {
        AddressSearchResultsList(results: service.searchResults, onSelect: selectAddress)
    }

    private func performSearch(query: String) {
        service.performSearch(query: query)
    }

    private func selectAddress(_ result: MKLocalSearchCompletion) {
        setSearchTextWithoutTriggeringSearch(result.title + ", " + result.subtitle)
        showResults = false

        Task {
            if let item = await service.fetchMapItem(for: result) {
                fillAddressFields(from: item)
            }
        }
    }

    private func fillAddressFields(from mapItem: MKMapItem) {
        let parsed = Core.MapKitAddressResolver.parseAddress(from: mapItem)
        unitNumber = parsed.unitNumber
        streetNumber = parsed.streetNumber
        streetName = parsed.streetName
        suburb = parsed.suburb.isEmpty ? parsed.city : parsed.suburb
        postcode = parsed.postcode
        state = parsed.state
        country = parsed.country
        poBox = parsed.poBox

        selectedAddress = AddressData(
            unitNumber: unitNumber,
            streetNumber: streetNumber,
            streetName: streetName,
            suburb: suburb,
            state: state,
            postcode: postcode,
            country: country,
            poBox: poBox
        )

        setSearchTextWithoutTriggeringSearch("")
    }

    private func setSearchTextWithoutTriggeringSearch(_ value: String) {
        suppressedSearchTextChangeCount += 1
        searchText = value
    }

    private var hasExistingAddressData: Bool {
        !unitNumber.isEmpty || !streetNumber.isEmpty || !streetName.isEmpty ||
            !suburb.isEmpty || !state.isEmpty || !postcode.isEmpty ||
            !country.isEmpty || !poBox.isEmpty
    }

    private func formatExistingAddress() -> String {
        var parts: [String] = []

        if !poBox.isEmpty {
            parts.append("PO Box \(poBox)")
        } else {
            // Handle street address components
            var streetComponents: [String] = []

            if !unitNumber.isEmpty {
                streetComponents.append("Unit \(unitNumber)")
            }

            // Combine street number and name without comma
            var streetAddress = ""
            if !streetNumber.isEmpty {
                streetAddress += streetNumber
            }
            if !streetName.isEmpty {
                if !streetAddress.isEmpty {
                    streetAddress += " "
                }
                streetAddress += streetName
            }

            if !streetAddress.isEmpty {
                streetComponents.append(streetAddress)
            }

            if !streetComponents.isEmpty {
                parts.append(streetComponents.joined(separator: ", "))
            }
        }

        // Add locality components
        if !suburb.isEmpty { parts.append(suburb) }
        if !state.isEmpty { parts.append(state) }
        if !postcode.isEmpty { parts.append(postcode) }
        if !country.isEmpty { parts.append(country) }

        return parts.joined(separator: ", ")
    }
}

// MARK: - Search Results List

/// Immutable snapshot of completer results for safe `ForEach` iteration.
private struct AddressSearchResultsList: View {
    let results: [MKLocalSearchCompletion]
    let onSelect: (MKLocalSearchCompletion) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(results.indices, id: \.self) { index in
                    let result = results[index]
                    Button(action: {
                        onSelect(result)
                    }) {
                        HStack(spacing: StyleGuide.Dimensions.paddingMediumLarge) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                                .font(StyleGuide.Typography.itemSubtitle)

                            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                                Text(result.title)
                                    .foregroundColor(Color("Text", bundle: .sharedUI))
                                    .font(StyleGuide.Typography.bodyMedium)
                                    .lineLimit(1)

                                Text(result.subtitle)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                    .font(StyleGuide.Typography.itemSubtitle)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
                        .padding(.vertical, StyleGuide.Dimensions.paddingXMedium)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(Color("Black30", bundle: .sharedUI))
                    .contentShape(Rectangle())

                    if index < results.count - 1 {
                        Divider()
                            .background(Color("White10", bundle: .sharedUI))
                            .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
                    }
                }
            }
        }
        .frame(maxHeight: 200)
        .background(Color("White15", bundle: .sharedUI))
        .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
        .padding(.top, StyleGuide.Dimensions.paddingXSmall)
    }
}
