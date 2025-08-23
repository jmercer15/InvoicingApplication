import Foundation
import SwiftUI
import AppKit

class TemplateManager: ObservableObject {
    static let shared = TemplateManager()
    
    @Published var recentTemplates: [TemplateMetadata] = []
    @Published var isLoading = false
    @Published var lastError: String?
    
    private let templatesDirectory: URL
    private let recentTemplatesKey = "RecentTemplates"
    private let maxRecentTemplates = 10
    
    private init() {
        // Create templates directory in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        templatesDirectory = appSupport.appendingPathComponent("InvoiceTemplates", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: templatesDirectory, withIntermediateDirectories: true)
        
        loadRecentTemplates()
    }
    
    // MARK: - Save Template
    
    func saveTemplate(
        document: InvoiceDocument,
        name: String,
        description: String = "",
        author: String = "",
        tags: [String] = [],
        thumbnailData: Data? = nil
    ) async -> Bool {
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        do {
            // Create metadata
            let metadata = TemplateMetadata(
                name: name,
                description: description,
                author: author,
                tags: tags,
                thumbnailData: thumbnailData
            )
            
            // Create template data
            let documentData = InvoiceDocumentData(from: document)
            let templateData = TemplateData(metadata: metadata, document: documentData)
            
            // Encode to JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(templateData)
            
            // Create filename
            let filename = "\(metadata.name.replacingOccurrences(of: " ", with: "_")).template"
            let fileURL = templatesDirectory.appendingPathComponent(filename)
            
            // Write to file
            try jsonData.write(to: fileURL)
            
            // Add to recent templates
            await MainActor.run {
                addToRecentTemplates(metadata)
                isLoading = false
            }
            
            return true
            
        } catch {
            await MainActor.run {
                lastError = "Failed to save template: \(error.localizedDescription)"
                isLoading = false
            }
            return false
        }
    }
    
    // MARK: - Load Template
    
    func loadTemplate(from url: URL) async -> TemplateData? {
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        do {
            let jsonData = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let templateData = try decoder.decode(TemplateData.self, from: jsonData)
            
            // Add to recent templates if it's not already there
            await MainActor.run {
                addToRecentTemplates(templateData.metadata)
                isLoading = false
            }
            
            return templateData
            
        } catch {
            await MainActor.run {
                lastError = "Failed to load template: \(error.localizedDescription)"
                isLoading = false
            }
            return nil
        }
    }
    
    func loadTemplate(metadata: TemplateMetadata) async -> TemplateData? {
        let filename = "\(metadata.name.replacingOccurrences(of: " ", with: "_")).template"
        let fileURL = templatesDirectory.appendingPathComponent(filename)
        return await loadTemplate(from: fileURL)
    }
    
    // MARK: - Browse Templates
    
    func browseTemplates() async -> [TemplateMetadata] {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: templatesDirectory,
                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            var templates: [TemplateMetadata] = []
            
            for fileURL in fileURLs where fileURL.pathExtension == "template" {
                if let templateData = await loadTemplate(from: fileURL) {
                    templates.append(templateData.metadata)
                }
            }
            
            // Sort by modification date (newest first)
            return templates.sorted { $0.modifiedAt > $1.modifiedAt }
            
        } catch {
            await MainActor.run {
                lastError = "Failed to browse templates: \(error.localizedDescription)"
            }
            return []
        }
    }
    
    // MARK: - Delete Template
    
    func deleteTemplate(metadata: TemplateMetadata) async -> Bool {
        do {
            let filename = "\(metadata.name.replacingOccurrences(of: " ", with: "_")).template"
            let fileURL = templatesDirectory.appendingPathComponent(filename)
            
            try FileManager.default.removeItem(at: fileURL)
            
            await MainActor.run {
                removeFromRecentTemplates(metadata.id)
            }
            
            return true
            
        } catch {
            await MainActor.run {
                lastError = "Failed to delete template: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    // MARK: - Recent Templates Management
    
    private func loadRecentTemplates() {
        if let data = UserDefaults.standard.data(forKey: recentTemplatesKey),
           let templates = try? JSONDecoder().decode([TemplateMetadata].self, from: data) {
            recentTemplates = templates
        }
    }
    
    private func saveRecentTemplates() {
        if let data = try? JSONEncoder().encode(recentTemplates) {
            UserDefaults.standard.set(data, forKey: recentTemplatesKey)
        }
    }
    
    private func addToRecentTemplates(_ metadata: TemplateMetadata) {
        // Remove if already exists
        recentTemplates.removeAll { $0.id == metadata.id }
        
        // Add to beginning
        recentTemplates.insert(metadata, at: 0)
        
        // Keep only the most recent templates
        if recentTemplates.count > maxRecentTemplates {
            recentTemplates = Array(recentTemplates.prefix(maxRecentTemplates))
        }
        
        saveRecentTemplates()
    }
    
    private func removeFromRecentTemplates(_ id: UUID) {
        recentTemplates.removeAll { $0.id == id }
        saveRecentTemplates()
    }
    
    // MARK: - Utility Methods
    
    @MainActor
    func generateThumbnail(from document: InvoiceDocument) -> Data? {
        // Create a thumbnail of the current document
        let thumbnailView = InvoiceCanvasView()
            .environmentObject(document)
            .frame(width: 200, height: 283) // A4 aspect ratio scaled down
            .background(Color.white)
        
        let renderer = ImageRenderer(content: thumbnailView)
        renderer.scale = 2.0
        
        guard let image = renderer.nsImage else { return nil }
        return image.tiffRepresentation
    }
    
    func clearError() {
        lastError = nil
    }
}
