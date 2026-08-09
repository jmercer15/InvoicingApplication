import SwiftUI
import Observation
import PersistenceModels
import SharedUI

struct ClientServiceEditorSheet: View {
    @Bindable var viewModel: ClientDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField(
                    "Service Name",
                    text: Binding(
                        get: { viewModel.clientServiceToEdit?.serviceName ?? "" },
                        set: { updateString(\.serviceName, to: $0) }
                    )
                )

                TextField(
                    "NDIS Code",
                    text: Binding(
                        get: { viewModel.clientServiceToEdit?.ndisCode ?? "" },
                        set: { updateOptionalString(\.ndisCode, to: $0) }
                    )
                )

                TextField(
                    "Unit",
                    text: Binding(
                        get: { viewModel.clientServiceToEdit?.unit ?? "" },
                        set: { updateString(\.unit, to: $0) }
                    )
                )

                TextField(
                    "Rate",
                    text: Binding(
                        get: {
                            guard let rate = viewModel.clientServiceToEdit?.rate else { return "" }
                            return CurrencyFormatting.editableAmount(rate)
                        },
                        set: { raw in
                            guard let service = viewModel.clientServiceToEdit else { return }
                            let filtered = raw.filter("0123456789.".contains)
                            if let value = Double(filtered) {
                                service.rate = Decimal(value)
                                viewModel.clientServiceToEdit = service
                            }
                        }
                    )
                )

                ConsecutiveMonthsStepperField(
                    consecutiveMonths: Binding(
                        get: { viewModel.clientServiceToEdit?.consecutiveMonths },
                        set: { newValue in
                            guard let service = viewModel.clientServiceToEdit else { return }
                            service.consecutiveMonths = newValue
                            viewModel.clientServiceToEdit = service
                        }
                    )
                )

                if let error = viewModel.clientServiceValidationError,
                   !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(error)
                        .formErrorStyle()
                }
            }
            .navigationTitle("Edit Service")
            .toolbar {
                AppToolbarSheetBar(
                    confirmTitle: "Save",
                    onCancel: {
                        viewModel.cancelClientServiceEdit()
                        dismiss()
                    },
                    onConfirm: { viewModel.saveClientService() }
                )
            }
        }
    }

    private func updateString(_ keyPath: ReferenceWritableKeyPath<ClientService, String>, to value: String) {
        guard let service = viewModel.clientServiceToEdit else { return }
        service[keyPath: keyPath] = value
        viewModel.clientServiceToEdit = service
    }

    private func updateOptionalString(_ keyPath: ReferenceWritableKeyPath<ClientService, String?>, to value: String) {
        guard let service = viewModel.clientServiceToEdit else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        service[keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed
        viewModel.clientServiceToEdit = service
    }
}
