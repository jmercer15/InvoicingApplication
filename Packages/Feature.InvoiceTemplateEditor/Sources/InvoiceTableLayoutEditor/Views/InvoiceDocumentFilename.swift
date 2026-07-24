import Foundation

enum InvoiceDocumentFilename {
    private static let fallbackInvoiceNumber = "Invoice"
    private static let maximumInvoiceNumberUTF8Length = 96
    private static let forbiddenCharacters = CharacterSet(charactersIn: "<>:\"/\\|?*")
    private static let trimmingCharacters = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: ".-"))

    static func pdf(invoiceNumber: String) -> String {
        "Invoice-\(safeInvoiceNumber(invoiceNumber)).pdf"
    }

    static func safeInvoiceNumber(_ invoiceNumber: String) -> String {
        var sanitized = ""
        var lastCharacterWasReplacement = false

        for character in invoiceNumber {
            let mustReplace = character.unicodeScalars.contains { scalar in
                CharacterSet.controlCharacters.contains(scalar)
                    || forbiddenCharacters.contains(scalar)
            }

            if mustReplace {
                if !sanitized.isEmpty, !lastCharacterWasReplacement {
                    sanitized.append("-")
                }
                lastCharacterWasReplacement = true
            } else {
                sanitized.append(character)
                lastCharacterWasReplacement = false
            }
        }

        let normalizedWhitespace = sanitized
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
        let trimmed = normalizedWhitespace.trimmingCharacters(in: trimmingCharacters)
        var limited = ""
        var utf8Length = 0
        for character in trimmed {
            let characterLength = character.utf8.count
            guard utf8Length + characterLength <= maximumInvoiceNumberUTF8Length else { break }
            limited.append(character)
            utf8Length += characterLength
        }
        limited = limited.trimmingCharacters(in: trimmingCharacters)

        return limited.isEmpty ? fallbackInvoiceNumber : limited
    }
}
