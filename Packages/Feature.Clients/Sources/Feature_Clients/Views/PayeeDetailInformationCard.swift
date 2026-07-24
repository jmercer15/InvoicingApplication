import SwiftUI
import SharedUI
import WorkspaceUI

struct PayeeDetailInformationCard: View {
    @Bindable var viewModel: PayeeDetailViewModel
    let maxLabelWidth: CGFloat
    let hasAddressData: Bool
    let addressText: String
    @Binding var showingMapSheet: Bool
    @Binding var showingAddressEditingSheet: Bool

    var body: some View {
        GroupBox {
            VStack(spacing: StyleGuide.Dimensions.paddingLarge) {
                HStack(alignment: .firstTextBaseline, spacing: StyleGuide.Dimensions.paddingSmall) {
                    Text("Name:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundStyle(StyleGuide.Colors.text)

                    VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
                        HStack {
                            TextField("Enter payee name", text: $viewModel.editableFullName)
                                .textFieldStyle(.roundedBorder)
                                .foregroundStyle(viewModel.fullNameError != nil ? ColorSystem.Status.error : StyleGuide.Colors.text)
                                .accentColor(viewModel.fullNameError != nil ? ColorSystem.Status.error : ColorSystem.Status.info)
                                .onChange(of: viewModel.editableFullName) { _, _ in viewModel.updateAndSavePayee() }

                            Button(action: { viewModel.copyToClipboard(viewModel.editableFullName) }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .pointerStyle(.link)
                            .accessibilityLabel("Copy payee name")
                            .accessibilityHint("Copies payee name to clipboard")
                        }

                        if let error = viewModel.fullNameError {
                            Text(error)
                                .formErrorStyle()
                        }
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: StyleGuide.Dimensions.paddingSmall) {
                    Text("Email:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundStyle(StyleGuide.Colors.text)

                    VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
                        HStack {
                            TextField("Enter email address", text: $viewModel.emailValidator.email)
                                .textFieldStyle(.roundedBorder)
                                .foregroundStyle(viewModel.emailValidator.validationMessage != nil ? ColorSystem.Status.error : StyleGuide.Colors.text)
                                .accentColor(viewModel.emailValidator.validationMessage != nil ? ColorSystem.Status.error : ColorSystem.Status.info)
                                .onChange(of: viewModel.emailValidator.email) { _, _ in
                                    if viewModel.emailValidator.isValid {
                                        viewModel.updateAndSavePayee()
                                    }
                                }

                            Button(action: { viewModel.copyToClipboard(viewModel.emailValidator.email) }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .pointerStyle(.link)
                            .accessibilityLabel("Copy email address")
                            .accessibilityHint("Copies email address to clipboard")
                        }

                        if let error = viewModel.emailValidator.validationMessage {
                            Text(error)
                                .formErrorStyle()
                        }
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: StyleGuide.Dimensions.paddingSmall) {
                    Text("Phone:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundStyle(StyleGuide.Colors.text)

                    VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
                        HStack {
                            TextField("Enter phone number", text: $viewModel.phoneFormatter.phoneNumber)
                                .textFieldStyle(.roundedBorder)
                                .foregroundStyle(viewModel.phoneFormatter.validationMessage != nil ? ColorSystem.Status.error : StyleGuide.Colors.text)
                                .accentColor(viewModel.phoneFormatter.validationMessage != nil ? ColorSystem.Status.error : ColorSystem.Status.info)
                                .onChange(of: viewModel.phoneFormatter.phoneNumber) { _, _ in
                                    if viewModel.phoneFormatter.isValid {
                                        viewModel.updateAndSavePayee()
                                    }
                                }

                            Button(action: { viewModel.copyToClipboard(viewModel.phoneFormatter.phoneNumber) }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .pointerStyle(.link)
                            .accessibilityLabel("Copy phone number")
                            .accessibilityHint("Copies phone number to clipboard")
                        }

                        if let error = viewModel.phoneFormatter.validationMessage {
                            Text(error)
                                .formErrorStyle()
                        }
                    }
                }

                RelationshipDetailAddressRow(
                    maxLabelWidth: maxLabelWidth,
                    hasAddressData: hasAddressData,
                    addressText: addressText,
                    showingMapSheet: $showingMapSheet,
                    showingAddressEditingSheet: $showingAddressEditingSheet
                )
                .fluidListTransition()
                .animation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping), value: hasAddressData)

                Spacer(minLength: 0)
            }
            .padding(DetailSectionTokens.contentPadding)
        } label: {
            DetailSectionHeader(icon: "person.text.rectangle", title: "Payee Information")
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
    }
}
