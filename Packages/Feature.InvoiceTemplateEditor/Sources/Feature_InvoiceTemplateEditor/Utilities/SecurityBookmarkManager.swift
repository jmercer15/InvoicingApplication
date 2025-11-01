import Foundation
import AppKit

class SecurityBookmarkManager: ObservableObject, @unchecked Sendable {
    static let shared = SecurityBookmarkManager()
    
    private let bookmarksKey = "SecurityBookmarks"
    private var bookmarks: [String: Data] = [:]
    
    private init() {
        loadBookmarks()
    }
    
    // MARK: - Bookmark Management
    
    func createBookmark(for url: URL) -> Data? {
        return try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
    
    func resolveBookmark(_ bookmarkData: Data) -> URL? {
        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
    
    func accessFile(at url: URL, operation: () throws -> Void) throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw SecurityBookmarkError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        try operation()
    }
    
    func accessFileWithBookmark(_ bookmarkData: Data, operation: (URL) throws -> Void) throws {
        guard let url = resolveBookmark(bookmarkData) else {
            throw SecurityBookmarkError.invalidBookmark
        }
        try accessFile(at: url) {
            try operation(url)
        }
    }
    
    // MARK: - Persistent Storage
    
    private func saveBookmark(_ bookmarkData: Data, for key: String) {
        bookmarks[key] = bookmarkData
        saveBookmarks()
    }
    
    private func loadBookmarks() {
        if let data = UserDefaults.standard.data(forKey: bookmarksKey),
           let loadedBookmarks = try? JSONDecoder().decode([String: Data].self, from: data) {
            bookmarks = loadedBookmarks
        }
    }
    
    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
    }
    
    // MARK: - File Access Utilities
    // Note: openFile() and saveFile() methods removed as they were unused
}

// MARK: - Security Bookmark Error

enum SecurityBookmarkError: LocalizedError {
    case accessDenied
    case invalidBookmark
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access denied to file"
        case .invalidBookmark:
            return "Invalid security bookmark"
        case .fileNotFound:
            return "File not found"
        }
    }
}
