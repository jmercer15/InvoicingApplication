import Core
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
        try await dataImporterActor.importSpecificData(type: source, data: data, fileName: fileName)
    }

    func importSpecificDataFromFile(url: URL, source: ImportSource) async throws -> ImportResult {
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

    func importAllData() async throws -> [ImportResult] {
        try await dataImporterActor.importAllData()
    }

    func importAllData(fileData: Data, fileName: String) async throws -> ImportResult {
        try await dataImporterActor.importSpecificData(type: .allData, data: fileData, fileName: fileName)
    }

    func export(source: ImportSource, dateString: String? = nil) async throws -> (data: Data, fileName: String) {
        let dateString = dateString ?? ImportExportTimestamp.fileSuffix()
        switch source {
        case .clients:
            let data = try await dataExporterActor.exportClients()
            return (data, "Clients-Export-\(dateString).json")
        case .payees:
            let data = try await dataExporterActor.exportPayees()
            return (data, "Payees-Export-\(dateString).json")
        case .services:
            let data = try await dataExporterActor.exportServices()
            return (data, "Services-Export-\(dateString).json")
        case .ndisItems:
            let data = try await dataExporterActor.exportNDISItems()
            return (data, "NDISItems-Export-\(dateString).json")
        case .invoices:
            let data = try await dataExporterActor.exportInvoices()
            return (data, "Invoices-Export-\(dateString).json")
        case .sessions:
            let data = try await dataExporterActor.exportSessions()
            return (data, "Sessions-Export-\(dateString).json")
        case .allData:
            let data = try await dataExporterActor.exportAllEntitiesToJSON()
            return (data, "AllData-Export-\(dateString).json")
        case .unknown:
            throw NSError(
                domain: "ImportExportCoordinatorError",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported export source"]
            )
        }
    }

    func exportAllData(dateString: String? = nil) async throws -> (data: Data, fileName: String) {
        let dateString = dateString ?? ImportExportTimestamp.fileSuffix()
        let data = try await dataExporterActor.exportAllEntitiesToJSON()
        return (data, "AllData-Export-\(dateString).json")
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
        try await Task.detached(priority: .userInitiated) {
            do {
                return try Data(contentsOf: url, options: .mappedIfSafe)
            } catch {
                throw ImportExportCatalogError.unableToReadInputFile(url: url, underlying: error)
            }
        }.value
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
