import Core
import Foundation
import os
import SwiftData

/// Durable storage for the last processed SwiftData history token, scoped per store directory.
struct HistoryTokenStore: Sendable {
    private static let fileName = "swiftdata-history-token.json"

    private let fileURL: URL

    init(container: ModelContainer) {
        if let storeURL = container.configurations.first?.url {
            fileURL = storeURL
                .deletingLastPathComponent()
                .appendingPathComponent(Self.fileName)
        } else {
            // Factory-created persistent containers always have a canonical URL. A unique
            // temporary token is only for isolated in-memory previews/tests.
            fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("invoicingapp-inmemory-\(UUID().uuidString)-\(Self.fileName)")
        }
    }

    func load() -> DefaultHistoryToken? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(DefaultHistoryToken.self, from: data)
        } catch {
            Logger.data.error("HistoryTokenStore load failed at \(self.fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func save(_ token: DefaultHistoryToken) {
        do {
            let directoryURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(token)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            Logger.data.error("HistoryTokenStore save failed at \(self.fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
