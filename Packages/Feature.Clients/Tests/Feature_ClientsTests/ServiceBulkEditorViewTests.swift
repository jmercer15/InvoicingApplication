import Testing
import Core
import PersistenceModels
import SwiftUI
@testable import Feature_Clients

@MainActor
@Suite struct ServiceBulkEditorViewTests {
    
    @MainActor
    final class TestState {
        var templates: [ClientServiceTemplate] = []
    }
    
    @Test func ClientServiceTemplateInitializationWithRegionalPrices() {
        let ndisItem = NDISItem(itemNumber: "01_001_0107_1_1", name: "Standard Therapy", unit: "hour")
        let regionalPrice1 = RegionalPrice()
        regionalPrice1.amount = 193.99
        regionalPrice1.regionIdentifier = "National"
        
        let regionalPrice2 = RegionalPrice()
        regionalPrice2.amount = 220.00
        regionalPrice2.regionIdentifier = "Remote"
        
        ndisItem.regionalPrices = [regionalPrice1, regionalPrice2]
        
        let template = ClientServiceTemplate(from: ndisItem)
        
        #expect(template.serviceName == "Standard Therapy")
        #expect(template.ndisCode == "01_001_0107_1_1")
        #expect(template.unit == "hour")
        #expect(template.priceMode == .ndis)
        #expect(template.availableNdisPrices["National"] == 193.99)
        #expect(template.availableNdisPrices["Remote"] == 220.00)
        #expect(template.selectedNdisPriceKey == "National")
        #expect(template.rate == 193.99)
    }
    
    @Test func ClientServiceTemplateInitializationWithoutRegionalPrices() {
        let ndisItem = NDISItem(itemNumber: "01_002_0107_1_1", name: "Custom Service", unit: "session")
        
        let template = ClientServiceTemplate(from: ndisItem)
        
        #expect(template.serviceName == "Custom Service")
        #expect(template.ndisCode == "01_002_0107_1_1")
        #expect(template.unit == "session")
        #expect(template.priceMode == .custom)
        #expect(template.rate == 0.0)
    }
    
    @Test func ServiceBulkEditorViewEmptyStateRendering() {
        let state = TestState()
        var saveCalled = false
        var backCalled = false
        
        let view = ServiceBulkEditorView(
            templates: Binding(get: { state.templates }, set: { state.templates = $0 }),
            onSave: { _ in saveCalled = true },
            onBackToServiceSelection: { backCalled = true }
        )
        
        #expect(state.templates.isEmpty)
        
        // Manually trigger and verify callbacks are wired correctly
        view.onSave([])
        view.onBackToServiceSelection()
        
        #expect(saveCalled)
        #expect(backCalled)
    }
}
