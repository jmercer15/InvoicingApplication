import PersistenceModels
import SwiftUI
import SwiftData
import SharedUI
import Observation

struct CalendarBulkOperationsToolbar: View {
    @Bindable var viewModel: CalendarViewModel
    @State private var showDeleteAlert = false
    
    var body: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMediumLarge) {
            if let progress = viewModel.bulkOperationProgress {
                progressView(progress)
            } else {
                selectionInfoView
            }
            
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
        .alert(deleteConfirmationTitle, isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button(deleteConfirmationButtonTitle, role: .destructive) {
                viewModel.bulkDeleteSessions()
            }
        } message: {
            Text(deleteConfirmationMessage)
        }
    }
    
    private var selectionInfoView: some View {
        HStack {
            Text("\(viewModel.selectedItemIDs.count) selected")
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(StyleGuide.Colors.textSecondary)
            
            // Select All / Deselect All — compare against session-only count (ignore EventKit events).
            Button(viewModel.areAllSelectableSessionsSelected ? "Deselect All" : "Select All") {
                if viewModel.areAllSelectableSessionsSelected {
                    viewModel.deselectAllItems()
                } else {
                    viewModel.selectAllItems()
                }
            }
            .buttonStyle(.glass)
            .disabled(viewModel.isBulkOperationInFlight)
        }
    }

    private func progressView(_ progress: CalendarBulkOperationProgress) -> some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            ProgressView(value: progress.fractionCompleted)
                .progressViewStyle(.linear)
                .frame(width: 96)
            Text(progress.message)
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(StyleGuide.Colors.textSecondary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(progress.message)
    }

    private var actionsView: some View {
        HStack {
            // Status change menu
            Menu {
                Button("Mark as Scheduled") {
                    viewModel.bulkChangeStatus(to: AppConstants.sessionStatusPlanned)
                }
                Button("Mark as Completed", systemImage: "checkmark.circle.fill") {
                    viewModel.bulkChangeStatus(to: AppConstants.sessionStatusCompleted)
                }
                Button("Mark as Cancelled") {
                    viewModel.bulkChangeStatus(to: AppConstants.sessionStatusCancelled)
                }
            } label: {
                Label("Change Status", systemImage: "tag")
            }
            .disabled(viewModel.selectedSessions.isEmpty || viewModel.isBulkOperationInFlight)
            
            // Delete button
            Button("Delete") {
                showDeleteAlert = true
            }
            .buttonStyle(.glassProminent)
            .tint(ColorSystem.Status.error.opacity(0.7))
            .disabled(viewModel.selectedSessions.isEmpty || viewModel.isBulkOperationInFlight)
        }
    }

    private var doneButton: some View {
        Button("Done") {
            viewModel.toggleBulkSelectionMode()
        }
        .buttonStyle(.glass)
        .disabled(viewModel.isBulkOperationInFlight)
    }

    private var selectedCount: Int {
        viewModel.selectedItemIDs.count
    }

    private var selectedInvoicedCount: Int {
        viewModel.selectedSessions.filter { $0.invoice != nil }.count
    }

    private var deleteConfirmationTitle: String {
        CalendarBulkDeleteConfirmationCopy.title(count: selectedCount)
    }

    private var deleteConfirmationButtonTitle: String {
        CalendarBulkDeleteConfirmationCopy.buttonTitle(count: selectedCount)
    }

    private var deleteConfirmationMessage: String {
        CalendarBulkDeleteConfirmationCopy.message(
            count: selectedCount,
            invoicedCount: selectedInvoicedCount
        )
    }
}

#Preview {
    // Preview intentionally minimal; full toolbar behavior depends on live calendar container state.
    EmptyView()
}
