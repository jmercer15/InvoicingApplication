import AppKit
import SwiftUI
import Core
import Data
import SharedUI

struct ClientDetailBillingInfoCard: View {
    @Bindable var viewModel: ClientDetailViewModel
    let maxLabelWidth: CGFloat
    let payeeEntities: [Payee]

    var body: some View {
        GroupBox {
            VStack(spacing: DetailSectionTokens.sectionListSpacing) {
                HStack(spacing: DetailSectionTokens.formStackSpacing) {
                    HStack(alignment: .center, spacing: DetailSectionTokens.formRowSpacing) {
                        Text("Is Minor:")
                            .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(StyleGuide.Colors.text)

                        Toggle("", isOn: $viewModel.editableIsMinor)
                            .toggleStyle(.switch)
                            .foregroundColor(StyleGuide.Colors.text)
                            .labelsHidden()
                            .onChange(of: viewModel.editableIsMinor) { _, isMinor in
                                if isMinor {
                                    viewModel.editableBillingAuthority = .parentGuardian
                                }
                                viewModel.updateAndSaveClient()
                            }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()
                        .frame(maxWidth: .infinity)
                }

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("Authority:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)

                    Picker("", selection: Binding(
                        get: { viewModel.editableBillingAuthority },
                        set: { viewModel.editableBillingAuthority = $0; viewModel.updateAndSaveClient() }
                    )) {
                        if !viewModel.editableIsMinor {
                            Text("Client").tag(Core.BillingAuthority.client)
                        }
                        Text("Parent/Guardian").tag(Core.BillingAuthority.parentGuardian)
                    }
                    .disabled(viewModel.editableIsMinor)
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.editableBillingAuthority == Core.BillingAuthority.parentGuardian {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("Parent/Guardian:")
                            .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(StyleGuide.Colors.text)

                        Picker("", selection: Binding(
                            get: { viewModel.selectedPayee?.id },
                            set: { newPayeeId in
                                viewModel.updatePayee(by: newPayeeId)
                            }
                        )) {
                            Text("Select Parent/Guardian").tag(nil as UUID?)
                            ForEach(payeeEntities) { payee in
                                Text(payee.fullName).tag(payee.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fluidListTransition()
                    .animation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping), value: viewModel.editableBillingAuthority)
                }

                HStack(alignment: .firstTextBaseline, spacing: DetailSectionTokens.formRowSpacing) {
                    Text("Credit:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)

                    HStack {
                        TextField("0.00", text: $viewModel.editableCreditAmountString)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(StyleGuide.Colors.text)
                            .accentColor(ColorSystem.Primary.blue)
                            .onChange(of: viewModel.editableCreditAmountString) { viewModel.updateAndSaveClient() }

                        Button(action: { copyToClipboard(viewModel.editableCreditAmountString) }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(ColorSystem.Neutral.gray500)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Copy credit amount")
                        .accessibilityHint("Copies the client credit amount to the pasteboard")
                    }
                }

                Divider()
                    .padding(.vertical, StyleGuide.Dimensions.paddingMedium)

                VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
                    Text("Invoice Email Recipients")
                        .formSectionTitleStyle()

                    if let clientEmail = viewModel.client.email, !clientEmail.isEmpty {
                        HStack(alignment: .center, spacing: StyleGuide.Dimensions.paddingMedium) {
                            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                                Text(viewModel.client.fullName)
                                    .font(StyleGuide.Typography.label)
                                    .foregroundColor(StyleGuide.Colors.text)
                                Text(clientEmail)
                                    .font(StyleGuide.Typography.caption)
                                    .foregroundColor(StyleGuide.Colors.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { viewModel.client.sendInvoicesToClient ?? true },
                                set: { viewModel.updateAndSaveClientToggle(sendInvoicesToClient: $0) }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
                        .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
                    }

                    if let payee = viewModel.client.payee, let payeeEmail = payee.email, !payeeEmail.isEmpty {
                        HStack(alignment: .center, spacing: StyleGuide.Dimensions.paddingMedium) {
                            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                                Text(payee.fullName)
                                    .font(StyleGuide.Typography.label)
                                    .foregroundColor(StyleGuide.Colors.text)
                                Text(payeeEmail)
                                    .font(StyleGuide.Typography.caption)
                                    .foregroundColor(StyleGuide.Colors.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { viewModel.client.sendInvoicesToPayee ?? true },
                                set: { viewModel.updateAndSaveClientToggle(sendInvoicesToPayee: $0) }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
                        .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
                    }

                    if viewModel.client.hasNdisPlan && viewModel.client.planManagementType == "Plan-Managed",
                       let planManager = viewModel.client.planManager,
                       let planManagerEmail = planManager.email,
                       !planManagerEmail.isEmpty {
                        HStack(alignment: .center, spacing: StyleGuide.Dimensions.paddingMedium) {
                            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                                Text(planManager.name ?? "")
                                    .font(StyleGuide.Typography.label)
                                    .foregroundColor(StyleGuide.Colors.text)
                                Text(planManagerEmail)
                                    .font(StyleGuide.Typography.caption)
                                    .foregroundColor(StyleGuide.Colors.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { viewModel.client.sendInvoicesToPlanManager ?? true },
                                set: { viewModel.updateAndSaveClientToggle(sendInvoicesToPlanManager: $0) }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
                        .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
                    }

                    if (viewModel.client.email?.isEmpty ?? true)
                        && (viewModel.client.payee?.email?.isEmpty ?? true)
                        && (viewModel.client.planManager?.email?.isEmpty ?? true) {
                        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                            Image(systemName: "envelope.badge.shield")
                                .font(.title3)
                                .foregroundColor(ColorSystem.Neutral.gray500)
                            Text("No email addresses available. Add email addresses to the relevant entities to configure invoice recipients.")
                                .font(StyleGuide.Typography.caption)
                                .foregroundColor(StyleGuide.Colors.textSecondary)
                        }
                        .standardCardStyle()
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(DetailSectionTokens.contentPadding)
        } label: {
            DetailSectionHeader(icon: "creditcard", title: "Billing Information")
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
