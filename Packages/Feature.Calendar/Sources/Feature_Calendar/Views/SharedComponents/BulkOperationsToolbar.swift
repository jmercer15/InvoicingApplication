import SwiftUI
import SwiftData
import Data
import SharedUI
import Observation

struct CalendarBulkOperationsToolbar: View {
    @Bindable var viewModel: CalendarViewModel
    @State private var showDeleteAlert = false
    
    var body: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMediumLarge) {
            selectionInfoView
            
            Divider()
                .frame(height: 20)
            
            actionsView
            
            Spacer()
            
            doneButton
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingMediumLarge)
        .glassEffect(.regular, in: .rect(cornerRadius: 0))
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(height: StyleGuide.Dimensions.hairlineWidth),
            alignment: .bottom
        )
        .alert("Delete Sessions", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.bulkDeleteSessions()
            }
        } message: {
            Text("Are you sure you want to delete \(viewModel.selectedSessions.count) session(s)? This action cannot be undone.")
        }
    }
    
    private var selectionInfoView: some View {
        HStack {
            Text("\(viewModel.selectedItemIDs.count) selected")
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundColor(StyleGuide.Colors.textSecondary)
            
            // Select All / Deselect All
            Button(viewModel.selectedItemIDs.count == viewModel.displayableItems.count ? "Deselect All" : "Select All") {
                if viewModel.selectedItemIDs.count == viewModel.displayableItems.count {
                    viewModel.deselectAllItems()
                } else {
                    viewModel.selectAllItems()
                }
            }
            .buttonStyle(.glass)
        }
    }

    private var actionsView: some View {
        HStack {
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
            .tint(ColorSystem.Status.error.opacity(0.7))
            .disabled(viewModel.selectedSessions.isEmpty)
        }
    }

    private var doneButton: some View {
        Button("Done") {
            viewModel.toggleBulkSelectionMode()
        }
        .buttonStyle(.glass)
    }
}

#Preview {
    // Preview intentionally minimal; full toolbar behavior depends on live calendar container state.
    EmptyView()
}  