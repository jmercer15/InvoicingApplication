import SwiftUI
import Core

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Capabilities & Categories

enum InspectorCategory {
    case text
    case container
    case table
    case image
    case shape
}

struct InspectorCapabilities {
    let showsContentControls: Bool
    let nestsContentControls: Bool
    let showsTypographySection: Bool
    let showsAppearanceSection: Bool
    let showsTableSection: Bool
    let showsImageSection: Bool
    let showsShapeSection: Bool
    let showsLayoutSection: Bool
    let showsVisibilitySection: Bool

    init(component: InvoiceComponent) {
        let type = component.type
        let isSimpleTextComponent = type == .textBox || type == .notes
        let supportsTypography = type.supportsTypography

        showsContentControls = isSimpleTextComponent
        nestsContentControls = isSimpleTextComponent && supportsTypography
        showsTypographySection = supportsTypography
        let supportsAppearance = type.supportsBackgroundFill || type.supportsBorderControls || type.supportsShadow
        showsAppearanceSection = supportsAppearance && !type.usesTableProperties
        showsTableSection = type.usesTableProperties
        showsImageSection = type.isImageComponent
        showsShapeSection = type.isShape
        showsLayoutSection = type.supportsLayoutControls && !type.usesTableProperties
        
        // Visibility mainly for sections with predefined fields
        switch type {
        case .billTo, .participant, .invoiceNumberAndDates, .paymentDetails:
            showsVisibilitySection = true
        default:
            showsVisibilitySection = false
        }
    }
}

func inspectorCategory(for component: InvoiceComponent) -> InspectorCategory {
    let type = component.type
    if type.usesTableProperties { return .table }
    if type.isImageComponent { return .image }
    if type.isShape { return .shape }
    if type.isSection { return .container }
    return .text
}

// MARK: - Inspector Section Types

enum InspectorSection: Hashable {
    case text
    case appearance
    case image
    case shape
    case layout
    case tableLayoutStructure
    case tableFill
    case tableBorders
    case tableShadow
    case tableTypography
    case tableColumns
    case sectionTitle
    case visibility
}

enum ColumnWidthMode: String, CaseIterable {
    case flexible = "Flexible"
    case autoSize = "Fit"
    case fixed = "Fixed"
}

// MARK: - Binding Helpers

extension ComponentPropertyEditor {
    func styleBinding<Value>(
        for component: InvoiceComponent,
        _ keyPath: KeyPath<ComponentStyle, Value>,
        update: @escaping (UUID, Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: { component.style[keyPath: keyPath] },
            set: { update(component.id, $0) }
        )
    }

    func numericStyleBinding<Value: BinaryFloatingPoint>(
        for component: InvoiceComponent,
        _ keyPath: KeyPath<ComponentStyle, Value>,
        update: @escaping (UUID, Value) -> Void
    ) -> Binding<Double> {
        Binding(
            get: { Double(component.style[keyPath: keyPath]) },
            set: { update(component.id, Value($0)) }
        )
    }
}
