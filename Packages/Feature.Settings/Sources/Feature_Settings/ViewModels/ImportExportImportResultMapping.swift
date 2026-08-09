import Core

enum ImportExportImportResultMapping {
    typealias CoreImportResult = Core.ImportResult

    static func make(_ dataResult: CoreImportResult) -> CoreImportResult {
        dataResult
    }

    static func make(
        from error: Error,
        source: ImportSource,
        fileName: String
    ) -> CoreImportResult {
        let message = error.localizedDescription
        return makeFailure(
            source: source,
            fileName: fileName,
            message: "Import failed: \(message)"
        )
    }

    static func makeFailure(
        source: ImportSource,
        fileName: String,
        message: String
    ) -> CoreImportResult {
        CoreImportResult(
            source: source,
            success: false,
            successful: 0,
            failed: 1,
            messages: [message],
            fileName: fileName
        )
    }

    static func make(
        sourceRawValue: String,
        successful: Int,
        failed: Int,
        importedCounts: [String: Int] = [:],
        messages: [String],
        fileName: String
    ) -> CoreImportResult {
        CoreImportResult(
            source: ImportSource(rawValue: sourceRawValue) ?? .unknown,
            success: failed == 0,
            successful: successful,
            failed: failed,
            importedCounts: importedCounts,
            messages: messages,
            fileName: fileName
        )
    }

    static func makeUnsupportedCombination(
        source: ImportSource,
        fileName: String,
        actualExtension: String?,
        supportedExtensions: [String]
    ) -> CoreImportResult {
        let normalizedExtension = (actualExtension ?? "").lowercased()
        let supported = supportedExtensions.map { ".\($0)" }.joined(separator: ", ")
        return makeFailure(
            source: source,
            fileName: fileName,
            message: "Unsupported file type for \(source.description). '\(normalizedExtension)' is not supported. Expected one of: \(supported)."
        )
    }
}
