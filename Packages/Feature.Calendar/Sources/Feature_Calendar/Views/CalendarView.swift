import SwiftUI
import SwiftData
import EventKit
import Core
import Data
import SharedUI
import WorkspaceUI
import Observation

// Button Styles and Controls moved to SharedComponents/CalendarStylesAndControls.swift

// MARK: - Root calendar shell

struct CalendarView: View {
    @Bindable var viewModel: CalendarViewModel
    @Environment(\.geocodingService) private var geocodingService
    init(viewModel: CalendarViewModel, queryRange: (start: Date, end: Date)) {
        self._viewModel = Bindable(viewModel)
    }

    private struct FilterTaskID: Equatable {
        let viewStart: Date
        let viewEnd: Date
        let filterStatuses: Set<String>
        let clientFilterIDs: Set<UUID>
        let showCancelled: Bool
        let searchText: String
        let dataRevision: Int
    }

    private var filterTaskID: FilterTaskID {
        let (start, end) = viewModel.currentViewDateRange
        return FilterTaskID(
            viewStart: start,
            viewEnd: end,
            filterStatuses: viewModel.filterStatuses,
            clientFilterIDs: viewModel.selectedClientFilterIDs,
            showCancelled: viewModel.showCancelledSessions,
            searchText: viewModel.searchText,
            dataRevision: viewModel.dataRevision
        )
    }

    private enum ActivePresentation: String, Identifiable {
        case sessionEditor
        case eventConversion
        case travelCharge
        case recurringModification

        var id: String { rawValue }
    }

    private var activePresentation: Binding<ActivePresentation?> {
        Binding(
            get: {
                if viewModel.selectedSessionInfo != nil { return .sessionEditor }
                if viewModel.eventToConvert != nil { return .eventConversion }
                if viewModel.isShowingTravelChargeSheet { return .travelCharge }
                if viewModel.showingRecurringModificationDialog { return .recurringModification }
                return nil
            },
            set: { newValue in
                guard newValue == nil else { return }
                viewModel.selectedSessionInfo = nil
                viewModel.eventToConvert = nil
                viewModel.isShowingTravelChargeSheet = false
                viewModel.pendingRecurringModification = nil
                viewModel.showingRecurringModificationDialog = false
            }
        )
    }

    private var operationErrorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.operationErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.operationErrorMessage = nil
                }
            }
        )
    }

    var body: some View {
        CalendarTabView(viewModel: viewModel)
            .task(id: filterTaskID) {
                viewModel.updateDisplayableItems()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .loadingOverlay(isLoading: viewModel.isLoading, message: "Loading calendar...")
            .sheet(item: activePresentation) { presentation in
                switch presentation {
                case .sessionEditor:
                    if let sessionInfo = viewModel.selectedSessionInfo {
                        SessionEditorSheetContainer(
                            viewModel: viewModel,
                            sessionInfo: sessionInfo,
                            onDismiss: { viewModel.selectedSessionInfo = nil },
                            onSave: { editMode, editorViewModel in
                                viewModel.handleSaveFromEditor(with: editMode, viewModel: editorViewModel)
                            },
                            onDelete: { mode, editorViewModel in
                                viewModel.handleDeleteFromEditor(with: mode, viewModel: editorViewModel)
                            }
                        )
                        .fluidSheetTransition()
                    } else {
                        Text("Error: Session data missing.")
                    }
                case .eventConversion:
                    if let event = viewModel.eventToConvert {
                        EventConversionSheetContainer(
                            viewModel: viewModel,
                            event: event,
                            onDismiss: { viewModel.eventToConvert = nil },
                            onSave: { editMode, editorViewModel in
                                viewModel.handleSaveFromEditor(with: editMode, viewModel: editorViewModel)
                            },
                            onDelete: { mode, editorViewModel in
                                viewModel.handleDeleteFromEditor(with: mode, viewModel: editorViewModel)
                            }
                        )
                        .fluidSheetTransition()
                    } else {
                        Text("Error: Event data missing.")
                    }
                case .travelCharge:
                    if let session = viewModel.selectedSessionForTravel,
                       let sessionDate = viewModel.selectedInstanceStartDateForTravel,
                       let geo = geocodingService {
                        let allItems = viewModel.allDayItems + viewModel.timedItems
                        let daySessions = allItems.filter { item in
                            guard let itemSession = item.underlyingSession,
                                  !itemSession.isTravel,
                                  itemSession.clientId == session.clientId else {
                                return false
                            }
                            guard let startDate = item.startDate else { return false }
                            return Calendar.current.isDate(startDate, inSameDayAs: sessionDate)
                        }

                        TravelChargeView(
                            viewModel: viewModel.makeTravelChargeViewModel(
                                mainSession: session,
                                daySessions: daySessions,
                                geocodingService: geo,
                                onSave: {
                                    viewModel.updateDisplayableItems()
                                    viewModel.selectedSessionForTravel = nil
                                    viewModel.selectedInstanceStartDateForTravel = nil
                                    viewModel.selectedInstanceEndDateForTravel = nil
                                }
                            )
                        )
                    } else if geocodingService == nil {
                        Text("Geocoding service is not available.")
                    } else {
                        Text("Error: Session data missing.")
                    }
                case .recurringModification:
                    RecurringScopePickerSheet(
                        title: "Apply Recurring Change",
                        options: viewModel.recurringModificationModes,
                        isDestructive: false,
                        label: { $0.title },
                        detail: { $0.detailText(isDelete: false) },
                        recommended: viewModel.recommendedRecurringModificationMode
                    ) { mode in
                        viewModel.executeRecurringModification(with: mode)
                    }
                }
            }
            .alert("Calendar Action Failed", isPresented: operationErrorIsPresented) {
                Button("OK", role: .cancel) {
                    viewModel.operationErrorMessage = nil
                }
            } message: {
                Text(viewModel.operationErrorMessage ?? "")
            }
    }
}
