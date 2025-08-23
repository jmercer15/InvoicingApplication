import SwiftUI
@preconcurrency import MapKit
import Combine
import EventKit
import SwiftData // Import SwiftData

struct MapView: View {
    @StateObject private var viewModel: MapViewModel // Change to @StateObject with explicit type
    @Environment(\.modelContext) private var modelContext // Change to modelContext
    @Environment(\.appNavigationManager) private var navigationManager

    init() {
        // Initialize MapViewModel with a placeholder ModelContext or actual if available
        // For preview/initialization, ModelContext() can be used,
        // then the actual context is set in .onAppear
        _viewModel = StateObject(wrappedValue: MapViewModel(modelContext: ModelContext(try! ModelContainer(for: AddressEntity.self))))
    }

    var body: some View {
        VStack {
            ZStack {
                            MapKitView(
                mapType: viewModel.selectedMapType,
                showsTraffic: viewModel.showsTraffic,
                showsUserLocation: viewModel.canShowUserLocation,
                showsScale: viewModel.showsScale,
                showsCompass: viewModel.showsCompass,
                showsRoutes: viewModel.showsRoutes,
                enableClustering: viewModel.enableClustering,
                annotations: viewModel.annotations,
                routeOverlays: viewModel.routeOverlays,
                navigationManager: navigationManager
            )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
                

            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            viewModel.setModelContext(modelContext) // Pass modelContext here
            viewModel.fetchSessions() // Call fetchSessions without context parameter
            handleNavigationContext()
        }
        .onChange(of: viewModel.selectedDate) { _, _ in
            viewModel.fetchSessions() // Call fetchSessions without context parameter
        }
        .onChange(of: viewModel.showsRoutes) { _, _ in
            viewModel.updateAnnotations()
        }
        .toolbar {
            // Principal title removed per unified toolbar guidelines
            ToolbarItemGroup(placement: .secondaryAction) {
                Button(action: { viewModel.enableClustering.toggle() }) { Label("Clusters", systemImage: "circle.grid.2x2") }
                .appInteractiveCursor()
                .help(viewModel.enableClustering ? "Hide cluster grouping" : "Show cluster grouping")
                Button(action: { viewModel.showsRoutes.toggle() }) { Label("Routes", systemImage: viewModel.showsRoutes ? "point.3.filled.connected.trianglepath.dotted" : "point.3.connected.trianglepath.dotted") }
                .appInteractiveCursor()
                .help(viewModel.showsRoutes ? "Hide session routes" : "Show session routes")
                Button(action: { viewModel.showsTraffic.toggle() }) { Label("Traffic", systemImage: "car") }
                .appInteractiveCursor()
                .help(viewModel.showsTraffic ? "Hide traffic overlays" : "Show traffic overlays")
                Menu {
                    Button("Standard") { viewModel.selectedMapType = .standard }
                    Button("Satellite") { viewModel.selectedMapType = .satellite }
                    Button("Hybrid") { viewModel.selectedMapType = .hybrid }
                } label: { Label("Map", systemImage: "map") }
                .appInteractiveCursor()
                .help("Change map type")
            }
        }
        
    }
    
    // MARK: - Navigation Context Handling
    private func handleNavigationContext() {
        guard let context = navigationManager.consumeNavigationContext() else { return }
        
        // Handle navigation to specific date
        if let targetDate = context.targetDate {
            viewModel.selectedDate = targetDate
        }
        
        // Handle navigation to specific session
        if let sessionID = context.targetEntity,
           context.targetEntityType == .session {
            // Try to find and focus on the specific session
            // This could involve zooming to the session location or highlighting it
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusOnSession(sessionID: sessionID)
            }
        }
    }
    
    private func focusOnSession(sessionID: UUID) {
        // Find the session in the current annotations and focus on it
        if let targetAnnotation = viewModel.annotations.first(where: { $0.session.id == sessionID }) {
            print("[MapView] Focusing on session: \(targetAnnotation.sessionNumber)")
            
            // Focus the map on this specific session
            let coordinate = targetAnnotation.coordinate
            if coordinate.latitude != 0 || coordinate.longitude != 0 {
                let _ = MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: 1000, // 1km radius for focused view
                    longitudinalMeters: 1000
                )
                
                // We need to access the map view, but we're in the SwiftUI view context
                // The auto-zoom will handle this when the view updates, but we can also
                // notify the view model to trigger a map region update
                print("[MapView] Found target session at coordinates: (\(coordinate.latitude), \(coordinate.longitude))")
            }
        }
    }


    
    private var completedSessionsCount: Int {
        let now = Date()
        return viewModel.annotations.filter { $0.instanceEnd < now }.count
    }
    
    private var upcomingSessionsCount: Int {
        let now = Date()
        return viewModel.annotations.filter { $0.instanceStart > now }.count
    }
    

}

// MARK: - MapViewModel
@MainActor
class MapViewModel: ObservableObject {
    @Published var showsTraffic: Bool = true
    @Published var showsScale: Bool = true
    @Published var showsCompass: Bool = true
    @Published var showsRoutes: Bool = false
    @Published var selectedDate: Date = Date()
    @Published var sessions: [SessionEntity] = []
    @Published var annotations: [SessionAnnotation] = []
    @Published var routeOverlays: [MKPolyline] = []
    @Published private(set) var canShowUserLocation: Bool = false
    @Published var selectedMapType: SelectableMapType = .standard
    @Published var enableClustering = true
    @Published var showOnlyTodaySessions = true

    // LocationManager was removed - using CoreLocation directly if needed
    private var modelContext: ModelContext? // Change to ModelContext
    private var addressesCurrentlyGeocoding = Set<UUID>()
    private var cancellables = Set<AnyCancellable>()

    // Update initializer to accept ModelContext
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // LocationManager was removed - handle authorization status manually
        canShowUserLocation = false
        
