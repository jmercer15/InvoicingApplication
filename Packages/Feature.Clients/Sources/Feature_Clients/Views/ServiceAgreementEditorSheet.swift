import SwiftUI
import Observation
import Core
import PersistenceModels
import SharedUI

struct ServiceAgreementEditorSheet: View {
    @Bindable var viewModel: ClientDetailViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Effective From", selection: binding(\.effectiveFrom, default: Date()), displayedComponents: .date)

                Toggle(
                    "Open-ended",
                    isOn: Binding(
                        get: { viewModel.serviceAgreementToEdit?.effectiveTo == nil },
                        set: { isOpenEnded in
                            guard let agreement = viewModel.serviceAgreementToEdit else { return }
                            if isOpenEnded {
                                agreement.effectiveTo = nil
                            } else if agreement.effectiveTo == nil {
                                agreement.effectiveTo = Calendar.current.date(byAdding: .year, value: 1, to: agreement.effectiveFrom)
                            }
                            viewModel.serviceAgreementToEdit = agreement
                        }
                    )
                )

                if viewModel.serviceAgreementToEdit?.effectiveTo != nil {
                    DatePicker(
                        "Effective To",
                        selection: Binding(
                            get: {
                                viewModel.serviceAgreementToEdit?.effectiveTo
                                    ?? Calendar.current.date(byAdding: .year, value: 1, to: Date())
                                    ?? Date()
                            },
                            set: { newDate in
                                guard let agreement = viewModel.serviceAgreementToEdit else { return }
                                agreement.effectiveTo = newDate
                                viewModel.serviceAgreementToEdit = agreement
                            }
                        ),
                        displayedComponents: .date
                    )
                }

                Picker("Cancellation Policy", selection: binding(\.cancellationPolicyType, default: CancellationPolicyType.twoClearBusinessDays.rawValue)) {
                    ForEach(CancellationPolicyType.allCases, id: \.rawValue) { policy in
                        Text(policy.rawValue).tag(policy.rawValue)
                    }
                }

                Toggle("Allows Provider Travel", isOn: binding(\.allowsProviderTravel, default: false))
                Toggle("Allows Telehealth", isOn: binding(\.allowsTelehealth, default: false))
                Toggle("Allows Non Face-to-Face", isOn: binding(\.allowsNonFaceToFace, default: false))

                TextField(
                    "Signatory Name (optional)",
                    text: Binding(
                        get: { viewModel.serviceAgreementToEdit?.participantSignatoryName ?? "" },
                        set: { updateOptionalString(\.participantSignatoryName, to: $0) }
                    )
                )

                TextField(
                    "Signatory Role (optional)",
                    text: Binding(
                        get: { viewModel.serviceAgreementToEdit?.participantSignatoryRole ?? "" },
                        set: { updateOptionalString(\.participantSignatoryRole, to: $0) }
                    )
                )

                Picker(
                    "Signature Method",
                    selection: Binding(
                        get: { viewModel.serviceAgreementToEdit?.signatureMethod ?? SignatureMethod.attestation.rawValue },
                        set: { updateOptionalString(\.signatureMethod, to: $0) }
                    )
                ) {
                    ForEach(SignatureMethod.allCases, id: \.rawValue) { method in
                        Text(method.rawValue.capitalized).tag(method.rawValue)
                    }
                }

                DatePicker(
                    "Signed At",
                    selection: Binding(
                        get: { viewModel.serviceAgreementToEdit?.signedAt ?? Date() },
                        set: { updateOptionalDate(\.signedAt, to: $0) }
                    ),
                    displayedComponents: .date
                )

                TextField(
                    "Notes (optional)",
                    text: Binding(
                        get: { viewModel.serviceAgreementToEdit?.notes ?? "" },
                        set: { updateOptionalString(\.notes, to: $0) }
                    )
                )

                if let error = viewModel.serviceAgreementValidationError,
                   !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(error)
                        .formErrorStyle()
                }
            }
            .navigationTitle("Service Agreement")
            .toolbar {
                AppToolbarSheetBar(
                    confirmTitle: "Save",
                    onCancel: {
                        viewModel.cancelServiceAgreementEdit()
                        dismiss()
                    },
                    onConfirm: { viewModel.saveServiceAgreement() }
                )
            }
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<ServiceAgreement, T>, default defaultValue: T) -> Binding<T> {
        Binding(
            get: { viewModel.serviceAgreementToEdit?[keyPath: keyPath] ?? defaultValue },
            set: { newValue in
                guard var agreement = viewModel.serviceAgreementToEdit else { return }
                agreement[keyPath: keyPath] = newValue
                viewModel.serviceAgreementToEdit = agreement
            }
        )
    }

    private func updateOptionalString(_ keyPath: WritableKeyPath<ServiceAgreement, String?>, to value: String) {
        guard var agreement = viewModel.serviceAgreementToEdit else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        agreement[keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed
        viewModel.serviceAgreementToEdit = agreement
    }

    private func updateOptionalDate(_ keyPath: WritableKeyPath<ServiceAgreement, Date?>, to value: Date) {
        guard var agreement = viewModel.serviceAgreementToEdit else { return }
        agreement[keyPath: keyPath] = value
        viewModel.serviceAgreementToEdit = agreement
    }
}
