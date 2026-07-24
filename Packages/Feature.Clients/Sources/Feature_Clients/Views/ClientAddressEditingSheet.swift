import SwiftUI
import Observation
import SharedUI
import WorkspaceUI

// MARK: - Client Address Editing Sheet

struct ClientAddressEditingSheet: View {
    @Bindable var viewModel: ClientDetailViewModel
    @Binding var isPresented: Bool

    @State private var form = AddressFormState()

    var body: some View {
        AddressFormSheet(
            state: form,
            isPresented: $isPresented,
            onSearchAddressSelected: { viewModel.updateAddressFromSearchResult($0) },
            onCommit: commitAddressChanges
        )
            .onAppear {
                loadExistingAddressData()
            }
    }

    private func loadExistingAddressData() {
        form.unitNumber = viewModel.editableUnitNumber
        form.streetNumber = viewModel.editableStreetNumber
        form.streetName = viewModel.editableStreetName
        form.suburb = viewModel.editableSuburb
        form.postcode = viewModel.editablePostcode
        form.state = viewModel.editableState
        form.country = viewModel.editableCountry
        form.poBox = viewModel.editablePoBox

        form.rebuildAddressSearchText(includeCity: viewModel.editableCity)
    }

    private func commitAddressChanges() {
        viewModel.editableUnitNumber = form.unitNumber
        viewModel.editableStreetNumber = form.streetNumber
        viewModel.editableStreetName = form.streetName
        viewModel.editableSuburb = form.suburb
        viewModel.editableCity = form.suburb
        viewModel.editablePostcode = form.postcode
        viewModel.editableState = form.state
        viewModel.editableCountry = form.country
        viewModel.editablePoBox = form.poBox

        viewModel.commitAddressChanges()
    }
}
