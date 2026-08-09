import SwiftUI
import DataInterfaces
import Core
import PersistenceModels
import SharedUI
import MapKit
import Observation
import SwiftData

@Observable
@MainActor
public final class TravelChargeAutomationViewModel {
    // MARK: - Dependencies
    private let modelContext: ModelContext
    /// Mirrors the latest `TravelChargeAutomationTestView` `@Query` snapshot for PID resolution without per-id fetches.
    private var sessionsById: [UUID: Session] = [:]
    /// Cancels stale background expansion when session query updates rapidly.
    private var expansionTask: Task<Void, Never>?
    private let automationActor: any TravelChargeAutomating
    private let geocodingService: any Core.GeocodingServiceProtocol
    private let mmmZoneLookup: any Core.MMMZoneLookupProtocol
    private let recurrenceRuleManager: Core.RecurrenceRuleManager
    private let expansionWorker = TravelChargeSessionExpansionWorker()

    // MARK: - Published Properties
    var selectedSessionInstances: Set<String> = []
    var cachedExpandedSessions: [TravelChargeSessionInstance] = []
    
    var isRunning: Bool = false
    var errorMessage: String? = nil
    var mmmZoneResult: String? = nil
    var mmmZoneForAddress: String? = nil
    
    var testChargeSummaries: [String] = []
    var testReviewSummaries: [String] = []
    var testDetailedReviewItems: [Core.DetailedReviewItem] = []
    
    var businessAddressInfo: BusinessAddressInfo? = nil
    var isLoadingBusinessAddress: Bool = false
    
    // Address search state
    var addressSearchText: String = ""
    var selectedAddress: AddressData? = nil

    public struct BusinessAddressInfo {
        public let hasBusiness: Bool
        public let fullFormattedAddress: String
        public let fullAddressText: String
        public let streetName: String
        public let suburb: String
        public let state: String
        public let postcode: String

        public var hasAddress: Bool {
            !fullFormattedAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    // MARK: - Initialization
    public init(
        modelContext: ModelContext,
        automationActor: any TravelChargeAutomating,
        geocodingService: any Core.GeocodingServiceProtocol,
        mmmZoneLookup: any Core.MMMZoneLookupProtocol,
        recurrenceRuleManager: Core.RecurrenceRuleManager
    ) {
        self.modelContext = modelContext
        self.automationActor = automationActor
        self.geocodingService = geocodingService
        self.mmmZoneLookup = mmmZoneLookup
        self.recurrenceRuleManager = recurrenceRuleManager
    }
    
    // MARK: - Public API
    
    public func getSession(by id: UUID) -> Session? {
        return sessionsById[id]
    }

    func updateSessions(_ sessions: [Session]) {
        sessionsById = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        let snapshots = sessions.map { $0.snapshot() }
        let calendar = Calendar.current
        let today = Date()

        let startOfRange = calendar.date(byAdding: .month, value: -6, to: today) ?? today
        let endOfRange = calendar.date(byAdding: .month, value: 6, to: today) ?? today

        let manager = recurrenceRuleManager
        expansionTask?.cancel()
        expansionTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let expanded = await self.expansionWorker.expand(
                from: snapshots,
                rangeStart: startOfRange,
                rangeEnd: endOfRange,
                recurrenceRuleManager: manager
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.cachedExpandedSessions = expanded
                let validInstanceIDs = Set(expanded.map(\.uniqueInstanceId))
                self.selectedSessionInstances = self.selectedSessionInstances.intersection(validInstanceIDs)
            }
        }
    }

    func updateBusiness(_ business: Business?) {
        applyBusinessAddressInfo(from: business)
    }

    public func loadBootstrapData(using fetcher: any ReferenceDataFetching) async {
        do {
            let bootstrap = try await fetcher.fetchTravelChargeBootstrapData()
            let sessionIDs = bootstrap.sessions.map(\.id)
            if sessionIDs.isEmpty {
                updateSessions([])
            } else {
                let predicate = #Predicate<Session> { sessionIDs.contains($0.id) }
                let sessions = try modelContext.fetch(FetchDescriptor<Session>(predicate: predicate))
                updateSessions(sessions)
            }

            if let businessID = bootstrap.primaryBusiness?.id {
                let businessPredicate = #Predicate<Business> { $0.id == businessID }
                let business = try modelContext.fetch(
                    FetchDescriptor<Business>(predicate: businessPredicate)
                ).first
                updateBusiness(business)
            } else {
                updateBusiness(nil)
            }
        } catch {
            print("Failed to load travel charge bootstrap data: \(error)")
        }
    }
    
