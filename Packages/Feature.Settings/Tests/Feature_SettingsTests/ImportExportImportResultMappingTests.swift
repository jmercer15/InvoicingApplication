import Core
import Data
import struct Data.ImportResult
@testable import Feature_Settings
import XCTest

final class ImportExportImportResultMappingTests: XCTestCase {
    func testMapsDataImportResultToCoreResult() {
        let dataResult = ImportResult(
            source: .ndisItems,
            successful: 7,
            failed: 2,
            importedCounts: ["NDISItem": 7],
            messages: ["Parsed 7 rows", "2 warnings"],
            fileName: "ndis-items.csv"
        )
        
        let coreResult = ImportExportImportResultMapping.make(dataResult)
        
        XCTAssertEqual(coreResult.source, .ndisItems)
        XCTAssertFalse(coreResult.success)
        XCTAssertEqual(coreResult.successful, 7)
        XCTAssertEqual(coreResult.failed, 2)
        XCTAssertEqual(coreResult.importedCounts["NDISItem"], 7)
        XCTAssertEqual(coreResult.fileName, "ndis-items.csv")
    }
    
    func testMapsPartialFailureToFailureResult() {
        let failure = ImportExportImportResultMapping.makeFailure(
            source: .clients,
            fileName: "clients.json",
            message: "Clients import failed"
        )
        
        XCTAssertFalse(failure.success)
        XCTAssertEqual(failure.successful, 0)
        XCTAssertEqual(failure.failed, 1)
        XCTAssertEqual(failure.messages, ["Clients import failed"])
        XCTAssertEqual(failure.source, .clients)
    }
    
    func testMapsUnsupportedCombination() {
        let failure = ImportExportImportResultMapping.makeUnsupportedCombination(
            source: .allData,
            fileName: "data.xls",
            actualExtension: "xls",
            supportedExtensions: ["json"]
        )
        
        XCTAssertFalse(failure.success)
        XCTAssertEqual(failure.failed, 1)
        XCTAssertTrue(failure.messages.first?.contains("Unsupported file type for All Data") ?? false)
    }
}
