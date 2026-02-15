import SwiftUI
import Core
import SharedUI

struct ComponentPropertyEditor: View {
    let component: InvoiceComponent
    @Binding var expandedSections: Set<AnyHashable>
    
    @EnvironmentObject var document: InvoiceDocument
    @EnvironmentObject var editorViewModel: InvoiceTemplateEditorViewModel
    @EnvironmentObject var templateDataService: TemplateDataService

    var liveComponent: InvoiceComponent {
        document.component(component.id) ?? component
    }

    @State var typographyTabSelection: [UUID: Int] = [:]
    @State var columnTabSelection: [UUID: Int] = [:]
    
    var body: some View {
        let capabilities = InspectorCapabilities(component: component)
        let descriptors = buildDescriptors(for: component, capabilities: capabilities)
        
        InspectorContentLayout(
            header: header(for: component),
            descriptors: descriptors,
            expandedSections: $expandedSections
        )
    }

    private func buildDescriptors(for component: InvoiceComponent, capabilities: InspectorCapabilities) -> [InspectorSectionDescriptor<InspectorSection>] {
        let category = inspectorCategory(for: component)
        
        var result: [InspectorSectionDescriptor<InspectorSection>] = []
        
        // Build descriptors in display order based on category
        for section in orderedSections(for: category) {
            if let descriptor = makeDescriptor(section: section, component: component, category: category, capabilities: capabilities) {
                result.append(descriptor)
            }
        }
        
        return result
    }
    
    private func makeDescriptor(
        section: InspectorSection,
        component: InvoiceComponent,
        category: InspectorCategory,
        capabilities: InspectorCapabilities
    ) -> InspectorSectionDescriptor<InspectorSection>? {
        switch section {
        case .text where category == .text && (capabilities.showsContentControls || capabilities.showsTypographySection):
            return InspectorSectionDescriptor(section: section, title: "Text", alwaysExpanded: false, isVisible: true) {
                AnyView(textSectionContent(for: component, capabilities: capabilities))
            }
            
        case .appearance where capabilities.showsAppearanceSection:
            return InspectorSectionDescriptor(section: section, title: "Appearance", alwaysExpanded: false, isVisible: true) {
                AnyView(appearanceSection(for: component))
            }

        case .visibility where capabilities.showsVisibilitySection:
            return InspectorSectionDescriptor(section: section, title: "Visibility", alwaysExpanded: false, isVisible: true) {
                AnyView(visibilitySection(for: component))
            }
            
        case .image where category == .image && capabilities.showsImageSection:
            return InspectorSectionDescriptor(section: section, title: "Image", alwaysExpanded: true, isVisible: true) {
                AnyView(imageContentControls(for: component))
            }
            
        case .shape where category == .shape && capabilities.showsShapeSection:
            return InspectorSectionDescriptor(section: section, title: "Shape", alwaysExpanded: true, isVisible: true) {
                AnyView(shapeSection(for: component))
            }
            
        case .layout where capabilities.showsLayoutSection:
            return InspectorSectionDescriptor(section: section, title: "Layout", alwaysExpanded: false, isVisible: true) {
                AnyView(layoutSection(for: component))
            }
            
        case .tableLayoutStructure, .tableFill, .tableTypography, .tableColumns, .sectionTitle
            where category == .table && capabilities.showsTableSection:
            return tableSectionDescriptors(for: component).first { $0.section == section }
            
        default:
            return nil
        }
    }
}

// MARK: - Table Data Helpers

extension ComponentPropertyEditor {
    func tablePreviewData(for component: InvoiceComponent) -> (component: InvoiceComponent, rowCount: Int, columnCount: Int, isHorizontal: Bool) {
        let currentComponent = document.component(component.id) ?? component
        let generator = DocumentGridDataGenerator(component: currentComponent, templateDataService: templateDataService, clientId: nil, invoiceId: nil)
        let sampleData = generator.generateSampleData()
        return (currentComponent, sampleData.count, sampleData.first?.count ?? 4, currentComponent.style.tableDirection == .horizontal)
    }

    func ensureTableTypographyData(for component: InvoiceComponent) {
        let tableData = tablePreviewData(for: component)
        if tableData.isHorizontal {
            if component.style.columnConfigurations.isEmpty {
                document.initializeAxisConfigurations(for: component.id, axis: .column, count: tableData.columnCount)
            }
        } else if component.style.rowConfigurations.isEmpty {
            document.initializeAxisConfigurations(for: component.id, axis: .row, count: tableData.rowCount)
        }
    }

    func ensureTableColumnData(for component: InvoiceComponent) {
        let tableData = tablePreviewData(for: component)
        if component.style.columnConfigurations.isEmpty {
            document.initializeAxisConfigurations(for: component.id, axis: .column, count: tableData.columnCount)
        }
    }
}
