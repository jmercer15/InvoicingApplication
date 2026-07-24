import SwiftUI
import AppKit
import SharedUI
import WorkspaceUI

struct PlanManagerDetailInformationCard: View {
    @Bindable var viewModel: PlanManagerDetailViewModel
    let maxLabelWidth: CGFloat
    let hasAddressData: Bool
    let addressText: String
    @Binding var showingMapSheet: Bool
    @Binding var showingAddressEditingSheet: Bool

    var body: some View {
        GroupBox {
            VStack(spacing: DetailSectionTokens.formStackSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: DetailSectionTokens.formRowSpacing) {
                    Text("Name:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)

                    VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
                        HStack {
                            TextField("Enter business name", text: $viewModel.editableBusinessName)
                                .textFieldStyle(.roundedBorder)
                                .foregroundColor(viewModel.businessNameError != nil ? ColorSystem.Status.error : StyleGuide.Colors.text)
                                .accentColor(viewModel.businessNameError != nil ? ColorSystem.Status.error : ColorSystem.Status.info)
                                .onChange(of: viewModel.editableBusinessName) { _, _ in viewModel.updateAndSavePlanManager() }

                            Button(action: { viewModel.copyToClipboard(viewModel.editableBusinessName) }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(StyleGuide.Colors.textSecondary)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .pointerStyle(.link)
                            .accessibilityLabel("Copy business name")
                            .accessibilityHint("Copies business name to clipboard")
                        }

                        if let error = viewModel.businessNameError {
                            Text(error)
                                .formErrorStyle()
                        }
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: DetailSectionTokens.formRowSpacing) {
                    Text("ABN:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)

                    VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
                        HStack {
                            TextField("Enter ABN", text: $viewModel.editableAbn)
                                .textFieldStyle(.roundedBorder)
                                .foregroundColor(viewModel.abnError != nil ? ColorSystem.Status.error : StyleGuide.Colors.text)
                                .accentColor(viewModel.abnError != nil ? ColorSystem.Status.error : ColorSystem.Status.info)
                                .onChange(of: viewModel.editableAbn) { _, _ in viewModel.updateAndSavePlanManager() }

                            Button(action: { viewModel.copyToClipboard(viewModel.editableAbn) }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(StyleGuide.Colors.textSecondary)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .pointerStyle(.link)
                            .accessibilityLabel("Copy ABN")
                            .accessibilityHint("Copies ABN to clipboard")
                        }

                        if let error = viewModel.abnError {
                            Text(error)
                                .formErrorStyle()
                        }
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: DetailSectionTokens.formRowSpacing) {
                    Text("Email:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)

                    VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
                        HStack {
                            TextField("Enter email address", text: $viewModel.emailValidator.email)
                                .textFieldStyle(.roundedBorder)
                                .foregroundColor(viewModel.emailValidator.validationMessage != nil ? ColorSystem.Status.error : StyleGuide.Colors.text)
                                .accentColor(viewModel.emailValidator.validationMessage != nil ? ColorSystem.Status.error : ColorSystem.Status.info)
                                .onChange(of: viewModel.emailValidator.email) { _, _ in
                                    if viewModel.emailValidator.isValid {
                                        viewModel.updateAndSavePlanManager()
                                    }
                                }

                            Button(action: { viewModel.copyToClipboard(viewModel.emailValidator.email) }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(StyleGuide.Colors.textSecondary)
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

                HStack(alignment: .firstTextBaseline, spacing: DetailSectionTokens.formRowSpacing) {
                    Text("Phone:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)

                    VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
                        HStack {
                            TextField("Enter phone number", text: $viewModel.phoneFormatter.phoneNumber)
                                .textFieldStyle(.roundedBorder)
                                .foregroundColor(viewModel.phoneFormatter.validationMessage != nil ? ColorSystem.Status.error : StyleGuide.Colors.text)
                                .accentColor(viewModel.phoneFormatter.validationMessage != nil ? ColorSystem.Status.error : ColorSystem.Status.info)
                                .onChange(of: viewModel.phoneFormatter.phoneNumber) { _, _ in
                                    if viewModel.phoneFormatter.isValid {
                                        viewModel.updateAndSavePlanManager()
                                    }
                                }

                            Button(action: { viewModel.copyToClipboard(viewModel.phoneFormatter.phoneNumber) }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(StyleGuide.Colors.textSecondary)
                                    .padding(StyleGuide.Dimensions.paddingXSmall)
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
            DetailSectionHeader(icon: "building.2", title: "Plan Manager Information")
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
    }
}
