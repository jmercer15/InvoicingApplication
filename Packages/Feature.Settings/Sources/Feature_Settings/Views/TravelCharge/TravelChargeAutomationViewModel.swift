import SwiftUI
import Combine
import Data
import Core
import SharedUI
import MapKit

@MainActor
public final class TravelChargeAutomationViewModel: ObservableObject {
    // MARK: - Dependencies
    public let unitOfWork: UnitOfWorkService
    public let automationService: TravelChargeAutomationService
    
    // MARK: - Published Properties
    @Published var sessions: [SessionEntity] = []
    @Published var selectedSessionInstances: Set<String> = []
    @Published var cachedExpandedSessions: [TravelChargeAutomationService.SessionInstance] = []
    
    @Published var isRunning: Bool = false
    @Published var errorMessage: String? = nil
    @Published var mmmZoneResult: String? = nil
    @Published var mmmZoneForAddress: String? = nil
    
    @Published var testChargeSummaries: [String] = []
    @Published var testReviewSummaries: [String] = []
    @Published var testDetailedReviewItems: [DetailedReviewItem] = []
    
    @Published var businessAddressInfo: BusinessAddressInfo? = nil
    @Published var isLoadingBusinessAddress: Bool = false
    
    // Address search state
    @Published var addressSearchText: String = ""
    @Published var selectedAddress: AddressData? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
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
    public init(unitOfWork: UnitOfWorkService) {
        self.unitOfWork = unitOfWork
        // Initialize automation service in testing mode by default for the test view
        self.automationService = TravelChargeAutomationService(
            unitOfWork: unitOfWork,
            businessRules: BusinessRules(),
            userPreferences: UserPreferences(),
            mmmZoneTable: MMMZoneTable(),
            testingMode: true
        )
    }
    
    // MARK: - Public API
    
    func refreshSessions() async {
        do {
            let fetchedSessions = try await unitOfWork.sessions.fetchAll()
            self.sessions = try resolveSessionEntities(for: fetchedSessions.map { $0.id })
            self.computeExpandedSessions()
        } catch {
            self.errorMessage = "Failed to fetch sessions: \(error.localizedDescription)"
        }
    }
    
    func computeExpandedSessions() {
        var instances: [TravelChargeAutomationService.SessionInstance] = []
        let calendar = Calendar.current
        let today = Date()
        
        let startOfRange = calendar.date(byAdding: .month, value: -6, to: today) ?? today
        let endOfRange = calendar.date(byAdding: .month, value: 6, to: today) ?? today
        
        let recurrenceService = RecurrenceService()
        
        let recurringSessions = sessions.filter { $0.recurrenceRuleData != nil }
        let domainSessions = recurringSessions.map { mapToDomain($0) }
        
        let expandedSessionData = recurrenceService.expandRecurringSessions(
            domainSessions,
            rangeStart: startOfRange,
            rangeEnd: endOfRange
        )
        
        for sessionData in expandedSessionData {
            guard let masterSession = sessions.first(where: { $0.id == sessionData.masterSession.id }) else { continue }
            for instance in sessionData.instances {
                let sessionInstance = TravelChargeAutomationService.SessionInstance(
                    session: masterSession,
                    instanceStart: instance.instanceStart,
                    instanceEnd: instance.instanceEnd
                )
                instances.append(sessionInstance)
            }
        }
        
        let nonRecurringSessions = sessions.filter { $0.recurrenceRuleData == nil }
        for session in nonRecurringSessions {
            if let start = session.startTime {
                let end = session.endTime ?? start
                let sessionInstance = TravelChargeAutomationService.SessionInstance(
                    session: session,
                    instanceStart: start,
                    instanceEnd: end
                )
                instances.append(sessionInstance)
            }
        }
        
        self.cachedExpandedSessions = instances.sorted { $0.instanceStart < $1.instanceStart }
    }
    
