import SwiftUI
import SwiftData
import Core
import DataInterfaces
import SharedUI
import WorkspaceUI
import Observation

public struct SettingsContentColumn: View {
    @Bindable private var viewModel: SettingsWorkspaceViewModel

    public init(viewModel: SettingsWorkspaceViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        SettingsView(selectedSection: selectedSectionBinding)
    }

    private var selectedSectionBinding: Binding<SettingsView.SettingsSection?> {
        Binding(
            get: { viewModel.selectedSection },
            set: { newValue in
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.selectedSection = newValue
                }
            }
        )
    }
}

public struct SettingsDetailColumn: View {
    @Bindable private var viewModel: SettingsWorkspaceViewModel
    @Environment(\.modelContext) var modelContext
    @Environment(\.settingsServices) private var settingsServices

    public init(viewModel: SettingsWorkspaceViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if let services = settingsServices {
                if let section = viewModel.selectedSection {
                    settingsDetailView(for: section, services: services)
                        .id("settings-\(section.id)")
                        .environment(\.modelContext, modelContext)
                } else {
                    EmptyStateView(
                        icon: "gearshape.2.fill",
                        title: "Settings",
                        message: "Select a category to view and edit settings."
                    )
                    .id("settings_empty_state")
                }
            } else {
                EmptyStateView(
                    icon: "exclamationmark.triangle.fill",
                    title: "Settings Configuration",
                    message: "Required settings services are not available."
                )
                .id("settings_config_error")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func settingsDetailView(for section: SettingsView.SettingsSection, services: any SettingsServicesProviding) -> some View {
        switch section {
        case .profile:
            ProfileSectionView()
        case .company:
            CompanySectionView()
        case .invoice: InvoiceSettingsView()
        case .ndisBilling: NDISBillingSettingsView()
        case .calendar:
            CalendarSectionView(sessionWiper: services.calendarSessionWiper)
        case .importExport:
            ImportExportSectionView(services: services)
        case .travelChargeTest:
            TravelChargeTestSectionView(automation: services.travelChargeAutomation)
        case .travelChargeReview:
            TravelChargeReviewSectionView(automation: services.travelChargeAutomation)
        case .systemHealth: SystemHealthView()
        }
    }
}

private struct ProfileSectionView: View {
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        ProfileView(viewModel: viewModel)
    }
}

private struct CompanySectionView: View {
    @Environment(\.businessPersisting) private var businessPersisting
    @Environment(\.geocodingService) private var geocodingService

    var body: some View {
        SettingsServiceGate(
            isAvailable: businessPersisting != nil && geocodingService != nil,
            icon: "building.2.crop.circle",
            title: "Company settings unavailable",
            message: "Business persistence or geocoding is not configured for this window."
        ) {
            if let persistence = businessPersisting, let geo = geocodingService {
                CompanySectionLoaded(businessPersisting: persistence, geocodingService: geo)
            }
        }
    }
}

private struct CompanySectionLoaded: View {
    @State private var viewModel: CompanyViewModel

    init(businessPersisting: any BusinessPersisting, geocodingService: any Core.GeocodingServiceProtocol) {
        _viewModel = State(initialValue: CompanyViewModel(
            businessPersisting: businessPersisting,
            geocodingService: geocodingService
        ))
    }

    var body: some View {
        CompanyView(viewModel: viewModel)
    }
}

private struct CalendarSectionView: View {
    @Environment(\.calendarPreferencesStore) private var calendarPreferencesStore
    @Environment(\.eventKitSyncService) private var eventKitSyncService

    let sessionWiper: any CalendarSessionWiping

    var body: some View {
        SettingsServiceGate(
            isAvailable: calendarPreferencesStore != nil && eventKitSyncService != nil,
            icon: "calendar.badge.exclamationmark",
            title: "Calendar services unavailable",
            message: "Calendar preferences or EventKit sync is not configured for this window."
        ) {
            if let store = calendarPreferencesStore, let eventKit = eventKitSyncService {
                CalendarSectionLoaded(
                    preferencesStore: store,
                    eventKitService: eventKit,
                    sessionWiper: sessionWiper
                )
            }
        }
    }
}

private struct CalendarSectionLoaded: View {
    @State private var viewModel: CalendarSettingsViewModel

    init(
        preferencesStore: CalendarPreferencesStore,
        eventKitService: any CalendarIntegrationService,
        sessionWiper: any CalendarSessionWiping
    ) {
        _viewModel = State(initialValue: CalendarSettingsViewModel(
            preferencesStore: preferencesStore,
            eventKitService: eventKitService,
            sessionWiper: sessionWiper
        ))
    }

    var body: some View {
        CalendarSettingsView(viewModel: viewModel)
    }
}

private struct ImportExportSectionView: View {
    @State private var viewModel: ImportExportViewModel

