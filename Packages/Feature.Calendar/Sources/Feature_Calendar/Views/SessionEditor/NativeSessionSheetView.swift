import SwiftUI
import SharedUI

struct NativeSessionSheetView: View {
    @Bindable var viewModel: NewSessionViewModel
    var onDismiss: () -> Void
    @State private var showsDeleteConfirmation = false

    private enum RecurringActionPresentation: String, Identifiable {
        case saveScope
        case deleteScope

        var id: String { rawValue }
    }

    private var recurringActionPresentation: Binding<RecurringActionPresentation?> {
        Binding(
            get: {
                if viewModel.showingEditModeDialog { return .saveScope }
                if viewModel.showingRecurringDeleteOptions { return .deleteScope }
                return nil
            },
            set: { newValue in
                guard newValue == nil else { return }
                viewModel.showingEditModeDialog = false
                viewModel.showingRecurringDeleteOptions = false
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            NativeSessionFormView(viewModel: viewModel)
            footer
        }
        .onAppear { viewModel.onSaveCompleted = onDismiss }
        .sheet(item: recurringActionPresentation) { presentation in
            switch presentation {
            case .saveScope:
                RecurringScopePickerSheet(
                    title: "Apply Changes",
                    options: viewModel.availableSaveModes,
                    isDestructive: false,
                    label: viewModel.saveScopeTitle(for:),
                    detail: { $0.detailText(isDelete: false) },
                    recommended: viewModel.recommendedSaveMode
                ) { mode in
                    viewModel.executeSave(with: mode)
                }
            case .deleteScope:
                RecurringScopePickerSheet(
                    title: "Delete Recurring Session",
                    options: viewModel.availableDeleteModes,
                    isDestructive: true,
                    label: viewModel.deleteScopeTitle(for:),
                    detail: { $0.detailText(isDelete: true) },
                    recommended: viewModel.recommendedDeleteMode
                ) { mode in
                    viewModel.executeDelete(with: mode)
                }
            }
        }
        .alert("Delete this session?", isPresented: $showsDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                viewModel.delete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteConfirmationMessage)
        }
        .confirmationDialog(
            "Session Linked to Invoice",
            isPresented: Binding(
                get: { viewModel.pendingInvoicedAction != nil },
                set: { isPresented in
                    if !isPresented { viewModel.cancelInvoicedAction() }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(
                viewModel.pendingInvoicedAction == .delete ? "Delete Anyway" : "Save Anyway",
                role: viewModel.pendingInvoicedAction == .delete ? .destructive : nil
            ) {
                viewModel.confirmInvoicedAction()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelInvoicedAction()
            }
        } message: {
            Text(viewModel.invoicedActionDialogMessage)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if let error = viewModel.persistenceError {
                feedbackRow(
                    message: error,
                    icon: "exclamationmark.triangle.fill",
                    color: ColorSystem.Status.error
                ) {
                    Button("Dismiss") {
                        viewModel.persistenceError = nil
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            } else if let readiness = viewModel.saveReadinessMessage {
                feedbackRow(
                    message: readiness,
                    icon: "checklist",
                    color: ColorSystem.Status.warning
                )
            } else if viewModel.requiresSaveScopeSelection || viewModel.requiresDeleteScopeSelection {
                feedbackRow(
                    message: "Next, choose how changes apply to the recurring series.",
                    icon: "repeat",
                    color: StyleGuide.Colors.textSecondary
                )
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                    deleteButton
                    Spacer()
                    cancelButton
                    saveButton
                }

                VStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                    HStack {
                        deleteButton
                        Spacer()
                        cancelButton
                    }
                    saveButton
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
            .background(StyleGuide.Colors.background)
        }
    }

    @ViewBuilder
    private var deleteButton: some View {
        if viewModel.isEditing {
            Button(role: .destructive) {
                showsDeleteConfirmation = true
            } label: {
                if viewModel.isDeleting {
                    Label("Deleting…", systemImage: "trash")
                } else {
                    Label("Delete", systemImage: "trash")
                }
            }
            .buttonStyle(.bordered)
            .foregroundStyle(ColorSystem.Status.error)
            .disabled(viewModel.isPerformingPersistence)
        }
    }

    private var cancelButton: some View {
        Button("Cancel") { onDismiss() }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)
            .disabled(viewModel.isPerformingPersistence)
    }

    private var saveButton: some View {
        Button {
            viewModel.handleSaveButtonTapped()
        } label: {
            if viewModel.isSaving {
                HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                    ProgressView().controlSize(.small)
                    Text("Saving…")
                }
            } else {
                Text(viewModel.saveButtonTitle)
            }
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
        .disabled(!viewModel.formIsValid || viewModel.isPerformingPersistence)
        .help(viewModel.saveReadinessMessage ?? viewModel.saveButtonTitle)
    }

    private func feedbackRow<Trailing: View>(
        message: String,
        icon: String,
        color: Color,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormSectionTokens.fieldStackSpacing) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(message)
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: StyleGuide.Dimensions.paddingSmall)
            trailing()
        }
        .padding(.horizontal)
        .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
        .background(color.opacity(StyleGuide.Opacity.light))
        .accessibilityElement(children: .contain)
    }

    private func feedbackRow(
        message: String,
        icon: String,
        color: Color
    ) -> some View {
        feedbackRow(message: message, icon: icon, color: color) {
            EmptyView()
        }
    }

    private var deleteConfirmationMessage: String {
        var parts = [
            viewModel.isEditingRecurringSession
                ? "You’ll choose which occurrences to delete next."
                : "This permanently deletes the session."
        ]
        if viewModel.isEditingInvoicedSession {
            parts.append("Its linked invoice will remain unchanged.")
        }
        return parts.joined(separator: " ")
    }
}
