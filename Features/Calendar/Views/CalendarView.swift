import SwiftUI

import EventKit

// Button Styles and Controls moved to SharedComponents/CalendarStylesAndControls.swift

// MARK: - Root calendar shell

struct CalendarView: View {
    @Environment(\.modelContext) private var viewContext
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var eventKitService: EventKitSyncService
    @Binding var showInspector: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {            
            switch viewModel.calendarViewType {
            case .week:
                WeekView(viewModel: viewModel, showInspector: $showInspector)
            case .month:
                MonthView(viewModel: viewModel, showInspector: $showInspector)
            case .agenda:
                AgendaView(viewModel: viewModel, showInspector: $showInspector)
            case .timeline:
                TimelineView(viewModel: viewModel, showInspector: $showInspector)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // --- Sheet for editing/creating sessions ---
        .sheet(isPresented: Binding(
            get: { viewModel.isShowingNewSessionSheet },
            set: {
                viewModel.isShowingNewSessionSheet = $0
                if !$0 { // When sheet is dismissed
                    viewModel.selectedSessionInfo = nil
                }
            }
        )) {
            if let sessionInfo = viewModel.selectedSessionInfo {
                let newSessionViewModel = NewSessionViewModel(
                    context: viewContext,
                    session: sessionInfo.session,
                    instanceDate: sessionInfo.instanceStart
                )
                
                NativeSessionSheetView(viewModel: newSessionViewModel, onDismiss: { viewModel.isShowingNewSessionSheet = false })
            .environment(\.modelContext, viewContext)
                    .onAppear {
                        newSessionViewModel.onSave = { editMode in
                            viewModel.handleSaveFromEditor(
                                with: editMode,
                                viewModel: newSessionViewModel
                            )
                        }
                    }
            }
        }
        // --- Keep onChange for session selection ---
        .onChange(of: viewModel.selectedSessionEquatableID) { _, newID in
            if newID != nil {
                viewModel.isShowingNewSessionSheet = true
            }
        }
        // --- Sheet for converting EKEvent ---
        .sheet(isPresented: Binding( 
                   get: { viewModel.eventToConvert != nil },
                   set: { if !$0 { viewModel.eventToConvert = nil } }
               )) {
            if let event = viewModel.eventToConvert {
                let newSessionViewModel = NewSessionViewModel(
                    context: viewContext,
                    from: event
                )
                
                NativeSessionSheetView(viewModel: newSessionViewModel, onDismiss: { viewModel.eventToConvert = nil })
                .environment(\.modelContext, viewContext)
                    .onAppear {
                        newSessionViewModel.onSave = { editMode in
                            viewModel.handleSaveFromEditor(
                                with: editMode,
                                viewModel: newSessionViewModel
                            )
                        }

                        newSessionViewModel.onDelete = { mode in
                            viewModel.handleDeleteFromEditor(with: mode, viewModel: newSessionViewModel)
                        }
                    }
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
                          itemSession.client == session.client else {
                        return false
                    }
                    guard let startDate = item.startDate else { return false }
                    return Calendar.current.isDate(startDate, inSameDayAs: sessionDate)
                }

                TravelChargeView(
                    mainSession: session,
                    instanceStartDate: viewModel.selectedInstanceStartDateForTravel,
                    instanceEndDate: viewModel.selectedInstanceEndDateForTravel,
                    daySessions: daySessions,
                    onSave: { 
                        viewModel.updateDisplayableItems()
                        viewModel.selectedSessionForTravel = nil
                        viewModel.selectedInstanceStartDateForTravel = nil
                        viewModel.selectedInstanceEndDateForTravel = nil
                    }
                )
                .environment(\.modelContext, viewContext)
            } else {
                Text("Error: Session data missing.")
            }
        }
        // --- Dialog for Recurring Event Modifications ---
        .confirmationDialog(
            "You've modified a recurring event. How would you like to apply your changes?",
            isPresented: $viewModel.showingRecurringModificationDialog,
            titleVisibility: .visible
        ) {
            Button("This Event Only") {
                viewModel.executeRecurringModification(with: .thisOnly)
            }
            .appInteractiveCursor()
            Button("This and Future Events") {
                viewModel.executeRecurringModification(with: .thisAndFuture)
            }
            .appInteractiveCursor()
            Button("All Events in Series") {
                viewModel.executeRecurringModification(with: .all)
            }
            .appInteractiveCursor()
            Button("Cancel", role: .cancel) {
                // Reset the pending modification if the user cancels
                viewModel.pendingRecurringModification = nil
            }
            .appInteractiveCursor()
        }
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
                    .appInteractiveCursor()
                }
                
                Spacer()
                
