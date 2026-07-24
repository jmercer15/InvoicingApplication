import XCTest
import Core
import SwiftUI
@testable import Feature_Clients

@MainActor
final class ServiceBulkEditorViewTests: XCTestCase {
    
    @MainActor
    final class TestState {
        var templates: [ClientServiceTemplate] = []
    }
    
    func testClientServiceTemplateInitializationWithRegionalPrices() {
        let ndisItem = NDISItem(itemNumber: "01_001_0107_1_1", name: "Standard Therapy", unit: "hour")
        let regionalPrice1 = RegionalPrice()
        regionalPrice1.amount = 193.99
        regionalPrice1.regionIdentifier = "National"
        
        let regionalPrice2 = RegionalPrice()
        regionalPrice2.amount = 220.00
        regionalPrice2.regionIdentifier = "Remote"
        
        ndisItem.regionalPrices = [regionalPrice1, regionalPrice2]
        
        let template = ClientServiceTemplate(from: ndisItem)
        
        XCTAssertEqual(template.serviceName, "Standard Therapy")
        XCTAssertEqual(template.ndisCode, "01_001_0107_1_1")
        XCTAssertEqual(template.unit, "hour")
        XCTAssertEqual(template.priceMode, .ndis)
        XCTAssertEqual(template.availableNdisPrices["National"], 193.99)
        XCTAssertEqual(template.availableNdisPrices["Remote"], 220.00)
        XCTAssertEqual(template.selectedNdisPriceKey, "National")
        XCTAssertEqual(template.rate, 193.99)
    }
    
    func testClientServiceTemplateInitializationWithoutRegionalPrices() {
        let ndisItem = NDISItem(itemNumber: "01_002_0107_1_1", name: "Custom Service", unit: "session")
        
        let template = ClientServiceTemplate(from: ndisItem)
        
        XCTAssertEqual(template.serviceName, "Custom Service")
        XCTAssertEqual(template.ndisCode, "01_002_0107_1_1")
        XCTAssertEqual(template.unit, "session")
        XCTAssertEqual(template.priceMode, .custom)
        XCTAssertEqual(template.rate, 0.0)
    }
    
    func testServiceBulkEditorViewEmptyStateRendering() {
        let state = TestState()
        var saveCalled = false
        var backCalled = false
        
        let view = ServiceBulkEditorView(
            templates: Binding(get: { state.templates }, set: { state.templates = $0 }),
            onSave: { _ in saveCalled = true },
            onBackToServiceSelection: { backCalled = true }
        )
        
        let body = view.body
        XCTAssertNotNil(body)
        XCTAssertTrue(state.templates.isEmpty)
        
        // Manually trigger and verify callbacks are wired correctly
        view.onSave([])
        view.onBackToServiceSelection()
        
        XCTAssertTrue(saveCalled)
        XCTAssertTrue(backCalled)
    }
}
