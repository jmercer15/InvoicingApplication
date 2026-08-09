import Core
import PersistenceModels
import Foundation
import SwiftData

/// Catalogue import/export + NDIS maintenance paths (delegates to importer/exporter actors).
actor ImportExportCatalogOperations {
    private let dataImporterActor: DataImporterActor
    private let dataExporterActor: DataExporterActor

    init(dataImporterActor: DataImporterActor, dataExporterActor: DataExporterActor) {
        self.dataImporterActor = dataImporterActor
        self.dataExporterActor = dataExporterActor
    }

    func fetchAvailableEffectiveDates() async throws -> [Date] {
        try await dataImporterActor.fetchNDISEffectiveDates()
    }

    func importNDISItemsFromCSV(url: URL, fileName: String) async throws -> ImportResult {
        try await dataImporterActor.importNDISItemsFromCSV(url: url, fileName: fileName)
    }

    func importNDISItemsFromExcel(url: URL, fileName: String) async throws -> ImportResult {
        try await dataImporterActor.importNDISItemsFromExcel(url: url, fileName: fileName)
    }

    func importSpecificData(source: ImportSource, data: Data, fileName: String) async throws -> ImportResult {
        if source != .ndisItems {
            try ImportPayloadValidator.validateJSONImport(data: data, source: source)
        }
        return try await dataImporterActor.importSpecificData(type: source, data: data, fileName: fileName)
    }

    func importSpecificDataFromFile(url: URL, source: ImportSource) async throws -> ImportResult {
        let accessedSecurityScopedResource = url.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScopedResource {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let fileName = url.lastPathComponent
        let extensionName = url.pathExtension.lowercased()
        let normalizedSource = source == .unknown ? .unknown : source

        guard let supportedExtensions = allowedExtensions(for: normalizedSource) else {
            throw ImportExportCatalogError.unsupportedImportSource(normalizedSource)
        }
        guard extensionName.isEmpty == false, supportedExtensions.contains(extensionName) else {
            throw ImportExportCatalogError.unsupportedFileExtension(
                source: normalizedSource,
                fileExtension: extensionName,
                supportedExtensions: Array(supportedExtensions).sorted()
            )
        }

        switch normalizedSource {
        case .ndisItems:
            if extensionName == "csv" {
                return try await importNDISItemsFromCSV(url: url, fileName: fileName)
            }
            return try await importNDISItemsFromExcel(url: url, fileName: fileName)
        case .allData:
            let data = try await readFileData(url: url)
            return try await importAllData(fileData: data, fileName: fileName)
            // for all-data exports
        default:
            let data = try await readFileData(url: url)
            return try await importSpecificData(source: normalizedSource, data: data, fileName: fileName)
        }
    }

    func importAllData(fileData: Data, fileName: String) async throws -> ImportResult {
        try await dataImporterActor.importSpecificData(type: .allData, data: fileData, fileName: fileName)
    }

    func export(
        source: ImportSource,
        redaction: ExportRedactionPreset = .none,
        dateString: String? = nil,
        encryption: ExportEncryptionOptions? = nil
    ) async throws -> (data: Data, fileName: String) {
        let dateString = dateString ?? ImportExportTimestamp.fileSuffix()
        let redactedSuffix = redaction == .omitBankAndNDISIdentifiers ? "-Redacted" : ""
        let exportPayload: (data: Data, fileName: String) = switch source {
        case .clients:
            (
                try await dataExporterActor.exportClients(redaction: redaction),
                "Clients-Export-\(dateString)\(redactedSuffix).json"
            )
        case .payees:
            (
                try await dataExporterActor.exportPayees(redaction: redaction),
                "Payees-Export-\(dateString)\(redactedSuffix).json"
            )
        case .services:
            (
                try await dataExporterActor.exportServices(redaction: redaction),
                "Services-Export-\(dateString)\(redactedSuffix).json"
            )
        case .ndisItems:
            (
                try await dataExporterActor.exportNDISItems(redaction: redaction),
                "NDISItems-Export-\(dateString).json"
            )
        case .invoices:
            (
                try await dataExporterActor.exportInvoices(redaction: redaction),
                "Invoices-Export-\(dateString)\(redactedSuffix).json"
            )
        case .sessions:
            (
                try await dataExporterActor.exportSessions(redaction: redaction),
                "Sessions-Export-\(dateString)\(redactedSuffix).json"
            )
        case .allData:
            (
                try await dataExporterActor.exportAllEntitiesToJSON(redaction: redaction),
                "AllData-Export-\(dateString)\(redactedSuffix).json"
            )
        case .unknown:
            throw NSError(
                domain: "ImportExportCoordinatorError",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported export source"]
            )
        }
        return try applyEncryptionIfNeeded(to: exportPayload, encryption: encryption)
    }

    func exportAllData(
        redaction: ExportRedactionPreset = .none,
        dateString: String? = nil,
        encryption: ExportEncryptionOptions? = nil
    ) async throws -> (data: Data, fileName: String) {
        let dateString = dateString ?? ImportExportTimestamp.fileSuffix()
        let redactedSuffix = redaction == .omitBankAndNDISIdentifiers ? "-Redacted" : ""
        let data = try await dataExporterActor.exportAllEntitiesToJSON(redaction: redaction)
        return try applyEncryptionIfNeeded(
            to: (data, "AllData-Export-\(dateString)\(redactedSuffix).json"),
            encryption: encryption
        )
    }

    func recalculateCurrentStatus() async throws -> (updated: Int, total: Int) {
        let updated = try await dataImporterActor.recalculateAllCurrentFlags()
        let total = try await dataImporterActor.countNDISItems()
        return (updated: updated, total: total)
    }

    func clearAllNDISItems() async throws -> (deletedItems: Int, deletedPrices: Int) {
        try await dataImporterActor.clearAllNDISItems()
    }

    private func readFileData(url: URL) async throws -> Data {
        try await Task(priority: .userInitiated) {
            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let fileSize = attributes[.size] as? NSNumber,
                   fileSize.intValue > ImportPayloadValidator.maxJSONPayloadBytes {
                    throw ImportPayloadValidationError.payloadTooLarge(
                        byteCount: fileSize.intValue,
                        limit: ImportPayloadValidator.maxJSONPayloadBytes
                    )
                }
                return data
            } catch let validation as ImportPayloadValidationError {
                throw validation
            } catch {
                throw ImportExportCatalogError.unableToReadInputFile(url: url, underlying: error)
            }
        }.value
    }

    private func applyEncryptionIfNeeded(
        to payload: (data: Data, fileName: String),
        encryption: ExportEncryptionOptions?
    ) throws -> (data: Data, fileName: String) {
        guard let encryption else { return payload }
        let encrypted = try EncryptedExportContainer.encrypt(plaintext: payload.data, passphrase: encryption.passphrase)
        let encryptedName = payload.fileName.replacingOccurrences(
            of: ".json",
            with: ".\(EncryptedExportContainer.fileExtension)"
        )
        return (encrypted, encryptedName)
    }
    
    private func allowedExtensions(for source: ImportSource) -> Set<String>? {
        switch source {
        case .ndisItems:
            return ["csv", "xls", "xlsx"]
        case .allData:
            return ["json"]
        case .unknown:
            return nil
        default:
            return ["json"]
        }
    }
}

public enum ImportExportCatalogError: LocalizedError, Sendable {
    case unsupportedFileExtension(source: ImportSource, fileExtension: String, supportedExtensions: [String])
    case unsupportedImportSource(ImportSource)
    case unableToReadInputFile(url: URL, underlying: Error)
    
    public var errorDescription: String? {
        switch self {
        case let .unsupportedFileExtension(source, fileExtension, supportedExtensions):
            let supported = supportedExtensions.sorted().joined(separator: ", ")
            let extensionText = fileExtension.isEmpty ? "<no extension>" : fileExtension
            return "Unsupported file type for \(source.description): \(extensionText). Supported extensions: \(supported)"
        case .unsupportedImportSource(let source):
            return "Unsupported import source: \(source.description)"
        case .unableToReadInputFile(_, let underlying):
            return "Unable to read selected input file: \(underlying.localizedDescription)"
        }
    }
}
