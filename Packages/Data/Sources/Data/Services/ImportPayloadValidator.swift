import Core
import Foundation

/// Validates untrusted import payloads before they reach SwiftData importers.
enum ImportPayloadValidator {
    static let maxJSONPayloadBytes = 100 * 1024 * 1024

    static func validateJSONImport(data: Data, source: ImportSource) throws {
        guard data.isEmpty == false else {
            throw ImportPayloadValidationError.emptyPayload
        }
        guard data.count <= maxJSONPayloadBytes else {
            throw ImportPayloadValidationError.payloadTooLarge(
                byteCount: data.count,
                limit: maxJSONPayloadBytes
            )
        }
        if EncryptedExportContainer.isEncryptedContainer(data) {
            throw ImportPayloadValidationError.encryptedPayloadRequiresPassphraseImport
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ImportPayloadValidationError.invalidJSON(underlying: error)
        }

        switch source {
        case .allData:
            try validateAllDataEnvelope(object)
        case .clients, .payees, .services, .invoices, .sessions:
            try validateEntityArrayEnvelope(object, source: source)
        case .ndisItems, .unknown:
            break
        }
    }

    private static func validateAllDataEnvelope(_ object: Any) throws {
        guard let envelope = object as? [String: Any] else {
            throw ImportPayloadValidationError.unexpectedTopLevelType(expected: "object")
        }
        guard envelope.isEmpty == false else {
            throw ImportPayloadValidationError.emptyPayload
        }
        let hasEntityCollection = envelope.values.contains { value in
            value is [[String: Any]] || value is [Any]
        }
        guard hasEntityCollection else {
            throw ImportPayloadValidationError.missingEntityCollections
        }
    }

    private static func validateEntityArrayEnvelope(_ object: Any, source: ImportSource) throws {
        guard let rows = object as? [Any] else {
            throw ImportPayloadValidationError.unexpectedTopLevelType(expected: "array")
        }
        guard rows.isEmpty || rows.allSatisfy({ $0 is [String: Any] }) else {
            throw ImportPayloadValidationError.invalidEntityRows(source: source)
        }
    }
}

public enum ImportPayloadValidationError: LocalizedError, Sendable {
    case emptyPayload
    case payloadTooLarge(byteCount: Int, limit: Int)
    case encryptedPayloadRequiresPassphraseImport
    case invalidJSON(underlying: Error)
    case unexpectedTopLevelType(expected: String)
    case missingEntityCollections
    case invalidEntityRows(source: ImportSource)

    public var errorDescription: String? {
        switch self {
        case .emptyPayload:
            return "Import file is empty."
        case let .payloadTooLarge(byteCount, limit):
            return "Import file is too large (\(byteCount) bytes). Maximum allowed size is \(limit) bytes."
        case .encryptedPayloadRequiresPassphraseImport:
            return "This file is an encrypted export (.invoicing-export). Decrypt it before importing, or re-export without encryption."
        case .invalidJSON:
            return "Import file is not valid JSON."
        case let .unexpectedTopLevelType(expected):
            return "Import JSON must be a top-level \(expected) for this import type."
        case .missingEntityCollections:
            return "All-data import must contain at least one entity collection."
        case let .invalidEntityRows(source):
            return "\(source.description) import must be a JSON array of objects."
        }
    }
}
