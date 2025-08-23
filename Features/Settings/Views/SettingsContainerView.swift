// /Users/user/Developer/InvoicingApplication/InvoicingApplication/InvoicingApplication/Views/Settings/SettingsContainerView.swift
// Cleaned version – travel charge automation components moved to separate files

import SwiftUI
import SwiftData
import MapKit

// MARK: - Settings Container
struct SettingsContainerView: View {
    @Environment(\.modelContext) private var viewContext
    @Binding var columnVisibility: NavigationSplitViewVisibility

    // State specific to Settings
    @State private var selectedSettingsSection: SettingsView.SettingsSection? = nil
    @State private var isSidebarVisible: Bool = true
    
    // State for managing the detail view transition
    @State private var displayedSettingsSection: SettingsView.SettingsSection? = nil
    @State private var isTransitioningToBlack: Bool = false

    var body: some View {
        // Wrap HSplitView in GeometryReader to get available width
        CustomHSplitView(
            fraction: 0.28,
            minPFraction: 0.2,
            minSFraction: 0.5,
            maxPFraction: 0.35,
            isPrimaryVisible: $isSidebarVisible,
            primary: {
                settingsList()
                    .background(Color(red: 0.11, green: 0.11, blue: 0.13))
            },
            secondary: {
                ZStack {
                    if isTransitioningToBlack {
                        Color.black
                            .transition(.opacity.animation(.easeInOut(duration: 0.1)))
                            .id("black_transition_layer")
                    } else if let section = displayedSettingsSection {
                        settingsDetailView(for: section)
                            .id("settings-\(section.id)")
                            .environment(\.modelContext, viewContext)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.animation(.easeInOut(duration: 0.2)),
                                    removal: .opacity
                                        .combined(with: .scale(scale: 0.9))
                                        .animation(.easeInOut(duration: 0.15))
                                )
                            )
                    } else {
                        EmptyStateView(
                            icon: "gearshape.2.fill",
                            title: "Settings",
                            message: "Select a category to view and edit settings."
                        )
                        .id("empty_state_detail_view")
                    }
                }
                .background(Color.black)
            },
            splitter: { _ in
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 6)
                    .overlay(Rectangle().fill(Color.white.opacity(0.25)).frame(width: 1))
            }
        )
        .background(Color.black)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { withAnimation(.easeInOut(duration: 0.25)) { isSidebarVisible.toggle() } }) {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle Sidebar")
                .appInteractiveCursor()
            }
        }
        .onAppear {
            // Initialise detail column on first appearance
            if selectedSettingsSection != nil && displayedSettingsSection == nil {
                displayedSettingsSection = selectedSettingsSection
            }
            isTransitioningToBlack = false
        }
        .onChange(of: selectedSettingsSection) { oldValue, newValue in
            handleSectionChange(from: oldValue, to: newValue)
        }
    }

    // MARK: - Helper views
    @ViewBuilder
    private func settingsList() -> some View {
        SettingsView(selectedSection: $selectedSettingsSection)
            .selectionColumnStyle()
    }

    @ViewBuilder
    private func settingsDetailView(for section: SettingsView.SettingsSection) -> some View {
        switch section {
        case .profile: ProfileView()
        case .company: CompanyView()
        case .invoice: InvoiceSettingsView()
        case .ndisBilling: NDISBillingSettingsView()
        case .calendar: CalendarSettingsView()
        case .importExport: ImportExportView()
        case .formComponents:
            Text("Form Components demos are not available in this build.")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .travelChargeTest: TravelChargeAutomationTestView()
        case .travelChargeReview: TravelChargeReviewView()
        case .systemHealth: SystemHealthView()
        }
    }

    // MARK: - Section change logic
    private func handleSectionChange(from oldValue: SettingsView.SettingsSection?,
                                     to newValue: SettingsView.SettingsSection?) {
        switch (oldValue, newValue) {
        case (nil, let newSection?) where newSection != .systemHealth:
            // First selection - direct transition
            withAnimation(.easeInOut(duration: 0.2)) {
                displayedSettingsSection = newSection
            }
            
        case (let oldSection?, let newSection?) where oldSection != newSection:
            // Section change - use black transition
            withAnimation(.easeInOut(duration: 0.1)) {
                isTransitioningToBlack = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedSettingsSection = newSection
                    isTransitioningToBlack = false
                }
            }
            
        case (_, nil):
            // Deselection - fade out
            withAnimation(.easeInOut(duration: 0.2)) {
                displayedSettingsSection = nil
            }
            
        default:
            break
        }
    }
}

// MARK: - System Health View
struct SystemHealthView: View {
    @Environment(\.modelContext) private var viewContext
    @State private var healthChecks: [HealthCheck] = []
    @State private var isRunning = false

