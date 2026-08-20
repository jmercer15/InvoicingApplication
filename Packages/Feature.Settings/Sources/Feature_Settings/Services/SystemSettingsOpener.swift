import AppKit
import Foundation

@MainActor
struct SystemSettingsOpener {
    static let bundleIdentifier = "com.apple.systempreferences"

    private let resolveApplicationURL: (String) -> URL?
    private let openApplicationURL: (URL) -> Bool

    init(
        resolveApplicationURL: @escaping (String) -> URL? = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        },
        openApplicationURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }
    ) {
        self.resolveApplicationURL = resolveApplicationURL
        self.openApplicationURL = openApplicationURL
    }

    func open() -> Bool {
        guard let applicationURL = resolveApplicationURL(Self.bundleIdentifier) else {
            return false
        }
        return openApplicationURL(applicationURL)
    }
}
