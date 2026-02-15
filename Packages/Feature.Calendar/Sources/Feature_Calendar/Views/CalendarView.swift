import SwiftUI
import SwiftData
import Data
import EventKit
import Core
import SharedUI

// Button Styles and Controls moved to SharedComponents/CalendarStylesAndControls.swift

// MARK: - Root calendar shell

struct CalendarView: View {
    @Environment(\.modelContext) private var viewContext
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var eventKitService: EventKitSyncService

    var body: some View {
        CalendarTabView(viewModel: viewModel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .loadingOverlay(isLoading: viewModel.isLoading, message: "Loading calendar...")
        // --- Sheet for editing/creating sessions ---
        .sheet(isPresented: Binding(
            get: { viewModel.selectedSessionInfo != nil },
            set: {
                if !$0 { // When sheet is dismissed
                    viewModel.selectedSessionInfo = nil
                }
            }
        )) {
            if let sessionInfo = viewModel.selectedSessionInfo {
                SessionEditorSheetContainer(
                    unitOfWork: viewModel.unitOfWork,
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
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.selectedSessionInfo != nil)
            }
        }
        // --- Sheet for converting EKEvent ---
        .sheet(isPresented: Binding( 
                   get: { viewModel.eventToConvert != nil },
                   set: { if !$0 { viewModel.eventToConvert = nil } }
               )) {
            if let event = viewModel.eventToConvert {
                EventConversionSheetContainer(
                    unitOfWork: viewModel.unitOfWork,
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
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.eventToConvert != nil)
            } else {
                 Text("Error: Event data missing.") 
            }
        }
        // --- Sheet for travel charges ---
        .sheet(isPresented: $viewModel.isShowingTravelChargeSheet) {
            if let session = viewModel.selectedSessionForTravel,
               let sessionDate = viewModel.selectedInstanceStartDateForTravel {
                
                // Combine and filter the displayable items to get only the non-travel sessions for the specific day
                let allItems = viewModel.allDayItems + viewModel.timedItems
                let daySessions = allItems.filter { item in
                    guard let itemSession = item.underlyingSession, // Use underlyingSession
                          !itemSession.isTravel,
                          itemSession.clientId == session.clientId else {
                        return false
                    }
                    guard let startDate = item.startDate else { return false }
                    return Calendar.current.isDate(startDate, inSameDayAs: sessionDate)
                }

                TravelChargeView(
                    unitOfWork: viewModel.unitOfWork,
                    mainSession: session,
                    daySessions: daySessions,
                    onSave: {
                        viewModel.updateDisplayableItems()
                        viewModel.selectedSessionForTravel = nil
                        viewModel.selectedInstanceStartDateForTravel = nil
                        viewModel.selectedInstanceEndDateForTravel = nil
                    }
                )
            } else {
                Text("Error: Session data missing.")
            }
        }
        .sheet(
            isPresented: $viewModel.showingRecurringModificationDialog,
            onDismiss: { viewModel.pendingRecurringModification = nil }
        ) {
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
        .onChange(of: viewModel.selectedSessionInfo != nil) { _, isPresented in
            guard isPresented else { return }
            viewModel.eventToConvert = nil
            viewModel.isShowingTravelChargeSheet = false
            viewModel.pendingRecurringModification = nil
            viewModel.showingRecurringModificationDialog = false
        }
        .onChange(of: viewModel.eventToConvert != nil) { _, isPresented in
            guard isPresented else { return }
            viewModel.selectedSessionInfo = nil
            viewModel.isShowingTravelChargeSheet = false
            viewModel.pendingRecurringModification = nil
            viewModel.showingRecurringModificationDialog = false
        }
        .onChange(of: viewModel.isShowingTravelChargeSheet) { _, isPresented in
            guard isPresented else { return }
            viewModel.selectedSessionInfo = nil
            viewModel.eventToConvert = nil
            viewModel.pendingRecurringModification = nil
            viewModel.showingRecurringModificationDialog = false
        }
        .onChange(of: viewModel.showingRecurringModificationDialog) { _, isPresented in
            guard isPresented else { return }
            viewModel.selectedSessionInfo = nil
            viewModel.eventToConvert = nil
            viewModel.isShowingTravelChargeSheet = false
        }
    }
}

private struct SessionEditorSheetContainer: View {
    let onDismiss: () -> Void
    let onSave: (RecurringEditMode, NewSessionViewModel) -> Void
    let onDelete: (RecurringEditMode, NewSessionViewModel) -> Void

    @StateObject private var editorViewModel: NewSessionViewModel

    init(
        unitOfWork: UnitOfWorkService,
        sessionInfo: (session: Session?, instanceStart: Date?, instanceEnd: Date?),
        onDismiss: @escaping () -> Void,
        onSave: @escaping (RecurringEditMode, NewSessionViewModel) -> Void,
        onDelete: @escaping (RecurringEditMode, NewSessionViewModel) -> Void
    ) {
        self.onDismiss = onDismiss
        self.onSave = onSave
        self.onDelete = onDelete
        _editorViewModel = StateObject(
            wrappedValue: NewSessionViewModel(
                unitOfWork: unitOfWork,
                session: sessionInfo.session,
                instanceDate: sessionInfo.instanceStart,
                instanceEndDate: sessionInfo.instanceEnd
            )
        )
    }

    var body: some View {
        NativeSessionSheetView(viewModel: editorViewModel, onDismiss: onDismiss)
            .onAppear {
                editorViewModel.onSave = { mode in
                    onSave(mode, editorViewModel)
                }
                editorViewModel.onDelete = { mode in
                    onDelete(mode, editorViewModel)
                }
            }
    }
}

private struct EventConversionSheetContainer: View {
    let onDismiss: () -> Void
    let onSave: (RecurringEditMode, NewSessionViewModel) -> Void
    let onDelete: (RecurringEditMode, NewSessionViewModel) -> Void

    @StateObject private var editorViewModel: NewSessionViewModel

    init(
        unitOfWork: UnitOfWorkService,
        event: EKEvent,
        onDismiss: @escaping () -> Void,
        onSave: @escaping (RecurringEditMode, NewSessionViewModel) -> Void,
        onDelete: @escaping (RecurringEditMode, NewSessionViewModel) -> Void
    ) {
        self.onDismiss = onDismiss
        self.onSave = onSave
        self.onDelete = onDelete
        _editorViewModel = StateObject(
            wrappedValue: NewSessionViewModel(unitOfWork: unitOfWork, from: event)
        )
    }

    var body: some View {
        NativeSessionSheetView(viewModel: editorViewModel, onDismiss: onDismiss)
            .onAppear {
                editorViewModel.onSave = { mode in
                    onSave(mode, editorViewModel)
                }
                editorViewModel.onDelete = { mode in
                    onDelete(mode, editorViewModel)
                }
            }
    }
}

private struct RecurringScopePickerSheet: View {
    let title: String
    let options: [RecurringEditMode]
    let isDestructive: Bool
    let label: (RecurringEditMode) -> String
    let detail: (RecurringEditMode) -> String
    let recommended: RecurringEditMode?
    let onSelect: (RecurringEditMode) -> Void

    @Environment(\.dismiss) private var dismiss
    
    private var orderedOptions: [RecurringEditMode] {
        guard let recommended, options.contains(recommended) else { return options }
        return [recommended] + options.filter { $0 != recommended }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(isDestructive
                         ? "Choose how broadly this delete should apply."
                         : "Choose how broadly these changes should apply.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }

                if orderedOptions.isEmpty {
                    Text("No available actions")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(orderedOptions, id: \.self) { mode in
                        Button(role: isDestructive ? .destructive : nil) {
                            dismiss()
                            // Defer mutation until after sheet dismissal completes.
                            Task { @MainActor in
                                onSelect(mode)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: mode.iconName)
                                    .foregroundColor(isDestructive ? .red : .accentColor)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(label(mode))
                                        if recommended == mode {
                                            Text("Recommended")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Text(detail(mode))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(minWidth: 460, idealWidth: 520, minHeight: 320, idealHeight: 420)
    }
}

struct NewSessionSheetView: View {
    @ObservedObject var viewModel: NewSessionViewModel
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            NewSessionView(viewModel: viewModel)
            
            // Footer with action buttons
            HStack {
                if viewModel.isEditing {
                    Button("Delete", role: .destructive) {
                        viewModel.delete()
                    }
                    .buttonStyle(.glass)
                    .foregroundColor(.red)
                    .accentColor(.red)
                    .disabled(viewModel.isPerformingPersistence)

                }
                
                Spacer()
                
                Button("Cancel") { onDismiss() }
                    .buttonStyle(.glass)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .accentColor(.blue)
                    .disabled(viewModel.isPerformingPersistence)

                
                Button(viewModel.saveButtonTitle) {
                    viewModel.handleSaveButtonTapped()
                }
                .disabled(!viewModel.formIsValid || viewModel.isPerformingPersistence)
                .buttonStyle(.glass)
                .foregroundColor(Color("Text", bundle: .sharedUI))
                .accentColor(.blue)

            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color("Background", bundle: .sharedUI))
        }
        .sheet(isPresented: $viewModel.showingEditModeDialog) {
            RecurringScopePickerSheet(
                title: "Apply Changes",
                options: viewModel.availableSaveModes,
                isDestructive: false,
                label: viewModel.saveScopeTitle(for:)
                ,
                detail: { $0.detailText(isDelete: false) },
                recommended: viewModel.recommendedSaveMode
            ) { mode in
                viewModel.executeSave(with: mode)
            }
        }
        .sheet(isPresented: $viewModel.showingRecurringDeleteOptions) {
            RecurringScopePickerSheet(
                title: "Delete Recurring Session",
                options: viewModel.availableDeleteModes,
                isDestructive: true,
                label: viewModel.deleteScopeTitle(for:)
                ,
                detail: { $0.detailText(isDelete: true) },
                recommended: viewModel.recommendedDeleteMode
            ) { mode in
                viewModel.executeDelete(with: mode)
            }
        }
    }
}

struct NativeSessionSheetView: View {
    @ObservedObject var viewModel: NewSessionViewModel
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            NativeSessionFormView(viewModel: viewModel)
            
            footer
        }
        .onAppear { viewModel.onSaveCompleted = onDismiss }
        .sheet(isPresented: $viewModel.showingEditModeDialog) {
            RecurringScopePickerSheet(
                title: "Apply Changes",
                options: viewModel.availableSaveModes,
                isDestructive: false,
                label: viewModel.saveScopeTitle(for:)
                ,
                detail: { $0.detailText(isDelete: false) },
                recommended: viewModel.recommendedSaveMode
            ) { mode in
                viewModel.executeSave(with: mode)
            }
        }
        .sheet(isPresented: $viewModel.showingRecurringDeleteOptions) {
            RecurringScopePickerSheet(
                title: "Delete Recurring Session",
                options: viewModel.availableDeleteModes,
                isDestructive: true,
                label: viewModel.deleteScopeTitle(for:)
                ,
                detail: { $0.detailText(isDelete: true) },
                recommended: viewModel.recommendedDeleteMode
            ) { mode in
                viewModel.executeDelete(with: mode)
            }
        }
    }
    
    private var footer: some View {
        VStack(spacing: 0) {
            HStack {
                if viewModel.isEditing {
                    Button("Delete", role: .destructive) { viewModel.delete() }
                        .buttonStyle(.glass)
                        .foregroundColor(.red)
                        .disabled(viewModel.isPerformingPersistence)
                }
                Spacer()
                Button("Cancel") { onDismiss() }
                    .buttonStyle(.glass)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .disabled(viewModel.isPerformingPersistence)
                Button(viewModel.saveButtonTitle) { viewModel.handleSaveButtonTapped() }
                    .buttonStyle(.glass)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .disabled(!viewModel.formIsValid || viewModel.isPerformingPersistence)
                    .overlay {
                        if viewModel.isPerformingPersistence {
                            ProgressView().scaleEffect(0.8).foregroundColor(Color("Text", bundle: .sharedUI))
                        }
                    }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color("Background", bundle: .sharedUI))
            
            if let error = viewModel.persistenceError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.persistenceError = nil
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
            } else if viewModel.requiresSaveScopeSelection || viewModel.requiresDeleteScopeSelection {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text("You will choose how changes apply to the recurring series on the next step.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }
}
