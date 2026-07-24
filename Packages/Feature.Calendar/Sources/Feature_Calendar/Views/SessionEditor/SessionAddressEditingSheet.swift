import SwiftUI
import SharedUI
import WorkspaceUI

// MARK: - Session address editing sheet

/// Wraps shared ``WorkspaceUI/AddressEditingSheet`` with session form bindings, cancel snapshot restore, and calendar chrome.
struct AddressEditingSheet: View {
    @Bindable var viewModel: NewSessionViewModel
    @Binding var isPresented: Bool

    @State private var addressUndoSnapshot: SessionFormModel.AddressEditingUndoSnapshot?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    StyleGuide.Colors.background,
                    StyleGuide.Colors.background.opacity(0.95),
                    StyleGuide.Colors.background.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            WorkspaceUI.AddressEditingSheet(
                isPresented: $isPresented,
                unitNumber: viewModel.formBinding(\.unitNumber),
                streetNumber: viewModel.formBinding(\.streetNumber),
                streetName: viewModel.formBinding(\.streetName),
                suburb: viewModel.formBinding(\.suburb),
                postcode: viewModel.formBinding(\.postcode),
                state: viewModel.formBinding(\.state),
                country: viewModel.formBinding(\.country),
                poBox: viewModel.formBinding(\.poBox),
                addressSearchText: viewModel.formBinding(\.addressSearchText),
                selectedAddress: viewModel.formBinding(\.selectedAddress),
                hasAddressData: viewModel.formModel.hasStructuredAddressInput,
                onSearchAddressSelected: { viewModel.updateAddressFromSearchResult($0) },
                onCommit: {},
                onClear: { viewModel.clearFormAddress() },
                onCancel: { restoreAddressFromUndoSnapshot() }
            )
        }
        .onChange(of: isPresented) { _, isOpen in
            if isOpen {
                addressUndoSnapshot = viewModel.formModel.addressEditingUndoSnapshot
            }
        }
    }

    private func restoreAddressFromUndoSnapshot() {
        guard let snapshot = addressUndoSnapshot else { return }
        var updated = viewModel.formModel
        updated.restoreAddressEditingUndo(snapshot)
        viewModel.formModel = updated
    }
}