    func loadBusinessAddressInfo() async {
        guard !isLoadingBusinessAddress else { return }
        isLoadingBusinessAddress = true
        defer { isLoadingBusinessAddress = false }

        do {
            if let business = try await unitOfWork.business.fetchFirst() {
                let address = business.address
                self.businessAddressInfo = BusinessAddressInfo(
                    hasBusiness: true,
                    fullFormattedAddress: address?.fullFormattedAddress ?? "",
                    fullAddressText: address?.fullFormattedAddress ?? "",
                    streetName: address?.streetName ?? "",
                    suburb: address?.suburb ?? "",
                    state: address?.state ?? "",
                    postcode: address?.postcode ?? ""
                )
            } else {
                self.businessAddressInfo = nil
            }
        } catch {
            print("❌ [TravelChargeAutomationViewModel] Error loading business address: \(error)")
            self.businessAddressInfo = nil
        }
    }
    
    func runAutomation() async {
        guard !selectedSessionInstances.isEmpty else { return }
        
        isRunning = true
        errorMessage = nil
        testChargeSummaries = []
        testReviewSummaries = []
        testDetailedReviewItems = []
        
        // Convert selected session instances to proper Session domain models
        var sessionsToProcess: [Session] = []
        let selectedInstances = cachedExpandedSessions.filter { selectedSessionInstances.contains($0.uniqueInstanceId) }
        
        for instance in selectedInstances {
            sessionsToProcess.append(mapToDomain(instance.session))
        }
        
        let earliestDate = selectedInstances.map { $0.instanceStart }.min() ?? Date()
        let latestDate = selectedInstances.map { $0.instanceEnd }.max() ?? Date()
        let dateRange = earliestDate...latestDate
        
        // Use the domain-based method
        do {
            try automationService.automateTravelCharges(for: sessionsToProcess, dateRange: dateRange)
        } catch {
            self.errorMessage = "Automation error: \(error.localizedDescription)"
        }
        
        let (charges, reviews, detailedReviews) = automationService.getTestResults()
        self.testChargeSummaries = charges
        self.testReviewSummaries = reviews
        self.testDetailedReviewItems = detailedReviews
        self.isRunning = false
    }
    
    func showMMMZone(for session: SessionEntity) async {
        if session.sessionLatitude != 0 || session.sessionLongitude != 0 {
            let coord = CLLocationCoordinate2D(latitude: session.sessionLatitude, longitude: session.sessionLongitude)
            if let mmmCode = MMMZoneLookup.shared.mmm(for: coord) {
                mmmZoneResult = "Code: \(mmmCode) for coordinates"
            } else {
                mmmZoneResult = "No MMM zone found for coordinates"
            }
        } else if let address = session.location, !address.isEmpty {
            if let coordinate = await GeocodingService.shared.geocodeAddressString(address) {
                let resolvedCoordinate = CLLocationCoordinate2D(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                session.sessionLatitude = resolvedCoordinate.latitude
                session.sessionLongitude = resolvedCoordinate.longitude

                if let mmmCode = MMMZoneLookup.shared.mmm(for: resolvedCoordinate) {
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
        
        if let coordinate = await GeocodingService.shared.geocodeAddressString(addressString) {
            let resolvedCoordinate = CLLocationCoordinate2D(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            if let mmmCode = MMMZoneLookup.shared.mmm(for: resolvedCoordinate) {
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
    
    private func mapToDomain(_ entity: SessionEntity) -> Session {
        return Session(
            id: entity.id,
            title: entity.title,
            startTime: entity.startTime,
            endTime: entity.endTime,
            isAllDay: entity.isAllDay,
            location: entity.location,
            notes: entity.notes,
            status: entity.status?.rawValue,
            isTravel: entity.isTravel,
            clientId: entity.client?.id,
            clientServiceId: entity.clientService?.id,
            groupID: entity.groupID,
            recurrenceRuleData: entity.recurrenceRuleData
        )
    }

    private func resolveSessionEntities(for sessionIds: [UUID]) throws -> [SessionEntity] {
        guard let swiftDataUnitOfWork = unitOfWork as? SwiftDataUnitOfWork else {
            return []
        }

        let resolver = EntityResolutionService(context: swiftDataUnitOfWork.legacyModelContext)
        return try sessionIds.compactMap { id in
            try resolver.resolveSession(id: id)
        }
    }
}
