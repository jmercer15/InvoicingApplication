import SwiftUI
import CoreGraphics
import Combine

@MainActor
public class InvoiceTemplateEditorViewModel: ObservableObject {
    @Published var document = InvoiceDocument()
    
    // The component palette now drives its own data, so this can be simplified.
    // If you need to programmatically add items, you would do so on the `document`.
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var hasUnsavedChanges = false
    @Published var showRulers = true

    // Template management
    @Published var currentTemplateName = "Untitled Template"
    @Published var templateDescription = ""
    @Published var templateTags: [String] = []

    // Component management
    @Published var clipboardComponent: InvoiceComponent?

    // Validation state
    @Published var validationErrors: [ValidationError] = []

    private var cancellables = Set<AnyCancellable>()
    private var lastSavedState: DocumentState?
    private(set) var currentMetadata: TemplateMetadata?

    struct ValidationError: Identifiable {
        let id = UUID()
        let componentId: UUID?
        let message: String
        let severity: Severity

        enum Severity {
            case warning, error
        }
    }

    struct DocumentState: Codable {
        let components: [InvoiceComponent]
        let selectedComponentID: UUID?
        let zoom: CGFloat
        let margins: InvoiceDocument.DocumentMargins
    }

    public init() {
        setupSubscriptions()
        loadDefaultTemplate()
    }

