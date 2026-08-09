import SwiftUI

extension ClientDetailView {
    enum ClientDetailSheet: String, Identifiable {
        case serviceAssignment
        case serviceBulkEditor
        case serviceAgreement
        case clientService
        case map
        case addressEditing

        var id: String { rawValue }
    }

    var activeSheet: ClientDetailSheet? {
        if showingServiceAssignment { return .serviceAssignment }
        if viewModel.isPresentingServiceBulkEditor { return .serviceBulkEditor }
        if viewModel.isPresentingServiceAgreementSheet { return .serviceAgreement }
        if viewModel.isPresentingClientServiceSheet { return .clientService }
        if showingMapSheet { return .map }
        if showingAddressEditingSheet { return .addressEditing }
        return nil
    }

    var activeSheetBinding: Binding<ClientDetailSheet?> {
        Binding(
            get: { activeSheet },
            set: { newValue in
                guard newValue == nil else { return }
                showingServiceAssignment = false
                showingMapSheet = false
                showingAddressEditingSheet = false
                viewModel.isPresentingServiceBulkEditor = false
                viewModel.isPresentingServiceAgreementSheet = false
                viewModel.isPresentingClientServiceSheet = false
            }
        )
    }

    func handleServiceBulkEditorDismiss() {
        guard reopenServiceAssignmentAfterBulkEditor else { return }
        reopenServiceAssignmentAfterBulkEditor = false
        showingServiceAssignment = true
    }
}
