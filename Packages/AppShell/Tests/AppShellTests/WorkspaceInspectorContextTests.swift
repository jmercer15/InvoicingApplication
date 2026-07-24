@testable import AppShell
import Core
import XCTest

@MainActor
final class WorkspaceInspectorContextTests: XCTestCase {
    func testInvoiceFeaturesUseOnlyIntegratedEditorInspector() {
        XCTAssertTrue(AppTab.invoices.usesIntegratedInvoiceEditorInspector)
        XCTAssertTrue(AppTab.invoiceTemplateEditor.usesIntegratedInvoiceEditorInspector)
        XCTAssertFalse(AppTab.relationships.usesIntegratedInvoiceEditorInspector)
        XCTAssertFalse(AppTab.ndisCatalogue.usesIntegratedInvoiceEditorInspector)
    }

    func testInspectorPresentationCombinesSplitColumnAndStandaloneWindow() {
        var presentation = InspectorPresentationState()

        XCTAssertFalse(presentation.isVisible)

        presentation.splitPresented = true
        XCTAssertTrue(presentation.isVisible)

        presentation.splitPresented = false
        presentation.standaloneOpen = true
        XCTAssertTrue(presentation.isVisible)

        presentation.standaloneOpen = false
        XCTAssertFalse(presentation.isVisible)
    }

    func testSplitInspectorHiddenWhenStandaloneInspectorOpen() {
        let presentation = InspectorPresentationState(
            splitPresented: true,
            standaloneOpen: true
        )

        let showsSplitColumn = presentation.splitPresented && !presentation.standaloneOpen
        XCTAssertFalse(showsSplitColumn)
        XCTAssertTrue(presentation.isVisible)
    }

    func testToolWindowPresenceRegistryTracksStandaloneInspectorAndActivity() {
        let registry = ToolWindowPresenceRegistry()

        XCTAssertFalse(registry.inspectorStandaloneOpen)
        XCTAssertFalse(registry.activityMonitorOpen)

        registry.setInspectorStandaloneOpen(true)
        XCTAssertTrue(registry.inspectorStandaloneOpen)

        registry.setActivityMonitorOpen(true)
        XCTAssertTrue(registry.activityMonitorOpen)

        registry.setInspectorStandaloneOpen(false)
        registry.setActivityMonitorOpen(false)
        XCTAssertFalse(registry.inspectorStandaloneOpen)
        XCTAssertFalse(registry.activityMonitorOpen)
    }

    func testToolWindowContextFocusedValueKind() {
        let inspectorContext = ToolWindowContext(kind: .standaloneInspector, isOpen: true)
        let activityContext = ToolWindowContext(kind: .activityMonitor, isOpen: false)

        XCTAssertEqual(inspectorContext.kind, .standaloneInspector)
        XCTAssertTrue(inspectorContext.isOpen)
        XCTAssertEqual(activityContext.kind, .activityMonitor)
        XCTAssertFalse(activityContext.isOpen)
    }
}