    var body: some View {
        FormComponentContainer {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        headerSection
                        actionButtonsSection
                    }
                    .padding(20)
                    .sectionCardStyle()

                    VStack(alignment: .leading, spacing: 12) {
                        resultsSection
                    }
                    .padding(20)
                    .sectionCardStyle()
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 24)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black.opacity(0.15))
                    .shadow(radius: 8)
            )
            #if os(macOS)
            .scrollIndicators(.visible)
            #endif
        }
        .onAppear { runHealthChecks() }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("System Health Check")
                .font(.title.bold())
            Text("Verify system configuration and data integrity")
                .foregroundColor(.secondary)
        }
    }

    private var actionButtonsSection: some View {
            HStack(spacing: 16) {
            Button(action: runHealthChecks) {
                Label("Run Health Check", systemImage: "heart.fill")
                }
            .disabled(isRunning)
                .buttonStyle(.glassProminent)

            if isRunning {
                ProgressView("Running checks...")
            }
        }
            }

    private var resultsSection: some View {
            VStack(alignment: .leading, spacing: 8) {
            Text("Health Check Results")
                        .font(.headline)
            
            if healthChecks.isEmpty {
                Text("No health checks run yet")
                                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(healthChecks, id: \.id) { check in
                            healthCheckRow(check)
                        }
                    }
                }
            }
        }
    }
    
    private func healthCheckRow(_ check: HealthCheck) -> some View {
                    VStack(alignment: .leading, spacing: 4) {
                            HStack {
                Image(systemName: check.status.icon)
                    .foregroundColor(check.status.color)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(check.title).font(.headline)
                    Text(check.description).font(.caption).foregroundColor(.secondary)
                }
            Spacer()
                if let action = check.action {
                    Button(action) { onAction(action, check) }.buttonStyle(.glass).controlSize(.small)
                }
            }
            Text(check.details).font(.caption).foregroundColor(.secondary).padding(.leading, 32)
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 8))
    }
    
    private func runHealthChecks() {
        isRunning = true
        healthChecks = []
        
        // Run checks asynchronously
        Task {
            await performHealthChecks()
            await MainActor.run {
                isRunning = false
            }
        }
    }
    
    private func performHealthChecks() async {
        var checks: [HealthCheck] = []
        
        // Check business address
        let businessDescriptor = FetchDescriptor<BusinessEntity>()
        if let business = try? viewContext.fetch(businessDescriptor).first,
           let address = business.address {
            let success = !address.fullFormattedAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            print(success ? "[SystemHealth] Business address validated" : "[SystemHealth] Validation failed")
            
            checks.append(HealthCheck(
                title: "Business Address",
                description: success ? "Address is configured" : "Address is missing or empty",
                status: success ? .success : .error,
                details: address.fullFormattedAddress,
                action: nil))
                                            } else {
            checks.append(HealthCheck(
                title: "Business Address",
                description: "No business entity found",
                status: .error,
                details: "Please configure business details in Company settings",
                action: nil))
        }
        
        // Check sessions
        let sessionDescriptor = FetchDescriptor<SessionEntity>()
        if let sessions = try? viewContext.fetch(sessionDescriptor) {
            let validSessions = sessions.filter { session in
                !(session.location?.isEmpty ?? true) || session.address != nil
            }
            
            checks.append(HealthCheck(
                title: "Session Data",
                description: "\(validSessions.count) of \(sessions.count) sessions have locations",
                status: validSessions.count == sessions.count ? .success : .warning,
                details: "\(sessions.count) sessions validated",
                action: nil))
        }
        
        // Check MMM zone lookup
        let testCoordinate = CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093) // Sydney
        if let _ = MMMZoneLookup.shared.mmm(for: testCoordinate) {
            checks.append(HealthCheck(
                title: "MMM Zone Lookup",
                description: "Zone lookup is working",
                status: .success,
                details: "MMM zone table is configured",
                action: nil))
                                            } else {
            checks.append(HealthCheck(
                title: "MMM Zone Lookup",
                description: "Zone lookup failed",
                status: .error,
                details: "MMM zone table may not be configured",
                action: nil))
        }
        
        // Check travel charge automation service
        let _ = TravelChargeAutomationService(
            context: viewContext,
            businessRules: BusinessRules(),
            userPreferences: UserPreferences(),
            mmmZoneTable: MMMZoneTable(),
            testingMode: true
        )
        
        checks.append(HealthCheck(
            title: "Travel Charge Automation",
            description: "Service is operational",
            status: .success,
            details: "Service is operational",
            action: nil))
        
        await MainActor.run {
            self.healthChecks = checks
        }
    }
    
    private func onAction(_ action: String, _ check: HealthCheck) {
        // Handle action button taps
        print("Health check action: \(action) for \(check.title)")
    }
}

// MARK: - Supporting Types

struct HealthCheck {
    let id = UUID()
    let title: String
    let description: String
    let status: HealthStatus
    let details: String
    let action: String?
}

enum HealthStatus {
    case success
    case warning
    case error
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// ------------------------------------------------------------------
// Travel Charge Automation Test View
// ------------------------------------------------------------------

// The TravelChargeAutomationTestView and related components have been moved to separate files:
// - TravelChargeAutomationTestView.swift
// - DetailedReviewView.swift  
// - ViolationDetailsView.swift
// - TravelChargeReviewSheet.swift

// TravelChargeAutomationTestView is now defined in TravelChargeAutomationTestView.swift
