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
                RelationshipDetailCopyableFieldRow(
                    label: "Name:",
                    maxLabelWidth: maxLabelWidth,
                    placeholder: "Enter payee name",
                    text: $viewModel.editableFullName,
                    errorMessage: viewModel.fullNameError,
                    copyAccessibilityLabel: "Copy payee name",
                    copyAccessibilityHint: "Copies payee name to clipboard",
                    onCopy: { viewModel.copyToClipboard(viewModel.editableFullName) },
                    onTextChange: { viewModel.updateAndSavePayee() }
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
                            viewModel.updateAndSavePayee()
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
                            viewModel.updateAndSavePayee()
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
            DetailSectionHeader(icon: "person.text.rectangle", title: "Payee Information")
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
    }
}
