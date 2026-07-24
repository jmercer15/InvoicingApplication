import Data
import Core

enum ImportExportImportResultMapping {
    typealias CoreImportResult = Core.ImportResult

    static func make(_ dataResult: Data.ImportResult) -> CoreImportResult {
        make(
            sourceRawValue: dataResult.source.rawValue,
            successful: dataResult.successful,
            failed: dataResult.failed,
            importedCounts: dataResult.importedCounts,
            messages: dataResult.messages,
            fileName: dataResult.fileName
        )
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

    static func makeAllDataSummary(
        from results: [Data.ImportResult],
        source: ImportSource = .allData,
        fileName: String = "Internal Resource Bundle"
    ) -> CoreImportResult {
        let totalSuccessful = results.reduce(0) { $0 + $1.successful }
        let totalFailed = results.reduce(0) { $0 + $1.failed }
        let allMessages = results.flatMap(\.messages)
        let aggregatedCounts = results.reduce(into: [String: Int]()) { counts, result in
            for (key, value) in result.importedCounts {
                counts[key, default: 0] += value
            }
        }

        return CoreImportResult(
            source: source,
            success: totalFailed == 0,
            successful: totalSuccessful,
            failed: totalFailed,
            importedCounts: aggregatedCounts,
            messages: allMessages,
            fileName: fileName
        )
    }

    static func makePreferredSourceResult(
        from results: [Data.ImportResult],
        preferredSource: ImportSource,
        fileName: String = "Internal Resource Bundle"
    ) -> CoreImportResult {
        guard let preferred = results.first(where: { $0.source == preferredSource }) else {
            return results.first.map(make(_:)) ?? CoreImportResult(
                source: preferredSource,
                success: false,
                successful: 0,
                failed: 1,
                messages: ["No result was returned."],
                fileName: fileName
            )
        }

        return make(preferred)
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
