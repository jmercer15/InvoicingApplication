import Core

/// Shared load/apply for relationship entity address editing (client, payee, plan manager).
struct RelationshipAddressEditableFields: Equatable {
    var unitNumber = ""
    var streetNumber = ""
    var streetName = ""
    var suburb = ""
    var city = ""
    var postcode = ""
    var state = ""
    var country = "Australia"
    var poBox = ""

    init(
        unitNumber: String = "",
        streetNumber: String = "",
        streetName: String = "",
        suburb: String = "",
        city: String = "",
        postcode: String = "",
        state: String = "",
        country: String = "Australia",
        poBox: String = ""
    ) {
        self.unitNumber = unitNumber
        self.streetNumber = streetNumber
        self.streetName = streetName
        self.suburb = suburb
        self.city = city
        self.postcode = postcode
        self.state = state
        self.country = country
        self.poBox = poBox
    }

    init(from address: Address?) {
        self.init()
        guard let address else { return }
        unitNumber = address.unitNumber
        streetNumber = address.streetNumber
        streetName = address.streetName
        suburb = address.suburb
        city = address.city
        postcode = address.postcode
        state = address.state
        country = address.country.isEmpty ? "Australia" : address.country
        poBox = address.poBox
    }

    func apply(to address: Address) {
        address.unitNumber = unitNumber
        address.streetNumber = streetNumber
        address.streetName = streetName
        address.suburb = suburb
        address.city = city
        address.state = state
        address.postcode = postcode
        address.country = country.isEmpty ? "Australia" : country
        address.poBox = poBox
        address.fullAddressText = address.fullFormattedAddress
    }
}

@MainActor
protocol RelationshipAddressFieldStorage: AnyObject {
    var editableUnitNumber: String { get set }
    var editableStreetNumber: String { get set }
    var editableStreetName: String { get set }
    var editableSuburb: String { get set }
    var editableCity: String { get set }
    var editablePostcode: String { get set }
    var editableState: String { get set }
    var editableCountry: String { get set }
    var editablePoBox: String { get set }
}

extension RelationshipAddressFieldStorage {
    func loadAddressFields(from address: Address?) {
        assign(RelationshipAddressEditableFields(from: address))
    }

    func applyEditableAddressFields(to address: Address) {
        RelationshipAddressEditableFields(
            unitNumber: editableUnitNumber,
            streetNumber: editableStreetNumber,
            streetName: editableStreetName,
            suburb: editableSuburb,
            city: editableCity,
            postcode: editablePostcode,
            state: editableState,
            country: editableCountry,
            poBox: editablePoBox
        ).apply(to: address)
    }

    fileprivate func assign(_ fields: RelationshipAddressEditableFields) {
        editableUnitNumber = fields.unitNumber
        editableStreetNumber = fields.streetNumber
        editableStreetName = fields.streetName
        editableSuburb = fields.suburb
        editableCity = fields.city
        editablePostcode = fields.postcode
        editableState = fields.state
        editableCountry = fields.country
        editablePoBox = fields.poBox
    }
}

extension ClientDetailViewModel: RelationshipAddressFieldStorage {}
extension PayeeDetailViewModel: RelationshipAddressFieldStorage {}
extension PlanManagerDetailViewModel: RelationshipAddressFieldStorage {}
