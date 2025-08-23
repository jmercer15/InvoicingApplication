import Foundation
import CoreGraphics

// MARK: - Validation Extension for InvoiceDocument

extension InvoiceDocument {
    struct DocumentValidationResult {
        let isValid: Bool
        let errors: [DocumentValidationError]
        let warnings: [DocumentValidationWarning]

        var hasErrors: Bool { !errors.isEmpty }
        var hasWarnings: Bool { !warnings.isEmpty }

        static var valid: DocumentValidationResult {
            DocumentValidationResult(isValid: true, errors: [], warnings: [])
        }

        static func invalid(errors: [DocumentValidationError] = [], warnings: [DocumentValidationWarning] = []) -> DocumentValidationResult {
            DocumentValidationResult(isValid: false, errors: errors, warnings: warnings)
        }
    }

    enum DocumentValidationError: LocalizedError {
        case emptyDocument
        case componentOutsidePage(componentId: UUID)
        case invalidComponentSize(componentId: UUID)
        case overlappingComponents(componentIds: [UUID])
        case tooManyComponents(count: Int)

        var errorDescription: String? {
            switch self {
            case .emptyDocument:
                return "Document contains no components"
            case .componentOutsidePage(let componentId):
                return "Component \(componentId) is positioned outside the page"
            case .invalidComponentSize(let componentId):
                return "Component \(componentId) has invalid size"
            case .overlappingComponents(let componentIds):
                return "Components are overlapping: \(componentIds.map { $0.uuidString }.joined(separator: ", "))"
            case .tooManyComponents(let count):
                return "Document contains too many components (\(count)). Maximum allowed: 200"
            }
        }
    }

    enum DocumentValidationWarning: LocalizedError {
        case componentNearEdge(componentId: UUID)
        case smallComponent(componentId: UUID)
        case noInvoiceTitle
        case noCompanyInfo
        case missingImageData(componentId: UUID)

        var errorDescription: String? {
            switch self {
            case .componentNearEdge(let componentId):
                return "Component \(componentId) is near the page edge"
            case .smallComponent(let componentId):
                return "Component \(componentId) is very small"
            case .noInvoiceTitle:
                return "Document has no invoice title"
            case .noCompanyInfo:
                return "Document has no company information"
            case .missingImageData(let componentId):
                return "Component \(componentId) has no image data"
            }
        }
    }

    func validateDocument() -> DocumentValidationResult {
        var errors: [DocumentValidationError] = []
        var warnings: [DocumentValidationWarning] = []

        // Check if document is empty
        if allComponents.isEmpty {
            errors.append(.emptyDocument)
        }

        // Check component count
        if allComponents.count > 200 {
            errors.append(.tooManyComponents(count: allComponents.count))
        }

        // Validate each component
        for component in allComponents {
            validateComponent(component, errors: &errors, warnings: &warnings)
        }

        // Check for overlapping components (performance consideration)
        if allComponents.count < 50 { // Only check if not too many components
            checkForOverlaps(errors: &errors)
        }

        // Check for required sections
        checkForRequiredSections(warnings: &warnings)

        return errors.isEmpty ? .valid : .invalid(errors: errors, warnings: warnings)
    }

    private func validateComponent(_ component: InvoiceComponent, errors: inout [DocumentValidationError], warnings: inout [DocumentValidationWarning]) {
        // Check if component is within page bounds
        let pageWidth = A4.width
        let pageHeight = A4.height

        if component.position.x < 0 || component.position.y < 0 ||
           component.position.x + component.size.width > pageWidth ||
           component.position.y + component.size.height > pageHeight {
            errors.append(.componentOutsidePage(componentId: component.id))
        }

        // Check component size
        if component.size.width <= 0 || component.size.height <= 0 {
            errors.append(.invalidComponentSize(componentId: component.id))
        }

        // Check if component is too small
        if component.size.width < 10 || component.size.height < 10 {
            warnings.append(.smallComponent(componentId: component.id))
        }

        // Check if component is near page edge
        let margin: CGFloat = 20
        if component.position.x < margin || component.position.y < margin ||
           component.position.x + component.size.width > pageWidth - margin ||
           component.position.y + component.size.height > pageHeight - margin {
            warnings.append(.componentNearEdge(componentId: component.id))
        }

        // Component-specific validation
        switch component.type {
        case .imagePlaceholder, .companyLogo:
            if component.style.imageData == nil {
                warnings.append(.missingImageData(componentId: component.id))
            }
        default:
            break
        }

        // Validate component style
        let styleErrors = component.style.validate()
        if !styleErrors.isEmpty {
            // Convert style errors to document errors
            for _ in styleErrors {
                errors.append(.invalidComponentSize(componentId: component.id))
            }
        }
    }

    private func checkForOverlaps(errors: inout [DocumentValidationError]) {
        let components = allComponents
        var overlappingGroups: [[UUID]] = []

        for i in 0..<components.count {
            for j in i+1..<components.count {
                let comp1 = components[i]
                let comp2 = components[j]

                if comp1.frame.intersects(comp2.frame) {
                    // Check if these components are already in an overlapping group
                    var foundGroup = false
                    for groupIndex in 0..<overlappingGroups.count {
                        if overlappingGroups[groupIndex].contains(comp1.id) || overlappingGroups[groupIndex].contains(comp2.id) {
                            overlappingGroups[groupIndex].append(contentsOf: [comp1.id, comp2.id])
                            foundGroup = true
                            break
                        }
                    }

                    if !foundGroup {
                        overlappingGroups.append([comp1.id, comp2.id])
                    }
                }
            }
        }

        // Add errors for overlapping groups
        for group in overlappingGroups where group.count >= 2 {
            errors.append(.overlappingComponents(componentIds: Array(Set(group))))
        }
    }

    private func checkForRequiredSections(warnings: inout [DocumentValidationWarning]) {
        let componentTypes = allComponents.map { $0.type }

        if !componentTypes.contains(.invoiceTitle) {
            warnings.append(.noInvoiceTitle)
        }

        if !componentTypes.contains(.companyName) && !componentTypes.contains(.companyABN) {
            warnings.append(.noCompanyInfo)
        }
    }
}