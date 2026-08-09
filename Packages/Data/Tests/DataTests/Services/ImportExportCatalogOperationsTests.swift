import Core
@testable import Data
import SwiftData
import Foundation
import Testing
import PersistenceModels
@MainActor
@Suite struct ImportExportCatalogOperationsTests {
    @Test func ImportSpecificDataFromFileRejectsUnsupportedSourceCombination() async throws {
        let (container, _) = try ModelContainerFactory.makeInMemoryContext()
        let importer = DataImporterActor(modelContainer: container)
        let exporter = DataExporterActor(modelContainer: container)
        let catalog = ImportExportCatalogOperations(dataImporterActor: importer, dataExporterActor: exporter)
        let tempURL = makeTemporaryFileURL()
        try "{}".data(using: .utf8)!.write(to: tempURL)
        
        do {
            _ = try await catalog.importSpecificDataFromFile(url: tempURL, source: .allData)
            Issue.record("Expected unsupported file type error.")
        } catch {
            guard let catalogError = error as? ImportExportCatalogError else {
                Issue.record("Expected ImportExportCatalogError.")
                return
            }
            if case let .unsupportedFileExtension(source, fileExtension, supportedExtensions) = catalogError {
                #expect(source == .allData)
                #expect(fileExtension == tempURL.pathExtension.lowercased())
                #expect(supportedExtensions.sorted() == ["json"])
            } else {
                Issue.record("Expected unsupported file extension error.")
            }
        }
    }
    
    @Test func ImportSpecificDataFromFileAllowsCsvForNDISImport() async throws {
        let (container, _) = try ModelContainerFactory.makeInMemoryContext()
        let importer = DataImporterActor(modelContainer: container)
        let exporter = DataExporterActor(modelContainer: container)
        let catalog = ImportExportCatalogOperations(dataImporterActor: importer, dataExporterActor: exporter)
        let tempURL = makeTemporaryFileURL(fileName: "ndis-items.txt")
        try "[]".data(using: .utf8)!.write(to: tempURL)
        
        do {
            _ = try await catalog.importSpecificDataFromFile(url: tempURL, source: .ndisItems)
            Issue.record("Expected unsupported file type error for NDIS import.")
        } catch {
            guard let catalogError = error as? ImportExportCatalogError else {
                Issue.record("Expected ImportExportCatalogError.")
                return
            }
            if case let .unsupportedFileExtension(source, fileExtension, supportedExtensions) = catalogError {
                #expect(source == .ndisItems)
                #expect(fileExtension == tempURL.pathExtension.lowercased())
                #expect(Set(supportedExtensions) == ["csv", "xls", "xlsx"])
            } else {
                Issue.record("Expected unsupported file extension error.")
            }
        }
    }

    @Test func ImportSpecificDataFromFileImportsVersionedNDISCSVRows() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let importer = DataImporterActor(modelContainer: container)
        let exporter = DataExporterActor(modelContainer: container)
        let catalog = ImportExportCatalogOperations(dataImporterActor: importer, dataExporterActor: exporter)
        let tempURL = makeTemporaryFileURL(fileName: "ndis-versioned-import.csv")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        let csv = """
Support Item Number,Support Item Name,Unit,Start date,End Date
100001,Support item A,Hour,01/01/2024,31/12/2024
100001,Support item A,Hour,01/01/2025,
"""
        try csv.data(using: .utf8)!.write(to: tempURL)

        let result = try await catalog.importSpecificDataFromFile(url: tempURL, source: .ndisItems)

        let items = try context.fetch(FetchDescriptor<NDISItem>())
        let uniqueVersionIdentifiers = Set(items.map(\.versionIdentifier))
        let importedRows = items.filter { $0.itemNumber == "100001" && $0.name == "Support item A" }

        #expect(result.source == .ndisItems)
        #expect(result.successful == 2)
        #expect(result.failed == 0)
        #expect(uniqueVersionIdentifiers.count == 2)
        #expect(importedRows.count == 2)
    }
    
    private func makeTemporaryFileURL(fileName: String = "incompatible-import.txt") -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(UUID().uuidString)-\(fileName)"
        )
    }
}
