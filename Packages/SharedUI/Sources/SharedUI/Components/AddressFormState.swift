import Foundation
import Observation

/// Holds editable address fields shared by client / payee / plan manager flows.
@Observable
@MainActor
public final class AddressFormState {
    public var unitNumber: String = ""
    public var streetNumber: String = ""
    public var streetName: String = ""
    public var suburb: String = ""
    public var postcode: String = ""
    public var state: String = ""
    public var country: String = ""
    public var poBox: String = ""
    public var addressSearchText: String = ""
    public var selectedAddress: AddressData?

    public init() {}

    public var hasAddressData: Bool {
        !unitNumber.isEmpty || !streetNumber.isEmpty || !streetName.isEmpty ||
            !suburb.isEmpty || !state.isEmpty || !postcode.isEmpty ||
            !country.isEmpty || !poBox.isEmpty
    }

    /// Sets ``addressSearchText`` from structured fields and optional locality (e.g. model `city` when suburb alone omits it).
    public func rebuildAddressSearchText(includeCity city: String = "") {
        addressSearchText = [
            unitNumber,
            streetNumber,
            streetName,
            suburb,
            city,
            state,
            postcode,
            country
        ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    public func clear() {
        unitNumber = ""
        streetNumber = ""
        streetName = ""
        suburb = ""
        state = ""
        postcode = ""
        country = ""
        poBox = ""
        addressSearchText = ""
        selectedAddress = nil
    }
}
