import Foundation
import Testing
@testable import Feature_Settings

@MainActor
struct SystemSettingsOpenerTests {
    @Test func opensResolvedSystemSettingsApplication() {
        let expectedURL = URL(fileURLWithPath: "/Applications/System Settings.app")
        var resolvedIdentifier: String?
        var openedURL: URL?
        let opener = SystemSettingsOpener(
            resolveApplicationURL: { identifier in
                resolvedIdentifier = identifier
                return expectedURL
            },
            openApplicationURL: { url in
                openedURL = url
                return true
            }
        )

        #expect(opener.open())
        #expect(resolvedIdentifier == SystemSettingsOpener.bundleIdentifier)
        #expect(openedURL == expectedURL)
    }

    @Test func reportsFailureWhenSystemSettingsCannotBeResolved() {
        var attemptedOpen = false
        let opener = SystemSettingsOpener(
            resolveApplicationURL: { _ in nil },
            openApplicationURL: { _ in
                attemptedOpen = true
                return true
            }
        )

        #expect(opener.open() == false)
        #expect(attemptedOpen == false)
    }

    @Test func reportsFailureWhenWorkspaceCannotOpenSystemSettings() {
        let applicationURL = URL(fileURLWithPath: "/Applications/System Settings.app")
        let opener = SystemSettingsOpener(
            resolveApplicationURL: { _ in applicationURL },
            openApplicationURL: { _ in false }
        )

        #expect(opener.open() == false)
    }
}
