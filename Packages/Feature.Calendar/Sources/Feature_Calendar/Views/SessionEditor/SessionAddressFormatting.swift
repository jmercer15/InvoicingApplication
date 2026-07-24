enum SessionAddressFormatting {
    static func displayAddress(
        unitNumber: String,
        streetNumber: String,
        streetName: String,
        suburb: String,
        city: String = "",
        state: String,
        postcode: String,
        country: String,
        poBox: String,
        streetComponentsSeparator: String = ", "
    ) -> String {
        var parts: [String] = []

        if !poBox.isEmpty {
            parts.append("PO Box \(poBox)")
        } else {
            var streetComponents: [String] = []

            if !unitNumber.isEmpty {
                streetComponents.append("Unit \(unitNumber)")
            }

            let streetAddress = [streetNumber, streetName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            if !streetAddress.isEmpty {
                streetComponents.append(streetAddress)
            }

            if !streetComponents.isEmpty {
                parts.append(streetComponents.joined(separator: streetComponentsSeparator))
            }
        }

        let locality = suburb.isEmpty ? city : suburb
        if !locality.isEmpty { parts.append(locality) }
        if !state.isEmpty { parts.append(state) }
        if !postcode.isEmpty { parts.append(postcode) }
        if !country.isEmpty { parts.append(country) }

        return parts.joined(separator: ", ")
    }
}
