import AppKit
import SwiftData
import SwiftUI
import Core
import Data
import SharedUI

struct ClientDetailClientInformationCard<Address: View>: View {
    @Bindable var viewModel: ClientDetailViewModel
    let maxLabelWidth: CGFloat
    let planManagers: [PlanManager]
    let hasAddressData: Bool
    @ViewBuilder var address: () -> Address

    var body: some View {
        GroupBox {
            VStack(spacing: DetailSectionTokens.formStackSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: DetailSectionTokens.formRowSpacing) {
                    Text("Name:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)

                    HStack {
                        TextField("Enter client name", text: $viewModel.editableFullName)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(StyleGuide.Colors.text)
                            .accentColor(ColorSystem.Primary.blue)
                            .onChange(of: viewModel.editableFullName) { viewModel.updateAndSaveClient() }

                        Button(action: { copyToClipboard(viewModel.editableFullName) }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(ColorSystem.Neutral.gray500)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        .accessibilityLabel("Copy name")
                        .accessibilityHint("Copies client name to clipboard")
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: DetailSectionTokens.formRowSpacing) {
                    Text("Email:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)

                    HStack {
                        TextField("Enter email address", text: $viewModel.emailValidator.email)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(StyleGuide.Colors.text)
                            .accentColor(ColorSystem.Primary.blue)
                            .onChange(of: viewModel.emailValidator.email) { viewModel.updateAndSaveClient() }

                        Button(action: { copyToClipboard(viewModel.emailValidator.email) }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(ColorSystem.Neutral.gray500)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        .accessibilityLabel("Copy email address")
                        .accessibilityHint("Copies email address to clipboard")
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: DetailSectionTokens.formRowSpacing) {
                    Text("Phone:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)

                    HStack {
                        TextField("Enter phone number", text: $viewModel.phoneFormatter.phoneNumber)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(StyleGuide.Colors.text)
                            .accentColor(ColorSystem.Primary.blue)
                            .onChange(of: viewModel.phoneFormatter.phoneNumber) { viewModel.updateAndSaveClient() }

                        Button(action: { copyToClipboard(viewModel.phoneFormatter.phoneNumber) }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(ColorSystem.Neutral.gray500)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        .accessibilityLabel("Copy phone number")
                        .accessibilityHint("Copies phone number to clipboard")
                    }
                }

                address()
                    .fluidListTransition()
                    .animation(.easeInOut(duration: StyleGuide.Animations.durationMedium), value: hasAddressData)

                Divider()
                    .padding(.vertical, StyleGuide.Dimensions.paddingMedium)

                HStack(alignment: .center, spacing: DetailSectionTokens.formRowSpacing) {
                    Text("Has NDIS Plan:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)

                    Toggle("", isOn: $viewModel.editableHasNdisPlan)
                        .toggleStyle(.switch)
                        .foregroundColor(StyleGuide.Colors.text)
                        .labelsHidden()
                        .onChange(of: viewModel.editableHasNdisPlan) { viewModel.updateAndSaveClient() }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.editableHasNdisPlan {
                    HStack(alignment: .firstTextBaseline, spacing: DetailSectionTokens.formRowSpacing) {
                        Text("NDIS:")
                            .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(StyleGuide.Colors.text)

                        HStack {
                            TextField("Enter NDIS number", text: $viewModel.editableNdisNumber)
                                .textFieldStyle(.roundedBorder)
                                .foregroundColor(StyleGuide.Colors.text)
                                .accentColor(ColorSystem.Primary.blue)
                                .onChange(of: viewModel.editableNdisNumber) { viewModel.updateAndSaveClient() }

                            Button(action: { copyToClipboard(viewModel.editableNdisNumber) }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(ColorSystem.Neutral.gray500)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Copy NDIS number")
                            .accessibilityHint("Copies NDIS number to clipboard")
                        }
                    }
                    .fluidListTransition()
                    .animation(.easeInOut(duration: StyleGuide.Animations.durationMedium), value: viewModel.editableHasNdisPlan)
                }

                if viewModel.editableHasNdisPlan {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("Type:")
                            .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(StyleGuide.Colors.text)

                        Picker("", selection: Binding(
                            get: { viewModel.editablePlanManagementType ?? "Self-Managed" },
                            set: { viewModel.editablePlanManagementType = $0; viewModel.updateAndSaveClient() }
                        )) {
                            Text("Self-Managed").tag("Self-Managed")
                            Text("Plan-Managed").tag("Plan-Managed")
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fluidListTransition()
                    .animation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping), value: viewModel.editableHasNdisPlan)
                }

                if viewModel.editableHasNdisPlan && viewModel.editablePlanManagementType == "Plan-Managed" {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("Plan Manager:")
                            .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(StyleGuide.Colors.text)

                        Picker("", selection: Binding(
                            get: { viewModel.selectedPlanManager?.id },
                            set: { newPlanManagerId in
                                viewModel.updatePlanManager(by: newPlanManagerId)
                            }
                        )) {
                            Text("Select Plan Manager").tag(nil as UUID?)
                            ForEach(planManagers) { planManager in
                                Text(planManager.name ?? "").tag(planManager.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fluidListTransition()
                    .animation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping), value: viewModel.editablePlanManagementType)
                }

                Spacer(minLength: 0)
            }
            .padding(DetailSectionTokens.contentPadding)
        } label: {
            DetailSectionHeader(icon: "person.circle", title: "Client Information")
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
