import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import Data
// import Core  // Removed to avoid type ambiguity with TravelChargeReviewItem
import SharedUI

struct TravelChargeAutomationTestView: View {
    @Environment(\.modelContext) private var viewContext
    @Query(sort: \SessionEntity.startTime, order: .reverse) private var sessions: [SessionEntity]
    
    private var maxLabelWidth: CGFloat {
        let labels = ["Address Search:"]
        return labels.map { $0.width() }.max() ?? 120
    }

    @State private var selectedSessions: Set<SessionEntity> = []
    @State private var selectedSessionInstances: Set<String> = [] // Store unique instance identifiers
    @State private var automationResults: [TravelChargeEntity] = []
    @State private var reviewItems: [TravelChargeReviewItem] = []
    @State private var isRunning = false
    @State private var errorMessage: String? = nil
    @State private var mmmZoneResult: String? = nil
    @State private var testChargeSummaries: [String] = []
    @State private var testReviewSummaries: [String] = []
    @State private var testDetailedReviewItems: [DetailedReviewItem] = []
    
    // New state for review sheet
    @State private var showingReviewSheet = false
    @State private var showingIntegratedReviewView = false
    @State private var reviewService: TravelChargeAutomationService?
    
    // Cached expanded sessions to avoid repeated computation
    @State private var cachedExpandedSessions: [TravelChargeAutomationService.SessionInstance] = []
    
    // Computed property to expand recurring sessions into individual instances
    // Uses the same logic as the calendar feature for consistency
    private var expandedSessions: [TravelChargeAutomationService.SessionInstance] {
        // Return cached sessions if available, otherwise compute them
        if cachedExpandedSessions.isEmpty {
            return computeExpandedSessions()
        }
        return cachedExpandedSessions
    }
    
    // Helper function to compute expanded sessions
    private func computeExpandedSessions() -> [TravelChargeAutomationService.SessionInstance] {
        var instances: [TravelChargeAutomationService.SessionInstance] = []
        let calendar = Calendar.current
        let today = Date()
        
        // Use a much wider date range to show all sessions (similar to calendar's approach)
        let startOfRange = calendar.date(byAdding: .month, value: -6, to: today) ?? today
        let endOfRange = calendar.date(byAdding: .month, value: 6, to: today) ?? today
        
        // Use RecurrenceService like the calendar feature does
        let recurrenceService = RecurrenceService()
        
        // Process recurring sessions using the same method as calendar
        let recurringSessions = sessions.filter { $0.recurrenceRuleData != nil }
        
        // Process recurring sessions using the same method as calendar
        print("[TravelChargeAutomationTestView] Processing \(recurringSessions.count) recurring sessions")
        let expandedSessionData = recurrenceService.expandRecurringSessions(
            recurringSessions,
            rangeStart: startOfRange,
            rangeEnd: endOfRange
        )
        print("[TravelChargeAutomationTestView] Expanded into \(expandedSessionData.count) session data objects")
        
        // Process expanded recurring sessions (same as calendar)
        for sessionData in expandedSessionData {
            for instance in sessionData.instances {
                instances.append(TravelChargeAutomationService.SessionInstance(
                    session: sessionData.masterSession,
                    instanceStart: instance.instanceStart,
                    instanceEnd: instance.instanceEnd
                ))
            }
        }
        
        // Process non-recurring sessions (same as calendar)
        let nonRecurringSessions = sessions.filter { $0.recurrenceRuleData == nil }
        for session in nonRecurringSessions {
            if let startTime = session.startTime {
                instances.append(TravelChargeAutomationService.SessionInstance(
                    session: session,
                    instanceStart: startTime,
                    instanceEnd: session.endTime ?? startTime
                ))
            }
        }
        
        return instances.sorted { $0.instanceStart < $1.instanceStart }
    }

