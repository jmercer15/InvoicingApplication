//
//  AddressSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation
import SwiftData

// MARK: - AddressSnapshot

public struct AddressSnapshot: Codable, Sendable, Equatable, Hashable {
    public var id: UUID
    public var country: String
    public var postcode: String
    public var state: String
    public var streetName: String
    public var streetNumber: String
    public var city: String
    public var suburb: String
    public var unitNumber: String
    public var poBox: String
    public var fullAddressText: String
    public var latitude: Double
    public var longitude: Double

    public init(
        id: UUID,
        country: String,
        postcode: String,
        state: String,
        streetName: String,
        streetNumber: String,
        city: String,
        suburb: String,
        unitNumber: String,
        poBox: String,
        fullAddressText: String = "",
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.country = country
        self.postcode = postcode
        self.state = state
        self.streetName = streetName
        self.streetNumber = streetNumber
        self.city = city
        self.suburb = suburb
        self.unitNumber = unitNumber
        self.poBox = poBox
        self.fullAddressText = fullAddressText
        self.latitude = latitude
        self.longitude = longitude
    }

    public init(_ address: Address) {
        self.init(
            id: address.id,
            country: address.country,
            postcode: address.postcode,
            state: address.state,
            streetName: address.streetName,
            streetNumber: address.streetNumber,
            city: address.city,
            suburb: address.suburb,
            unitNumber: address.unitNumber,
            poBox: address.poBox,
            fullAddressText: address.fullAddressText,
            latitude: address.latitude,
            longitude: address.longitude
        )
    }

    /// Mirrors `Address.fullFormattedAddress` at snapshot time (used by automation / billing).
    public var fullFormattedAddress: String {
        var components: [String] = []
        if !poBox.isEmpty {
            components.append("PO Box \(poBox)")
        } else {
            var streetComponents: [String] = []
            if !unitNumber.isEmpty { streetComponents.append("Unit \(unitNumber)") }
            var streetAddress = ""
            if !streetNumber.isEmpty { streetAddress += streetNumber }
            if !streetName.isEmpty {
                if !streetAddress.isEmpty { streetAddress += " " }
                streetAddress += streetName
            }
            if !streetAddress.isEmpty { streetComponents.append(streetAddress) }
            if !streetComponents.isEmpty {
                components.append(streetComponents.joined(separator: ", "))
            }
        }

        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSuburb = suburb.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCity.isEmpty {
            components.append(trimmedCity)
            if !trimmedSuburb.isEmpty,
               trimmedSuburb.caseInsensitiveCompare(trimmedCity) != .orderedSame {
                components.append(trimmedSuburb)
            }
        } else if !trimmedSuburb.isEmpty {
            components.append(trimmedSuburb)
        }
        if !state.isEmpty { components.append(state) }
        if !postcode.isEmpty { components.append(postcode) }
        if !country.isEmpty { components.append(country) }
        let composed = components.joined(separator: ", ")
        if !composed.isEmpty { return composed }
        return fullAddressText
    }
}

