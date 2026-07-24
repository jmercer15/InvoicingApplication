import SwiftUI
import Core
import SharedUI

struct NativeSessionSheetView: View {
    @Bindable var viewModel: NewSessionViewModel
    var onDismiss: () -> Void

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
    }

    private var footer: some View {
        VStack(spacing: 0) {
            HStack {
                if viewModel.isEditing {
                    Button("Delete", role: .destructive) { viewModel.delete() }
                        .buttonStyle(.glass)
                        .foregroundColor(ColorSystem.Status.error)
                        .disabled(viewModel.isPerformingPersistence)
                }
                Spacer()
                Button("Cancel") { onDismiss() }
                    .buttonStyle(.glass)
                    .foregroundColor(StyleGuide.Colors.text)
                    .disabled(viewModel.isPerformingPersistence)
                Button(viewModel.saveButtonTitle) { viewModel.handleSaveButtonTapped() }
                    .buttonStyle(.glass)
                    .foregroundColor(StyleGuide.Colors.text)
                    .disabled(!viewModel.formIsValid || viewModel.isPerformingPersistence)
                    .overlay {
                        if viewModel.isPerformingPersistence {
                            ProgressView().scaleEffect(0.8).foregroundColor(StyleGuide.Colors.text)
                        }
                    }
            }
            .padding(.horizontal)
            .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
            .background(StyleGuide.Colors.background)

            if let error = viewModel.persistenceError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(ColorSystem.Status.error)
                    Text(error)
                        .foregroundColor(ColorSystem.Status.error)
                        .font(StyleGuide.Typography.itemSubtitle)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.persistenceError = nil
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
                .padding(.horizontal)
                .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
                .background(ColorSystem.Status.error.opacity(StyleGuide.Opacity.light))
            } else if viewModel.requiresSaveScopeSelection || viewModel.requiresDeleteScopeSelection {
                HStack(spacing: FormSectionTokens.fieldStackSpacing) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text("You will choose how changes apply to the recurring series on the next step.")
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
            }
        }
    }
}
