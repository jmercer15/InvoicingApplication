import SwiftUI

@MainActor
public final class TemplateEditorWorkspaceViewModel: ObservableObject {
    // MARK: - Dependencies
    public let templateManager: TemplateManager
    
    public let editorViewModel: InvoiceTemplateEditorViewModel

    @Published var templates: [TemplateItem] = []
    @Published var isLoadingTemplates = false
    @Published var isOpeningTemplate = false
    @Published var templateLoadError: String?
    @Published var activeTemplate: TemplateItem?
    @Published var showingSaveDialog = false
    @Published var showingBrowserDialog = false
    @Published var lastAvailableSize: CGSize = .zero
    @Published var showRulers = true
    @Published var showMargins = false
    @Published var showDividers = true
    @Published var isPaletteVisible = true
    @Published var isSectionsPanelVisible = true
    @Published var rulerUnit: RulerUnit = .points
    @Published var showMarginsOverlay = false
    @Published var marginLeftStr = ""
    @Published var marginRightStr = ""
    @Published var marginTopStr = ""
    @Published var marginBottomStr = ""

    private var hasLoadedTemplates = false

    public init(templateManager: TemplateManager, editorViewModel: InvoiceTemplateEditorViewModel) {
        self.templateManager = templateManager
        self.editorViewModel = editorViewModel
        refreshMarginStrings()
    }

    func loadTemplates(forceReload: Bool = false) {
        guard !isLoadingTemplates else { return }
        if hasLoadedTemplates && !forceReload { return }

        isLoadingTemplates = true
        templateLoadError = nil

        Task { [weak self] in
            guard let self else { return }
            let metadataList = await templateManager.browseTemplates()

            await MainActor.run {
                let items = metadataList
                    .map { TemplateItem(metadata: $0) }
                    .sorted { $0.lastModified > $1.lastModified }

                let resolvedItems = items
                self.templates = resolvedItems

                if let currentActive = self.activeTemplate {
                    if let metadata = currentActive.metadata,
                       let matching = resolvedItems.first(where: { $0.id == metadata.id }) {
                        self.activeTemplate = matching
                    } else if let matchingByName = resolvedItems.first(where: { $0.name == self.editorViewModel.currentTemplateName }) {
                        self.activeTemplate = matchingByName
                    }
                }

                self.hasLoadedTemplates = true
                self.isLoadingTemplates = false
            }
        }
    }

    func refreshTemplates() {
        hasLoadedTemplates = false
        loadTemplates(forceReload: true)
    }
    
    private func refreshMarginStrings() {
        let margins = editorViewModel.document.margins
        marginLeftStr = String(format: "%.0f", margins.left)
        marginRightStr = String(format: "%.0f", margins.right)
        marginTopStr = String(format: "%.0f", margins.top)
        marginBottomStr = String(format: "%.0f", margins.bottom)
    }

