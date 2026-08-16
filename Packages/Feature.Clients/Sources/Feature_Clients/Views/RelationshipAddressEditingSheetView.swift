import SwiftUI
import PersistenceModels
import SharedUI
import WorkspaceUI

/// Shared address editing sheet for payee / plan manager detail screens.
struct RelationshipAddressEditingSheetView<ViewModel: RelationshipAddressEditingViewModel & Observable>: View {
    @Bindable var viewModel: ViewModel
    @Binding var isPresented: Bool

    @State private var form = AddressFormState()

    var body: some View {
        AddressFormSheet(
            state: form,
            isPresented: $isPresented,
            hasAddressDataOverride: form.hasAddressData || viewModel.persistedAddress != nil,
            onSearchAddressSelected: { viewModel.updateAddressFromSearchResult($0) },
            onCommit: {
                form.applyStructuredFields(to: viewModel)
                viewModel.commitAddressChanges(autosave: true)
            }
        )
        .onAppear {
            viewModel.loadAddressDetails()
            form.loadStructuredFields(from: viewModel)
            if let address = viewModel.persistedAddress {
                form.addressSearchText = viewModel.formattedAddressString(from: address)
            }
        }
    }
}
