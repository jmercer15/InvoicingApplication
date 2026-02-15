import SwiftUI
import Core
import SharedUI

struct PropertyInspector: View {
    @EnvironmentObject private var document: InvoiceDocument
    @EnvironmentObject private var editorViewModel: InvoiceTemplateEditorViewModel
    @EnvironmentObject private var templateDataService: TemplateDataService
    
    @State private var expandedSections: Set<AnyHashable> = []
    
    private enum DisplayMode {
        case component(InvoiceComponent)
        case split(SectionSplitLeafContext)
        case tableElement(TableElementSelection, InvoiceComponent)
        case empty
    }
    
    private var displayMode: DisplayMode {
        // Check for specific table element selection first
        if let componentID = document.selectedComponentID,
           let element = document.selectedTableElement,
           let component = document.component(componentID) {
            return .tableElement(element, component)
        }
        
        if let splitContext = document.leafContext(for: document.selectedSplitSelection) {
            return .split(splitContext)
        } else if let component = document.component(document.selectedComponentID) {
            return .component(component)
        }
        return .empty
    }
    
    var body: some View {
        Group {
            switch displayMode {
            case .component(let component):
                ComponentPropertyEditor(
                    component: component,
                    expandedSections: $expandedSections
                )
                .environmentObject(document)
                .environmentObject(editorViewModel)
                .environmentObject(templateDataService)
                
            case .split(let context):
                LayoutPropertyEditor(
                    context: context,
                    expandedSections: $expandedSections
                )
                .environmentObject(document)
                
            case .tableElement(let selection, let component):
                TableElementPropertyEditor(
                    selection: selection,
                    component: component,
                    expandedSections: $expandedSections
                )
                .environmentObject(document)
                
            case .empty:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        //.padding(TemplateEditorPanelStyle.outerPadding)
    }
}

// Note: PropertyInspector requires complex environment setup. 
// Use ComponentPropertyEditor, LayoutPropertyEditor, or InspectorComponents previews for visual testing.

/// Alias for modern naming convention
typealias ModernInspectorView = PropertyInspector
