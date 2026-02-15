import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import Data
import Core
import SharedUI

struct TravelChargeAutomationTestView: View {
    @StateObject var viewModel: TravelChargeAutomationViewModel
    
    // New state for review sheet
    @State private var showingReviewSheet = false
    @State private var showingIntegratedReviewView = false
    
    private var maxLabelWidth: CGFloat {
        let labels = ["Address Search:"]
        return labels.map { $0.width() }.max() ?? 120
    }

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
            Task {
                await viewModel.refreshSessions()
                await viewModel.loadBusinessAddressInfo()
            }
        }
        .sheet(isPresented: $showingReviewSheet) {
            TravelChargeReviewSheet(
                chargeSummaries: viewModel.testChargeSummaries,
                reviewSummaries: viewModel.testReviewSummaries,
                detailedReviewItems: viewModel.testDetailedReviewItems,
                reviewService: viewModel.automationService
            )
        }
        .sheet(isPresented: $showingIntegratedReviewView) {
            TravelChargeReviewView(viewModel: TravelChargeReviewViewModel(unitOfWork: viewModel.unitOfWork))
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
                if viewModel.isLoadingBusinessAddress {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Checking business address...")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    }
                } else if let info = viewModel.businessAddressInfo {
                    if info.hasBusiness {
                        let hasAddress = info.hasAddress
                        VStack(alignment: .leading, spacing: 4) {
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
                        TextField("Enter address to search", text: $viewModel.addressSearchText)
                            .textFieldStyle(.roundedBorder)
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
                        Text("MMM Zone: \(zone)").foregroundColor(.blue)
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
        VStack(spacing: 8) {
            HStack(spacing: 16) {
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
                   let matchingInstance = viewModel.cachedExpandedSessions.first(where: { sessionInstance in
                       return sessionInstance.uniqueInstanceId == firstInstanceId
                   }) {
                    Button("Show MMM Zone Lookup") {
                        Task {
                            await viewModel.showMMMZone(for: matchingInstance.session)
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
                Text(error).foregroundColor(.red)
            }
            if let mmmZone = viewModel.mmmZoneResult {
                Text("MMM Zone: \(mmmZone)").foregroundColor(.blue)
            }
        }
    }

    private var resultsSection: some View {
        VStack(spacing: 8) {
            if !viewModel.testChargeSummaries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Test Mode: Would Create Travel Charges:")
                            .font(.headline)
                        Spacer()
                        Text("\(viewModel.testChargeSummaries.count) charges")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                            .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                            .background(Color.blue.opacity(StyleGuide.Opacity.light))
                            .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                    }
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(viewModel.testChargeSummaries.enumerated()), id: \.offset) { index, summary in
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
            if !viewModel.testReviewSummaries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Test Mode: Review Items:")
                            .font(.headline)
                        Spacer()
                        Text("\(viewModel.testReviewSummaries.count) items")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                            .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                            .background(Color.orange.opacity(StyleGuide.Opacity.light))
                            .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                    }
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(viewModel.testReviewSummaries.enumerated()), id: \.offset) { index, summary in
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
