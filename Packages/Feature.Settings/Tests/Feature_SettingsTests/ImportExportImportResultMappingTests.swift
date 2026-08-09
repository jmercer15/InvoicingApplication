import Core
import Data
import struct Data.ImportResult
@testable import Feature_Settings
import Testing
@Suite struct ImportExportImportResultMappingTests {
    @Test func MapsDataImportResultToCoreResult() {
        let dataResult = ImportResult(
            source: .ndisItems,
            successful: 7,
            failed: 2,
            importedCounts: ["NDISItem": 7],
            messages: ["Parsed 7 rows", "2 warnings"],
            fileName: "ndis-items.csv"
        )
        
        let coreResult = ImportExportImportResultMapping.make(dataResult)
        
        #expect(coreResult.source == .ndisItems)
        #expect(!(coreResult.success))
        #expect(coreResult.successful == 7)
        #expect(coreResult.failed == 2)
        #expect(coreResult.importedCounts["NDISItem"] == 7)
        #expect(coreResult.fileName == "ndis-items.csv")
    }
    
    @Test func MapsPartialFailureToFailureResult() {
        let failure = ImportExportImportResultMapping.makeFailure(
            source: .clients,
            fileName: "clients.json",
            message: "Clients import failed"
        )
        
        #expect(!(failure.success))
        #expect(failure.successful == 0)
        #expect(failure.failed == 1)
        #expect(failure.messages == ["Clients import failed"])
        #expect(failure.source == .clients)
    }
    
    @Test func MapsUnsupportedCombination() {
        let failure = ImportExportImportResultMapping.makeUnsupportedCombination(
            source: .allData,
            fileName: "data.xls",
            actualExtension: "xls",
            supportedExtensions: ["json"]
        )
        
        #expect(!(failure.success))
        #expect(failure.failed == 1)
        #expect(failure.messages.first?.contains("Unsupported file type for All Data") ?? false)
    }
}
