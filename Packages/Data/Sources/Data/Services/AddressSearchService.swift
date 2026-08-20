import Foundation
import MapKit
import Observation

@Observable
@MainActor
public final class AddressSearchService: NSObject, @MainActor MKLocalSearchCompleterDelegate {
    public var searchResults: [MKLocalSearchCompletion] = []
    public var isSearching: Bool = false
    public var errorMessage: String?

    private let completer: MKLocalSearchCompleter
    private var searchTask: Task<Void, Never>?
    private var searchGeneration = 0

    public override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()
        self.completer.delegate = self
        self.completer.resultTypes = [.address, .pointOfInterest]
        self.completer.pointOfInterestFilter = MKPointOfInterestFilter(including: [])
    }

    public func performSearch(query: String) {
        searchTask?.cancel()
        searchGeneration &+= 1
        let activeGeneration = searchGeneration

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.searchResults = []
            self.isSearching = false
            self.errorMessage = nil
            return
        }

        self.isSearching = true
        self.errorMessage = nil

        searchTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            self.completer.queryFragment = trimmed
            do {
                try await Task.sleep(for: .seconds(3))
            } catch is CancellationError {
                return
            } catch {
                return
            }
            guard self.searchGeneration == activeGeneration else { return }
            if self.searchResults.isEmpty && self.isSearching {
                self.isSearching = false
                self.errorMessage = "Search timed out. Please try again."
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
}
