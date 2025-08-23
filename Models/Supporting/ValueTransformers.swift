import Foundation

import AppKit



// ADD: Transformer specifically for [Date]
@objc(DateArrayValueTransformer)
final class DateArrayValueTransformer: NSSecureUnarchiveFromDataTransformer {

    static let name = NSValueTransformerName(rawValue: "DateArrayValueTransformer")

    override static var allowedTopLevelClasses: [AnyClass] {
        // IMPORTANT: Allow NSArray and NSDate for secure coding/decoding
        return [NSArray.self, NSDate.self]
    }

    public static func register() {
        let transformer = DateArrayValueTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)
        print("Registered DateArrayValueTransformer") // Add print statement for confirmation
    }
}