        // Observe changes to the ModelContext
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.fetchSessions() // Re-fetch sessions on data change
            }
            .store(in: &cancellables)
    }
    
    // Allow setting ModelContext after init (for SwiftUI environment injection)
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    private func handleAuthorizationStatus(_ status: CLAuthorizationStatus) {
        // LocationManager was removed - simplified handling
        canShowUserLocation = false
    }

    func fetchSessions() {
        guard let context = modelContext else { return } // Use the stored modelContext
        
        let calendar = Calendar.current
        // Fetch for the entire month of the selected date to have a better chance of showing data.
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate) else {
            print("[MapViewModel] Could not calculate month interval for selected date.")
            return
        }
        let startDate = monthInterval.start
        let endDate = monthInterval.end

        // Fetch all sessions (no predicate on dynamic variables)
        let descriptor = FetchDescriptor<SessionEntity>(sortBy: [SortDescriptor(\SessionEntity.startTime)])
        do {
            let allSessions = try context.fetch(descriptor)
            // In-memory filtering for date range
            sessions = allSessions.filter { ($0.startTime ?? .distantPast) >= startDate && ($0.startTime ?? .distantPast) < endDate }
            print("[MapViewModel] Fetched \(sessions.count) sessions for \(selectedDate.formatted(date: .long, time: .omitted))")
            updateAnnotations()
        } catch {
            print("Failed to fetch sessions: \(error)")
        }
    }

    func updateAnnotations() {
        var validAnnotations: [SessionAnnotation] = []
        
        print("[MapViewModel] Starting updateAnnotations with selectedDate: \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
        print("[MapViewModel] Total fetched sessions: \(sessions.count)")
        
        // Create expanded session instances including recurrence
        var expandedSessions: [SessionInstance] = []
        
        for session in sessions {
            if session.recurrenceRuleData == nil {
                // Non-recurring session
                if let startTime = session.startTime, Calendar.current.isDate(startTime, inSameDayAs: selectedDate) {
                    expandedSessions.append(SessionInstance(session: session, instanceStart: startTime, instanceEnd: session.endTime ?? startTime))
                }
            } else {
                // Recurring session - expand it
                if let rule = unarchiveRecurrenceRule(from: session.recurrenceRuleData),
                   let sessionStartTime = session.startTime,
                   let sessionEndTime = session.endTime {
                    
                    let instances = generateSessionInstances(
                        for: session,
                        rule: rule,
                        masterStartTime: sessionStartTime,
                        masterEndTime: sessionEndTime,
                        targetDate: selectedDate
                    )
                    expandedSessions.append(contentsOf: instances)
                }
            }
        }
        
        print("[MapViewModel] Expanded to \(expandedSessions.count) session instances for selected date.")
        
        // Sort sessions by start time for proper routing order and numbering
        expandedSessions.sort { $0.instanceStart < $1.instanceStart }
        
        // Store coordinates for route calculation
        var sessionCoordinates: [CLLocationCoordinate2D] = []
        
        // Now process the expanded sessions for map annotations with sequential numbering
        for (index, sessionInstance) in expandedSessions.enumerated() {
            let session = sessionInstance.session
            let sessionNumber = index + 1
            
            // Prioritize session-specific coordinates
            if session.sessionLatitude != 0 || session.sessionLongitude != 0 {
                print("[MapViewModel] Found session-specific coordinates for '\(session.title)': (\(session.sessionLatitude), \(session.sessionLongitude))")
                let coordinate = CLLocationCoordinate2D(latitude: session.sessionLatitude, longitude: session.sessionLongitude)
                sessionCoordinates.append(coordinate)
                validAnnotations.append(SessionAnnotation(session: session, sessionNumber: sessionNumber, instanceStart: sessionInstance.instanceStart, instanceEnd: sessionInstance.instanceEnd))
            } 
            // Fallback to client's address
            else if let client = session.client, let address = client.address {
                if address.latitude != 0 || address.longitude != 0 {
                    print("[MapViewModel] Using client address coordinates for '\(session.title)': (\(address.latitude), \(address.longitude))")
                    let coordinate = CLLocationCoordinate2D(latitude: address.latitude, longitude: address.longitude)
                    sessionCoordinates.append(coordinate)
                    validAnnotations.append(SessionAnnotation(session: session, address: address, sessionNumber: sessionNumber, instanceStart: sessionInstance.instanceStart, instanceEnd: sessionInstance.instanceEnd))
                } else {
                    // Geocode the client's address if it's missing coordinates
                    print("[MapViewModel] No coordinates for client '\(client.fullName)'. Triggering geocoding.")
                    geocodeAddress(for: address)
                }
            }
            // Fallback: If no client or address, still add annotation if it has a title
            else if !session.title.isEmpty { // Check if title is not empty
                 print("[MapViewModel] Session '\(session.title)' has no coordinates and no client address to fall back to. Adding annotation with title only.")
                 validAnnotations.append(SessionAnnotation(session: session, sessionNumber: sessionNumber, instanceStart: sessionInstance.instanceStart, instanceEnd: sessionInstance.instanceEnd))
            }
            else {
                 print("[MapViewModel] Session has no coordinates, no client address, and no title. Skipping annotation.")
            }
        }
        
        self.annotations = validAnnotations
        print("[MapViewModel] Finished updating. Created \(self.annotations.count) annotations to display immediately.")
        
        // Calculate routes between sessions if enabled and we have multiple locations
        if showsRoutes && sessionCoordinates.count > 1 {
            calculateRoutes(between: sessionCoordinates)
        } else {
            self.routeOverlays = []
        }
    }
    
    private func calculateRoutes(between coordinates: [CLLocationCoordinate2D]) {
        print("[MapViewModel] Calculating routes between \(coordinates.count) locations")
        
        // Clear existing routes on main thread
        DispatchQueue.main.async {
            self.routeOverlays = []
        }
        
        let dispatchGroup = DispatchGroup()
        var calculatedRoutes: [MKPolyline] = []
        let routesQueue = DispatchQueue(label: "routes.calculation", attributes: .concurrent)
        let routesLock = NSLock()
        
        // Calculate routes between consecutive sessions
        for i in 0..<(coordinates.count - 1) {
            dispatchGroup.enter()
            let startCoordinate = coordinates[i]
            let endCoordinate = coordinates[i + 1]
            
            calculateRoute(from: startCoordinate, to: endCoordinate) { polyline in
                defer { dispatchGroup.leave() }
                
                if let polyline = polyline {
                    let polylineCopy = polyline
                    routesQueue.async {
                        routesLock.lock()
                        calculatedRoutes.append(polylineCopy)
                        routesLock.unlock()
                        print("[MapViewModel] Calculated route segment \(i + 1) of \(coordinates.count - 1)")
                    }
                }
            }
        }
        
        // Update UI once all routes are calculated
        dispatchGroup.notify(queue: .main) { [weak self] in
            self?.routeOverlays = calculatedRoutes
            print("[MapViewModel] Updated map with \(calculatedRoutes.count) route segments")
        }
    }
    
    private func calculateRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, completion: @escaping (MKPolyline?) -> Void) {
        let request = MKDirections.Request()
        if #available(macOS 15.0, *) {
            request.source = MKMapItem(location: CLLocation(latitude: start.latitude, longitude: start.longitude), address: nil)
            request.destination = MKMapItem(location: CLLocation(latitude: end.latitude, longitude: end.longitude), address: nil)
        } else {
            request.source = MKMapItem(location: CLLocation(latitude: start.latitude, longitude: start.longitude), address: nil)
            request.destination = MKMapItem(location: CLLocation(latitude: end.latitude, longitude: end.longitude), address: nil)
        }
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let error = error {
                print("[MapViewModel] Route calculation error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let route = response?.routes.first else {
                print("[MapViewModel] No route found")
                completion(nil)
                return
            }
            
            completion(route.polyline)
        }
    }
    
    private func geocodeAddress(for address: AddressEntity) {
        // Ensure we have a context and aren't already processing this address.
        guard let context = modelContext, !addressesCurrentlyGeocoding.contains(address.id) else { return }

        let fullAddressString = address.fullFormattedAddress
        guard !fullAddressString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        self.addressesCurrentlyGeocoding.insert(address.id)

        let addressID = address.id
        
        // Use the new MapKit geocoding API
        Task {
            defer {
                // Always remove from the processing set when done.
                self.addressesCurrentlyGeocoding.remove(addressID)
            }
            
            do {
                guard let request = MKGeocodingRequest(addressString: fullAddressString) else {
                    print("Failed to create geocoding request for '\(fullAddressString)'")
                    return
                }
                let mapItems = try await request.mapItems
                
                if let firstItem = mapItems.first {
                    let location = firstItem.location
                    // Re-fetch the address using the ID to avoid Sendable issues
                    let addressDescriptor = FetchDescriptor<AddressEntity>(predicate: #Predicate { $0.id == addressID })
                    guard let currentAddress = try? context.fetch(addressDescriptor).first else { return }
                    
                    // Perform SwiftData update (implicitly on the correct queue if done directly on model object)
                    currentAddress.latitude = location.coordinate.latitude
                    currentAddress.longitude = location.coordinate.longitude

                    do {
                        try context.save() // Save changes to the address entity
                        print("Successfully geocoded and saved address: \(fullAddressString)")
                        // Trigger a refresh to update the map with the new annotation.
                        DispatchQueue.main.async {
                            self.fetchSessions() // Call fetchSessions without context parameter
                        }
                    } catch {
                        print("Failed to save context after geocoding: \(error)")
                    }
                }
            } catch {
                print("Geocoding failed for '\(fullAddressString)': \(error.localizedDescription)")
            }
        }
    }

    // Map types for picker
    enum SelectableMapType: String, CaseIterable, Identifiable {
        case standard = "Standard"
        case satellite = "Satellite"
        case hybrid = "Hybrid"
        case satelliteFlyover = "Satellite Flyover"
        case hybridFlyover = "Hybrid Flyover"
        
        var id: String { rawValue }
        
        var mkMapType: MKMapType {
            switch self {
            case .standard: return .standard
            case .satellite: return .satellite
            case .hybrid: return .hybrid
            case .satelliteFlyover: return .satelliteFlyover
            case .hybridFlyover: return .hybridFlyover
            }
        }
    }

    // MARK: - Session Instance Helper
    private struct SessionInstance {
        let session: SessionEntity
        let instanceStart: Date
        let instanceEnd: Date
    }
    
    // MARK: - Recurrence Support Functions
    private func unarchiveRecurrenceRule(from data: Data?) -> EKRecurrenceRule? {
        guard let ruleData = data else { return nil }
        return RecurrenceRuleManager.shared.deserialize(ruleData)
    }
    
    private func generateSessionInstances(
        for templateSession: SessionEntity,
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        masterEndTime: Date,
        targetDate: Date
    ) -> [SessionInstance] {
        var instances: [SessionInstance] = []
        let calendar = Calendar.current
        let masterDuration = masterEndTime.timeIntervalSince(masterStartTime)
        
        // Create a window around the target date to search for occurrences
        let searchStart = calendar.date(byAdding: .month, value: -1, to: targetDate) ?? targetDate
        let searchEnd = calendar.date(byAdding: .month, value: 1, to: targetDate) ?? targetDate

        var iterationDate = max(masterStartTime, searchStart)
        let recurrenceActualEndDate = rule.recurrenceEnd?.endDate
        let maxIterations = 100 // Reasonable limit for a month window
        var currentIteration = 0
        var occurrenceCountSinceMaster = 0

        while iterationDate < searchEnd && currentIteration < maxIterations {
            if let ruleEndDate = recurrenceActualEndDate, iterationDate > ruleEndDate {
                break
            }
            if let ruleEndCount = rule.recurrenceEnd?.occurrenceCount, ruleEndCount > 0 && occurrenceCountSinceMaster >= ruleEndCount {
                break
            }

            if matchesRule(date: iterationDate, rule: rule, masterStartTime: masterStartTime, calendar: calendar, templateIsAllDay: templateSession.isAllDay) {
                let instanceStartDate = iterationDate
                var finalInstanceStartDate = instanceStartDate
                if !templateSession.isAllDay {
                    let masterTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: masterStartTime)
                    finalInstanceStartDate = calendar.date(bySettingHour: masterTimeComponents.hour ?? 0,
                                                           minute: masterTimeComponents.minute ?? 0,
                                                           second: masterTimeComponents.second ?? 0,
                                                           of: instanceStartDate) ?? instanceStartDate
                }
                
                let instanceEndDate = finalInstanceStartDate.addingTimeInterval(masterDuration)
                
                // Only add if this instance occurs on our target date
                if calendar.isDate(finalInstanceStartDate, inSameDayAs: targetDate) {
                    instances.append(SessionInstance(
                        session: templateSession,
                        instanceStart: finalInstanceStartDate,
                        instanceEnd: instanceEndDate
                    ))
                }
            }
            
            occurrenceCountSinceMaster += 1

            // Advance iterationDate based on the rule's frequency and interval
            let interval = rule.interval > 0 ? rule.interval : 1
            var nextDateOpt: Date?
            
            switch rule.frequency {
            case .daily:
                nextDateOpt = calendar.date(byAdding: .day, value: interval, to: iterationDate)
            case .weekly:
                nextDateOpt = calendar.date(byAdding: .weekOfYear, value: interval, to: iterationDate)
            case .monthly:
                nextDateOpt = calendar.date(byAdding: .month, value: interval, to: iterationDate)
            case .yearly:
                nextDateOpt = calendar.date(byAdding: .year, value: interval, to: iterationDate)
            @unknown default:
                currentIteration = maxIterations
            }
            
            guard let nextDate = nextDateOpt else { break }
            if nextDate <= iterationDate { break }
            iterationDate = nextDate
            currentIteration += 1
        }
        
        if !instances.isEmpty {
            print("[MapViewModel] Generated \(instances.count) occurrences for session '\(templateSession.title)' on target date")
        }
        return instances
    }
    
    private func matchesRule(date: Date, rule: EKRecurrenceRule, masterStartTime: Date, calendar: Calendar, templateIsAllDay: Bool) -> Bool {
        // Check if specific months are required
        if let months = rule.monthsOfTheYear, !months.isEmpty {
            let currentMonth = calendar.component(.month, from: date)
            if !months.contains(where: { $0.intValue == currentMonth }) {
                return false
            }
        }
        
        // For weekly recurrence
        if rule.frequency == .weekly {
            if let days = rule.daysOfTheWeek, !days.isEmpty {
                let currentWeekday = calendar.component(.weekday, from: date)
                if !days.contains(where: { $0.dayOfTheWeek.rawValue == currentWeekday }) {
                    return false
                }
            } else {
                if calendar.component(.weekday, from: date) != calendar.component(.weekday, from: masterStartTime) {
                    return false
                }
            }
        }

        // For monthly recurrence
        if rule.frequency == .monthly {
            if let daysOfTheMonth = rule.daysOfTheMonth, !daysOfTheMonth.isEmpty {
                let currentDay = calendar.component(.day, from: date)
                let daysInMonth = calendar.range(of: .day, in: .month, for: date)!.count
                var matchedDay = false
                for dayNum in daysOfTheMonth {
                    let d = dayNum.intValue
                    if d > 0 && d == currentDay { matchedDay = true; break }
                    if d < 0 && (daysInMonth + d + 1) == currentDay { matchedDay = true; break }
                }
                if !matchedDay { return false }
            } else if let daysOfWeek = rule.daysOfTheWeek, !daysOfWeek.isEmpty, let setPos = rule.setPositions, !setPos.isEmpty {
                if !checkSetPositionMatch(date: date, rule: rule, calendar: calendar) { return false }
            } else {
                if calendar.component(.day, from: date) != calendar.component(.day, from: masterStartTime) {
                    return false
                }
            }
        }
        
        // For yearly recurrence
        if rule.frequency == .yearly {
            if let daysOfMonth = rule.daysOfTheMonth, !daysOfMonth.isEmpty {
                let currentDay = calendar.component(.day, from: date)
                let daysInMonth = calendar.range(of: .day, in: .month, for: date)!.count
                var matchedDay = false
                for dayNum in daysOfMonth {
                    let d = dayNum.intValue
                    if d > 0 && d == currentDay { matchedDay = true; break }
                    if d < 0 && (daysInMonth + d + 1) == currentDay { matchedDay = true; break }
                }
                if !matchedDay { return false }
            } else if let daysOfWeek = rule.daysOfTheWeek, !daysOfWeek.isEmpty, let setPos = rule.setPositions, !setPos.isEmpty {
                if !checkSetPositionMatch(date: date, rule: rule, calendar: calendar) { return false }
            } else {
                if calendar.component(.day, from: date) != calendar.component(.day, from: masterStartTime) {
                    return false
                }
            }
        }

        return true
    }
    
    private func checkSetPositionMatch(date: Date, rule: EKRecurrenceRule, calendar: Calendar) -> Bool {
        guard let daysOfTheWeek = rule.daysOfTheWeek, !daysOfTheWeek.isEmpty,
              let setPositions = rule.setPositions, !setPositions.isEmpty else {
            return true
        }

        let targetWeekdayComponent = calendar.component(.weekday, from: date)

        guard daysOfTheWeek.contains(where: { $0.dayOfTheWeek.rawValue == targetWeekdayComponent }) else {
            return false
        }

        let yearMonth = calendar.dateComponents([.year, .month], from: date)
        let startOfMonth = calendar.date(from: yearMonth)!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        
        var weekdayInstancesInMonth: [Date] = []
        for dayOffset in 0..<range.count {
            let testDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfMonth)!
            if calendar.component(.weekday, from: testDate) == daysOfTheWeek.first!.dayOfTheWeek.rawValue {
                weekdayInstancesInMonth.append(testDate)
            }
        }
        
        if weekdayInstancesInMonth.isEmpty { return false }

        for pos in setPositions {
            let position = pos.intValue
            if position > 0 && position <= weekdayInstancesInMonth.count {
                if calendar.isDate(weekdayInstancesInMonth[position - 1], inSameDayAs: date) {
                    return true
                }
            } else if position < 0 {
                let indexFromEnd = weekdayInstancesInMonth.count + position
                if indexFromEnd >= 0 && indexFromEnd < weekdayInstancesInMonth.count {
                    if calendar.isDate(weekdayInstancesInMonth[indexFromEnd], inSameDayAs: date) {
                        return true
                    }
                }
            }
        }
        return false
    }
}

