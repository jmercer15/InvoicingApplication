import SwiftUI
import Core
import Data
import SharedUI

struct NativeSessionFormSupportLogSection: View {
    @Bindable var viewModel: NewSessionViewModel

    var body: some View {
        GroupBox("Support Log") {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXMedium) {
                Toggle("Capture support log for this session", isOn: supportLogBinding(\.isEnabled))
                    .toggleStyle(.switch)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.formModel.supportLogDraft.isEnabled {
                    let requiredFieldCount = 7
                    let completedRequiredFieldCount = [
                        viewModel.formModel.supportLogDraft.participantName,
                        viewModel.formModel.supportLogDraft.participantNdisNumber,
                        viewModel.formModel.supportLogDraft.supportItemNumber,
                        viewModel.formModel.supportLogDraft.serviceDescription,
                        viewModel.formModel.supportLogDraft.location,
                        viewModel.formModel.supportLogDraft.deliveredBy,
                        viewModel.formModel.supportLogDraft.attestedBy
                    ]
                    .map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .filter { $0 }
                    .count

                    HStack(spacing: FormSectionTokens.fieldStackSpacing) {
                        Image(systemName: "checklist")
                            .foregroundStyle(Color.accentColor)
                        Text("Required fields completed: \(completedRequiredFieldCount)/\(requiredFieldCount)")
                            .font(StyleGuide.Typography.caption)
                            .foregroundStyle(StyleGuide.Colors.textSecondary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                    .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                    .background(
                        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous)
                            .fill(Color.accentColor.opacity(0.10))
                    )

                    VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
                        Text("Participant & Support")
                            .font(StyleGuide.Typography.caption)
                            .foregroundStyle(StyleGuide.Colors.textSecondary)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Participant:")
                                .frame(width: StyleGuide.Dimensions.formSupportLabelWidth, alignment: .trailing)
                                .foregroundColor(StyleGuide.Colors.text)
                            TextField("Participant name", text: supportLogBinding(\.participantName))
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("NDIS #:")
                                .frame(width: StyleGuide.Dimensions.formSupportLabelWidth, alignment: .trailing)
                                .foregroundColor(StyleGuide.Colors.text)
                            TextField("Participant NDIS number", text: supportLogBinding(\.participantNdisNumber))
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Item #:")
                                .frame(width: StyleGuide.Dimensions.formSupportLabelWidth, alignment: .trailing)
                                .foregroundColor(StyleGuide.Colors.text)
                            TextField("Support item number", text: supportLogBinding(\.supportItemNumber))
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Description:")
                                .frame(width: StyleGuide.Dimensions.formSupportLabelWidth, alignment: .trailing)
                                .foregroundColor(StyleGuide.Colors.text)
                            TextField("Service description", text: supportLogBinding(\.serviceDescription))
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
                        Text("Delivery Evidence")
                            .font(StyleGuide.Typography.caption)
                            .foregroundStyle(StyleGuide.Colors.textSecondary)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Delivered:")
                                .frame(width: StyleGuide.Dimensions.formSupportLabelWidth, alignment: .trailing)
                                .foregroundColor(StyleGuide.Colors.text)
                            DatePicker(
                                "",
                                selection: supportLogBinding(\.deliveredFrom),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                            DatePicker(
                                "",
                                selection: supportLogBinding(\.deliveredTo),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Delivered by:")
                                .frame(width: StyleGuide.Dimensions.formSupportLabelWidth, alignment: .trailing)
                                .foregroundColor(StyleGuide.Colors.text)
                            TextField("Staff name", text: supportLogBinding(\.deliveredBy))
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Attested by:")
                                .frame(width: StyleGuide.Dimensions.formSupportLabelWidth, alignment: .trailing)
                                .foregroundColor(StyleGuide.Colors.text)
                            TextField("Attested by", text: supportLogBinding(\.attestedBy))
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Attested at:")
                                .frame(width: StyleGuide.Dimensions.formSupportLabelWidth, alignment: .trailing)
                                .foregroundColor(StyleGuide.Colors.text)
                            DatePicker(
                                "",
                                selection: supportLogBinding(\.attestedAt),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Location:")
                                .frame(width: StyleGuide.Dimensions.formSupportLabelWidth, alignment: .trailing)
                                .foregroundColor(StyleGuide.Colors.text)
                            TextField("Location", text: supportLogBinding(\.location))
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
                        Text("Optional Compliance Details")
                            .font(StyleGuide.Typography.caption)
                            .foregroundStyle(StyleGuide.Colors.textSecondary)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Method:")
                                .frame(width: StyleGuide.Dimensions.formSupportLabelWidth, alignment: .trailing)
                                .foregroundColor(StyleGuide.Colors.text)
                            Picker("", selection: Binding(
                                get: { viewModel.formModel.supportLogDraft.signatureMethod ?? SignatureMethod.attestation.rawValue },
                                set: { newValue in
                                    var updated = viewModel.formModel
                                    updated.supportLogDraft.signatureMethod = newValue
                                    viewModel.formModel = updated
                                }
                            )) {
                                ForEach(SignatureMethod.allCases, id: \.rawValue) { method in
                                    Text(method.rawValue.capitalized).tag(method.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Signed by:")
                                .frame(width: StyleGuide.Dimensions.formSupportLabelWidth, alignment: .trailing)
                                .foregroundColor(StyleGuide.Colors.text)
                            TextField(
                                "Participant/nominee signature",
                                text: Binding(
                                    get: { viewModel.formModel.supportLogDraft.signedBy ?? "" },
                                    set: { newValue in
                                        var updated = viewModel.formModel
                                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                        updated.supportLogDraft.signedBy = trimmed.isEmpty ? nil : trimmed
                                        viewModel.formModel = updated
                                    }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Cancel code:")
                                .frame(width: StyleGuide.Dimensions.formSupportLabelWidth, alignment: .trailing)
                                .foregroundColor(StyleGuide.Colors.text)
                            TextField(
                                "NSDH / NSDF / NSDT / NSDO",
                                text: Binding(
                                    get: { viewModel.formModel.supportLogDraft.cancellationReasonCode ?? "" },
                                    set: { newValue in
                                        var updated = viewModel.formModel
                                        let trimmed = String(newValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().prefix(4))
                                        updated.supportLogDraft.cancellationReasonCode = trimmed.isEmpty ? nil : trimmed
                                        viewModel.formModel = updated
                                    }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Notes:")
                                .frame(width: StyleGuide.Dimensions.formSupportLabelWidth, alignment: .trailing)
                                .foregroundColor(StyleGuide.Colors.text)
                            TextField(
                                "Optional notes",
                                text: Binding(
                                    get: { viewModel.formModel.supportLogDraft.notes ?? "" },
                                    set: { newValue in
                                        var updated = viewModel.formModel
                                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                        updated.supportLogDraft.notes = trimmed.isEmpty ? nil : trimmed
                                        viewModel.formModel = updated
                                    }
                                ),
                                axis: .vertical
                            )
                            .lineLimit(2...5)
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .background(Color.clear)
    }

    private func supportLogBinding<T>(_ keyPath: WritableKeyPath<SessionSupportLogDraft, T>) -> Binding<T> {
        Binding(
            get: { viewModel.formModel.supportLogDraft[keyPath: keyPath] },
            set: { newValue in
                var updated = viewModel.formModel
                updated.supportLogDraft[keyPath: keyPath] = newValue
                viewModel.formModel = updated
            }
        )
    }
}
