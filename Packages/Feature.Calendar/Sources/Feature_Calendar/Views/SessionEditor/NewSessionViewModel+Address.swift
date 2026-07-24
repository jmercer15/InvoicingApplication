import Foundation
import Core
import Data
import SharedUI

extension NewSessionViewModel {

    // MARK: - Address Search Result

    func updateAddressFromSearchResult(_ address: AddressData) {
        var updated = formModel
        address.copyToStructuredAddressFields(
            unitNumber: &updated.unitNumber,
            streetNumber: &updated.streetNumber,
            streetName: &updated.streetName,
            suburb: &updated.suburb,
            city: &updated.city,
            state: &updated.state,
            postcode: &updated.postcode,
            country: &updated.country,
            poBox: &updated.poBox
        )
        formModel = updated
    }

    // MARK: - Clear Address

    func clearFormAddress() {
        var updated = formModel
        updated.unitNumber         = ""
        updated.streetNumber       = ""
        updated.streetName         = ""
        updated.suburb             = ""
        updated.city               = ""
        updated.state              = ""
        updated.postcode           = ""
        updated.country            = ""
        updated.poBox              = ""
        updated.sessionLatitude    = 0.0
        updated.sessionLongitude   = 0.0
        updated.addressSearchText  = ""
        updated.selectedAddress    = nil
        formModel = updated
    }

    // MARK: - Populate from Persisted Address

    func populateFormFromAddress(_ address: Address) {
        var updated = formModel
        updated.unitNumber       = address.unitNumber
        updated.streetNumber     = address.streetNumber
        updated.streetName       = address.streetName
        updated.suburb           = address.suburb
        updated.city             = address.city
        updated.state            = address.state
        updated.postcode         = address.postcode
        updated.country          = address.country
        updated.poBox            = address.poBox
        updated.sessionLatitude  = address.latitude
        updated.sessionLongitude = address.longitude
        formModel = updated
    }
}