// MARK: - Custom Session Annotation
class SessionAnnotation: NSObject, MKAnnotation {
    let session: SessionEntity
    let address: AddressEntity?
    let sessionNumber: Int
    let instanceStart: Date
    let instanceEnd: Date
    
    // MKAnnotation required properties
    var coordinate: CLLocationCoordinate2D {
        if session.sessionLatitude != 0 || session.sessionLongitude != 0 {
            return CLLocationCoordinate2D(latitude: session.sessionLatitude, longitude: session.sessionLongitude)
        } else if let address = address, address.latitude != 0 || address.longitude != 0 {
            return CLLocationCoordinate2D(latitude: address.latitude, longitude: address.longitude)
        }
        return CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }
    
    var title: String? {
        return session.client?.fullName ?? "Unknown Client" // Keep default "Unknown Client"
    }
    
    var subtitle: String? {
        return "Session #\(sessionNumber)"
    }
    
    // Clustering support
    var clusteringIdentifier: String?
    
    init(session: SessionEntity, address: AddressEntity? = nil, sessionNumber: Int, instanceStart: Date, instanceEnd: Date) {
        self.session = session
        self.address = address
        self.sessionNumber = sessionNumber
        self.instanceStart = instanceStart
        self.instanceEnd = instanceEnd
        super.init()
    }
    
