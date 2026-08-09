@testable import AppShell
import Core
import Testing
@MainActor
@Suite struct WorkspaceInspectorContextTests {
    @Test func InvoiceFeaturesUseOnlyIntegratedEditorInspector() {
        #expect(AppTab.invoices.usesIntegratedInvoiceEditorInspector)
        #expect(AppTab.invoiceTemplateEditor.usesIntegratedInvoiceEditorInspector)
        #expect(!(AppTab.relationships.usesIntegratedInvoiceEditorInspector))
        #expect(!(AppTab.ndisCatalogue.usesIntegratedInvoiceEditorInspector))
    }

    @Test func InspectorPresentationCombinesSplitColumnAndStandaloneWindow() {
        var presentation = InspectorPresentationState()

        #expect(!(presentation.isVisible))

        presentation.splitPresented = true
        #expect(presentation.isVisible)

        presentation.splitPresented = false
        presentation.standaloneOpen = true
        #expect(presentation.isVisible)

        presentation.standaloneOpen = false
        #expect(!(presentation.isVisible))
    }

    @Test func SplitInspectorHiddenWhenStandaloneInspectorOpen() {
        let presentation = InspectorPresentationState(
            splitPresented: true,
            standaloneOpen: true
        )

        let showsSplitColumn = presentation.splitPresented && !presentation.standaloneOpen
        #expect(!(showsSplitColumn))
        #expect(presentation.isVisible)
    }

    @Test func ToolWindowPresenceRegistryTracksStandaloneInspectorAndActivity() {
        let registry = ToolWindowPresenceRegistry()

        #expect(!(registry.inspectorStandaloneOpen))
        #expect(!(registry.activityMonitorOpen))

        registry.setInspectorStandaloneOpen(true)
        #expect(registry.inspectorStandaloneOpen)

        registry.setActivityMonitorOpen(true)
        #expect(registry.activityMonitorOpen)

        registry.setInspectorStandaloneOpen(false)
        registry.setActivityMonitorOpen(false)
        #expect(!(registry.inspectorStandaloneOpen))
        #expect(!(registry.activityMonitorOpen))
    }

    @Test func ToolWindowContextFocusedValueKind() {
        let inspectorContext = ToolWindowContext(kind: .standaloneInspector, isOpen: true)
        let activityContext = ToolWindowContext(kind: .activityMonitor, isOpen: false)

        #expect(inspectorContext.kind == .standaloneInspector)
        #expect(inspectorContext.isOpen)
        #expect(activityContext.kind == .activityMonitor)
        #expect(!(activityContext.isOpen))
    }
}
