import SwiftUI
import SwiftData
import MapKit
import Data
import Core
import SharedUI

struct NDISBillingContextView: View {
    @Binding var billingContext: NDISBillingContext
    let session: SessionEntity
    let shouldAutoDetermine: Bool
    @Environment(\.modelContext) private var modelContext
    
    // Automation orchestrator
    private var automationOrchestrator: NDISBillingAutomationOrchestrator {
        NDISBillingAutomationOrchestrator(modelContext: modelContext)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Billing Context")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            // Support Item Selection
            SupportItemSelectionView(
                selectedSupportItem: $billingContext.supportItemNumber,
                session: session
            )
            
            // Service Type Context
            ServiceTypeContextView(
                billingContext: $billingContext,
                session: session,
                automationOrchestrator: automationOrchestrator
            )
            
            // Geographic and Time Context
            GeographicTimeContextView(
                billingContext: $billingContext,
                session: session,
                automationOrchestrator: automationOrchestrator
            )
            
            // Travel and Transport Context
            TravelTransportContextView(
                billingContext: $billingContext,
                session: session,
                automationOrchestrator: automationOrchestrator
            )
            
            // Special Circumstances
            SpecialCircumstancesView(billingContext: $billingContext, session: session, automationOrchestrator: automationOrchestrator)
            
            Spacer()
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
        .background(Color("Background", bundle: .sharedUI))
        .scrollEdgeEffectStyle(.hard, for: .top)
        .onAppear {
            // Execute automation flow when view appears, but only if shouldAutoDetermine is true
            if shouldAutoDetermine {
                Task {
                    var context = billingContext
                    let result = await automationOrchestrator.executeAutomationFlow(for: session, context: &context)
                    
                    await MainActor.run {
                        billingContext = context
                        if result.hasErrors {
                            print("❌ [NDIS Billing] Automation completed with errors: \(result.errors)")
                        }
                        
                        if result.hasWarnings {
                            print("⚠️ [NDIS Billing] Automation completed with warnings: \(result.warnings)")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Support Item Selection

struct SupportItemSelectionView: View {
    @Binding var selectedSupportItem: String
    let session: SessionEntity
    @State private var searchText = ""
    @State private var showingSupportItemPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Support Item")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedSupportItem.isEmpty ? "Select Support Item" : selectedSupportItem)
                        .font(.caption)
                        .foregroundColor(selectedSupportItem.isEmpty ? Color("TextSecondary", bundle: .sharedUI) : Color("Text", bundle: .sharedUI))
                    
                    if let clientService = session.clientService {
                        Text("Default: \(clientService.ndisCode ?? "None")")
                            .font(.caption2)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    }
                }
                
                Spacer()
                
                Button("Change") {
                    showingSupportItemPicker = true
                }
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 6))
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .contentShape(RoundedRectangle(cornerRadius: 6))
                .help("Change support item for this session")
                .appInteractiveCursor()
            }
            .padding()
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingSupportItemPicker) {
            SupportItemPickerView(selectedItem: $selectedSupportItem)
            .fluidSheetTransition()
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showingSupportItemPicker)
        }
    }
}

// MARK: - Service Type Context

struct ServiceTypeContextView: View {
    @Binding var billingContext: NDISBillingContext
    let session: SessionEntity
    let automationOrchestrator: NDISBillingAutomationOrchestrator
    
    private var ndisItem: NDISItemEntity? {
        session.clientService?.ndisItem
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Service Type")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                BillingContextToggle(
                    title: "Complex Behavior Support",
                    description: "High intensity support for complex behaviors (manually set by user)",
                    isOn: $billingContext.isComplexBehavior,
                    isAutoDetermined: false, // Not auto-determined
                    isDisabled: !automationOrchestrator.isComplexBehaviorSupported(for: session) // Disabled if NDIS item doesn't support it
                )
                
                BillingContextToggle(
                    title: "High Intensity Support",
                    description: "Support requiring high intensity assistance (manually set by user)",
                    isOn: $billingContext.isHighIntensity,
                    isAutoDetermined: false, // Not auto-determined
                    isDisabled: !automationOrchestrator.isHighIntensitySupported(for: session) // Disabled if NDIS item doesn't support it
                )
                
                BillingContextToggle(
                    title: "Group Support",
                    description: "Support provided in a group setting (determined by session data and service type)",
                    isOn: $billingContext.isGroupSupport,
                    isAutoDetermined: billingContext.autoDeterminedValues.contains(.groupSupport),
                    isDisabled: false // Always available - based on session data
                )
                
