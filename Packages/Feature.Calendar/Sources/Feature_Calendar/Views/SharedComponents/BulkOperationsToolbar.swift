import SwiftUI
import SwiftData
import Data
import SharedUI

struct CalendarBulkOperationsToolbar: View {
    @ObservedObject var viewModel: CalendarViewModel
    @State private var showStatusMenu = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection info
            Text("\(viewModel.selectedItemIDs.count) selected")
                .font(.caption)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            
            // Select All / Deselect All
            Button(viewModel.selectedItemIDs.count == viewModel.displayableItems.count ? "Deselect All" : "Select All") {
                if viewModel.selectedItemIDs.count == viewModel.displayableItems.count {
                    viewModel.deselectAllItems()
                } else {
                    viewModel.selectAllItems()
                }
            }
            .buttonStyle(.glass)
            
            Divider()
                .frame(height: 20)
            
            // Status change menu
            Menu {
                Button("Mark as Planned") {
                    viewModel.bulkChangeStatus(to: AppConstants.sessionStatusPlanned)
                }
                Button("Mark as Confirmed") {
                    viewModel.bulkChangeStatus(to: AppConstants.sessionStatusConfirmed)
                }
                Button("Mark as Completed") {
                    viewModel.bulkChangeStatus(to: AppConstants.sessionStatusCompleted)
                }
                Button("Mark as Cancelled") {
                    viewModel.bulkChangeStatus(to: AppConstants.sessionStatusCancelled)
                }
            } label: {
                Label("Change Status", systemImage: "tag")
            }
            .disabled(viewModel.selectedSessions.isEmpty)
            
            // Delete button
            Button("Delete") {
                showDeleteAlert = true
            }
            .buttonStyle(.glassProminent)
            .tint(Color.red.opacity(0.7))
            .disabled(viewModel.selectedSessions.isEmpty)
            
            Spacer()
            
            // Exit bulk mode
            Button("Done") {
                viewModel.toggleBulkSelectionMode()
            }
            .buttonStyle(.glass)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.gray.opacity(0.1))
        .alert("Delete Sessions", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.bulkDeleteSessions()
            }
        } message: {
            Text("Are you sure you want to delete \(viewModel.selectedSessions.count) session(s)? This action cannot be undone.")
        }
    }
}

#Preview {
    // Note: Preview disabled - would need CalendarViewModel(sessionsRepository:clientsRepository:clientServicesRepository:eventKitService:modelContext:)
    EmptyView()
    /*
    let container = try! ModelContainer(for: SessionEntity.self)
    let context = ModelContext(container)
    let sessionsRepository = SessionsRepositorySwiftData(modelContext: context)
    let eventKitService = EventKitSyncService.shared
    let dataManager = CalendarDataManager(sessionsRepository: sessionsRepository, eventKitService: eventKitService)
    CalendarBulkOperationsToolbar(viewModel: CalendarViewModel(
        sessionsRepository: sessionsRepository,
        eventKitService: eventKitService,
        dataManager: dataManager,
        modelContext: context
    ))
    */
} 