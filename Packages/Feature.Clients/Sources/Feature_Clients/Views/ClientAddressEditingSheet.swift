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
        form.loadStructuredFields(from: viewModel)
        form.rebuildAddressSearchText(includeCity: viewModel.editableCity)
    }

    private func commitAddressChanges() {
        form.applyStructuredFields(to: viewModel)
        viewModel.commitAddressChanges()
    }
}
