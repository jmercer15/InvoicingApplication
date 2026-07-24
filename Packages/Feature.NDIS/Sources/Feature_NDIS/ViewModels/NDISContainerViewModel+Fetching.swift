import SwiftUI
import SwiftData
import Core
import Data

extension NDISContainerViewModel {

    // MARK: - Data Processing Entry Point

    @MainActor
    public func refreshItems(_ itemIDs: [UUID]) async {
        await refreshItems(allSupportItems(from: itemIDs))
    }
    
    @MainActor
    public func refreshItems(_ itemSnapshots: [NDISItemSnapshot]) async {
        let incomingItemIDs = itemSnapshots.map(\.id)
        guard !hasLoadedCatalogue || allSupportItemIDs != incomingItemIDs else { return }

        hasLoadedCatalogue = true
        loadError = nil
        allSupportItemIDs = incomingItemIDs
        supportItemSnapshotsByID = Dictionary(uniqueKeysWithValues: itemSnapshots.map { ($0.id, $0) })
        await submitProjectionUpdate(context: makeProcessingContext(using: itemSnapshots)).value
    }

    @MainActor
    public func refreshPreferredRegion(using business: Business?) {
        hasResolvedPreferredRegion = true
        let nextRegion = Self.regionIdentifier(for: business?.address)
        guard preferredRegionIdentifier != nextRegion else { return }
        preferredRegionIdentifier = nextRegion
        if hasLoadedCatalogue {
            scheduleDataProcessing()
        }
    }
    
    @MainActor
    public func fetchChangesSummary() async {
        isAnalyzingChanges = true
        changesError = nil
        defer { isAnalyzingChanges = false }
        
        do {
            let container = modelContext.container
            let actor = NDISVersioningActor(modelContainer: container)
            let summary = try await actor.getChangesSummary()
            self.changesSummary = summary
            self.changesError = nil
        } catch {
            print("Error fetching changes summary: \(error)")
            self.changesError = error
        }
    }
    
    @MainActor
    public func loadItemHistory(for itemNumber: String) async {
        isAnalyzingChanges = true
        defer { isAnalyzingChanges = false }
        
        do {
            let container = modelContext.container
            let actor = NDISVersioningActor(modelContainer: container)
            let changes = try await actor.analyzeItemChanges(itemNumber: itemNumber)
            self.itemChanges = changes
        } catch {
            print("Error loading item history for \(itemNumber): \(error)")
        }
    }
}
