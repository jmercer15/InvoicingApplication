import Foundation

/// Field-redaction options for Settings JSON exports.
///
/// Redaction presets omit selected sensitive columns while keeping records usable for
/// non-claim backups (names, dates, amounts). Full-fidelity exports remain available via `.none`.
public enum ExportRedactionPreset: String, CaseIterable, Codable, Sendable, Identifiable {
    case none
    case omitBankAndNDISIdentifiers

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none:
            return "Full export"
        case .omitBankAndNDISIdentifiers:
            return "Omit bank & NDIS IDs"
        }
    }

    public var summary: String {
        switch self {
        case .none:
            return "Includes banking details and participant NDIS numbers."
        case .omitBankAndNDISIdentifiers:
            return "Removes bank account fields, participant NDIS numbers, support-log participant names, and claim submission references. Support-item catalogue codes are kept. BPR claim CSV exports are unchanged."
        }
    }
}

/// Classifies export sources for consent and copy.
public enum ExportSensitivity: Sendable {
    /// Catalogue/reference exports without participant identifiers.
    case reference
    /// Exports that include participant, payee, or financial account identifiers.
    case piiHeavy

    public static func level(for source: ImportSource) -> ExportSensitivity {
        switch source {
        case .ndisItems:
            return .reference
        case .clients, .payees, .services, .invoices, .sessions, .allData, .unknown:
            return .piiHeavy
        }
    }

    public static func requiresConsent(for source: ImportSource) -> Bool {
        level(for: source) == .piiHeavy
    }

    public static func consentTitle(for kind: ExportConsentKind) -> String {
        switch kind {
        case .single(let source):
            return "Export \(source.description)?"
        case .allData:
            return "Export all data?"
        }
    }

    public static func consentMessage(for kind: ExportConsentKind, preset: ExportRedactionPreset) -> String {
        let base: String = switch kind {
        case .single(let source):
            if source == .payees || source == .invoices {
                "This export includes personally identifiable information such as client names, contact details, invoice amounts, and banking details."
            } else {
                "This export includes personally identifiable information such as client names, contact details, invoice amounts, and related business records."
            }
        case .allData:
            "This exports every entity in plaintext JSON, including client and payee contact details, NDIS participant numbers, invoice banking details, and claim metadata."
        }

        if preset == .omitBankAndNDISIdentifiers {
            return base + "\n\nRedaction preset: \(preset.displayName) — \(preset.summary)"
        }
        return base + "\n\nRedaction preset: \(preset.displayName). Store the saved file on an encrypted volume and limit sharing."
    }
}

public enum ExportConsentKind: Sendable, Equatable {
    case single(ImportSource)
    case allData
}