    // Address search state
    @State private var addressSearchText: String = ""
    @State private var selectedAddress: AddressData? = nil
    @State private var unitNumber: String = ""
    @State private var streetNumber: String = ""
    @State private var streetName: String = ""
    @State private var suburb: String = ""
    @State private var postcode: String = ""
    @State private var state: String = ""
    @State private var country: String = ""
    @State private var poBox: String = ""
    @State private var mmmZoneForAddress: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    headerSection
                    instructionsSection
                }
                .padding(20)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 8) {
                    businessAddressSection
                    addressSearchSection
                }
                .padding(20)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 8) {
                    sessionListSection
                    actionButtonsSection
                }
                .padding(20)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 8) {
                    resultsSection
                }
                .padding(20)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))
            }
            .padding(.vertical, StyleGuide.Dimensions.paddingXXLarge)
            .padding(.horizontal, StyleGuide.Dimensions.paddingXLarge)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        #if os(macOS)
        .scrollIndicators(.visible)
        #endif
        .onAppear {
            // Compute expanded sessions when view appears
            if cachedExpandedSessions.isEmpty {
                cachedExpandedSessions = computeExpandedSessions()
            }
        }
        .onChange(of: sessions.count) { _, _ in
            // Recompute when sessions change
            cachedExpandedSessions = computeExpandedSessions()
        }
        .onChange(of: testChargeSummaries.count) { _, newCount in
            print("DEBUG: testChargeSummaries count changed to: \(newCount)")
        }
        .onChange(of: testReviewSummaries.count) { _, newCount in
            print("DEBUG: testReviewSummaries count changed to: \(newCount)")
        }
        .sheet(isPresented: $showingReviewSheet) {
            TravelChargeReviewSheet(
                chargeSummaries: testChargeSummaries,
                reviewSummaries: testReviewSummaries,
                detailedReviewItems: testDetailedReviewItems,
                reviewService: reviewService
            )
        }
        .sheet(isPresented: $showingIntegratedReviewView) {
            TravelChargeReviewView()
        }
        .onChange(of: showingReviewSheet) { _, isPresented in
            if isPresented {
                print("DEBUG: Presenting review sheet with \(testChargeSummaries.count) charges and \(testReviewSummaries.count) reviews")
            }
        }
    }

    private func runAutomation() {
        print("DEBUG: runAutomation called")
        print("DEBUG: selectedSessionInstances count: \(selectedSessionInstances.count)")
        print("DEBUG: selectedSessionInstances: \(selectedSessionInstances)")
        
        guard !selectedSessionInstances.isEmpty else { 
            print("DEBUG: No sessions selected, returning early")
            return 
        }
        isRunning = true
        errorMessage = nil
        automationResults = []
        reviewItems = []
        testChargeSummaries = []
        testReviewSummaries = []
        let context = viewContext
        
        // Debug: Check business address before running automation
        let businessDescriptor = FetchDescriptor<BusinessEntity>()
        if let business = try? context.fetch(businessDescriptor).first {
            let address = business.address
            let fullFormattedAddress = address?.fullFormattedAddress ?? "nil"
            let fullAddressText = address?.fullAddressText ?? "nil"
            let hasStreetName = !(address?.streetName ?? "").isEmpty
            let hasSuburb = !(address?.suburb ?? "").isEmpty
            
            print("DEBUG: Business address check:")
            print("  - fullFormattedAddress: '\(fullFormattedAddress)'")
            print("  - fullAddressText: '\(fullAddressText)'")
            print("  - hasStreetName: \(hasStreetName)")
            print("  - hasSuburb: \(hasSuburb)")
            print("  - streetName: '\(address?.streetName ?? "nil")'")
            print("  - suburb: '\(address?.suburb ?? "nil")'")
            print("  - state: '\(address?.state ?? "nil")'")
            print("  - postcode: '\(address?.postcode ?? "nil")'")
        } else {
            print("DEBUG: No business entity found")
        }
        
        let _ = TravelChargeAutomationService(
            context: context,
            businessRules: BusinessRules(),
            userPreferences: UserPreferences(),
            mmmZoneTable: MMMZoneTable(),
            testingMode: true // Enable testing mode
        )
        // Run automation on main queue to avoid context issues
        Task {
            await MainActor.run {
                self.isRunning = true
            }
            
            // Use the same context to avoid SwiftData relationship issues
            let backgroundService = TravelChargeAutomationService(
                context: viewContext,
                businessRules: BusinessRules(),
                userPreferences: UserPreferences(),
                mmmZoneTable: MMMZoneTable(),
                testingMode: true
            )
            
            // Store the service for the review sheet
            self.reviewService = backgroundService
            
            // Convert selected session instances to proper SessionEntity objects
            var sessionsToProcess: [SessionEntity] = []
            
            print("DEBUG: Processing \(selectedSessionInstances.count) selected instances")
            print("DEBUG: Available expanded sessions: \(expandedSessions.count)")
            
            for instanceId in selectedSessionInstances {
                print("DEBUG: Looking for instance ID: \(instanceId)")
                // Find the corresponding session instance
                if let matchingInstance = expandedSessions.first(where: { sessionInstance in
                    let matches = sessionInstance.uniqueInstanceId == instanceId
                    print("DEBUG: Checking \(sessionInstance.uniqueInstanceId) == \(instanceId): \(matches)")
                    return matches
                }) {
                    print("DEBUG: Found matching instance for session: \(matchingInstance.session.title)")
                    sessionsToProcess.append(matchingInstance.session)
                } else {
                    print("DEBUG: No matching instance found for ID: \(instanceId)")
                }
            }
            
            print("DEBUG: Sessions to process: \(sessionsToProcess.count)")
            
            // Calculate date range that includes all selected session instances
            let selectedInstances = expandedSessions.filter { sessionInstance in
                return selectedSessionInstances.contains(sessionInstance.uniqueInstanceId)
            }
            
            let earliestDate = selectedInstances.map { $0.instanceStart }.min() ?? Date()
            let latestDate = selectedInstances.map { $0.instanceEnd }.max() ?? Date()
            let dateRange = earliestDate...latestDate
            
            print("DEBUG: Using date range: \(earliestDate) to \(latestDate)")
            
            // Run automation with same context
            backgroundService.automateTravelCharges(for: sessionsToProcess, dateRange: dateRange) {
                // This completion block runs when all async operations are done
                Task { @MainActor in
                                let (charges, reviews, detailedReviews) = backgroundService.getTestResults()
            
            print("DEBUG: Updating UI with results")
            print("DEBUG: Charges count: \(charges.count)")
            print("DEBUG: Reviews count: \(reviews.count)")
            print("DEBUG: Detailed reviews count: \(detailedReviews.count)")
            print("DEBUG: Charge summaries: \(charges)")
            print("DEBUG: Review summaries: \(reviews)")
            
            self.testChargeSummaries = charges
            self.testReviewSummaries = reviews
            self.testDetailedReviewItems = detailedReviews
                    self.isRunning = false
                    
                    print("DEBUG: Updated testChargeSummaries count: \(self.testChargeSummaries.count)")
                    print("DEBUG: Updated testReviewSummaries count: \(self.testReviewSummaries.count)")
                }
            }
            
            // Don't get results here - wait for completion
            return
        }
    }

    private func showMMMZone(for session: SessionEntity) {
        if session.sessionLatitude != 0 || session.sessionLongitude != 0 {
            let coord = CLLocationCoordinate2D(latitude: session.sessionLatitude, longitude: session.sessionLongitude)
            if let mmmCode = MMMZoneLookup.shared.mmm(for: coord) {
                mmmZoneResult = "Code: \(mmmCode) for coordinates"
            } else {
                mmmZoneResult = "No MMM zone found for coordinates"
            }
        } else if let address = session.location, !address.isEmpty {
            // Use the new MapKit geocoding API
            Task {
                do {
                    guard let request = MKGeocodingRequest(addressString: address) else {
                        mmmZoneResult = "Could not create geocoding request for address"
                        return
                    }
                    let coordinate = try await Task.detached {
                        let mapItems = try await request.mapItems
                        guard let firstItem = mapItems.first,
                              firstItem.location != nil else {
                            throw NSError(domain: "GeocodingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No location found"])
                        }
                        return firstItem.location.coordinate
                    }.value
                    
                    session.sessionLatitude = coordinate.latitude
                    session.sessionLongitude = coordinate.longitude
                    if let mmmCode = MMMZoneLookup.shared.mmm(for: coordinate) {
                        mmmZoneResult = "Code: \(mmmCode) for coordinates (after geocoding)"
                    } else {
                        mmmZoneResult = "No MMM zone found for coordinates (after geocoding)"
                    }
                } catch {
                    mmmZoneResult = "Could not geocode address: \(error.localizedDescription)"
                }
            }
        } else {
            mmmZoneResult = "Session has no address or coordinates."
        }
    }

    private func runMMMZoneLookupOnAddress(_ address: AddressData) {
        // Use the full address for geocoding
        let addressString = address.fullAddress
        if !addressString.isEmpty {
            // Use the new MapKit geocoding API
            Task {
                do {
                    guard let request = MKGeocodingRequest(addressString: addressString) else {
                        self.mmmZoneForAddress = "Could not create geocoding request for address"
                        return
                    }
                    let coordinate = try await Task.detached {
                        let mapItems = try await request.mapItems
                        guard let firstItem = mapItems.first else {
                            throw NSError(domain: "GeocodingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No location found"])
                        }
                        return firstItem.location.coordinate
                    }.value
                    
                    if let mmmCode = MMMZoneLookup.shared.mmm(for: coordinate) {
                        self.mmmZoneForAddress = "Code: \(mmmCode) for coordinates (after geocoding)"
                    } else {
                        self.mmmZoneForAddress = "No MMM zone found for coordinates (after geocoding)"
                    }
                } catch {
                    self.mmmZoneForAddress = "Could not geocode address for MMM zone lookup: \(error.localizedDescription)"
                }
            }
        } else {
            mmmZoneForAddress = "No address selected."
        }
    }

    private func dateFormatter() -> DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Travel Charge Automation Test")
                .font(.title.bold())
            Text("Select one or more sessions and run the automation. Or search for an address below to test MMM zone lookup.")
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
        }
    }
            
    private var instructionsSection: some View {
            GroupBox(label: Label("Instructions", systemImage: "info.circle")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Sessions must have a location set to create travel charges")
                    Text("• Business address must be configured in Settings → Company Details")
                    Text("• Sessions marked with ⚠️ need a location set")
                    Text("• Travel charges are created for first/last sessions of the day")
                }
                .font(.caption)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            .padding(.bottom, 8)
    }
            
    private var businessAddressSection: some View {
            GroupBox(label: Label("Business Address Status", systemImage: "building.2")) {
                let businessDescriptor = FetchDescriptor<BusinessEntity>()
                if let business = try? viewContext.fetch(businessDescriptor).first,
                   let address = business.address {
                    let fullFormattedAddress = address.fullFormattedAddress
                    let hasAddress = !fullFormattedAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: hasAddress ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(hasAddress ? .green : .red)
                            Text(hasAddress ? "Business address is set" : "Business address is missing or empty")
                                .font(.caption)
                        }
                        if hasAddress {
                            Text("Address: \(fullFormattedAddress)")
                                .font(.caption2)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        } else {
                            Text("Address fields are empty - please set business address in Company settings")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("No business entity or address found")
                            .font(.caption)
                    }
                }
            }
            .padding(.bottom, 8)
    }

    private var addressSearchSection: some View {
            GroupBox(label: Label("Address Search (MapKit)", systemImage: "magnifyingglass")) {
                VStack(alignment: .leading, spacing: 8) {
                    SettingsRow(label: "Address Search:", labelWidth: maxLabelWidth) {
                        TextField("Enter address to search", text: $addressSearchText)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Address search")
                            .accessibilityHint("Enter an address to search for MMM zone lookup")
                    }
                    if let address = selectedAddress {
                        Text("Selected: \(address.fullAddress)")
                        Button("Run MMM Zone Lookup on Address") {
                            runMMMZoneLookupOnAddress(address)
                        }
                        .buttonStyle(.glassProminent)
                        .appInteractiveCursor()
                    }
                    if let zone = mmmZoneForAddress {
                        Text("MMM Zone: \(zone)").foregroundColor(.blue)
                    }
                }
            }
            .padding(.bottom, 8)
    }

    private var sessionListSection: some View {
            List(selection: $selectedSessions) {
                ForEach(expandedSessions, id: \.uniqueInstanceId) { sessionInstance in
                    let session = sessionInstance.session
                    HStack {
                        VStack(alignment: .leading) {
                            Text(session.title).font(.headline)
                            if let client = session.client?.fullName {
                                Text("Client: \(client)").font(.caption)
                            }
                            // Show specific instance time for recurring sessions
                            if session.recurrenceRuleData != nil {
                                Text("Instance: \(sessionInstance.instanceStart, formatter: dateFormatter())").font(.caption2).foregroundColor(.blue)
                                Text("End: \(sessionInstance.instanceEnd, formatter: dateFormatter())").font(.caption2).foregroundColor(.blue)
                            } else {
                                Text("\(sessionInstance.instanceStart, formatter: dateFormatter())").font(.caption2)
                            }
                            // Check both location string and linked address entity
                            Group {
                                if let loc = session.location, !loc.isEmpty {
                                    Text(loc).font(.caption2).foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                } else if let address = session.address {
                                    Text(address.fullFormattedAddress).font(.caption2).foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                } else {
                                    Text("No location set").font(.caption2).foregroundColor(.red)
                                }
                            }
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            // Check if session has any location data
                            if !((session.location != nil && !session.location!.isEmpty) || session.address != nil) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .help("Session has no location set")
                            }
                            if session.recurrenceRuleData != nil {
                                Image(systemName: "repeat.circle.fill")
                                    .foregroundColor(.blue)
                                    .help("Recurring session instance")
                            }
                            // Use the unique instance ID for selection
                            if selectedSessionInstances.contains(sessionInstance.uniqueInstanceId) {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Use the unique instance ID for selection
                        let instanceId = sessionInstance.uniqueInstanceId
                        print("DEBUG: Tapped session instance: \(instanceId)")
                        print("DEBUG: Session title: \(sessionInstance.session.title)")
                        print("DEBUG: Instance start: \(sessionInstance.instanceStart)")
                        
                        if selectedSessionInstances.contains(instanceId) {
                            selectedSessionInstances.remove(instanceId)
                            print("DEBUG: Removed from selection")
                        } else {
                            selectedSessionInstances.insert(instanceId)
                            print("DEBUG: Added to selection")
                        }
                        print("DEBUG: Current selection count: \(selectedSessionInstances.count)")
                    }
                }
            }
            .frame(maxHeight: 200)
            .listStyle(.plain)
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button(action: runAutomation) {
                    Label("Run Automation", systemImage: "play.circle")
                }
                .disabled(selectedSessionInstances.isEmpty || isRunning)
                .buttonStyle(.glassProminent)
                .appInteractiveCursor()

                if let firstInstanceId = selectedSessionInstances.first,
                   let matchingInstance = expandedSessions.first(where: { sessionInstance in
                       return sessionInstance.uniqueInstanceId == firstInstanceId
                   }) {
                    Button("Show MMM Zone Lookup") {
                        showMMMZone(for: matchingInstance.session)
                    }
                    .buttonStyle(.glass)
                    .appInteractiveCursor()
                }
                
                // New button to show review results
                if !testChargeSummaries.isEmpty || !testReviewSummaries.isEmpty {
                    Button("Review Results") {
                        print("DEBUG: Review Results button tapped")
                        print("DEBUG: testChargeSummaries.count: \(testChargeSummaries.count)")
                        print("DEBUG: testReviewSummaries.count: \(testReviewSummaries.count)")
                        showingReviewSheet = true
                    }
                    .buttonStyle(.glass)
                    .appInteractiveCursor()
                }
                
                // Button to access integrated review system
                Button("Compliance Review") {
                    showingIntegratedReviewView = true
                }
                .buttonStyle(.glass)
                .appInteractiveCursor()
                .disabled(reviewItems.isEmpty)
            }

            if isRunning {
                ProgressView("Running automation...")
            }
            if let error = errorMessage {
                Text(error).foregroundColor(.red)
            }
            if let mmmZone = mmmZoneResult {
                Text("MMM Zone: \(mmmZone)").foregroundColor(.blue)
            }
        }
            }

    private var resultsSection: some View {
        VStack(spacing: 8) {
            if !automationResults.isEmpty {
                Text("Created Travel Charges:").font(.headline)
                List(automationResults, id: \.id) { charge in
                    VStack(alignment: .leading) {
                        Text(charge.client?.fullName ?? "Unknown Client").bold()
                        if let start = charge.startTime {
                            Text("\(start, formatter: dateFormatter())")
                        }
                        Text("Distance: \(String(format: "%.1f", charge.travelDistance ?? 0.0)) km, MMM Zone: \(charge.mmmZoneName ?? "?")")
                        if let notes = charge.notes { Text(notes).font(.caption).foregroundColor(Color("TextSecondary", bundle: .sharedUI)) }
                    }
                }
                .frame(height: 120)
            }
            if !reviewItems.isEmpty {
                Text("Review Items:").font(.headline)
                List(reviewItems, id: \.id) { item in
                    VStack(alignment: .leading) {
                        Text(item.session?.title ?? "Session").bold()
                        Text(item.reason ?? "No reason provided").foregroundColor(.orange)
                        if let date = item.timestamp {
                            Text("\(date, formatter: dateFormatter())").font(.caption2)
                        }
                    }
                }
                .frame(height: 100)
            }
            if !testChargeSummaries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Test Mode: Would Create Travel Charges:")
                            .font(.headline)
                        Spacer()
                        Text("\(testChargeSummaries.count) charges")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                            .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                            .background(Color.blue.opacity(StyleGuide.Opacity.light))
                            .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                    }
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(testChargeSummaries.enumerated()), id: \.offset) { index, summary in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Travel Charge #\(index + 1)")
                                        .font(.headline)
                                        .foregroundColor(.accentColor)
                                    
                                    Text(summary)
                                        .font(.caption)
                                        .padding(8)
                                        .background(Color.gray.opacity(StyleGuide.Opacity.light))
                                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.bottom, 8)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 300)
                }
            }
            if !testReviewSummaries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Test Mode: Review Items:")
                            .font(.headline)
                        Spacer()
                        Text("\(testReviewSummaries.count) items")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                            .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                            .background(Color.orange.opacity(StyleGuide.Opacity.light))
                            .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                    }
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(testReviewSummaries.enumerated()), id: \.offset) { index, summary in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Review Item #\(index + 1)")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                    
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .padding(8)
                                        .background(Color.orange.opacity(StyleGuide.Opacity.light))
                                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.bottom, 6)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
    }
} 