    private func setupSubscriptions() {
        // Monitor document changes for unsaved changes
        document.objectWillChange
            .sink { [weak self] _ in
                self?.hasUnsavedChanges = true
            }
            .store(in: &cancellables)

        // Auto-save functionality
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.autoSaveIfNeeded()
            }
            .store(in: &cancellables)
    }

    // MARK: - Document Operations

    func createNewDocument() {
        guard !hasUnsavedChanges || canDiscardChanges() else { return }

        document = InvoiceDocument()
        currentTemplateName = "Untitled Template"
        templateDescription = ""
        templateTags = []
        hasUnsavedChanges = false
        lastSavedState = nil
        clearValidationErrors()
        currentMetadata = nil
    }

    func loadTemplate(_ templateData: TemplateData) {
        guard !hasUnsavedChanges || canDiscardChanges() else { return }

        document.loadTemplate(templateData)
        currentTemplateName = templateData.metadata.name
        templateDescription = templateData.metadata.description
        templateTags = templateData.metadata.tags
        hasUnsavedChanges = false
        lastSavedState = captureCurrentState()
        clearValidationErrors()
        validateDocument()
        currentMetadata = templateData.metadata
    }

    func saveTemplate() async -> TemplateMetadata? {
        isLoading = true
        defer { isLoading = false }

        let templateManager = await MainActor.run { TemplateManager.shared }
        let metadata = await templateManager.saveTemplate(
            document: document,
            name: currentTemplateName,
            description: templateDescription,
            author: "User",
            tags: templateTags,
            thumbnailData: generateThumbnail(),
            existingMetadata: currentMetadata
        )

        if let metadata {
            hasUnsavedChanges = false
            lastSavedState = captureCurrentState()
            currentMetadata = metadata
        }

        return metadata
    }
    
    func exportToPDF(fileName: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let _ = try await document.exportToPDF(fileName: fileName)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
    
    func exportToImage(format: ExportService.ImageFormat = .png, fileName: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let _ = try await document.exportToImage(format: format, fileName: fileName)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func autoSaveIfNeeded() {
        guard hasUnsavedChanges else { return }

        // Save current state for recovery
        lastSavedState = captureCurrentState()
    }

    private func captureCurrentState() -> DocumentState {
        return DocumentState(
            components: document.components,
            selectedComponentID: document.selectedComponentID,
            zoom: document.zoom,
            margins: document.margins
        )
    }

    private func canDiscardChanges() -> Bool {
        // In a real app, this would show an alert to the user
        // For now, we'll allow discarding changes
        return true
    }

    // MARK: - Component Operations

    func addComponent(_ component: InvoiceComponent) {
        document.add(component)
        validateComponent(component)
        hasUnsavedChanges = true
    }

    func duplicateComponent(_ component: InvoiceComponent) {
        var newComponent = component
        newComponent.id = UUID()
        newComponent.position = CGPoint(
            x: component.position.x + 10,
            y: component.position.y + 10
        )
        addComponent(newComponent)
    }

    func deleteComponent(_ component: InvoiceComponent) {
        document.remove(component.id)
        hasUnsavedChanges = true
    }

    func copyComponent(_ component: InvoiceComponent) {
        clipboardComponent = component
    }

    func pasteComponent() {
        guard let component = clipboardComponent else { return }

        var newComponent = component
        newComponent.id = UUID()
        newComponent.position = CGPoint(
            x: component.position.x + 10,
            y: component.position.y + 10
        )
        addComponent(newComponent)
    }

    func bringToFront(_ component: InvoiceComponent) {
        document.bringToFront(component.id)
        hasUnsavedChanges = true
    }

    func sendToBack(_ component: InvoiceComponent) {
        document.sendToBack(component.id)
        hasUnsavedChanges = true
    }

    // MARK: - Validation

    func validateDocument() {
        validationErrors.removeAll()

        for component in document.getAllComponents() {
            validateComponent(component)
        }

        // Check for overlapping components (performance consideration)
        if document.getAllComponents().count < 100 { // Only check if not too many components
            checkForOverlaps()
        }
    }

    private func validateComponent(_ component: InvoiceComponent) {
        // Remove existing errors for this component
        validationErrors.removeAll { $0.componentId == component.id }

        // Size validation
        if component.size.width < 10 || component.size.height < 10 {
            addValidationError(
                componentId: component.id,
                message: "Component is too small",
                severity: .warning
            )
        }

        // Position validation
        if component.position.x < 0 || component.position.y < 0 {
            addValidationError(
                componentId: component.id,
                message: "Component is positioned off the page",
                severity: .warning
            )
        }

        // Component-specific validation
        switch component.type {
        case .textBox, .companyName, .companyEmail:
            if component.style.placeholderText.isEmpty {
                addValidationError(
                    componentId: component.id,
                    message: "Text component has no placeholder text",
                    severity: .warning
                )
            }
        case .imagePlaceholder, .companyLogo:
            if component.style.imageData == nil {
                addValidationError(
                    componentId: component.id,
                    message: "Image component has no image data",
                    severity: .warning
                )
            }
        default:
            break
        }
    }

    private func checkForOverlaps() {
        let components = document.getAllComponents()
        for i in 0..<components.count {
            for j in i+1..<components.count {
                let comp1 = components[i]
                let comp2 = components[j]

                if comp1.frame.intersects(comp2.frame) {
                    addValidationError(
                        componentId: nil,
                        message: "Components are overlapping",
                        severity: .warning
                    )
                    break
                }
            }
        }
    }

    private func addValidationError(componentId: UUID?, message: String, severity: ValidationError.Severity) {
        let error = ValidationError(
            componentId: componentId,
            message: message,
            severity: severity
        )
        validationErrors.append(error)
    }

    private func clearValidationErrors() {
        validationErrors.removeAll()
    }

    // MARK: - Layer Management

    func selectComponent(_ component: InvoiceComponent?) {
        document.selectedComponentID = component?.id
    }

    func selectComponent(id: UUID?) {
        document.selectedComponentID = id
    }

    func toggleVisibility(for component: InvoiceComponent) {
        document.toggleVisibility(for: component.id)
    }

    func toggleLock(for component: InvoiceComponent) {
        document.toggleLock(for: component.id)
    }

    func moveLayerUp(_ component: InvoiceComponent) {
        document.moveLayerUp(component.id)
    }

    func moveLayerDown(_ component: InvoiceComponent) {
        document.moveLayerDown(component.id)
    }

    func canMoveLayerUp(_ component: InvoiceComponent) -> Bool {
        document.canMoveLayerUp(component.id)
    }

    func canMoveLayerDown(_ component: InvoiceComponent) -> Bool {
        document.canMoveLayerDown(component.id)
    }

    // MARK: - Helper Methods

    private func loadDefaultTemplate() {
        // Create a basic template with common invoice components
        let defaultComponents = [
            InvoiceComponent(
                type: .companyName,
                position: CGPoint(x: 50, y: 50),
                size: CGSize(width: 300, height: 40)
            ),
            InvoiceComponent(
                type: .companyLogo,
                position: CGPoint(x: 400, y: 50),
                size: CGSize(width: 100, height: 40)
            ),
            InvoiceComponent(
                type: .invoiceNumberAndDates,
                position: CGPoint(x: 50, y: 120),
                size: CGSize(width: 200, height: 80)
            ),
            InvoiceComponent(
                type: .billTo,
                position: CGPoint(x: 50, y: 220),
                size: CGSize(width: 250, height: 120)
            ),
            InvoiceComponent(
                type: .servicesTable,
                position: CGPoint(x: 50, y: 360),
                size: CGSize(width: 500, height: 200)
            ),
            InvoiceComponent(
                type: .totals,
                position: CGPoint(x: 350, y: 580),
                size: CGSize(width: 200, height: 100)
            )
        ]

        for component in defaultComponents {
            document.add(component)
        }

        hasUnsavedChanges = false
        lastSavedState = captureCurrentState()
        currentMetadata = nil
    }

    private func generateThumbnail() -> Data? {
        // This would generate a thumbnail image of the current document
        // For now, return nil
        return nil
    }

}
