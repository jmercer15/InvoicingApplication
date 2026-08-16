import SwiftUI
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
                RelationshipDetailCopyableFieldRow(
                    label: "Name:",
                    maxLabelWidth: maxLabelWidth,
                    placeholder: "Enter business name",
                    text: $viewModel.editableBusinessName,
                    errorMessage: viewModel.businessNameError,
                    copyAccessibilityLabel: "Copy business name",
                    copyAccessibilityHint: "Copies business name to clipboard",
                    onCopy: { viewModel.copyToClipboard(viewModel.editableBusinessName) },
                    onTextChange: { viewModel.updateAndSavePlanManager() }
                )

                RelationshipDetailCopyableFieldRow(
                    label: "ABN:",
                    maxLabelWidth: maxLabelWidth,
                    placeholder: "Enter ABN",
                    text: $viewModel.editableAbn,
                    errorMessage: viewModel.abnError,
                    copyAccessibilityLabel: "Copy ABN",
                    copyAccessibilityHint: "Copies ABN to clipboard",
                    onCopy: { viewModel.copyToClipboard(viewModel.editableAbn) },
                    onTextChange: { viewModel.updateAndSavePlanManager() }
                )

                RelationshipDetailCopyableFieldRow(
                    label: "Email:",
                    maxLabelWidth: maxLabelWidth,
                    placeholder: "Enter email address",
                    text: $viewModel.emailValidator.email,
                    errorMessage: viewModel.emailValidator.validationMessage,
                    copyAccessibilityLabel: "Copy email address",
                    copyAccessibilityHint: "Copies email address to clipboard",
                    onCopy: { viewModel.copyToClipboard(viewModel.emailValidator.email) },
                    onTextChange: {
                        if viewModel.emailValidator.isValid {
                            viewModel.updateAndSavePlanManager()
                        }
                    }
                )

                RelationshipDetailCopyableFieldRow(
                    label: "Phone:",
                    maxLabelWidth: maxLabelWidth,
                    placeholder: "Enter phone number",
                    text: $viewModel.phoneFormatter.phoneNumber,
                    errorMessage: viewModel.phoneFormatter.validationMessage,
                    copyAccessibilityLabel: "Copy phone number",
                    copyAccessibilityHint: "Copies phone number to clipboard",
                    onCopy: { viewModel.copyToClipboard(viewModel.phoneFormatter.phoneNumber) },
                    onTextChange: {
                        if viewModel.phoneFormatter.isValid {
                            viewModel.updateAndSavePlanManager()
                        }
                    }
                )

                RelationshipDetailAddressRow(
                    maxLabelWidth: maxLabelWidth,
                    hasAddressData: hasAddressData,
                    addressText: addressText,
                    showingMapSheet: $showingMapSheet,
                    showingAddressEditingSheet: $showingAddressEditingSheet
                )
                .fluidListTransition()
                .animation(
                    .spring(
                        response: StyleGuide.Animations.springResponse,
                        dampingFraction: StyleGuide.Animations.springDamping
                    ),
                    value: hasAddressData
                )

                Spacer(minLength: 0)
            }
            .padding(DetailSectionTokens.contentPadding)
        } label: {
            DetailSectionHeader(icon: "building.2", title: "Plan Manager Information")
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
    }
}
