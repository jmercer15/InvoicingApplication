import Foundation
@testable import AppShell
import Testing
@MainActor
@Suite struct AppSessionTests {
    @Test func BootstrapFailurePublishesStartupError() async {
        struct StartupTestError: LocalizedError {
            var errorDescription: String? { "test startup failure" }
        }

        let session = AppSession(
            bootstrapper: AppBootstrapper { _ in
                throw StartupTestError()
            }
        )

        await session.bootstrap()

        guard case .failed(let error) = session.phase else {
            Issue.record("Expected failed startup phase")
            return
        }

        #expect(error.errorDescription == "Failed to start InvoicingApplication.")
        #expect(error.recoverySuggestion == "test startup failure")
    }

    @Test func ConcurrentBootstrapRunsOnlyOneRuntimeFactory() async {
        actor Counter {
            private(set) var value = 0

            func increment() {
                value += 1
            }
        }

        struct StartupTestError: Error {}

        let counter = Counter()
        let session = AppSession(
            bootstrapper: AppBootstrapper { _ in
                await counter.increment()
                try await Task.sleep(for: .milliseconds(25))
                throw StartupTestError()
            }
        )

        async let first: Void = session.bootstrap()
        async let second: Void = session.bootstrap()
        _ = await (first, second)

        let calls = await counter.value
        #expect(calls == 1)
    }
}
