import Foundation

/// Creates a recoverable, same-directory copy of a store before a qualified migration opens it.
/// The caller owns retention; this helper never replaces or deletes the source store.
public enum PersistentStoreRecovery {
    public static func createRecoveryCopyIfNeeded(
        for storeURL: URL,
        fileManager: FileManager = .default
    ) throws -> URL? {
        guard fileManager.fileExists(atPath: storeURL.path) else { return nil }

        let recoveryDirectory = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("MigrationRecovery", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)

        for sourceURL in storeFiles(for: storeURL, fileManager: fileManager) {
            let destinationURL = recoveryDirectory.appendingPathComponent(sourceURL.lastPathComponent)
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }
        return recoveryDirectory
    }

    static func storeFiles(for storeURL: URL, fileManager: FileManager) -> [URL] {
        let candidates = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm")
        ]
        return candidates.filter { fileManager.fileExists(atPath: $0.path) }
    }

    /// Moves an incompatible canonical store aside before an explicitly user-approved fresh start.
    /// This never deletes files and never scans or moves legacy Application Support locations.
    public static func archiveForFreshInstall(
        storeURL: URL,
        fileManager: FileManager = .default
    ) throws -> URL? {
        let sourceFiles = storeFiles(for: storeURL, fileManager: fileManager)
        guard !sourceFiles.isEmpty else { return nil }

        let archiveDirectory = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("FreshStartArchivedStores", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: archiveDirectory, withIntermediateDirectories: true)

        for sourceURL in sourceFiles {
            try fileManager.moveItem(
                at: sourceURL,
                to: archiveDirectory.appendingPathComponent(sourceURL.lastPathComponent)
            )
        }
        return archiveDirectory
    }
}