                BillingContextToggle(
                    title: "Telehealth",
                    description: "Service provided via telehealth (NDIS Support Catalogue: Non-Face-to-Face Support Provision) - manually set by user",
                    isOn: $billingContext.isTelehealth,
                    isAutoDetermined: false, // Not auto-determined - must be manually set based on actual delivery method
                    isDisabled: ndisItem?.nonFaceToFaceProvision != true
                )
                
                BillingContextToggle(
                    title: "Non-Face-to-Face",
                    description: "Service delivered remotely (video call, phone, etc.) - set based on actual delivery method (NDIS Support Catalogue: Non-Face-to-Face Support Provision) - manually set by user",
                    isOn: $billingContext.isNonFaceToFace,
                    isAutoDetermined: false, // Not auto-determined - must be manually set based on actual delivery method
                    isDisabled: ndisItem?.nonFaceToFaceProvision != true
                )
                
                BillingContextToggle(
                    title: "Short Notice Cancellation",
                    description: "Service cancelled with short notice (NDIS Support Catalogue: Short Notice Cancellations) - determined by session status",
                    isOn: $billingContext.isShortNoticeCancellation,
                    isAutoDetermined: billingContext.autoDeterminedValues.contains(.shortNoticeCancellation),
                    isDisabled: ndisItem?.shortNoticeCancellations != true
                )
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Geographic and Time Context

struct GeographicTimeContextView: View {
    @Binding var billingContext: NDISBillingContext
    let session: SessionEntity
    let automationOrchestrator: NDISBillingAutomationOrchestrator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location & Time")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                BillingContextToggle(
                    title: "Remote Area",
                    description: "Service provided in remote area (determined by session location data)",
                    isOn: $billingContext.isRemoteArea,
                    isAutoDetermined: billingContext.autoDeterminedValues.contains(.remoteArea),
                    isDisabled: false // Always available - based on session location data
                )
                
                BillingContextToggle(
                    title: "Very Remote Area",
                    description: "Service provided in very remote area (determined by session location data)",
                    isOn: $billingContext.isVeryRemoteArea,
                    isAutoDetermined: billingContext.autoDeterminedValues.contains(.veryRemoteArea),
                    isDisabled: false // Always available - based on session location data
                )
                
                BillingContextToggle(
                    title: "Public Holiday",
                    description: "Service provided on public holiday (determined by session date/time data)",
                    isOn: $billingContext.isPublicHoliday,
                    isAutoDetermined: billingContext.autoDeterminedValues.contains(.publicHoliday),
                    isDisabled: false // Always available - based on session date/time data
                )
                
                BillingContextToggle(
                    title: "Weekend Service",
                    description: "Service provided on weekend (determined by session date/time data)",
                    isOn: $billingContext.isWeekend,
                    isAutoDetermined: billingContext.autoDeterminedValues.contains(.weekend),
                    isDisabled: false // Always available - based on session date/time data
                )
                
                BillingContextToggle(
                    title: "Evening Service",
                    description: "Service provided in evening hours (determined by session date/time data)",
                    isOn: $billingContext.isEvening,
                    isAutoDetermined: billingContext.autoDeterminedValues.contains(.evening),
                    isDisabled: false // Always available - based on session date/time data
                )
                
                BillingContextToggle(
                    title: "Night Service",
                    description: "Service provided during night hours (determined by session date/time data)",
                    isOn: $billingContext.isNight,
                    isAutoDetermined: billingContext.autoDeterminedValues.contains(.night),
                    isDisabled: false // Always available - based on session date/time data
                )
                
                // Enhanced geographic information
                if session.sessionLatitude != 0.0 && session.sessionLongitude != 0.0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Geographic Information")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.top, 8)
                        
                        let coordinate = CLLocationCoordinate2D(
                            latitude: session.sessionLatitude,
                            longitude: session.sessionLongitude
                        )
                        
                        if let mmmCode = MMMZoneLookup.shared.mmm(for: coordinate) {
                            GeographicInfoRow(
                                title: "MMM Zone",
                                value: "\(mmmCode)",
                                description: getMMMZoneDescription(mmmCode)
                            )
                            
                            GeographicInfoRow(
                                title: "Coordinates",
                                value: String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude),
                                description: "Session location"
                            )
                            
