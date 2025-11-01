import Foundation
import SwiftUI
import AppKit
import CoreGraphics

class TemplateManager: ObservableObject, @unchecked Sendable {
    @MainActor
    static let shared = TemplateManager()
    
    @Published var recentTemplates: [TemplateMetadata] = []
    @Published var isLoading = false
    @Published var lastError: String?
    
    let templatesDirectory: URL
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
    
    // MARK: - Template Operations
    // Template CRUD operations moved to TemplateOperations.swift
    
    // MARK: - Security-Scoped Bookmarks (App Sandbox Compliance)
    
    func createSecurityBookmark(for url: URL) -> Data? {
        return SecurityBookmarkManager.shared.createBookmark(for: url)
    }
    
    func resolveSecurityBookmark(_ bookmarkData: Data) -> URL? {
        return SecurityBookmarkManager.shared.resolveBookmark(bookmarkData)
    }
    
    func accessFile(at url: URL, operation: () throws -> Void) throws {
        try SecurityBookmarkManager.shared.accessFile(at: url, operation: operation)
    }
    
    // MARK: - Helper Methods
    
    func sanitizeFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        var sanitized = name.components(separatedBy: invalidCharacters).joined(separator: "_")
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: " ", with: "_")
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }
        if sanitized.isEmpty {
            sanitized = "Template"
        }
        return sanitized
    }
    
    private func findLegacyMetadata(for pdfURL: URL) -> URL? {
        let baseName = pdfURL.deletingPathExtension().lastPathComponent
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: templatesDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let decoder = JSONDecoder()
        for fileURL in fileURLs where fileURL.pathExtension == "metadata" {
            if fileURL == findMetadataForPDF(at: pdfURL) {
                continue
            }
            if let data = try? Data(contentsOf: fileURL),
               let templateData = try? decoder.decode(TemplateData.self, from: data) {
                let sanitized = sanitizeFileName(templateData.metadata.name)
                if sanitized == baseName {
                    return fileURL
                }
            }
        }

        return nil
    }

    func templateData(for pdfURL: URL) -> TemplateData? {
        let decoder = JSONDecoder()
        let metadataURL = findMetadataForPDF(at: pdfURL)

        if let data = try? Data(contentsOf: metadataURL),
           let templateData = try? decoder.decode(TemplateData.self, from: data) {
            return templateData
        }

        if let legacyURL = findLegacyMetadata(for: pdfURL),
           let data = try? Data(contentsOf: legacyURL),
           let templateData = try? decoder.decode(TemplateData.self, from: data) {
            try? data.write(to: metadataURL)
            try? FileManager.default.removeItem(at: legacyURL)
            return templateData
        }

        return nil
    }
    
    private func findMetadataForPDF(at pdfURL: URL) -> URL {
        // Try to find metadata file with same name but .metadata extension
        let baseName = pdfURL.deletingPathExtension().lastPathComponent
        return templatesDirectory.appendingPathComponent("\(baseName).metadata")
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
    
    func addToRecentTemplates(_ metadata: TemplateMetadata) {
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
    
    func removeFromRecentTemplates(_ id: UUID) {
        recentTemplates.removeAll { $0.id == id }
        saveRecentTemplates()
    }
    
    // MARK: - Utility Methods
    
    @MainActor
    func generateThumbnail(from document: InvoiceDocument) -> Data? {
        // Create a thumbnail of the current document using the modern canvas
        let workspace = TemplateEditorWorkspaceViewModel()
        workspace.editorViewModel.document = document
        workspace.marginLeftStr = String(format: "%.0f", document.margins.left)
        workspace.marginRightStr = String(format: "%.0f", document.margins.right)
        workspace.marginTopStr = String(format: "%.0f", document.margins.top)
        workspace.marginBottomStr = String(format: "%.0f", document.margins.bottom)
        
        let thumbnailView = ModernCanvasView()
            .environmentObject(workspace)
            .environmentObject(workspace.editorViewModel)
            .environmentObject(document)
            .frame(width: 200, height: 283) // A4 aspect ratio scaled down
            .background(Color.canvasBackground)
        
        let renderer = ImageRenderer(content: thumbnailView)
        renderer.scale = 2.0
        
        guard let image = renderer.nsImage else { return nil }
        return image.tiffRepresentation
    }
    
    func clearError() {
        lastError = nil
    }
}

// MARK: - Template Error

enum TemplateError: LocalizedError {
    case accessDenied
    case pdfGenerationFailed
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access denied to file"
        case .pdfGenerationFailed:
            return "Failed to generate PDF template"
        case .fileNotFound:
            return "Template file not found"
        }
    }
}