    func runAutomation() async {
        guard !selectedSessionInstances.isEmpty else { return }
        
        isRunning = true
        errorMessage = nil
        testChargeSummaries = []
        testReviewSummaries = []
        testDetailedReviewItems = []
        
        let selectedInstances = cachedExpandedSessions.filter { selectedSessionInstances.contains($0.uniqueInstanceId) }
        let selectedSessionIDs = Set(selectedInstances.map { $0.session.session.id })
        let modelIDs = modelIDs(for: selectedSessionIDs)
        
        let earliestDate = selectedInstances.map { $0.instanceStart }.min() ?? Date()
        let latestDate = selectedInstances.map { $0.instanceEnd }.max() ?? Date()
        let dateRange = earliestDate...latestDate
        
        let result = await automationActor.runAutomation(
            sessionModelIDs: modelIDs,
            dateRange: dateRange,
            testingMode: true,
            mmmZoneLookup: mmmZoneLookup,
            recurrenceRuleManager: recurrenceRuleManager
        )
        self.testChargeSummaries = result.charges
        self.testReviewSummaries = result.reviews
        self.testDetailedReviewItems = result.detailedReviews
        self.isRunning = false
    }
    
    /// Uses the session model from the workspace `@Query` snapshot when available.
    public func showMMMZone(for session: Session?) async {
        guard let session else {
            mmmZoneResult = "Session no longer available."
            return
        }
        await resolveMMMZone(for: session)
    }
    
    private func resolveMMMZone(for session: Session) async {
        if session.sessionLatitude != 0 || session.sessionLongitude != 0 {
            let coord = CLLocationCoordinate2D(latitude: session.sessionLatitude, longitude: session.sessionLongitude)
            if let mmmCode = mmmZoneLookup.mmm(for: coord) {
                mmmZoneResult = "Code: \(mmmCode) for coordinates"
            } else {
                mmmZoneResult = "No MMM zone found for coordinates"
            }
        } else if let address = session.location, !address.isEmpty {
            if let coordinate = await geocodingService.geocodeAddressString(address) {
                let resolvedCoordinate = CLLocationCoordinate2D(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                session.sessionLatitude = resolvedCoordinate.latitude
                session.sessionLongitude = resolvedCoordinate.longitude
                do {
                    try modelContext.save()
                } catch {
                    errorMessage = "Failed to persist session coordinates: \(error.localizedDescription)"
                }

                if let mmmCode = mmmZoneLookup.mmm(for: resolvedCoordinate) {
                    mmmZoneResult = "Code: \(mmmCode) for coordinates (after geocoding)"
                } else {
                    mmmZoneResult = "No MMM zone found for coordinates (after geocoding)"
                }
            } else {
                mmmZoneResult = "No location found for address"
            }
        } else {
            mmmZoneResult = "Session has no address or coordinates."
        }
    }
    
    func runMMMZoneLookupOnAddress(_ address: AddressData) async {
        let addressString = address.fullAddress
        guard !addressString.isEmpty else {
            mmmZoneForAddress = "No address selected."
            return
        }
        
        if let coordinate = await geocodingService.geocodeAddressString(addressString) {
            let resolvedCoordinate = CLLocationCoordinate2D(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            if let mmmCode = mmmZoneLookup.mmm(for: resolvedCoordinate) {
                self.mmmZoneForAddress = "Code: \(mmmCode) for coordinates (after geocoding)"
            } else {
                self.mmmZoneForAddress = "No MMM zone found for coordinates (after geocoding)"
            }
        } else {
            self.mmmZoneForAddress = "No location found for address"
        }
    }
    
    func toggleSessionSelection(instanceId: String) {
        if selectedSessionInstances.contains(instanceId) {
            selectedSessionInstances.remove(instanceId)
        } else {
            selectedSessionInstances.insert(instanceId)
        }
    }
    
    // MARK: - Private Helpers
    
    private func modelIDs(for sessionIDs: Set<UUID>) -> [PersistentIdentifier] {
        guard !sessionIDs.isEmpty else { return [] }
        var modelIDs: [PersistentIdentifier] = []
        modelIDs.reserveCapacity(sessionIDs.count)
        for id in sessionIDs {
            if let session = sessionsById[id] {
                modelIDs.append(session.persistentModelID)
            }
        }
        return modelIDs
    }

    private func applyBusinessAddressInfo(from business: Business?) {
        guard let business else {
            businessAddressInfo = nil
            return
        }

        let address = business.address
        businessAddressInfo = BusinessAddressInfo(
            hasBusiness: true,
            fullFormattedAddress: address?.fullFormattedAddress ?? "",
            fullAddressText: address?.fullAddressText ?? address?.fullFormattedAddress ?? "",
            streetName: address?.streetName ?? "",
            suburb: {
                let suburb = address?.suburb.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !suburb.isEmpty { return suburb }
                return address?.city ?? ""
            }(),
            state: address?.state ?? "",
            postcode: address?.postcode ?? ""
        )
    }
}

private actor TravelChargeSessionExpansionWorker {
    func expand(
        from snapshots: [SessionSnapshot],
        rangeStart: Date,
        rangeEnd: Date,
        recurrenceRuleManager: Core.RecurrenceRuleManager
    ) async -> [TravelChargeSessionInstance] {
        TravelChargeAutomationSessionExpansion.buildExpandedInstances(
            from: snapshots,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            recurrenceRuleManager: recurrenceRuleManager
        )
    }
}
