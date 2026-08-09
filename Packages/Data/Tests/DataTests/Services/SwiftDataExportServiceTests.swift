import Core
import PersistenceModels
@testable import Data
import Foundation
import SwiftData
import Testing
@Suite struct SwiftDataExportServiceTests {
    @Test func ExportAllEntitiesToJSONReturnsExpectedStructure() throws {
        let (container, _) = try ModelContainerFactory.makeInMemoryContext()
        let modelContext = ModelContext(container)
        let client = Client(ndisNumber: "C-001", fullName: "Test Client")
        modelContext.insert(client)
        try modelContext.save()
        
        let exportedData = try SwiftDataExportService.exportAllEntitiesToJSON(context: modelContext)
        let payload = try JSONSerialization.jsonObject(with: exportedData) as? [String: Any]
        
        let clientRecords = payload?["Client"] as? [[String: Any]]
        #expect(payload != nil)
        #expect(clientRecords != nil)
        #expect(clientRecords?.count == 1)
        #expect(clientRecords?.first?["fullName"] as? String == "Test Client")
        #expect(clientRecords?.first?["ndisNumber"] as? String == "C-001")
    }
    
    @Test func ExportAllEntitiesToJSONHasRuntimeDiagnosticSignal() throws {
        let (container, _) = try ModelContainerFactory.makeInMemoryContext()
        let modelContext = ModelContext(container)
        (0..<10).forEach { index in
            modelContext.insert(Client(ndisNumber: "N\(index)", fullName: "Client \(index)"))
        }
        try modelContext.save()
        
        let startedAt = Date()
        _ = try SwiftDataExportService.exportAllEntitiesToJSON(context: modelContext)
        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        
        print("[Diagnostics] exportAllEntitiesToJSON elapsed: \(elapsedMs)ms")
    }
}
