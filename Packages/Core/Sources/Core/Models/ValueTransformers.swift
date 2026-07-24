import Foundation

public enum PersistenceValueTransformers {
    public static func registerAll() {
        DateArrayValueTransformer.register()
    }
}

@objc(DateArrayValueTransformer)
final class DateArrayValueTransformer: NSSecureUnarchiveFromDataTransformer {
    static let name = NSValueTransformerName(rawValue: "DateArrayValueTransformer")

    override class var allowedTopLevelClasses: [AnyClass] {
        [NSArray.self, NSDate.self]
    }

    static func register() {
        ValueTransformer.setValueTransformer(DateArrayValueTransformer(), forName: name)
    }
}

public enum PersistenceAttributeCoder {
    public static let encoder = JSONEncoder()
    public static let decoder = JSONDecoder()

    public static func encodeString(_ value: String) -> Data? {
        try? encoder.encode(value)
    }

    public static func decodeString(from value: Any?) -> String? {
        if let data = value as? Data {
            if let string = try? decoder.decode(String.self, from: data) {
                return string
            }
            if let legacyString = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data) {
                return legacyString as String
            }
        }

        if let string = value as? String {
            return string
        }

        if let nsString = value as? NSString {
            return nsString as String
        }

        return nil
    }

    public static func encodeEnum<EnumType: RawRepresentable>(_ value: EnumType?) -> Data? where EnumType.RawValue == String {
        guard let value else { return nil }
        return encodeString(value.rawValue)
    }

    public static func decodeEnum<EnumType: RawRepresentable>(from data: Data?) -> EnumType? where EnumType.RawValue == String {
        guard let rawValue = decodeString(from: data) else { return nil }
        return EnumType(rawValue: rawValue)
    }

    public static func encodeAddress(_ address: AddressSnapshot?) -> Data? {
        guard let address else { return nil }
        return try? encoder.encode(address)
    }

    public static func decodeAddress(from data: Data?) -> AddressSnapshot? {
        guard let data else { return nil }

        if let address = try? decoder.decode(AddressSnapshot.self, from: data) {
            return address
        }

        if let legacyDictionary = try? NSKeyedUnarchiver.unarchivedObject(
            ofClasses: [
                NSDictionary.self,
                NSArray.self,
                NSString.self,
                NSNumber.self,
                NSUUID.self,
            ],
            from: data
        ) as? NSDictionary {
            return address(from: legacyDictionary)
        }

        return nil
    }

    private static func address(from dictionary: NSDictionary) -> AddressSnapshot? {
        func string(_ key: String) -> String {
            if let value = dictionary[key] as? String {
                return value
            }
            if let value = dictionary[key] as? NSString {
                return value as String
            }
            return ""
        }

        func double(_ key: String) -> Double {
            if let value = dictionary[key] as? Double {
                return value
            }
            if let value = dictionary[key] as? NSNumber {
                return value.doubleValue
            }
            return 0
        }

        let idValue: UUID = {
            if let uuid = dictionary["id"] as? UUID {
                return uuid
            }
            if let uuid = dictionary["id"] as? NSUUID {
                return uuid as UUID
            }
            if let string = dictionary["id"] as? String, let uuid = UUID(uuidString: string) {
                return uuid
            }
            return UUID()
        }()

        return AddressSnapshot(
            id: idValue,
            country: string("country"),
            postcode: string("postcode"),
            state: string("state"),
            streetName: string("streetName"),
            streetNumber: string("streetNumber"),
            city: string("city"),
            suburb: string("suburb"),
            unitNumber: string("unitNumber"),
            poBox: string("poBox"),
            latitude: double("latitude"),
            longitude: double("longitude")
        )
    }
}