    // Custom hash and equality for Set operations
    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(session.id) // Use session.id
        hasher.combine(sessionNumber)
        hasher.combine(instanceStart)
        return hasher.finalize()
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? SessionAnnotation else { return false }
        return session.id == other.session.id && // Use session.id
               sessionNumber == other.sessionNumber &&
               instanceStart == other.instanceStart
    }
}

// Custom cluster annotation view for grouped sessions
class SessionClusterAnnotationView: MKAnnotationView {
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        displayPriority = .defaultHigh
        collisionMode = .circle
        
        // Create a circular cluster view
        frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        layer?.backgroundColor = NSColor.systemBlue.cgColor
        layer?.cornerRadius = 20
        layer?.borderWidth = 2
        layer?.borderColor = NSColor.white.cgColor
        
        // Add shadow
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOffset = CGSize(width: 0, height: 2)
        layer?.shadowRadius = 4
        layer?.shadowOpacity = 0.3
        
        canShowCallout = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        
        guard let cluster = annotation as? MKClusterAnnotation else { return }
        
        let count = cluster.memberAnnotations.count
        
        // Update cluster appearance based on count
        if count < 5 {
            layer?.backgroundColor = NSColor.systemGreen.cgColor
        } else if count < 10 {
            layer?.backgroundColor = NSColor.systemOrange.cgColor
        } else {
            layer?.backgroundColor = NSColor.systemRed.cgColor
        }
        
