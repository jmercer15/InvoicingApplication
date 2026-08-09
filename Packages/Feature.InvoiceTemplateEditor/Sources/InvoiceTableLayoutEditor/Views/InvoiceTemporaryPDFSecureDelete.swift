import Foundation

extension InvoiceTemporaryPDFWorkspace {
    /// Overwrites file contents with zeros before deletion to reduce sensitive PDF recovery risk.
    static func securelyDeleteWorkspace(at workspaceDirectory: URL) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: workspaceDirectory.path) else { return }

        if let enumerator = fileManager.enumerator(
            at: workspaceDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                    continue
                }
                secureOverwriteFile(at: fileURL)
            }
        }

        try? fileManager.removeItem(at: workspaceDirectory)
    }

    private static func secureOverwriteFile(at url: URL) {
        let fileManager = FileManager.default
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? NSNumber else {
            return
        }

        let length = fileSize.intValue
        guard length > 0 else { return }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }

        let chunkSize = 65_536
        var remaining = length
        let zeroChunk = Data(repeating: 0, count: chunkSize)

        do {
            try handle.seek(toOffset: 0)
            while remaining > 0 {
                let writeSize = min(chunkSize, remaining)
                if writeSize == chunkSize {
                    try handle.write(contentsOf: zeroChunk)
                } else {
                    try handle.write(contentsOf: zeroChunk.prefix(writeSize))
                }
                remaining -= writeSize
            }
            try handle.synchronize()
        } catch {
            return
        }
    }
}
