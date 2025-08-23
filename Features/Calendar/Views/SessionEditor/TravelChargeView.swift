import SwiftUI
import SwiftData
import MapKit


struct TravelChargeView: View {
    @Environment(\.modelContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Enums for Travel Logic
    enum TravelChargeType: String, CaseIterable, Identifiable {
        case standard = "Standard Travel"
        case activityBased = "Activity-Based Transport"
        var id: String { rawValue }
    }

    enum TravelDirection: String, CaseIterable, Identifiable {
        case before = "Before Session"
        case after = "After Session"
        var id: String { rawValue }
    }

    enum MMMZone: String, CaseIterable, Identifiable {
        case mmm1_3 = "Zones 1-3 (Metro)"
        case mmm4_5 = "Zones 4-5 (Regional)"
        case mmm6_7 = "Zones 6-7 (Remote/Very Remote)"
        var id: String { rawValue }
        
        var maxTime: Double {
            switch self {
            case .mmm1_3: return 30
            case .mmm4_5: return 60
            case .mmm6_7: return .infinity
            }
        }
    }

    enum VehicleType: String, CaseIterable, Identifiable {
        case standard = "Standard Car"
        case modified = "Modified/Bus"
        var id: String { rawValue }

        var rate: Double {
            switch self {
            case .standard: return 0.99
            case .modified: return 2.76
            }
        }
    }
    
    // MARK: - Core Properties
    let mainSession: SessionEntity
    let instanceStartDate: Date?
    let instanceEndDate: Date?
    let daySessions: [DisplayableCalendarItem]
    let onSave: () -> Void

    // MARK: - View State
    @State private var chargeType: TravelChargeType = .standard
    @State private var mmmZone: MMMZone = .mmm1_3

    // Standard Travel
    @State private var includeLabour: Bool = true
    @State private var includeNonLabour: Bool = true
    @State private var travelTimeBeforeString: String = "30"
    @State private var travelTimeAfterString: String = "30"
    
    // Activity-Based Transport
    @State private var vehicleType: VehicleType = .standard
    @State private var distanceString: String = ""
    @State private var parkingString: String = ""
    @State private var tollsString: String = ""

    // Shared State
    @State private var participantCountString: String = "1"
    @State private var splitCosts: Bool = false
    @State private var travelDirection: TravelDirection = .before
    @State private var isLoading: Bool = false
    
    // Distance Calculation State
    @State private var fromAddressString: String = ""
    @State private var toAddressString: String = ""
    @State private var isCalculatingDistance: Bool = false
    @State private var distanceCalculationError: String?
    
    @State private var hasExistingTravelBefore: Bool = false
    @State private var hasExistingTravelAfter: Bool = false
    
    @State private var labourService: ClientServiceEntity?
    @State private var nonLabourService: ClientServiceEntity?
    
    // MARK: - Computed Properties
    private var travelTimeBefore: Double { Double(travelTimeBeforeString) ?? 0 }
    private var travelTimeAfter: Double { Double(travelTimeAfterString) ?? 0 }
    private var participantCount: Int { Int(participantCountString) ?? 1 }
    private var distance: Double { Double(distanceString) ?? 0 }
    private var parking: Double { Double(parkingString) ?? 0 }
    private var tolls: Double { Double(tollsString) ?? 0 }

    private var effectiveStartTime: Date {
        instanceStartDate ?? mainSession.startTime ?? Date()
    }

    private var effectiveEndTime: Date {
        instanceEndDate ?? mainSession.endTime ?? Date()
    }

    private var canSave: Bool {
        if chargeType == .standard {
            return (includeLabour || includeNonLabour)
        } else {
            return true
        }
    }
    
    private var accentColor: Color { .blue }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Form {
                Section {
                    EnumDropdown(label: "", selection: $chargeType, displayStyle: .segmented)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)

                switch chargeType {
                case .standard:
                    standardTravelForm
                case .activityBased:
                    activityBasedForm
                }

                multiParticipantSection
                travelServiceSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 550, idealWidth: 600, minHeight: 600)
        .onAppear(perform: {
            loadServices()
            checkForExistingTravel()
            setupAndCalculateDistance()
        })
        .overlay {
            if isLoading {
                ProgressView("Loading Services...")
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Travel Charges")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("For: \(mainSession.title)")
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Cancel", role: .cancel, action: { dismiss() })
            Button("Save", action: saveTravelCharges)
                .buttonStyle(.glassProminent)
                .disabled(!canSave)
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Form Sections
    @ViewBuilder
    private var standardTravelForm: some View {
        Section("Labour Cost (Time-Based)") {
            FormToggle(label: "Include Labour Costs", isOn: $includeLabour.animation())

            if includeLabour {
                EnumDropdown(label: "MMM Zone", selection: $mmmZone, displayStyle: .menu)
                EnumDropdown(label: "Travel occurs", selection: $travelDirection, displayStyle: .segmented)
                    .onChange(of: travelDirection) {
                        setupAndCalculateDistance()
                    }

                if travelDirection == .before {
                    FormNumberField(label: "Time Before (minutes)", value: $travelTimeBeforeString, placeholder: "30", allowDecimal: false, allowNegative: false)
                        .disabled(hasExistingTravelBefore)
                } else {
                    FormNumberField(label: "Time After (minutes)", value: $travelTimeAfterString, placeholder: "30", allowDecimal: false, allowNegative: false)
                        .disabled(hasExistingTravelAfter)
                }
            }
        }
        
        Section("Non-Labour Cost (Distance-Based)") {
            FormToggle(label: "Include Kilometre Allowance", isOn: $includeNonLabour.animation())

            if includeNonLabour {
                VStack(alignment: .leading, spacing: 12) {
                    addressDisplay()
                    distanceField()
                }
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private func addressDisplay() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("From: \(fromAddressString)")
            Text("To:   \(toAddressString)")
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    @ViewBuilder
    private func distanceField() -> some View {
        HStack {
            FormNumberField(label: "Distance (km)", value: $distanceString, placeholder: "e.g., 15", allowDecimal: true, allowNegative: false)
            
            if isCalculatingDistance {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 44, height: 44)
            } else {
                Button(action: setupAndCalculateDistance) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderless)
                .help("Recalculate distance")
            }
        }
        if let error = distanceCalculationError {
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
        }
    }

    @ViewBuilder
    private var activityBasedForm: some View {
        Section("Activity-Based Transport Costs") {
            // Vehicle & Distance Costs
            EnumDropdown(label: "Vehicle Type", selection: $vehicleType, displayStyle: .menu)
            FormNumberField(label: "Distance (Round Trip, km)", value: $distanceString, placeholder: "e.g., 25", allowDecimal: true, allowNegative: false)
            
            // Other Costs
            FormCurrencyField(label: "Parking Fees", value: $parkingString, placeholder: "e.g., 5.50")
            FormCurrencyField(label: "Road Tolls", value: $tollsString, placeholder: "e.g., 4.75")
            
            Divider()
            
            // Time Costs
            Text("Travel Time").font(.caption).foregroundColor(.secondary)
            EnumDropdown(label: "Travel occurs", selection: $travelDirection, displayStyle: .segmented)
                .onChange(of: travelDirection) {
                    setupAndCalculateDistance()
                }

            if travelDirection == .before {
                FormNumberField(label: "Time Before (minutes)", value: $travelTimeBeforeString, placeholder: "30", allowDecimal: false, allowNegative: false)
                    .disabled(hasExistingTravelBefore)
            } else {
                FormNumberField(label: "Time After (minutes)", value: $travelTimeAfterString, placeholder: "30", allowDecimal: false, allowNegative: false)
                    .disabled(hasExistingTravelAfter)
            }
        }
    }
    
    private var multiParticipantSection: some View {
        Section("Multi-Participant") {
            FormToggle(label: "Split Costs Between Multiple Participants", isOn: $splitCosts.animation())

            if splitCosts {
                FormNumberField(label: "Number of Participants", value: $participantCountString, placeholder: "2", allowDecimal: false, allowNegative: false)
            }
        }
    }

    private var travelServiceSection: some View {
        Section("NDIS Service Items") {
            if chargeType == .standard && includeLabour {
                serviceRow(title: "Labour Service", service: labourService)
            }
            if chargeType == .standard && includeNonLabour {
                serviceRow(title: "Non-Labour Service", service: nonLabourService)
            }
            if chargeType == .activityBased {
                serviceRow(title: "Activity Transport Service", service: labourService)
            }
            
            if (chargeType == .standard && includeLabour && labourService == nil) ||
               (chargeType == .standard && includeNonLabour && nonLabourService == nil) ||
               (chargeType == .activityBased && labourService == nil) {
                Text("Could not find a matching NDIS travel item for this service's registration group.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private func serviceRow(title: String, service: ClientServiceEntity?) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundColor(.secondary)
            if let service = service {
                Text(service.serviceName)
                Text(service.ndisCode ?? "No NDIS Code")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("N/A").italic()
            }
        }
    }

    // MARK: - Data Logic
    private func checkForExistingTravel() {
        let sessionStartTime = effectiveStartTime
        let sessionEndTime = effectiveEndTime
        
        // Find travel sessions that are perfectly aligned with the start or end of the main session
        let travelBeforeDescriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { 
            $0.isTravel == true
        })
        let travelAfterDescriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { 
            $0.isTravel == true
        })
        do {
            let beforeCandidates = try viewContext.fetch(travelBeforeDescriptor)
            let existingBefore = beforeCandidates.filter {
                $0.endTime == sessionStartTime && $0.client == mainSession.client
            }
            if !existingBefore.isEmpty {
                self.hasExistingTravelBefore = true
                self.travelDirection = .after // Switch to after if before exists
            }
            let afterCandidates = try viewContext.fetch(travelAfterDescriptor)
            let existingAfter = afterCandidates.filter {
                $0.startTime == sessionEndTime && $0.client == mainSession.client
            }
            if !existingAfter.isEmpty {
                self.hasExistingTravelAfter = true
                if !hasExistingTravelBefore { // Only switch if before wasn't already found
                    self.travelDirection = .before
                }
            }
        } catch {
            print("Failed to fetch existing travel sessions: \(error)")
        }
    }

    private func loadServices() {
        isLoading = true
        guard let mainService = mainSession.clientService,
              let client = mainSession.client else {
            isLoading = false
            return
        }
        
        // Labour service is the same as the main session's service
        self.labourService = mainService
        
        // Find the corresponding non-labour service for the client
        guard let mainNdisCode = mainService.ndisCode,
              let registrationGroup = mainNdisCode.split(separator: "_")[safe: 2] else {
            isLoading = false
            return
        }

        let nonLabourCodeFragment = "_799_\(registrationGroup)_"
        
        let clientServices = client.clientServices ?? []
        self.nonLabourService = clientServices.first {
            $0.ndisCode?.contains(nonLabourCodeFragment) == true
        }
        isLoading = false
    }

    private func saveTravelCharges() {
        guard canSave else { return }

        // --- Standard Travel ---
        if chargeType == .standard {
            if includeLabour, let service = labourService {
                createTimeBasedSessions(service: service)
            }
            if includeNonLabour, let service = nonLabourService {
                createEventBasedSessions(service: service)
            }
        }
        // --- Activity-Based Transport ---
        else {
            if let service = labourService {
                createActivityBasedSessions(service: service)
            }
        }

        do {
            try viewContext.save()
            onSave()
            dismiss()
        } catch {
            print("Failed to save travel charges: \(error.localizedDescription)")
        }
    }

    private func createTimeBasedSessions(service: ClientServiceEntity) {
        let _ = splitCosts ? Double(participantCount) : 1.0
        let hourlyRate = service.rate / (splitCosts ? Double(participantCount) : 1.0)
        
        let maxTime = mmmZone.maxTime
        
        if travelDirection == .before && !hasExistingTravelBefore {
            let clampedTime = min(travelTimeBefore, maxTime)
            createSession(
                title: "Travel (Time) to \(mainSession.title)",
                startTime: effectiveStartTime.addingTimeInterval(-clampedTime * 60),
                endTime: effectiveStartTime,
                service: service,
                notes: "Labour cost travel. Rate: \(hourlyRate)/hr. Split between \(participantCount) participant(s)."
            )
        }
        if travelDirection == .after && !hasExistingTravelAfter {
            let clampedTime = min(travelTimeAfter, maxTime)
            createSession(
                title: "Travel (Time) from \(mainSession.title)",
                startTime: effectiveEndTime,
                endTime: effectiveEndTime.addingTimeInterval(clampedTime * 60),
                service: service,
                notes: "Labour cost travel. Rate: \(hourlyRate)/hr. Split between \(participantCount) participant(s)."
            )
        }
    }
    
    private func createEventBasedSessions(service: ClientServiceEntity) {
        let costDivisor = splitCosts ? Double(participantCount) : 1.0
        let cost = (distance * 1.0) / costDivisor // Assuming $1.00 per km
        let notes = "Non-labour cost: \(distance) km @ $1.00/km = \(cost.formatted(.currency(code: "AUD"))). Split between \(participantCount) participant(s)."
        
        if travelDirection == .before && !hasExistingTravelBefore {
            createSession(
                title: "Travel (Non-Labour) to \(mainSession.title)",
                startTime: effectiveStartTime,
                endTime: effectiveStartTime, // Zero duration
                service: service,
                notes: notes,
                isAllDay: true // Represents an event, not a time block
            )
        }
        if travelDirection == .after && !hasExistingTravelAfter {
             createSession(
                title: "Travel (Non-Labour) from \(mainSession.title)",
                startTime: effectiveEndTime,
                endTime: effectiveEndTime, // Zero duration
                service: service,
                notes: notes,
                isAllDay: true
            )
        }
    }

    private func createActivityBasedSessions(service: ClientServiceEntity) {
        let costDivisor = splitCosts ? Double(participantCount) : 1.0
        let timeCost = ((travelDirection == .before ? travelTimeBefore : travelTimeAfter) / 60.0) * service.rate
        let vehicleCost = distance * vehicleType.rate
        let totalCost = (timeCost + vehicleCost + parking + tolls) / costDivisor
        
        let notes = """
        Activity-Based Transport Breakdown (Split by \(participantCount)):
        - Time: \((travelDirection == .before ? travelTimeBefore : travelTimeAfter)) mins @ \(service.rate.formatted(.currency(code: "AUD")))/hr = \((timeCost/costDivisor).formatted(.currency(code: "AUD")))
        - Vehicle: \(distance) km @ \(vehicleType.rate.formatted(.currency(code: "AUD")))/km = \((vehicleCost/costDivisor).formatted(.currency(code: "AUD")))
        - Parking: \((parking/costDivisor).formatted(.currency(code: "AUD")))
        - Tolls: \((tolls/costDivisor).formatted(.currency(code: "AUD")))
        - TOTAL PER PARTICIPANT: \(totalCost.formatted(.currency(code: "AUD")))
        """
        
        // For activity based, we create a single, all-encompassing travel session
        // before the main session, containing all cost info in the notes.
        let startTime = travelDirection == .before ? effectiveStartTime.addingTimeInterval(-travelTimeBefore * 60) : effectiveEndTime
        let endTime = travelDirection == .before ? effectiveStartTime : effectiveEndTime.addingTimeInterval(travelTimeAfter * 60)

        createSession(
            title: "Activity Transport for \(mainSession.title)",
            startTime: startTime,
            endTime: endTime,
            service: service,
            notes: notes
        )
    }

    private func createSession(title: String, startTime: Date, endTime: Date, service: ClientServiceEntity, notes: String, isAllDay: Bool = false) {
        // Use SessionFactory for consistent travel session creation
        let sessionFactory = SessionFactory(context: viewContext)
        let newSession = sessionFactory.createTravelSession(
            client: mainSession.client!,
            service: service,
            linkedSession: mainSession,
            startTime: startTime,
            endTime: endTime,
            location: mainSession.location,
            distance: distance,
            duration: travelDirection == .before ? travelTimeBefore : travelTimeAfter,
            chargeType: chargeType == .standard ? "labour" : "activity-based",
            travelDirection: travelDirection == .before ? "before" : "after",
            notes: notes
        )
        
        // Override title and isAllDay as needed
        newSession.title = title
        newSession.isAllDay = isAllDay
    }

    private func setupAndCalculateDistance() {
        Task {
            await doSetupAndCalculateDistance()
        }
    }

    private func doSetupAndCalculateDistance() async {
        await MainActor.run {
        distanceCalculationError = nil
        isCalculatingDistance = true
        }

        guard let sessionLocation = mainSession.location, !sessionLocation.isEmpty else {
            await MainActor.run {
                distanceCalculationError = "The current session address is missing."
                isCalculatingDistance = false
            }
            return
        }
        
        guard let sessionCoordinates = await getOrFetchCoordinates(for: mainSession) else {
            await MainActor.run {
                distanceCalculationError = "Could not geocode the current session address: \(sessionLocation)"
                isCalculatingDistance = false
            }
            return
        }

        let otherLocationData = getOtherLocationEntity()
        
        guard let otherEntity = otherLocationData.entity else {
            await MainActor.run {
                distanceCalculationError = otherLocationData.address // Contains the error message
                isCalculatingDistance = false
            }
            return
        }

        guard let otherCoordinates = await getOrFetchCoordinates(for: otherEntity) else {
            await MainActor.run {
                distanceCalculationError = "Could not geocode the other location's address: \(otherLocationData.address)"
                isCalculatingDistance = false
            }
            return
        }

        await MainActor.run {
        if travelDirection == .before {
            fromAddressString = otherLocationData.address
            toAddressString = sessionLocation
        } else {
            fromAddressString = sessionLocation
            toAddressString = otherLocationData.address
            }
        }

        calculateDrivingDistance(from: sessionCoordinates, to: otherCoordinates)
    }

    private func getOtherLocationEntity() -> (address: String, entity: SessionEntity?) {
        // Sort the sessions by their instance start time to ensure correct order
        let sortedSessions = daySessions.sorted { (item1: DisplayableCalendarItem, item2: DisplayableCalendarItem) -> Bool in
            guard let date1 = item1.startDate, let date2 = item2.startDate else {
                return false // Or handle as an error
            }
            return date1 < date2
        }

        // Find the index of the main session in this sorted list
        guard let currentIndex = sortedSessions.firstIndex(where: { item in
            switch item {
            case .session(let session):
                // This is a standard, non-recurring session
                return session.id == mainSession.id
                
            case .recurringSessionInstance(let template, let instanceStartDate, _, _):
                // This is an instance of a recurring session. We only need to match the day.
                let areDatesEquivalent = Calendar.current.isDate(instanceStartDate, inSameDayAs: effectiveStartTime)
                return template.id == mainSession.id && areDatesEquivalent
                
            default:
                // This handles .event and .eventSegment cases, which should be ignored
                return false
            }
        }) else {
            // If it's not in the list, it's the only session, so use the business address
            return getBusinessLocation()
        }

        if travelDirection == .before {
            if currentIndex > 0 {
                let previousItem = sortedSessions[currentIndex - 1]
                if let locationTuple = getLocationData(for: previousItem) {
                    return locationTuple
                }
            }
        } else { // .after
            if currentIndex < sortedSessions.count - 1 {
                let nextItem = sortedSessions[currentIndex + 1]
                if let locationTuple = getLocationData(for: nextItem) {
                    return locationTuple
                }
            }
        }

        // Fallback for first/last session of the day, or if adjacent session has no location.
        return getBusinessLocation()
    }

    private func getLocationData(for item: DisplayableCalendarItem) -> (address: String, entity: SessionEntity)? {
        guard let sessionTemplate = item.underlyingSession else { return nil }

        // For non-recurring, or if recurring has no exception, use the template's location.
        if let location = sessionTemplate.location, !location.isEmpty {
            return (location, sessionTemplate)
        }

        // If no location can be found on the item, return nil.
        return nil
    }

    private func getBusinessLocation() -> (address: String, entity: SessionEntity?) {
        let businessDescriptor = FetchDescriptor<BusinessEntity>()
        do {
            if let business = try viewContext.fetch(businessDescriptor).first, let address = business.address {
                return (address.fullFormattedAddress, nil)
            }
        } catch {
            print("Error fetching business entity: \(error)")
        }
        return ("Business address not set.", nil)
    }

    private func getOrFetchCoordinates(for entity: SessionEntity) async -> CLLocationCoordinate2D? {
        if entity.sessionLatitude != 0 || entity.sessionLongitude != 0 {
            return CLLocationCoordinate2D(latitude: entity.sessionLatitude, longitude: entity.sessionLongitude)
        }
        
        return await withCheckedContinuation { continuation in
            GeocodingService.shared.geocodeAndSave(sessionEntity: entity, in: viewContext) {
                if entity.sessionLatitude != 0 || entity.sessionLongitude != 0 {
                    continuation.resume(returning: CLLocationCoordinate2D(latitude: entity.sessionLatitude, longitude: entity.sessionLongitude))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func getOrFetchCoordinates(for address: AddressEntity) async -> CLLocationCoordinate2D? {
        if address.latitude != 0 || address.longitude != 0 {
            return CLLocationCoordinate2D(latitude: address.latitude, longitude: address.longitude)
        }

        return await withCheckedContinuation { continuation in
            GeocodingService.shared.geocodeAndSave(addressEntity: address, in: viewContext) {
                if address.latitude != 0 || address.longitude != 0 {
                    continuation.resume(returning: CLLocationCoordinate2D(latitude: address.latitude, longitude: address.longitude))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func calculateDrivingDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) {
        let request = MKDirections.Request()
        if #available(macOS 15.0, *) {
            request.source = MKMapItem(location: CLLocation(latitude: from.latitude, longitude: from.longitude), address: nil)
            request.destination = MKMapItem(location: CLLocation(latitude: to.latitude, longitude: to.longitude), address: nil)
        } else {
            request.source = MKMapItem(location: CLLocation(latitude: from.latitude, longitude: from.longitude), address: nil)
            request.destination = MKMapItem(location: CLLocation(latitude: to.latitude, longitude: to.longitude), address: nil)
        }
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            DispatchQueue.main.async {
                self.isCalculatingDistance = false
                if let error = error {
                    self.distanceCalculationError = "MapKit Error: \(error.localizedDescription)"
                    return
                }
                if let route = response?.routes.first {
                    let distanceInKm = route.distance / 1000
                    self.distanceString = String(format: "%.1f", distanceInKm)
                } else {
                    self.distanceCalculationError = "No route found."
                }
            }
        }
    }
}

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