                Button("Cancel") { onDismiss() }
                    .buttonStyle(.glass)
                    .foregroundColor(.white)
                    .accentColor(.blue)
                    .appInteractiveCursor()
                
                Button("Save") {
                    viewModel.save()
                }
                .disabled(!viewModel.formIsValid)
                .buttonStyle(.glass)
                .foregroundColor(.white)
                .accentColor(.blue)
                .appInteractiveCursor()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.black)
        }
        .confirmationDialog(
            "This is a recurring event. How would you like to apply your changes?",
            isPresented: $viewModel.showingRecurringEditOptions,
            titleVisibility: .visible
        ) {
            Button("Save This Event Only") { viewModel.executeSave(with: .thisOnly) }
            .appInteractiveCursor()
            Button("Save This and Future Events") { viewModel.executeSave(with: .thisAndFuture) }
            .appInteractiveCursor()
            Button("Save All Events in Series") { viewModel.executeSave(with: .all) }
            .appInteractiveCursor()
            Button("Cancel", role: .cancel) { }
            .appInteractiveCursor()
        }
        .confirmationDialog(
            "This is a recurring event. How would you like to delete?",
            isPresented: $viewModel.showingRecurringDeleteOptions,
            titleVisibility: .visible
        ) {
            Button("Delete This Event Only", role: .destructive) { viewModel.executeDelete(with: .thisOnly) }
            .appInteractiveCursor()
            Button("Delete This and Future Events", role: .destructive) { viewModel.executeDelete(with: .thisAndFuture) }
            .appInteractiveCursor()
            Button("Delete All Events in Series", role: .destructive) { viewModel.executeDelete(with: .all) }
            .appInteractiveCursor()
            Button("Cancel", role: .cancel) { }
            .appInteractiveCursor()
        }
    }
}

struct NativeSessionSheetView: View {
    @ObservedObject var viewModel: NewSessionViewModel
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            NativeSessionFormView(viewModel: viewModel)
            
            // Footer with action buttons
            HStack {
                if viewModel.isEditing {
                    Button("Delete", role: .destructive) {
                        viewModel.delete()
                    }
                    .buttonStyle(.glass)
                    .foregroundColor(.red)
                    .accentColor(.red)
                    .appInteractiveCursor()
                    .disabled(viewModel.isSaving)
                }
                
                Spacer()
                
                Button("Cancel") { onDismiss() }
                    .buttonStyle(.glass)
                    .foregroundColor(.white)
                    .accentColor(.blue)
                    .appInteractiveCursor()
                    .disabled(viewModel.isSaving)
                
                Button("Save") {
                    // Use the same reliable save mechanism as CalendarViewModel
                    // This ensures consistent behavior and proper error handling
                    viewModel.handleSaveButtonTapped()
                }
                .disabled(!viewModel.formIsValid || viewModel.isSaving)
                .buttonStyle(.glass)
                .foregroundColor(.white)
                .accentColor(.blue)
                .appInteractiveCursor()
                .overlay(
                    Group {
                        if viewModel.isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                    }
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.black)
            
            // Error display
            if let error = viewModel.saveError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.saveError = nil
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
            }
        }
        .onAppear {
            // Set up the onSaveCompleted callback to dismiss the sheet when save completes
            viewModel.onSaveCompleted = {
                print("[NativeSessionSheetView] Save completed, dismissing sheet")
                onDismiss()
            }
        }
        .onDisappear {
            // Cleanup when the sheet is dismissed
            viewModel.cleanup()
        }
        .confirmationDialog(
            "This is a recurring event. How would you like to apply your changes?",
            isPresented: $viewModel.showingRecurringEditOptions,
            titleVisibility: .visible
        ) {
            Button("Save This Event Only") { viewModel.executeSave(with: .thisOnly) }
            .appInteractiveCursor()
            Button("Save This and Future Events") { viewModel.executeSave(with: .thisAndFuture) }
            .appInteractiveCursor()
            Button("Save All Events in Series") { viewModel.executeSave(with: .all) }
            .appInteractiveCursor()
            Button("Cancel", role: .cancel) { }
            .appInteractiveCursor()
        }
        .confirmationDialog(
            "This is a recurring event. How would you like to delete?",
            isPresented: $viewModel.showingRecurringDeleteOptions,
            titleVisibility: .visible
        ) {
            Button("Delete This Event Only", role: .destructive) { viewModel.executeDelete(with: .thisOnly) }
            .appInteractiveCursor()
            Button("Delete This and Future Events", role: .destructive) { viewModel.executeDelete(with: .thisAndFuture) }
            .appInteractiveCursor()
            Button("Delete All Events in Series", role: .destructive) { viewModel.executeDelete(with: .all) }
            .appInteractiveCursor()
            Button("Cancel", role: .cancel) { }
            .appInteractiveCursor()
        }
    }
}


