import SwiftUI
import SwiftData
import Data
import SharedUI

public struct SettingsContentColumn: View {
    @ObservedObject private var viewModel: SettingsWorkspaceViewModel

    public init(viewModel: SettingsWorkspaceViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        SettingsView(selectedSection: selectedSectionBinding)
            .frame(minWidth: 250)
            .background(Color("Background", bundle: .sharedUI))
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
    @ObservedObject private var viewModel: SettingsWorkspaceViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var previousSelection: SettingsView.SettingsSection? = nil

    public init(viewModel: SettingsWorkspaceViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ZStack {
            if viewModel.isTransitioning {
                Color("Background", bundle: .sharedUI)
                    .fluidTransition()
                    .id("settings_transition")
            } else if let section = viewModel.displayedSection {
                settingsDetailView(for: section)
                    .id("settings-\(section.id)")
                    .environment(\.modelContext, modelContext)
                    .fluidDetailTransition()
            } else {
                EmptyStateView(
                    icon: "gearshape.2.fill",
                    title: "Settings",
                    message: "Select a category to view and edit settings."
                )
                .id("settings_empty_state")
            }
        }
        .background(Color("Background", bundle: .sharedUI))
        .onAppear(perform: applyInitialSelection)
        .onChange(of: viewModel.selectedSection) { newValue in
            handleSectionChange(from: previousSelection, to: newValue)
            previousSelection = newValue
        }
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
        case .travelChargeTest: TravelChargeAutomationTestView()
        case .travelChargeReview: TravelChargeReviewView()
        case .systemHealth: SystemHealthView()
        }
    }

    private func applyInitialSelection() {
        if viewModel.displayedSection == nil, let section = viewModel.selectedSection {
            viewModel.displayedSection = section
            previousSelection = section
        }
    }

    private func handleSectionChange(from oldValue: SettingsView.SettingsSection?, to newValue: SettingsView.SettingsSection?) {
        switch (oldValue, newValue) {
        case (nil, let newSection?) where newSection != .systemHealth:
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.displayedSection = newSection
            }

        case (let oldSection?, let newSection?) where oldSection != newSection:
            withAnimation(.easeInOut(duration: 0.1)) { viewModel.isTransitioning = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.displayedSection = newSection
                    viewModel.isTransitioning = false
                }
            }

        case (_, nil):
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.displayedSection = nil
            }

        default:
            break
        }
    }
}
