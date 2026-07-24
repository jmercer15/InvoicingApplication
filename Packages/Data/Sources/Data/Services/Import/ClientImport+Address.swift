import Foundation
import Core

extension ClientImport {
    
    internal static func formatAddressForComparison(client: ClientJSON) -> String {
        if let address = client.address {
            return address.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Create composite address from components
            return [
                client.addressLine1,
                client.addressLine2,
                client.addressCity ?? client.city,
                client.addressState ?? client.state,
                client.addressPostalCode ?? client.postalCode ?? client.zip
            ].compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    internal static func parseAddress(_ address: String) -> (line1: String?, line2: String?, city: String?, state: String?, postalCode: String?) {
        let lines = address.split(separator: "\n").map { String($0) }
        let line1 = lines.first
        let line2 = lines.count > 1 ? lines[1] : nil
        
        // Try to extract city, state, zip from the last line
        var city: String?
        var state: String?
        var postalCode: String?
        
        if let lastLine = lines.last {
            // Common patterns: "City, State ZIP" or "City State ZIP"
            let components = lastLine.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            if components.count > 1 {
                city = components[0]
                let stateZip = components[1].split(separator: " ").map { String($0) }
                state = stateZip.first
                postalCode = stateZip.last
            } else {
                // Try space-separated format
                let parts = lastLine.split(separator: " ").map { String($0) }
                if parts.count >= 3 {
                    if let lastPart = parts.last, lastPart.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil {
                        postalCode = lastPart
                        state = parts[parts.count - 2]
                        city = parts.dropLast(2).joined(separator: " ")
                    }
                }
            }
        }
        
        return (line1, line2, city, state, postalCode)
    }
    
    internal static func parseStreetAddress(_ street: String) -> (number: String?, name: String?) {
        let parts = street.split(separator: " ").map { String($0) }
        
        if parts.isEmpty {
            return (nil, nil)
        }
        
        if let firstPart = parts.first, firstPart.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil {
            return (firstPart, parts.dropFirst().joined(separator: " "))
        } else {
            for (index, part) in parts.enumerated() {
                if part.contains("/") && part.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil {
                    let beforeParts = parts[0..<index].joined(separator: " ")
                    let number = part
                    let afterParts = index + 1 < parts.count ? parts[(index + 1)...].joined(separator: " ") : ""
                    return (number, [beforeParts, afterParts].filter { !$0.isEmpty }.joined(separator: " "))
                }
            }
        }
        
        return (nil, street)
    }
    
    internal static func setAddressComponents(address: Address, components: (line1: String?, line2: String?, city: String?, state: String?, postalCode: String?)) {
        if let line1 = components.line1 {
            let streetComponents = parseStreetAddress(line1)
            address.streetNumber = streetComponents.number ?? ""
            address.streetName = streetComponents.name ?? ""
        }

        address.unitNumber = components.line2 ?? ""
        address.suburb = components.city ?? ""
        address.state = components.state ?? ""
        address.postcode = components.postalCode ?? ""
    }

    internal static func parseCoordinates(from text: String) -> (latitude: Double, longitude: Double)? {
        let pattern = #"(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)

        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges == 3 else {
            return nil
        }

        let latitudeString = nsText.substring(with: match.range(at: 1))
        let longitudeString = nsText.substring(with: match.range(at: 2))
        guard let latitude = Double(latitudeString),
              let longitude = Double(longitudeString),
              abs(latitude) <= 90,
              abs(longitude) <= 180 else {
            return nil
        }

        return (latitude, longitude)
    }
}
