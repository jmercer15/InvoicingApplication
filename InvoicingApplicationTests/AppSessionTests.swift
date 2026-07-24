import XCTest
import Core
import Data
@testable import AppShell
@testable import InvoicingApplication

@MainActor
final class AppSessionTests: XCTestCase {
    func testBootstrapFailureMovesToFailedPhase() async {
        struct SampleError: Error {}

        let session = AppSession(bootstrapper: AppBootstrapper { _ in
            throw SampleError()
        })

        await session.bootstrap()

        guard case .failed = session.phase else {
            return XCTFail("Expected failed phase")
        }
    }

    func testDuplicateBootstrapWhileInFlightDoesNotInvokeBootstrapperTwice() async {
        final class Gate {
            var calls = 0
            var continuation: CheckedContinuation<AppRuntime, Error>?
        }

        let gate = Gate()
        let session = AppSession(bootstrapper: AppBootstrapper { _ in
            gate.calls += 1
            return try await withCheckedThrowingContinuation { continuation in
                gate.continuation = continuation
            }
        })

        async let first: Void = session.bootstrap()
        await Task.yield()
        await session.bootstrap()

        XCTAssertEqual(gate.calls, 1)

        let runtime = try! await makeTestRuntime()
        gate.continuation?.resume(returning: runtime)
        await first

        guard case .ready = session.phase else {
            return XCTFail("Expected ready phase")
        }
    }

    func testSuccessfulBootstrapMovesToReadyPhase() async throws {
        let runtime = try await makeTestRuntime()
        let session = AppSession(bootstrapper: AppBootstrapper { _ in runtime })

        await session.bootstrap()

        guard case let .ready(readyRuntime) = session.phase else {
            return XCTFail("Expected ready phase")
        }
        XCTAssertTrue(readyRuntime.modelContainer === runtime.modelContainer)
    }

    private func makeTestRuntime() async throws -> AppRuntime {
        let database = try await AppDatabase.bootstrap(policy: .inMemory)

        let dbPhase = ProductionRuntimeAssembly.DatabasePhase(database: database)
        let independent = ProductionRuntimeAssembly.makeIndependentServices()
        let persistence = ProductionRuntimeAssembly.makePersistenceBundle(phase: dbPhase)
        let storeChangeMonitor = SwiftDataStoreChangeMonitor(modelContainer: database.container)
        let services = ProductionRuntimeAssembly.assembleWorkspaceServices(
            independent: independent,
            database: database,
            storeChangeMonitor: storeChangeMonitor
        )
        let ndisService = TestNDISBillingIntegrationService()

        return AppRuntime(
            database: database,
            services: services,
            persistence: persistence,
            ndisBillingIntegrationService: ndisService
        )
    }
}

private struct TestNDISBillingIntegrationService: NDISBillingIntegrationServiceProtocol {
    func generateNDISInvoice(for sessionIds: [UUID], clientId: UUID) async throws -> NDISBillingReport {
        NDISBillingReport(
            invoice: nil,
            processedSessionsCount: sessionIds.count,
            successfulSessionsCount: 0,
            failedSessions: []
        )
    }
}