    init(services: any SettingsServicesProviding) {
        _viewModel = State(initialValue: ImportExportViewModel(
            claimPersistence: services.importExportClaimPersistence,
            importExportCoordinator: services.importExportCoordinator,
            bulkClaimExportHashVerifier: services.bulkClaimExportHashVerifier
        ))
    }

    var body: some View {
        ImportExportView(viewModel: viewModel)
    }
}

private struct TravelChargeTestSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.geocodingService) private var geocodingService
    @Environment(\.mmmZoneLookup) private var mmmZoneLookup
    @Environment(\.recurrenceRuleManager) private var recurrenceRuleManager
    @Environment(\.travelChargeReviewFetching) private var travelChargeReviewFetching

    let automation: any TravelChargeAutomating

    var body: some View {
        SettingsServiceGate(
            isAvailable: geocodingService != nil
                && mmmZoneLookup != nil
                && recurrenceRuleManager != nil
                && travelChargeReviewFetching != nil,
            icon: "road.lanes",
            title: "Travel automation prerequisites missing",
            message: "Geocoding, MMM lookup, recurrence, or review fetching is not configured for this window."
        ) {
            if let geo = geocodingService,
               let mmm = mmmZoneLookup,
               let recurrence = recurrenceRuleManager,
               let reviewFetching = travelChargeReviewFetching {
                TravelChargeTestSectionLoaded(
                    modelContext: modelContext,
                    automation: automation,
                    geocodingService: geo,
                    mmmZoneLookup: mmm,
                    recurrenceRuleManager: recurrence,
                    reviewFetching: reviewFetching
                )
            }
        }
    }
}

private struct TravelChargeTestSectionLoaded: View {
    @State private var automationViewModel: TravelChargeAutomationViewModel
    @State private var reviewViewModel: TravelChargeReviewViewModel

    init(
        modelContext: ModelContext,
        automation: any TravelChargeAutomating,
        geocodingService: any Core.GeocodingServiceProtocol,
        mmmZoneLookup: any Core.MMMZoneLookupProtocol,
        recurrenceRuleManager: RecurrenceRuleManager,
        reviewFetching: any TravelChargeReviewFetching
    ) {
        _automationViewModel = State(initialValue: TravelChargeAutomationViewModel(
            modelContext: modelContext,
            automationActor: automation,
            geocodingService: geocodingService,
            mmmZoneLookup: mmmZoneLookup,
            recurrenceRuleManager: recurrenceRuleManager
        ))
        _reviewViewModel = State(initialValue: TravelChargeReviewViewModel(
            automationActor: automation,
            mmmZoneLookup: mmmZoneLookup,
            recurrenceRuleManager: recurrenceRuleManager,
            reviewFetching: reviewFetching
        ))
    }

    var body: some View {
        TravelChargeAutomationTestView(
            viewModel: automationViewModel,
            reviewViewModel: reviewViewModel
        )
    }
}

private struct TravelChargeReviewSectionView: View {
    @Environment(\.travelChargeReviewFetching) private var travelChargeReviewFetching
    @Environment(\.mmmZoneLookup) private var mmmZoneLookup
    @Environment(\.recurrenceRuleManager) private var recurrenceRuleManager

    let automation: any TravelChargeAutomating

    var body: some View {
        SettingsServiceGate(
            isAvailable: travelChargeReviewFetching != nil
                && mmmZoneLookup != nil
                && recurrenceRuleManager != nil,
            icon: "road.lanes",
            title: "Travel review prerequisites missing",
            message: "Review fetching, MMM lookup, or recurrence services are not configured for this window."
        ) {
            if let reviewFetching = travelChargeReviewFetching,
               let mmm = mmmZoneLookup,
               let recurrence = recurrenceRuleManager {
                TravelChargeReviewSectionLoaded(
                    automation: automation,
                    mmmZoneLookup: mmm,
                    recurrenceRuleManager: recurrence,
                    reviewFetching: reviewFetching
                )
            }
        }
    }
}

private struct TravelChargeReviewSectionLoaded: View {
    @State private var viewModel: TravelChargeReviewViewModel

    init(
        automation: any TravelChargeAutomating,
        mmmZoneLookup: any Core.MMMZoneLookupProtocol,
        recurrenceRuleManager: RecurrenceRuleManager,
        reviewFetching: any TravelChargeReviewFetching
    ) {
        _viewModel = State(initialValue: TravelChargeReviewViewModel(
            automationActor: automation,
            mmmZoneLookup: mmmZoneLookup,
            recurrenceRuleManager: recurrenceRuleManager,
            reviewFetching: reviewFetching
        ))
    }

    var body: some View {
        TravelChargeReviewView(viewModel: viewModel)
    }
}