                            if let sessionLocation = getSessionLocationDisplay(session) {
                                GeographicInfoRow(
                                    title: "Address",
                                    value: sessionLocation,
                                    description: "Session location"
                                )
                            }
                        } else {
                            Text("MMM Zone: Not found")
                                .font(.caption2)
                                .foregroundColor(Color("Inactive", bundle: .sharedUI))
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 8)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func getMMMZoneDescription(_ mmmCode: Int) -> String {
        switch mmmCode {
        case 1: return "Major Cities"
        case 2: return "Inner Regional"
        case 3: return "Outer Regional"
        case 4: return "Remote"
        case 5: return "Very Remote"
        default: return "Unknown"
        }
    }
    
    private func getSessionLocationDisplay(_ session: SessionEntity) -> String? {
        if let location = session.location, !location.isEmpty {
            return location
        }
        if let address = session.address {
            return address.fullFormattedAddress
        }
        return nil
    }
}

// MARK: - Geographic Info Row

struct GeographicInfoRow: View {
    let title: String
    let value: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                Spacer()
                Text(value)
                    .font(.caption2)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            
            Text(description)
                .font(.caption2)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Travel and Transport Context

struct TravelTransportContextView: View {
    @Binding var billingContext: NDISBillingContext
    let session: SessionEntity
    let automationOrchestrator: NDISBillingAutomationOrchestrator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Travel & Transport")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                BillingContextToggle(
                    title: "Provider Travel",
                    description: "Provider travels to participant (NDIS Support Catalogue: Provider Travel)",
                    isOn: $billingContext.isProviderTravel,
                    isAutoDetermined: billingContext.autoDeterminedValues.contains(.providerTravel),
                    isDisabled: session.clientService?.ndisItem?.providerTravel != true
                )
                
                BillingContextToggle(
                    title: "Activity Transport",
                    description: "Transport for community participation (determined by session data and service type)",
                    isOn: $billingContext.isActivityTransport,
                    isAutoDetermined: billingContext.autoDeterminedValues.contains(.activityTransport),
                    isDisabled: false // Always available - based on session data and service type
                )
                
