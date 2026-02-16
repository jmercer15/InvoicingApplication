import XCTest
import SwiftData
import Core
@testable import Data

@MainActor
final class SupportLogRepositoryTests: XCTestCase {
    private var modelContext: ModelContext!
    private var repository: SupportLogRepositorySwiftData!

    override func setUp() async throws {
        try await super.setUp()
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        modelContext = context
        repository = SupportLogRepositorySwiftData(modelContext: modelContext)
    }

    override func tearDown() async throws {
        repository = nil
        modelContext = nil
        try await super.tearDown()
    }

    func testFetchBySessionReturnsOnlyMatchingLogs() async throws {
        let client = try insertClient()
        let firstSession = try insertSession(client: client)
        let secondSession = try insertSession(client: client)

        let firstLog = try await repository.create(
            makeLog(clientId: client.id, sessionId: firstSession.id, deliveredFrom: makeDate(2026, 1, 10))
        )
        _ = try await repository.create(
            makeLog(clientId: client.id, sessionId: secondSession.id, deliveredFrom: makeDate(2026, 1, 11))
        )

        let logs = try await repository.fetchBySession(firstSession.id)

        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.id, firstLog.id)
    }

    func testFetchByClientRespectsDateRange() async throws {
        let client = try insertClient()
        let session = try insertSession(client: client)

        _ = try await repository.create(
            makeLog(clientId: client.id, sessionId: session.id, deliveredFrom: makeDate(2026, 1, 1))
        )
        let inRange = try await repository.create(
            makeLog(clientId: client.id, sessionId: session.id, deliveredFrom: makeDate(2026, 2, 10))
        )

        let logs = try await repository.fetchByClient(
            client.id,
            from: makeDate(2026, 2, 1),
            to: makeDate(2026, 2, 28)
        )

        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.id, inRange.id)
    }

    func testCreateRejectsMissingRequiredFields() async throws {
        let client = try insertClient()
        let session = try insertSession(client: client)
        let deliveredFrom = makeDate(2026, 2, 10)
        let invalid = SupportLog(
            id: UUID(),
            clientId: client.id,
            sessionId: session.id,
            participantName: "",
            participantNdisNumber: "4300123456",
            supportItemNumber: "01_011_0107_1_1",
            serviceDescription: "Daily support",
            location: "Home",
            deliveredFrom: deliveredFrom,
            deliveredTo: deliveredFrom.addingTimeInterval(3_600),
            quantityHours: 1.0,
            deliveredBy: "Support Worker",
            attestedBy: "Participant",
            attestedAt: deliveredFrom.addingTimeInterval(3_600),
            signatureMethod: SignatureMethod.attestation.rawValue
        )

        do {
            _ = try await repository.create(invalid)
            XCTFail("Expected validation failure for empty participant name.")
        } catch { }
    }

    private func insertClient() throws -> ClientEntity {
        let client = ClientEntity(
            id: UUID(),
            ndisNumber: "4300\(Int.random(in: 100000...999999))",
            fullName: "Support Log Test Client",
            status: .active
        )
        modelContext.insert(client)
        try modelContext.save()
        return client
    }

    private func insertSession(client: ClientEntity) throws -> SessionEntity {
        let session = SessionEntity(id: UUID())
        session.title = "Support Session"
        session.client = client
        session.status = .completed
        session.startTime = Date().addingTimeInterval(-3_600)
        session.endTime = Date()
        modelContext.insert(session)
        try modelContext.save()
        return session
    }

    private func makeLog(clientId: UUID, sessionId: UUID, deliveredFrom: Date) -> SupportLog {
        SupportLog(
            id: UUID(),
            clientId: clientId,
            sessionId: sessionId,
            participantName: "Participant",
            participantNdisNumber: "4300123456",
            supportItemNumber: "01_011_0107_1_1",
            serviceDescription: "Daily support",
            location: "Home",
            deliveredFrom: deliveredFrom,
            deliveredTo: deliveredFrom.addingTimeInterval(3_600),
            quantityHours: 1.0,
            deliveredBy: "Support Worker",
            attestedBy: "Participant",
            attestedAt: deliveredFrom.addingTimeInterval(3_600),
            signatureMethod: SignatureMethod.attestation.rawValue,
            signedBy: nil,
            signedAt: nil,
            cancellationReasonCode: nil,
            notes: nil
        )
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }
}
