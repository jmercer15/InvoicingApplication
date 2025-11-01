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

    // MARK: - Parsing Helpers
    /// Parses an address string to extract individual components
    /// This is a best-effort parsing that may not work for all address formats
    public func parseAddressString(_ addressString: String) -> [String: String] {
        var components: [String: String] = [:]
        let address = addressString.trimmingCharacters(in: .whitespacesAndNewlines)

        let patterns: [(String, String)] = [
            (#"Unit\s+([^,]+),\s*(\d+)\s+(.+?)(?:,|$)"#, "unit"),
            (#"^(\d+)\s+(.+?)(?:,|$)"#, "streetNumber"),
            (#"([A-Z]{2,3})\s+(\d{4})"#, "state"),
            (#"(\d{4})"#, "postcode"),
            (#"([A-Za-z]+)$"#, "country")
        ]

        for (pattern, componentType) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: address, options: [], range: NSRange(location: 0, length: address.utf16.count))
                for match in matches {
                    switch componentType {
                    case "unit":
                        if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: address) {
                            components["unit"] = String(address[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    case "streetNumber":
                        if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: address) {
                            components["streetNumber"] = String(address[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        if match.numberOfRanges > 2, let range = Range(match.range(at: 2), in: address) {
                            components["streetName"] = String(address[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    case "state":
                        if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: address) {
                            components["state"] = String(address[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        if match.numberOfRanges > 2, let range = Range(match.range(at: 2), in: address) {
                            components["postcode"] = String(address[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    case "postcode":
                        if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: address) {
                            components["postcode"] = String(address[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    case "suburb":
                        if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: address) {
                            components["suburb"] = String(address[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    case "country":
                        if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: address) {
                            components["country"] = String(address[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    default:
                        break
                    }
                }
            }
        }

        return components
    }
}


