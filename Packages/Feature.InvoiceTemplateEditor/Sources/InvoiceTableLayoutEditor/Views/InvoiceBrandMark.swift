import Foundation

enum InvoiceBrandMark {
    static func initials(for businessName: String) -> String {
        let words = businessName.split { character in
            !character.isLetter && !character.isNumber
        }
        let initials = words.prefix(2).compactMap(\.first)
        guard !initials.isEmpty else { return "IN" }
        return String(initials).uppercased()
    }
}