    private func sanitizeTemplateName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        var sanitized = name.components(separatedBy: invalidCharacters).joined(separator: "_")
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: " ", with: "_")
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }
        return sanitized.isEmpty ? "Template" : sanitized
    }

    private func makeUniqueTemplateName(basedOn base: String, excluding templateID: UUID? = nil) -> String {
        let trimmedBase = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmedBase.isEmpty ? "Template" : trimmedBase

        let existingSanitized = Set(
            templates
                .filter { $0.id != templateID }
                .map { sanitizeTemplateName($0.name).lowercased() }
        )

        var candidate = baseName
        var sanitizedCandidate = sanitizeTemplateName(candidate).lowercased()

        if !existingSanitized.contains(sanitizedCandidate) {
            return candidate
        }

        var copyIndex = 1
        while true {
            copyIndex += 1
            let suffix = copyIndex == 2 ? " Copy" : " Copy \(copyIndex - 1)"
            candidate = baseName + suffix
            sanitizedCandidate = sanitizeTemplateName(candidate).lowercased()
            if !existingSanitized.contains(sanitizedCandidate) {
                return candidate
            }
        }
    }

    func sortTemplatesByRecency() {
        templates.sort { $0.lastModified > $1.lastModified }
    }

    @discardableResult
    func beginNewTemplate(
        name: String = "Untitled Template",
        description: String = "",
        tags: [String] = []
    ) -> TemplateItem {
        let uniqueName = makeUniqueTemplateName(basedOn: name)

        editorViewModel.createNewDocument()
        editorViewModel.currentTemplateName = uniqueName
        editorViewModel.templateDescription = description
        editorViewModel.templateTags = tags
        refreshMarginStrings()

        // Remove existing draft placeholders with the same name
        templates.removeAll { $0.metadata == nil && $0.name == uniqueName }

        let draftTemplate = TemplateItem(
            id: UUID(),
            name: uniqueName,
            description: description.isEmpty ? "Draft template" : description,
            category: .all,
            previewImage: "rectangle.and.pencil.and.ellipsis",
            isPremium: false,
            lastModified: Date(),
            tags: tags,
            metadata: nil
        )

        templates.insert(draftTemplate, at: 0)
        sortTemplatesByRecency()
        activeTemplate = draftTemplate
        return draftTemplate
    }

    func openTemplate(_ template: TemplateItem) async -> Bool {
        guard !isOpeningTemplate else { return false }

        isOpeningTemplate = true
        templateLoadError = nil
        defer { isOpeningTemplate = false }

        if let metadata = template.metadata {
            guard let templateData = await templateManager.loadTemplate(metadata: metadata) else {
                templateLoadError = "Unable to load template \"\(template.name)\"."
                return false
            }

            editorViewModel.loadTemplate(templateData)
            refreshMarginStrings()
            applySavedTemplateMetadata(templateData.metadata)
            return true
        } else {
            editorViewModel.createNewDocument()
            editorViewModel.currentTemplateName = template.name
            editorViewModel.templateDescription = template.description
            editorViewModel.templateTags = template.tags
            activeTemplate = template
            refreshMarginStrings()
            return true
        }
    }

    func closeTemplate() {
        activeTemplate = nil
    }

    func applySavedTemplateMetadata(_ metadata: TemplateMetadata) {
        let updatedItem = TemplateItem(metadata: metadata)

        // Remove draft placeholders matching the same name
        templates.removeAll { item in
            item.metadata == nil && item.name == metadata.name
        }

        if let index = templates.firstIndex(where: { $0.id == updatedItem.id }) {
            templates[index] = updatedItem
        } else {
            templates.insert(updatedItem, at: 0)
        }

        sortTemplatesByRecency()
        activeTemplate = updatedItem
    }

    func updateActiveTemplateMetadata(
        name: String? = nil,
        description: String? = nil,
        tags: [String]? = nil,
        thumbnailData: Data? = nil
    ) {
        guard let current = activeTemplate else { return }

        let newTags = tags ?? current.tags
        let updated = TemplateItem(
            id: current.id,
            name: name ?? current.name,
            description: description ?? current.description,
            category: current.metadata != nil ? TemplateCategory(metadataTags: newTags) : TemplateCategory(metadataTags: newTags),
            previewImage: current.previewImage,
            isPremium: current.isPremium,
            lastModified: Date(),
            tags: newTags,
            thumbnailData: thumbnailData ?? current.thumbnailData,
            metadata: current.metadata
        )

        activeTemplate = updated

        if let index = templates.firstIndex(where: { $0.id == updated.id }) {
            templates[index] = updated
        }
        sortTemplatesByRecency()
    }

    func deleteTemplate(_ template: TemplateItem) async -> Bool {
        guard let metadata = template.metadata else { return false }
        let success = await templateManager.deleteTemplate(metadata: metadata)

        if success {
            templates.removeAll { $0.id == template.id }
            if activeTemplate?.id == template.id {
                activeTemplate = nil
            }
        }

        return success
    }

    func duplicateTemplate(_ template: TemplateItem) async -> TemplateItem? {
        guard let metadata = template.metadata else { return nil }
        guard let templateData = await templateManager.loadTemplate(metadata: metadata) else { return nil }

        let duplicateName = makeUniqueTemplateName(basedOn: template.name)

        let documentCopy = InvoiceDocument()
        templateData.document.apply(to: documentCopy)

        let savedMetadata = await templateManager.saveTemplate(
            document: documentCopy,
            name: duplicateName,
            description: templateData.metadata.description,
            author: templateData.metadata.author,
            tags: templateData.metadata.tags,
            thumbnailData: templateData.metadata.thumbnailData,
            existingMetadata: nil
        )

        guard let savedMetadata else { return nil }

        let newItem = TemplateItem(metadata: savedMetadata)
        if let index = templates.firstIndex(where: { $0.id == newItem.id }) {
            templates[index] = newItem
        } else {
            templates.insert(newItem, at: 0)
        }
        sortTemplatesByRecency()
        return newItem
    }

    func updateTemplateMetadata(
        for template: TemplateItem,
        name: String,
        description: String,
        tags: [String]
    ) async -> TemplateItem? {
        guard let metadata = template.metadata else { return nil }
        guard let templateData = await templateManager.loadTemplate(metadata: metadata) else { return nil }

        let newName = makeUniqueTemplateName(basedOn: name, excluding: template.id)
        let documentCopy = InvoiceDocument()
        templateData.document.apply(to: documentCopy)

        let updatedMetadata = await templateManager.saveTemplate(
            document: documentCopy,
            name: newName,
            description: description,
            author: templateData.metadata.author,
            tags: tags,
            thumbnailData: templateData.metadata.thumbnailData,
            existingMetadata: metadata
        )

        guard let updatedMetadata else { return nil }

        let updatedItem = TemplateItem(metadata: updatedMetadata)
        if let index = templates.firstIndex(where: { $0.id == updatedItem.id }) {
            templates[index] = updatedItem
        } else {
            templates.insert(updatedItem, at: 0)
        }
        sortTemplatesByRecency()
        if activeTemplate?.id == updatedItem.id {
            activeTemplate = updatedItem
        }
        return updatedItem
    }
}
