import SwiftUI
import SwiftData
import Core
import Data
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
    private func settingsDetailView(for section: SettingsView.SettingsSection, services: SettingsServices) -> some View {
        switch section {
        case .profile:
            ProfileSectionView()
        case .company:
            CompanySectionView()
        case .invoice: InvoiceSettingsView()
        case .ndisBilling: NDISBillingSettingsView()
        case .calendar:
            CalendarSectionView()
        case .importExport:
            ImportExportSectionView(
                modelContext: modelContext,
                importExportCoordinator: services.importExportCoordinator
            )
        case .travelChargeTest:
            TravelChargeTestSectionView(
                automationActor: services.travelChargeAutomationActor
            )
        case .travelChargeReview:
            TravelChargeReviewSectionView(
                automationActor: services.travelChargeAutomationActor
            )
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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.geocodingService) private var geocodingService

    var body: some View {
        if let geo = geocodingService {
            CompanySectionLoaded(modelContext: modelContext, geocodingService: geo)
        } else {
            EmptyStateView(
                icon: "mappin.slash",
                title: "Geocoding unavailable",
                message: "The geocoding service is not configured for this window."
            )
        }
    }
}

private struct CompanySectionLoaded: View {
    @State private var viewModel: CompanyViewModel

    init(modelContext: ModelContext, geocodingService: any Core.GeocodingServiceProtocol) {
        _viewModel = State(initialValue: CompanyViewModel(
            modelContext: modelContext,
            geocodingService: geocodingService
        ))
    }

    var body: some View {
        CompanyView(viewModel: viewModel)
    }
}

private struct CalendarSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendarPreferencesStore) private var calendarPreferencesStore
    @Environment(\.eventKitSyncService) private var eventKitSyncService

    var body: some View {
        if let store = calendarPreferencesStore, let eventKit = eventKitSyncService {
            CalendarSectionLoaded(
                modelContext: modelContext,
                preferencesStore: store,
                eventKitService: eventKit
            )
        } else {
            EmptyStateView(
                icon: "calendar.badge.exclamationmark",
                title: "Calendar services unavailable",
                message: "Calendar preferences or EventKit sync is not configured for this window."
            )
        }
    }
}

private struct CalendarSectionLoaded: View {
    @State private var viewModel: CalendarSettingsViewModel

    init(
        modelContext: ModelContext,
        preferencesStore: CalendarPreferencesStore,
        eventKitService: EventKitSyncService
    ) {
        _viewModel = State(initialValue: CalendarSettingsViewModel(
            modelContext: modelContext,
            preferencesStore: preferencesStore,
            eventKitService: eventKitService
        ))
    }

    var body: some View {
        CalendarSettingsView(viewModel: viewModel)
    }
}

private struct ImportExportSectionView: View {
    @State private var viewModel: ImportExportViewModel

    init(
        modelContext: ModelContext,
        importExportCoordinator: ImportExportCoordinator
    ) {
        _viewModel = State(initialValue: ImportExportViewModel(
            modelContext: modelContext,
            importExportCoordinator: importExportCoordinator
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

    let automationActor: TravelChargeAutomationActor

    var body: some View {
        if let geo = geocodingService, let mmm = mmmZoneLookup, let recurrence = recurrenceRuleManager {
            TravelChargeTestSectionLoaded(
                modelContext: modelContext,
                automationActor: automationActor,
                geocodingService: geo,
                mmmZoneLookup: mmm,
                recurrenceRuleManager: recurrence
            )
        } else {
            EmptyStateView(
                icon: "road.lanes",
                title: "Travel automation prerequisites missing",
                message: "Geocoding, MMM lookup, or recurrence services are not configured for this window."
            )
        }
    }
}

private struct TravelChargeTestSectionLoaded: View {
    @State private var automationViewModel: TravelChargeAutomationViewModel
    @State private var reviewViewModel: TravelChargeReviewViewModel

    init(
        modelContext: ModelContext,
        automationActor: TravelChargeAutomationActor,
        geocodingService: any Core.GeocodingServiceProtocol,
        mmmZoneLookup: any Core.MMMZoneLookupProtocol,
        recurrenceRuleManager: RecurrenceRuleManager
    ) {
        _automationViewModel = State(initialValue: TravelChargeAutomationViewModel(
            modelContext: modelContext,
            automationActor: automationActor,
            geocodingService: geocodingService,
            mmmZoneLookup: mmmZoneLookup,
            recurrenceRuleManager: recurrenceRuleManager
        ))
        _reviewViewModel = State(initialValue: TravelChargeReviewViewModel(
            automationActor: automationActor,
            mmmZoneLookup: mmmZoneLookup,
            recurrenceRuleManager: recurrenceRuleManager,
            modelContext: modelContext,
            modelContainer: modelContext.container
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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.mmmZoneLookup) private var mmmZoneLookup
    @Environment(\.recurrenceRuleManager) private var recurrenceRuleManager

    let automationActor: TravelChargeAutomationActor

    var body: some View {
        if let mmm = mmmZoneLookup, let recurrence = recurrenceRuleManager {
            TravelChargeReviewSectionLoaded(
                modelContext: modelContext,
                automationActor: automationActor,
                mmmZoneLookup: mmm,
                recurrenceRuleManager: recurrence
            )
        } else {
            EmptyStateView(
                icon: "road.lanes",
                title: "Travel review prerequisites missing",
                message: "MMM lookup or recurrence services are not configured for this window."
            )
        }
    }
}

private struct TravelChargeReviewSectionLoaded: View {
    @State private var viewModel: TravelChargeReviewViewModel

    init(
        modelContext: ModelContext,
        automationActor: TravelChargeAutomationActor,
        mmmZoneLookup: any Core.MMMZoneLookupProtocol,
        recurrenceRuleManager: RecurrenceRuleManager
    ) {
        _viewModel = State(initialValue: TravelChargeReviewViewModel(
            automationActor: automationActor,
            mmmZoneLookup: mmmZoneLookup,
            recurrenceRuleManager: recurrenceRuleManager,
            modelContext: modelContext,
            modelContainer: modelContext.container
        ))
    }

    var body: some View {
        TravelChargeReviewView(viewModel: viewModel)
    }
}
