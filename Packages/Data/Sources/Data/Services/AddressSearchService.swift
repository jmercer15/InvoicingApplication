import Foundation
import MapKit

@MainActor
public final class AddressSearchService: NSObject, ObservableObject, @preconcurrency MKLocalSearchCompleterDelegate {
    @Published public var searchResults: [MKLocalSearchCompletion] = []
    @Published public var isSearching: Bool = false
    @Published public var errorMessage: String?

    private let completer: MKLocalSearchCompleter
    private var debounceTimer: Timer?

    public override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()
        self.completer.delegate = self
        self.completer.resultTypes = [.address, .pointOfInterest]
        self.completer.pointOfInterestFilter = MKPointOfInterestFilter(including: [])
    }

    public func performSearch(query: String) {
        debounceTimer?.invalidate()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.searchResults = []
            self.isSearching = false
            self.errorMessage = nil
            return
        }

        self.isSearching = true
        self.errorMessage = nil

        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.completer.queryFragment = trimmed
            }

            // Timeout safeguard
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self else { return }
                if self.searchResults.isEmpty && self.isSearching {
                    self.isSearching = false
                    self.errorMessage = "Search timed out. Please try again."
                }
            }
        }
    }

    // MARK: - MKLocalSearchCompleterDelegate
    public func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.searchResults = completer.results
        self.isSearching = false
        self.errorMessage = nil
    }

    public func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        self.isSearching = false
        self.searchResults = []
        self.errorMessage = "Search failed. Please try again."
    }

    // MARK: - MapKit Search
    public func fetchMapItem(for completion: MKLocalSearchCompletion) async -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.first
        } catch {
            return nil
        }
    }

    public func resolveAddress(
        for completion: MKLocalSearchCompletion
    ) async -> (mapItem: MKMapItem, parsedAddress: EventKitLocationParser.ParsedLocation)? {
        guard let mapItem = await fetchMapItem(for: completion) else { return nil }
        let parsed = MapKitAddressResolver.parseAddress(from: mapItem)
        return (mapItem, parsed)
    }

    // MARK: - Parsing Helpers
    /// Parses an address string to extract individual components
    /// This is a best-effort parsing that may not work for all address formats
    public func parseAddressString(_ addressString: String) -> [String: String] {
        let parsed = EventKitLocationParser.parse(locationText: addressString)
        var components: [String: String] = [:]
        components["unit"] = parsed.unitNumber
        components["streetNumber"] = parsed.streetNumber
        components["streetName"] = parsed.streetName
        components["suburb"] = parsed.suburb
        components["city"] = parsed.city
        components["state"] = parsed.state
        components["postcode"] = parsed.postcode
        components["country"] = parsed.country
        components["poBox"] = parsed.poBox
        components["fullAddressText"] = parsed.fullAddressText
        return components
    }
}