                if billingContext.isProviderTravel {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Travel Details")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        // Auto-calculated fields
                        HStack {
                            Text("Distance (km)")
                            Spacer()
                            TextField("0", value: $billingContext.travelDistance, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        .opacity(billingContext.autoDeterminedValues.contains(.travelDetails) ? 0.7 : 1.0)
                        .overlay(
                            billingContext.autoDeterminedValues.contains(.travelDetails) ?
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color("Green", bundle: .sharedUI))
                                    .font(.caption)
                            } : nil
                        )
                        
                        HStack {
                            Text("Time (minutes)")
                            Spacer()
                            TextField("0", value: $billingContext.travelTime, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        .opacity(billingContext.autoDeterminedValues.contains(.travelDetails) ? 0.7 : 1.0)
                        .overlay(
                            billingContext.autoDeterminedValues.contains(.travelDetails) ?
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color("Green", bundle: .sharedUI))
                                    .font(.caption)
                            } : nil
                        )
                        
                        // Manual fields
                        HStack {
                            Text("Tolls")
                            Spacer()
                            TextField("0", value: $billingContext.travelTolls, format: .currency(code: "AUD"))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        .overlay(
                            HStack {
                                Spacer()
                                Text("Manual")
                                    .font(.caption2)
                                    .foregroundColor(Color("Inactive", bundle: .sharedUI))
                            }
                        )
                        
                        HStack {
                            Text("Parking")
                            Spacer()
                            TextField("0", value: $billingContext.travelParking, format: .currency(code: "AUD"))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        .overlay(
                            HStack {
                                Spacer()
                                Text("Manual")
                                    .font(.caption2)
                                    .foregroundColor(Color("Inactive", bundle: .sharedUI))
                            }
                        )
                        
                        if billingContext.autoDeterminedValues.contains(.travelDetails) {
                            Text("Distance and Time auto-calculated from business address to session location")
                                .font(.caption2)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        }
                        
                        // Enhanced travel information
                        if let clientService = session.clientService,
                           let ndisItem = clientService.ndisItem {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NDIS Travel Items")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.top, 8)
                                
                                TravelNDISItemRow(
                                    title: "Labour Travel",
                                    itemNumber: ndisItem.itemNumber,
                                    description: "Same as primary support"
                                )
                                
                                if let nonLabourItem = automationOrchestrator.mapToTravelNDISItem(session: session, chargeType: "non-labour") {
                                    TravelNDISItemRow(
                                        title: "Non-Labour Travel",
                                        itemNumber: nonLabourItem.itemNumber,
                                        description: "799 rule applied"
                                    )
                                }
                                
                                if billingContext.isActivityTransport,
                                   let activityItem = automationOrchestrator.mapToTravelNDISItem(session: session, chargeType: "activity-based") {
                                    TravelNDISItemRow(
                                        title: "Activity Transport",
                                        itemNumber: activityItem.itemNumber,
                                        description: "590 rule applied"
                                    )
                                }
                            }
                            .padding(.top, 8)
                            .padding(.horizontal, 8)
                            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Travel NDIS Item Row

struct TravelNDISItemRow: View {
    let title: String
    let itemNumber: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                Spacer()
                Text(itemNumber)
                    .font(.caption2)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            
            Text(description)
                .font(.caption2)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Special Circumstances

struct SpecialCircumstancesView: View {
    @Binding var billingContext: NDISBillingContext
    let session: SessionEntity
    let automationOrchestrator: NDISBillingAutomationOrchestrator
    
    private var ndisItem: NDISItemEntity? {
        session.clientService?.ndisItem
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Special Circumstances")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                BillingContextToggle(
                    title: "Shadow Shift",
                    description: "Support worker shadowing (manually set by user)",
                    isOn: $billingContext.isShadowShift,
                    isAutoDetermined: false, // Not auto-determined
                    isDisabled: !automationOrchestrator.areSpecialCircumstancesSupported(for: session).shadowShift // Disabled if NDIS item doesn't support it
                )
                
                BillingContextToggle(
                    title: "SIL Unplanned Exit",
                    description: "Unplanned exit from SIL (NDIS Support Catalogue: Irregular SIL Supports) - manually set by user",
                    isOn: $billingContext.isSilUnplannedExit,
                    isAutoDetermined: false, // Not auto-determined
                    isDisabled: ndisItem?.irregularSILSupports != true
                )
                
                BillingContextToggle(
                    title: "NDIA Report",
                    description: "Report writing for NDIA (NDIS Support Catalogue: NDIA Requested Reports) - manually set by user",
                    isOn: $billingContext.isNdiaReport,
                    isAutoDetermined: false, // Not auto-determined
                    isDisabled: ndisItem?.ndiaRequestedReports != true
                )
                
                BillingContextToggle(
                    title: "Prepayment",
                    description: "Prepayment claim (determined by session data) - manually set by user",
                    isOn: $billingContext.isPrepayment,
                    isAutoDetermined: false, // Not auto-determined - must be manually set based on actual circumstances
                    isDisabled: false // Always available - based on session data
                )
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Enhanced Billing Context Toggle

struct BillingContextToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    let isAutoDetermined: Bool
    let isDisabled: Bool
    @State private var showingPopover = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isDisabled ? Color("TextSecondary", bundle: .sharedUI) : Color("Text", bundle: .sharedUI))
                    
                    if isAutoDetermined {
                        Image(systemName: "wand.and.stars")
                            .font(.caption2)
                            .foregroundColor(Color("Draft", bundle: .sharedUI))
                            .help("Auto-determined by automation")
                    }
                    
                    Button(action: {
                        showingPopover = true
                    }) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundColor(Color("Draft", bundle: .sharedUI))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .popover(isPresented: $showingPopover) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(title)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(description)
                                .font(.body)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            
                            Spacer()
                        }
                        .padding()
                        .frame(width: 300, height: 150)
                    }
                    .help("More info about this setting")
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .scaleEffect(0.8)
                .disabled(isDisabled)
                .help(isDisabled ? "Not available for this support item" : "Toggle setting")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .opacity(isDisabled ? 0.6 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Support Item Picker

struct SupportItemPickerView: View {
    @Binding var selectedItem: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    // Mock support items - in real app this would come from NDIS catalog
    private let supportItems = [
        "01_011_0125_6_3": "Assistance with daily personal activities",
        "01_012_0125_6_3": "Assistance with daily personal activities - high intensity",
        "01_013_0125_6_3": "Assistance with daily personal activities - complex",
        "01_014_0125_6_3": "Assistance with daily personal activities - SIL",
        "02_011_0125_6_3": "Assistance with household tasks",
        "02_012_0125_6_3": "Assistance with household tasks - high intensity",
        "03_011_0125_6_3": "Assistance with community participation",
        "03_012_0125_6_3": "Assistance with community participation - high intensity"
    ]
    
    var filteredItems: [(String, String)] {
        if searchText.isEmpty {
            return Array(supportItems)
        } else {
            return supportItems.filter { key, value in
                key.localizedCaseInsensitiveContains(searchText) ||
                value.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    
                    TextField("Search support items...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                
                // Support items list
                List(filteredItems, id: \.0) { item in
                    Button(action: {
                        selectedItem = item.0
                        dismiss()
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.0)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text(item.1)
                                .font(.caption2)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                .lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Select Support Item")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Cancel") { dismiss() }
                        .appInteractiveCursor()
                }
            }
            
        }
    }
}

