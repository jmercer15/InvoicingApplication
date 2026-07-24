import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import Data
import Core
import SharedUI
import WorkspaceUI

struct TravelChargeAutomationTestView: View {
    @Environment(\.modelContext) private var modelContext
    @State var viewModel: TravelChargeAutomationViewModel
    @State private var reviewViewModel: TravelChargeReviewViewModel

    @State private var unitNumber: String = ""
    @State private var streetNumber: String = ""
    @State private var streetName: String = ""
    @State private var suburb: String = ""
    @State private var postcode: String = ""
    @State private var state: String = ""
    @State private var country: String = ""
    @State private var poBox: String = ""

    // New state for review sheet
    @State private var showingReviewSheet = false
    @State private var showingIntegratedReviewView = false

    private struct RefreshTaskID: Equatable {
        let isRunning: Bool
    }
    private var refreshTaskID: RefreshTaskID {
        RefreshTaskID(isRunning: viewModel.isRunning)
    }
    
    private var maxLabelWidth: CGFloat {
        let labels = ["Address Search:"]
        return labels.map { $0.width() }.max() ?? 120
    }

    @ScaledMetric(relativeTo: .body) private var paddingXXLarge = StyleGuide.Dimensions.paddingXXLarge
    @ScaledMetric(relativeTo: .body) private var paddingXLarge = StyleGuide.Dimensions.paddingXLarge
    @ScaledMetric(relativeTo: .body) private var paddingMedium = StyleGuide.Dimensions.paddingMedium
    @ScaledMetric(relativeTo: .body) private var paddingSmall = StyleGuide.Dimensions.paddingSmall
    @ScaledMetric(relativeTo: .body) private var cornerRadiusXSmall = StyleGuide.Dimensions.cornerRadiusXSmall
    @ScaledMetric(relativeTo: .body) private var cornerRadiusSmall = StyleGuide.Dimensions.cornerRadiusSmall

    public init(
        viewModel: @autoclosure @escaping () -> TravelChargeAutomationViewModel,
        reviewViewModel: @autoclosure @escaping () -> TravelChargeReviewViewModel
    ) {
        _viewModel = State(initialValue: viewModel())
        _reviewViewModel = State(initialValue: reviewViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                    headerSection
                    instructionsSection
                }
                .standardSectionStyle()

                VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                    businessAddressSection
                    addressSearchSection
                }
                .standardSectionStyle()

                VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                    sessionListSection
                    actionButtonsSection
                }
                .standardSectionStyle()

                VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                    resultsSection
                }
                .standardSectionStyle()
            }
            .padding(.vertical, paddingXXLarge)
            .padding(.horizontal, paddingXLarge)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        #if os(macOS)
        .scrollIndicators(.visible)
        #endif
        .task(id: refreshTaskID) { @MainActor in
            let actor = ReferenceDataWorkflowActor(modelContainer: modelContext.container)
            do {
                let sessionIDs = try await actor.fetchAllSessionIDs()
                let businessIDs = try await actor.fetchAllBusinessIDs()

                let sessionDesc = FetchDescriptor<Session>(
                    predicate: #Predicate { sessionIDs.contains($0.persistentModelID) }
                )
                let businessDesc = FetchDescriptor<Business>(
                    predicate: #Predicate { businessIDs.contains($0.persistentModelID) }
                )
                let sessions = (try? modelContext.fetch(sessionDesc)) ?? []
                let businesses = (try? modelContext.fetch(businessDesc)) ?? []

                viewModel.updateSessions(sessions)
                viewModel.updateBusiness(businesses.first)
            } catch {
                print("Failed to fetch data for TravelChargeAutomationTestView: \(error)")
            }
        }
        .sheet(isPresented: $showingReviewSheet) {
            TravelChargeReviewSheet(
                chargeSummaries: viewModel.testChargeSummaries,
                reviewSummaries: viewModel.testReviewSummaries,
                detailedReviewItems: viewModel.testDetailedReviewItems
            )
        }
        .sheet(isPresented: $showingIntegratedReviewView) {
            TravelChargeReviewContainer(viewModel: reviewViewModel)
        }
    }



    private static let cellDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
            Text("Travel Charge Automation Test")
                .font(.title.bold())
            Text("Select one or more sessions and run the automation. Or search for an address below to test MMM zone lookup.")
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
        }
    }
            
    private var instructionsSection: some View {
            GroupBox(label: Label("Instructions", systemImage: "info.circle")) {
                VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
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
                if viewModel.isLoadingBusinessAddress {
                    HStack(spacing: FormSectionTokens.fieldStackSpacing) {
                        ProgressView()
                        Text("Checking business address...")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    }
                } else if let info = viewModel.businessAddressInfo {
                    if info.hasBusiness {
                        let hasAddress = info.hasAddress
                        VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                            HStack {
                                Image(systemName: hasAddress ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(hasAddress ? .green : .red)
                                    Text(hasAddress ? "Business address is set" : "Business address is missing or empty")
                                    .font(.caption)
                            }
                            if hasAddress {
                                Text("Address: \(info.fullFormattedAddress)")
                                    .font(.caption2)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            } else {
                                Text("Address fields are empty - please set business address in Company settings")
                                    .font(.caption2)
                                    .foregroundColor(ColorSystem.Status.warning)
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(ColorSystem.Status.error)
                            Text("No business entity or address found")
                                .font(.caption)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ColorSystem.Status.error)
                        Text("No business entity or address found")
                            .font(.caption)
                    }
                }
            }
            .padding(.bottom, 8)
    }

    private var addressSearchSection: some View {
            GroupBox(label: Label("Address Search (MapKit)", systemImage: "magnifyingglass")) {
                VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                    SettingsRow(label: "Address Search:", labelWidth: maxLabelWidth) {
                        NativeAddressSearchField(
                            searchText: Binding(
                                get: { viewModel.addressSearchText },
                                set: { viewModel.addressSearchText = $0 }
                            ),
                            selectedAddress: Binding(
                                get: { viewModel.selectedAddress },
                                set: { viewModel.selectedAddress = $0 }
                            ),
                            unitNumber: $unitNumber,
                            streetNumber: $streetNumber,
                            streetName: $streetName,
                            suburb: $suburb,
                            postcode: $postcode,
                            state: $state,
                            country: $country,
                            poBox: $poBox
                        )
                        .accessibilityLabel("Address search")
                        .accessibilityHint("Enter an address to search for MMM zone lookup")
                    }
                    if let address = viewModel.selectedAddress {
                        Text("Selected: \(address.fullAddress)")
                        Button("Run MMM Zone Lookup on Address") {
                            Task {
                                await viewModel.runMMMZoneLookupOnAddress(address)
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .pointerStyle(.link)
                    }
                    if let zone = viewModel.mmmZoneForAddress {
                        Text("MMM Zone: \(zone)").foregroundColor(ColorSystem.Status.info)
                    }
                }
            }
            .padding(.bottom, 8)
    }

    private var sessionListSection: some View {
            List {
                ForEach(viewModel.cachedExpandedSessions, id: \.uniqueInstanceId) { sessionInstance in
                    let session = sessionInstance.session
                    HStack {
                        VStack(alignment: .leading) {
                            Text(session.title).font(.headline)
                            if let client = session.client?.fullName {
                                 Text("Client: \(client)").font(.caption)
                            }
                            // Show specific instance time for recurring sessions
                            if session.recurrenceRuleData != nil {
                                Text("Instance: \(sessionInstance.instanceStart, formatter: Self.cellDateFormatter)").font(.caption2).foregroundColor(ColorSystem.Status.info)
                                Text("End: \(sessionInstance.instanceEnd, formatter: Self.cellDateFormatter)").font(.caption2).foregroundColor(ColorSystem.Status.info)
                            } else {
                                Text("\(sessionInstance.instanceStart, formatter: Self.cellDateFormatter)").font(.caption2)
                            }
                            // Check both location string and linked address entity
                            Group {
                                if let loc = session.location, !loc.isEmpty {
                                    Text(loc).font(.caption2).foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                } else if let address = session.address {
                                    Text(address.fullFormattedAddress).font(.caption2).foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                } else {
                                    Text("No location set").font(.caption2).foregroundColor(ColorSystem.Status.error)
                                }
                            }
                        }
                        Spacer()
                        HStack(spacing: FormSectionTokens.labelFieldSpacing) {
                            // Check if session has any location data
                            if !((session.location != nil && !session.location!.isEmpty) || session.address != nil) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(ColorSystem.Status.warning)
                                    .help("Session has no location set")
                            }
                            if session.recurrenceRuleData != nil {
                                Image(systemName: "repeat.circle.fill")
                                    .foregroundColor(ColorSystem.Status.info)
                                    .help("Recurring session instance")
                            }
                            // Use the unique instance ID for selection
                            if viewModel.selectedSessionInstances.contains(sessionInstance.uniqueInstanceId) {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.toggleSessionSelection(instanceId: sessionInstance.uniqueInstanceId)
                    }
                }
            }
            .frame(maxHeight: 200)
            .listStyle(.plain)
    }

    private var actionButtonsSection: some View {
        VStack(spacing: FormSectionTokens.fieldStackSpacing) {
            HStack(spacing: FormSectionTokens.formGroupSpacing) {
                Button(action: {
                    Task {
                        await viewModel.runAutomation()
                    }
                }) {
                    Label("Run Automation", systemImage: "play.circle")
                }
                .disabled(viewModel.selectedSessionInstances.isEmpty || viewModel.isRunning)
                .buttonStyle(.glassProminent)
                .pointerStyle(.link)

                if let firstInstanceId = viewModel.selectedSessionInstances.first,
                   let matchingInstance = viewModel.cachedExpandedSessions.first(where: { $0.uniqueInstanceId == firstInstanceId }) {
                    Button("Show MMM Zone Lookup") {
                        Task {
                            let sid = matchingInstance.session.session.id
                            if let session = viewModel.getSession(by: sid) {
                                await viewModel.showMMMZone(for: session)
                            }
                        }
                    }
                    .buttonStyle(.glass)
                    .pointerStyle(.link)
                }
                
                // New button to show review results
                if !viewModel.testChargeSummaries.isEmpty || !viewModel.testReviewSummaries.isEmpty {
                    Button("Review Results") {
                        showingReviewSheet = true
                    }
                    .buttonStyle(.glass)
                    .pointerStyle(.link)
                }
                
                // Button to access integrated review system
                Button("Compliance Review") {
                    showingIntegratedReviewView = true
                }
                .buttonStyle(.glass)
                .pointerStyle(.link)
            }

            if viewModel.isRunning {
                ProgressView("Running automation...")
            }
            if let error = viewModel.errorMessage {
                Text(error).foregroundColor(ColorSystem.Status.error)
            }
            if let mmmZone = viewModel.mmmZoneResult {
                Text("MMM Zone: \(mmmZone)").foregroundColor(ColorSystem.Status.info)
            }
        }
    }

    private var resultsSection: some View {
        VStack(spacing: FormSectionTokens.fieldStackSpacing) {
            if !viewModel.testChargeSummaries.isEmpty {
                VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                    HStack {
                        Text("Test Mode: Would Create Travel Charges:")
                            .font(.headline)
                        Spacer()
                        Text("\(viewModel.testChargeSummaries.count) charges")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            .padding(.horizontal, paddingMedium)
                            .padding(.vertical, paddingSmall)
                            .background(Color.blue.opacity(StyleGuide.Opacity.light))
                            .cornerRadius(cornerRadiusXSmall)
                    }
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: FormSectionTokens.sectionStackSpacing) {
                            ForEach(Array(viewModel.testChargeSummaries.enumerated()), id: \.offset) { index, summary in
                                VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                                    Text("Travel Charge #\(index + 1)")
                                        .font(.headline)
                                        .foregroundColor(.accentColor)
                                    
                                    Text(summary)
                                        .font(.caption)
                                        .padding(StyleGuide.Dimensions.paddingMedium)
                                        .background(Color.gray.opacity(StyleGuide.Opacity.light))
                                        .cornerRadius(cornerRadiusSmall)
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
            if !viewModel.testReviewSummaries.isEmpty {
                VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                    HStack {
                        Text("Test Mode: Review Items:")
                            .font(.headline)
                        Spacer()
                        Text("\(viewModel.testReviewSummaries.count) items")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            .padding(.horizontal, paddingMedium)
                            .padding(.vertical, paddingSmall)
                            .background(Color.orange.opacity(StyleGuide.Opacity.light))
                            .cornerRadius(cornerRadiusXSmall)
                    }
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                            ForEach(Array(viewModel.testReviewSummaries.enumerated()), id: \.offset) { index, summary in
                                VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                                    Text("Review Item #\(index + 1)")
                                        .font(.headline)
                                        .foregroundColor(ColorSystem.Status.warning)
                                    
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundColor(ColorSystem.Status.warning)
                                        .padding(StyleGuide.Dimensions.paddingMedium)
                                        .background(Color.orange.opacity(StyleGuide.Opacity.light))
                                        .cornerRadius(cornerRadiusSmall)
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
