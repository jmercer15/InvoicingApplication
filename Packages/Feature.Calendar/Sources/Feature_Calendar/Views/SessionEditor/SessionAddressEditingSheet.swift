import SwiftUI
import SharedUI
import WorkspaceUI

// MARK: - Session address editing sheet

/// Wraps shared ``WorkspaceUI/AddressFormSheet`` with session form bindings, cancel snapshot restore, and calendar chrome.
struct SessionAddressEditingSheet: View {
    @Bindable var viewModel: NewSessionViewModel
    @Binding var isPresented: Bool

    @State private var form = AddressFormState()
    @State private var addressUndoSnapshot: SessionFormModel.AddressEditingUndoSnapshot?

    var body: some View {
        ZStack {
            AppSheetBackdrop()
                .ignoresSafeArea()

            AddressFormSheet(
                state: form,
                isPresented: $isPresented,
                hasAddressDataOverride: viewModel.formModel.hasStructuredAddressInput,
                onSearchAddressSelected: { addressData in
                    viewModel.updateAddressFromSearchResult(addressData)
                    loadFormFromViewModel()
                },
                onCommit: {
                    commitFormToViewModel()
                },
                onCancel: {
                    restoreAddressFromUndoSnapshot()
                }
            )
        }
        .onAppear {
            loadFormFromViewModel()
        }
        .onChange(of: isPresented) { _, isOpen in
            if isOpen {
                addressUndoSnapshot = viewModel.formModel.addressEditingUndoSnapshot
                loadFormFromViewModel()
            }
        }
    }

    private func loadFormFromViewModel() {
        form.unitNumber = viewModel.formModel.unitNumber
        form.streetNumber = viewModel.formModel.streetNumber
        form.streetName = viewModel.formModel.streetName
        form.suburb = viewModel.formModel.suburb
        form.postcode = viewModel.formModel.postcode
        form.state = viewModel.formModel.state
        form.country = viewModel.formModel.country
        form.poBox = viewModel.formModel.poBox
        form.addressSearchText = viewModel.formModel.addressSearchText
        form.selectedAddress = viewModel.formModel.selectedAddress
    }

    private func commitFormToViewModel() {
        var updated = viewModel.formModel
        updated.unitNumber = form.unitNumber
        updated.streetNumber = form.streetNumber
        updated.streetName = form.streetName
        updated.suburb = form.suburb
        updated.postcode = form.postcode
        updated.state = form.state
        updated.country = form.country
        updated.poBox = form.poBox
        updated.addressSearchText = form.addressSearchText
        updated.selectedAddress = form.selectedAddress
        viewModel.formModel = updated
    }

    private func restoreAddressFromUndoSnapshot() {
        guard let snapshot = addressUndoSnapshot else { return }
        var updated = viewModel.formModel
        updated.restoreAddressEditingUndo(snapshot)
        viewModel.formModel = updated
        loadFormFromViewModel()
    }
}
