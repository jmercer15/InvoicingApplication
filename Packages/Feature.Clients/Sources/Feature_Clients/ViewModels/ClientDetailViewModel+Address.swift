import SwiftData
import Core
import PersistenceModels
import Data
import SharedUI

extension ClientDetailViewModel {

    // MARK: - Address Search Result

    /// Applies picker / search `AddressData` onto editable fields (parity with session editor).
    func updateAddressFromSearchResult(_ address: AddressData) {
        address.copyToStructuredAddressFields(
            unitNumber: &editableUnitNumber,
            streetNumber: &editableStreetNumber,
            streetName: &editableStreetName,
            suburb: &editableSuburb,
            city: &editableCity,
            state: &editableState,
            postcode: &editablePostcode,
            country: &editableCountry,
            poBox: &editablePoBox
        )
    }

    // MARK: - Commit Address Edits

    func commitAddressChanges() {
        let address = client.address ?? Address()
        if client.address == nil { modelContext.insert(address); client.address = address }
        applyEditableAddressFields(to: address)
        Task { await saveClientUpdates() }
        isEditingAddress = false
    }
}
