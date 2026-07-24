import SwiftUI
import Data
import SharedUI

struct NativeSessionFormLocationSection: View {
    @Bindable var viewModel: NewSessionViewModel
    @Binding var showAddressEditingSheet: Bool

    private var hasAddressData: Bool {
        viewModel.formModel.hasStructuredAddressInput
    }

    var body: some View {
        GroupBox("Location") {
            VStack(spacing: FormSectionTokens.fieldStackSpacing) {
                if hasAddressData {
                    compactAddressView
                        .fluidListTransition()
                        .animation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping), value: hasAddressData)

                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
                        .fluidListTransition()
                        .animation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping), value: hasAddressData)
                } else if viewModel.sessionToEdit?.address != nil {
                    SessionAddressDisplayView(address: viewModel.sessionToEdit?.address)
                        .fluidListTransition()
                        .animation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping), value: viewModel.sessionToEdit?.address != nil)
                }

                HStack {
                    Spacer()
                    Button(hasAddressData ? "Edit Address" : "Add Address") {
                        showAddressEditingSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .background(Color.clear)
        .sheet(isPresented: $showAddressEditingSheet) {
            AddressEditingSheet(
                viewModel: viewModel,
                isPresented: $showAddressEditingSheet
            )
            .fluidSheetTransition()
            .animation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping), value: showAddressEditingSheet)
        }
    }

    private var compactAddressView: some View {
        HStack {
            Text(formatAddressForDisplay())
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundColor(StyleGuide.Colors.text)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall))
    }

    private func formatAddressForDisplay() -> String {
        SessionAddressFormatting.displayAddress(
            unitNumber: viewModel.formModel.unitNumber,
            streetNumber: viewModel.formModel.streetNumber,
            streetName: viewModel.formModel.streetName,
            suburb: viewModel.formModel.suburb,
            city: viewModel.formModel.city,
            state: viewModel.formModel.state,
            postcode: viewModel.formModel.postcode,
            country: viewModel.formModel.country,
            poBox: viewModel.formModel.poBox,
            streetComponentsSeparator: " "
        )
    }
}
