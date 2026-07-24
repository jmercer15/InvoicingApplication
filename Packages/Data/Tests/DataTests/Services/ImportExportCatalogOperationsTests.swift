import Core
@testable import Data
import SwiftData
import Foundation
import XCTest

@MainActor
final class ImportExportCatalogOperationsTests: XCTestCase {
    func testImportSpecificDataFromFileRejectsUnsupportedSourceCombination() async throws {
        let (container, _) = try ModelContainerFactory.makeInMemoryContext()
        let importer = DataImporterActor(modelContainer: container)
        let exporter = DataExporterActor(modelContainer: container)
        let catalog = ImportExportCatalogOperations(dataImporterActor: importer, dataExporterActor: exporter)
        let tempURL = makeTemporaryFileURL()
        try "{}".data(using: .utf8)!.write(to: tempURL)
        
        do {
            _ = try await catalog.importSpecificDataFromFile(url: tempURL, source: .allData)
            XCTFail("Expected unsupported file type error.")
        } catch {
            guard let catalogError = error as? ImportExportCatalogError else {
                return XCTFail("Expected ImportExportCatalogError.")
            }
            if case let .unsupportedFileExtension(source, fileExtension, supportedExtensions) = catalogError {
                XCTAssertEqual(source, .allData)
                XCTAssertEqual(fileExtension, tempURL.pathExtension.lowercased())
                XCTAssertEqual(supportedExtensions.sorted(), ["json"])
            } else {
                XCTFail("Expected unsupported file extension error.")
            }
        }
    }
    
    func testImportSpecificDataFromFileAllowsCsvForNDISImport() async throws {
        let (container, _) = try ModelContainerFactory.makeInMemoryContext()
        let importer = DataImporterActor(modelContainer: container)
        let exporter = DataExporterActor(modelContainer: container)
        let catalog = ImportExportCatalogOperations(dataImporterActor: importer, dataExporterActor: exporter)
        let tempURL = makeTemporaryFileURL(fileName: "ndis-items.txt")
        try "[]".data(using: .utf8)!.write(to: tempURL)
        
        do {
            _ = try await catalog.importSpecificDataFromFile(url: tempURL, source: .ndisItems)
            XCTFail("Expected unsupported file type error for NDIS import.")
        } catch {
            guard let catalogError = error as? ImportExportCatalogError else {
                return XCTFail("Expected ImportExportCatalogError.")
            }
            if case let .unsupportedFileExtension(source, fileExtension, supportedExtensions) = catalogError {
                XCTAssertEqual(source, .ndisItems)
                XCTAssertEqual(fileExtension, tempURL.pathExtension.lowercased())
                XCTAssertEqual(Set(supportedExtensions), ["csv", "xls", "xlsx"])
            } else {
                XCTFail("Expected unsupported file extension error.")
            }
        }
    }

    func testImportSpecificDataFromFileImportsVersionedNDISCSVRows() async throws {
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

        XCTAssertEqual(result.source, .ndisItems)
        XCTAssertEqual(result.successful, 2)
        XCTAssertEqual(result.failed, 0)
        XCTAssertEqual(uniqueVersionIdentifiers.count, 2)
        XCTAssertEqual(importedRows.count, 2)
    }
    
    private func makeTemporaryFileURL(fileName: String = "incompatible-import.txt") -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(UUID().uuidString)-\(fileName)"
        )
    }
}