        // Add count label
        subviews.forEach { $0.removeFromSuperview() }
        
        let label = NSTextField(labelWithString: "\(count)")
        label.font = NSFont.boldSystemFont(ofSize: 14)
        label.textColor = .white
        label.alignment = .center
        label.frame = bounds
        addSubview(label)
        

    }
}

// MARK: - MapKitView (NSViewRepresentable)
struct MapKitView: NSViewRepresentable {
    var mapType: MapViewModel.SelectableMapType
    var showsTraffic: Bool
    var showsUserLocation: Bool
    var showsScale: Bool
    var showsCompass: Bool
    var showsRoutes: Bool
    var enableClustering: Bool
    var annotations: [SessionAnnotation]
    var routeOverlays: [MKPolyline]
    weak var navigationManager: AppNavigationManager?
    
    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsBuildings = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        
        // Register annotation views for clustering
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "SessionAnnotation")
        mapView.register(SessionClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: "SessionCluster")
        
        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        // Ensure coordinator has navigation manager reference
        if let navigationManager = navigationManager {
            context.coordinator.setNavigationManager(navigationManager)
        }
        
        // Update map type
        mapView.mapType = mapType.mkMapType
        
        // Update traffic overlay
        mapView.showsTraffic = showsTraffic
        
        // Update annotations with clustering support
        let currentAnnotations = Set(mapView.annotations.compactMap { $0 as? SessionAnnotation })
        let newAnnotations = Set(annotations)
        
        let toRemove = currentAnnotations.subtracting(newAnnotations)
        let toAdd = newAnnotations.subtracting(currentAnnotations)
        
        mapView.removeAnnotations(Array(toRemove))
        mapView.addAnnotations(Array(toAdd))
        
        // Configure clustering
        for annotation in mapView.annotations {
            if let sessionAnnotation = annotation as? SessionAnnotation {
                sessionAnnotation.clusteringIdentifier = enableClustering ? "session" : nil
            }
        }
        
        // Update route overlays
        mapView.removeOverlays(mapView.overlays)
        if showsRoutes {
            mapView.addOverlays(routeOverlays)
        }
        
        // Automatically zoom to fit all displayed sessions
        autoZoomToFitSessions(mapView: mapView)
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(self)
        // The coordinator will need access to navigation manager from the parent view
        return coordinator
    }
    
    // MARK: - Auto Zoom Functionality
    private func autoZoomToFitSessions(mapView: MKMapView) {
        guard !annotations.isEmpty else {
            print("[MapView] No annotations to zoom to")
            return
        }
        
        // Calculate the bounding box of all session annotations
        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude
        
        var validCoordinatesCount = 0
        
        for annotation in annotations {
            let coordinate = annotation.coordinate
            
            // Skip invalid coordinates
            guard coordinate.latitude != 0 || coordinate.longitude != 0 else { continue }
            
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
            validCoordinatesCount += 1
        }
        
        guard validCoordinatesCount > 0 else {
            print("[MapView] No valid coordinates found for auto-zoom")
            return
        }
        
        // If we only have one session, center on it with a reasonable zoom level
        if validCoordinatesCount == 1 {
            let singleCoordinate = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            let region = MKCoordinateRegion(
                center: singleCoordinate,
                latitudinalMeters: 2000, // 2km radius
                longitudinalMeters: 2000
            )
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                mapView.setRegion(region, animated: true)
                print("[MapView] Centered map on single session location")
            }
            return
        }
        
        // Calculate center and span for multiple sessions
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        
        // Calculate span with padding (20% extra on each side)
        let latDelta = (maxLat - minLat) * 1.4  // 40% total padding
        let lonDelta = (maxLon - minLon) * 1.4  // 40% total padding
        
        // Ensure minimum span for visibility
        let minSpan = 0.01 // About 1km
        let finalLatDelta = max(latDelta, minSpan)
        let finalLonDelta = max(lonDelta, minSpan)
        
        let span = MKCoordinateSpan(
            latitudeDelta: finalLatDelta,
            longitudeDelta: finalLonDelta
        )
        
        let region = MKCoordinateRegion(center: center, span: span)
        
        // Apply the region with a slight delay to ensure all annotations are loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            mapView.setRegion(region, animated: true)
            print("[MapView] Auto-zoomed to fit \(validCoordinatesCount) sessions with center: (\(centerLat), \(centerLon)), span: (\(finalLatDelta), \(finalLonDelta))")
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapKitView
        weak var navigationManager: AppNavigationManager?

        init(_ parent: MapKitView) {
            self.parent = parent
            super.init()
        }
        
        func setNavigationManager(_ manager: AppNavigationManager) {
            self.navigationManager = manager
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            
            print("[MapView] Creating view for annotation: \(type(of: annotation))")
            
            // Handle cluster annotations
            if let cluster = annotation as? MKClusterAnnotation {
                let identifier = "SessionCluster"
                var clusterView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? SessionClusterAnnotationView
                
                if clusterView == nil {
                    clusterView = SessionClusterAnnotationView(annotation: cluster, reuseIdentifier: identifier)
                } else {
                    clusterView?.annotation = cluster
                }
                
                return clusterView
            }
            
            // Handle individual session annotations
            guard let sessionAnnotation = annotation as? SessionAnnotation else { 
                print("[MapView] Annotation is not a SessionAnnotation: \(type(of: annotation))")
                return nil 
            }
            
            print("[MapView] Creating view for SessionAnnotation #\(sessionAnnotation.sessionNumber)")
            
            let identifier = "SessionAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            
            // Ensure callout is always enabled
            annotationView?.canShowCallout = true
            annotationView?.animatesWhenAdded = true
            annotationView?.displayPriority = .required
            
            // Configure marker appearance with session number and enhanced styling
            let sessionNumber = sessionAnnotation.sessionNumber
            let session = sessionAnnotation.session
            
            // Enhanced glyph based on session characteristics
            let glyphText = "\(sessionNumber)"
            var subtitleText = "Session \(sessionNumber)"
            
            // Add visual indicators for special characteristics
            if session.status == "Completed" {
                subtitleText += " ✓"
            } else if session.status == "Cancelled" {
                subtitleText += " ✗"
            } else if session.status == "Confirmed" {
                subtitleText += " !"
            }
            
                         // Show billing status (if linked to invoice)
             if session.invoice != nil {
                 subtitleText += " 💼"
             }
             
             // Show if it's recurring
             if session.recurrenceRuleData != nil {
                 subtitleText += " 🔄"
             }
            
            annotationView?.glyphText = glyphText
            
            // Enhanced time-based color coding with additional context
            let now = Date()
            let sessionStart = sessionAnnotation.instanceStart
            let sessionEnd = sessionAnnotation.instanceEnd
            
            if sessionEnd < now {
                // Past session - use status-specific colors
                if session.status == "Cancelled" {
                    annotationView?.markerTintColor = NSColor.systemRed.withAlphaComponent(0.7)
                } else {
                    annotationView?.markerTintColor = NSColor.systemGreen
                }
                annotationView?.glyphTintColor = NSColor.white
            } else if sessionStart <= now && now <= sessionEnd {
                // Current session - bright red with pulsing effect if possible
                annotationView?.markerTintColor = NSColor.systemRed
                annotationView?.glyphTintColor = NSColor.white
            } else {
                                 // Future session - color code by confirmation status and service type
                 if session.status == "Confirmed" {
                     annotationView?.markerTintColor = NSColor.systemBlue
                 } else {
                     annotationView?.markerTintColor = NSColor.systemOrange // Unconfirmed
                 }
                 
                 // Special color for high-priority or high-value sessions
                 if let clientService = session.clientService, clientService.rate > 150 { // Use clientService.rate
                     annotationView?.markerTintColor = NSColor.systemPurple // Premium services
                 }
                
                annotationView?.glyphTintColor = NSColor.white
            }
            

            
            // Create an enhanced callout with navigation buttons
            let calloutView = createSessionCalloutView(for: sessionAnnotation)
            annotationView?.detailCalloutAccessoryView = calloutView
            
            print("[MapView] Set simple callout accessory view for session #\(sessionAnnotation.sessionNumber)")
            
            // Also set left and right accessory views if needed for better callout display
            annotationView?.leftCalloutAccessoryView = nil
            annotationView?.rightCalloutAccessoryView = nil
            
            return annotationView
        }
        
        private func createSessionCalloutView(for annotation: SessionAnnotation) -> NSView {
            let session = annotation.session
            
            // Create a VStack-like container using NSStackView
            let containerView = NSStackView()
            containerView.orientation = .vertical
            containerView.spacing = 8
            containerView.alignment = .leading
            
            // Session title and number
            let titleLabel = NSTextField(labelWithString: "Session #\(annotation.sessionNumber)")
            titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
            titleLabel.textColor = .labelColor
            containerView.addArrangedSubview(titleLabel)
            
            // Client name
            let clientLabel = NSTextField(labelWithString: "Client: \(session.client?.fullName ?? "Unknown Client")")
            clientLabel.font = NSFont.systemFont(ofSize: 11)
            clientLabel.textColor = .secondaryLabelColor
            containerView.addArrangedSubview(clientLabel)
            
            // Time information
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            let startTime = timeFormatter.string(from: annotation.instanceStart)
            let endTime = timeFormatter.string(from: annotation.instanceEnd)
            
            let timeLabel = NSTextField(labelWithString: "Time: \(startTime) - \(endTime)")
            timeLabel.font = NSFont.systemFont(ofSize: 11)
            timeLabel.textColor = .secondaryLabelColor
            containerView.addArrangedSubview(timeLabel)
            
            // Navigation buttons container
            let buttonContainer = NSStackView()
            buttonContainer.orientation = .horizontal
            buttonContainer.spacing = 8
            
            // View in Calendar button
            let calendarButton = NSButton(title: "View in Calendar", target: nil, action: nil)
            calendarButton.bezelStyle = .rounded
            calendarButton.font = NSFont.systemFont(ofSize: 10)
            calendarButton.action = #selector(MapKitView.Coordinator.navigateToSessionInCalendar(_:))
            calendarButton.target = self.parent.makeCoordinator()
            calendarButton.tag = annotation.sessionNumber // Use session number as identifier
            buttonContainer.addArrangedSubview(calendarButton)
            
            // View Client button
            if session.client != nil {
                let clientButton = NSButton(title: "View Client", target: nil, action: nil)
                clientButton.bezelStyle = .rounded
                clientButton.font = NSFont.systemFont(ofSize: 10)
                clientButton.action = #selector(MapKitView.Coordinator.navigateToClient(_:))
                clientButton.target = self.parent.makeCoordinator()
                clientButton.tag = annotation.sessionNumber
                buttonContainer.addArrangedSubview(clientButton)
            }
            
            containerView.addArrangedSubview(buttonContainer)
            
            // Set container frame
            containerView.frame = NSRect(x: 0, y: 0, width: 200, height: 80)
            
            return containerView
        }
        
        private func createDetailCalloutView(for annotation: SessionAnnotation) -> NSView {
            print("[MapView] Creating detail callout view for session #\(annotation.sessionNumber)")
            
            // Create a simplified but informative callout for better reliability
            var detailText = ""
            let session = annotation.session
            
            // HEADER: Session number and status with visual indicators
            let now = Date()
            var statusIcon = ""
            var statusText = ""
            if annotation.instanceEnd < now {
                statusIcon = "✅"
                statusText = "Completed"
            } else if annotation.instanceStart <= now && now <= annotation.instanceEnd {
                statusIcon = "🔴"
                statusText = "In Progress"
            } else {
                statusIcon = "📅"
                statusText = "Scheduled"
            }
            detailText += "\(statusIcon) Session #\(annotation.sessionNumber) - \(statusText)\n\n"
            
            // CLIENT INFORMATION
            detailText += "👤 Client: \(session.client?.fullName ?? "Unknown Client")\n" // Handle nil
            
            // TIME AND DURATION DETAILS
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            
            let startTime = timeFormatter.string(from: annotation.instanceStart)
            let endTime = timeFormatter.string(from: annotation.instanceEnd)
            let sessionDate = dateFormatter.string(from: annotation.instanceStart)
            let duration = annotation.instanceEnd.timeIntervalSince(annotation.instanceStart)
            let hours = Int(duration) / 3600
            let minutes = Int(duration) % 3600 / 60
            
            detailText += "📅 Date: \(sessionDate)\n"
            if hours > 0 {
                detailText += "🕐 Time: \(startTime) - \(endTime) (\(hours)h \(minutes)m)\n"
            } else {
                detailText += "🕐 Time: \(startTime) - \(endTime) (\(minutes)m)\n"
            }
            
            // SERVICE DETAILS
            if let clientService = session.clientService {
                detailText += "\n--- SERVICE DETAILS ---\n"
                
                let serviceName = clientService.serviceName // Use non-optional
                detailText += "🔧 Service: \(serviceName)\n"
                
                                 // NDIS Item Information (through relationship)
                 if let ndisItem = clientService.ndisItem {
                     if !ndisItem.itemNumber.isEmpty { // Check for empty string
                         detailText += "📋 NDIS Code: \(ndisItem.itemNumber)\n"
                     }
                     
                     if !ndisItem.name.isEmpty { // Check for empty string
                         detailText += "📝 NDIS Item: \(ndisItem.name)\n"
                     }
                 }
                 
                 // Pricing Information
                 if clientService.rate > 0 { // Use clientService.rate
                     let formatter = NumberFormatter()
                     formatter.numberStyle = .currency
                     formatter.locale = Locale(identifier: "en_AU")
                     let rate = formatter.string(from: NSNumber(value: clientService.rate)) ?? "$\(clientService.rate)" // Use clientService.rate
                     detailText += "💰 Rate: \(rate)/\(clientService.unit)\n" // Use clientService.unit
                     
                     // Calculate session cost based on unit type
                     var sessionCost: Double = 0
                     if clientService.unit.lowercased() == "hour" { // Use clientService.unit
                         sessionCost = clientService.rate * (duration / 3600) // Use clientService.rate
                     } else {
                         sessionCost = clientService.rate // Per session/item // Use clientService.rate
                     }
                     let cost = formatter.string(from: NSNumber(value: sessionCost)) ?? "$\(sessionCost)"
                     detailText += "💵 Session Cost: \(cost)\n"
                 }
            }
            
            // SESSION STATUS AND BILLING
            detailText += "\n--- SESSION STATUS ---\n"
            
            if session.status == "Confirmed" {
                detailText += "✅ Status: Confirmed\n"
            } else if session.status == "Completed" {
                detailText += "✅ Status: Completed\n"
            } else if session.status == "Cancelled" {
                detailText += "❌ Status: Cancelled\n"
            } else if session.status == "Planned" {
                detailText += "⏳ Status: Planned\n"
            } else {
                detailText += "📋 Status: \(session.status ?? "Unknown")\n" // Optional status fallback
            }
            
            if session.invoice != nil {
                detailText += "💼 Billing: Invoiced\n"
            } else {
                detailText += "💼 Billing: Not Invoiced\n"
            }
            
            // LOCATION INFORMATION
            detailText += "\n--- LOCATION ---\n"
            
            if annotation.session.sessionLatitude != 0 || annotation.session.sessionLongitude != 0 {
                detailText += "📍 Session-Specific Location\n"
                detailText += "🌐 Coordinates: \(String(format: "%.6f", annotation.session.sessionLatitude)), \(String(format: "%.6f", annotation.session.sessionLongitude))\n"
            } else if let address = annotation.address {
                var streetParts: [String] = []
                if !address.unitNumber.isEmpty {
                    streetParts.append("Unit \(address.unitNumber)")
                }
                if !address.streetNumber.isEmpty {
                    streetParts.append(address.streetNumber)
                }
                if !address.streetName.isEmpty {
                    streetParts.append(address.streetName)
                }
                
                if !address.poBox.isEmpty {
                    detailText += "🏠 Address: PO Box \(address.poBox)\n"
                } else if !streetParts.isEmpty {
                    detailText += "🏠 Address: \(streetParts.joined(separator: " "))\n"
                }
                
                if !address.suburb.isEmpty {
                    detailText += "🏘️ Suburb: \(address.suburb)\n"
                }
                
                if !address.state.isEmpty {
                    detailText += "🗺️ State: \(address.state)\n"
                }
                
                if !address.postcode.isEmpty {
                    detailText += "📮 Postcode: \(address.postcode)\n"
                }
            }
            
            // RECURRENCE INFORMATION
            if session.recurrenceRuleData != nil {
                detailText += "\n--- RECURRENCE ---\n"
                detailText += "🔄 Recurring Session\n"
                // Could decode and show recurrence pattern details if needed
            }
            
            // NOTES AND ADDITIONAL INFO
            if let notes = session.notes, !notes.isEmpty {
                detailText += "\n--- NOTES ---\n"
                detailText += "📝 \(notes)\n"
            }
            
            // CREATION/MODIFICATION INFO (using EventEntity properties)
            if let creationDate = session.ekCreationDate {
                let createdFormatter = DateFormatter()
                createdFormatter.dateStyle = .short
                createdFormatter.timeStyle = .short
                detailText += "\n--- METADATA ---\n"
                detailText += "📅 Created: \(createdFormatter.string(from: creationDate))\n"
            }
            
            if let lastModified = session.lastModifiedDate {
                let modifiedFormatter = DateFormatter()
                modifiedFormatter.dateStyle = .short
                modifiedFormatter.timeStyle = .short
                detailText += "✏️ Modified: \(modifiedFormatter.string(from: lastModified))\n"
            }
            
            // Create the label with enhanced styling - limited height for better callout display
            let finalText = detailText.trimmingCharacters(in: .whitespacesAndNewlines)
            print("[MapView] Detail text length: \(finalText.count) characters")
            
            let detailLabel = NSTextField(wrappingLabelWithString: finalText)
            detailLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
            detailLabel.textColor = .labelColor
            detailLabel.backgroundColor = .clear
            detailLabel.isEditable = false
            detailLabel.isSelectable = true // Allow selection for copying
            detailLabel.maximumNumberOfLines = 15 // Limit lines to prevent oversized callouts
            detailLabel.preferredMaxLayoutWidth = 280 // Reasonable width
            
            // Create a container view to ensure proper sizing
            let containerView = NSView()
            containerView.addSubview(detailLabel)
            
            // Set up constraints
            detailLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                detailLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
                detailLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
                detailLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
                detailLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
                containerView.widthAnchor.constraint(lessThanOrEqualToConstant: 300),
                containerView.heightAnchor.constraint(lessThanOrEqualToConstant: 400)
            ])
            
            print("[MapView] Created callout view container")
            return containerView
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 4.0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        // MARK: - Navigation Actions
        @objc func navigateToSessionInCalendar(_ sender: NSButton) {
            guard let sessionAnnotation = findSessionByNumber(sender.tag) else { return }
            
            navigationManager?.navigateToSession(
                sessionAnnotation.session.id, // Use session.id
                date: sessionAnnotation.instanceStart
            )
        }
        
        @objc func navigateToClient(_ sender: NSButton) {
            guard let sessionAnnotation = findSessionByNumber(sender.tag),
                  let client = sessionAnnotation.session.client else { return }
            
            navigationManager?.navigateToClient(client.id) // Use client.id
        }
        
        private func findSessionByNumber(_ sessionNumber: Int) -> SessionAnnotation? {
            return parent.annotations.first { $0.sessionNumber == sessionNumber }
        }
    }
}

// MARK: - Helper Control Button
struct ControlToggleButton: View {
    @Binding var isOn: Bool
    let icon: String
    let helpText: String
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.white)
        }
        .toggleStyle(.button)
        .clipShape(Circle())
        .help(helpText)
    }
} 
