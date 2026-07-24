import Foundation

enum ImportExportTimestamp {
    static func fileSuffix() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}
