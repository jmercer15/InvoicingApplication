import XCTest
import SwiftData
import Core
@testable import Data
@testable import Feature_Calendar

@MainActor
final class NewSessionViewModelSupportLogTests: XCTestCase {
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private var unitOfWork: SwiftDataUnitOfWork!

    override func setUp() async throws {
        try await super.setUp()

        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        modelContainer = container
        modelContext = context
        unitOfWork = SwiftDataUnitOfWork(modelContext: modelContext, modelContainer: modelContainer)
    }

    override func tearDown() async throws {
        unitOfWork = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    func testSaveWithEnabledSupportLog_CreatesSupportLogForSavedSession() async throws {
        let (client, service) = try insertClientAndService()
        let viewModel = NewSessionViewModel(unitOfWork: unitOfWork, session: nil, instanceDate: nil, instanceEndDate: nil)

        await waitForInitialLoad(viewModel)

        var onSaveCompletedCalled = false
        viewModel.onSaveCompleted = {
            onSaveCompletedCalled = true
        }

        var form = viewModel.formModel
        let start = Date().addingTimeInterval(600)
        form.title = "Support Log Save Test"
        form.startTime = start
        form.endTime = start.addingTimeInterval(3600)
        form.status = SessionStatus.scheduled.rawValue
        form.location = "Participant Home"
        form.selectedClientID = client.id
        form.selectedClientServiceID = service.id
        form.supportLogDraft.isEnabled = true
        form.supportLogDraft.participantName = client.fullName
        form.supportLogDraft.participantNdisNumber = client.ndisNumber
        form.supportLogDraft.supportItemNumber = "01_001_0107_1_1"
        form.supportLogDraft.serviceDescription = "Personal support"
        form.supportLogDraft.location = "Participant Home"
        form.supportLogDraft.deliveredFrom = form.startTime
        form.supportLogDraft.deliveredTo = form.endTime
        form.supportLogDraft.deliveredBy = "Worker One"
        form.supportLogDraft.attestedBy = "Worker One"
        form.supportLogDraft.attestedAt = Date()
        form.supportLogDraft.signatureMethod = SignatureMethod.signature.rawValue
        form.supportLogDraft.signedBy = "Participant"
        form.supportLogDraft.signedAt = Date()
        viewModel.formModel = form

        viewModel.handleSaveButtonTapped()
        await waitForSaveCompletion(viewModel)

        XCTAssertNil(viewModel.persistenceError)
        XCTAssertTrue(onSaveCompletedCalled)

        let sessions = try await unitOfWork.sessions.fetchAll()
        XCTAssertEqual(sessions.count, 1)
        guard let savedSession = sessions.first else {
            XCTFail("Expected one saved session")
            return
        }

        let logs = try await unitOfWork.supportLogs.fetchBySession(savedSession.id)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.participantName, client.fullName)
        XCTAssertEqual(logs.first?.supportItemNumber, "01_001_0107_1_1")
    }

    func testSaveWithInvalidSupportLog_SetsPersistenceErrorAndSkipsSaveCompletionCallback() async throws {
        let (client, service) = try insertClientAndService()
        let viewModel = NewSessionViewModel(unitOfWork: unitOfWork, session: nil, instanceDate: nil, instanceEndDate: nil)

        await waitForInitialLoad(viewModel)

        var onSaveCompletedCalled = false
        viewModel.onSaveCompleted = {
            onSaveCompletedCalled = true
        }

        var form = viewModel.formModel
        let start = Date().addingTimeInterval(900)
        form.title = "Support Log Validation Failure Test"
        form.startTime = start
        form.endTime = start.addingTimeInterval(3600)
        form.status = SessionStatus.scheduled.rawValue
        form.location = "Participant Home"
        form.selectedClientID = client.id
        form.selectedClientServiceID = service.id
        form.supportLogDraft.isEnabled = true
        form.supportLogDraft.participantName = ""
        form.supportLogDraft.participantNdisNumber = client.ndisNumber
        form.supportLogDraft.supportItemNumber = ""
        form.supportLogDraft.serviceDescription = ""
        form.supportLogDraft.location = ""
        form.supportLogDraft.deliveredFrom = form.startTime
        form.supportLogDraft.deliveredTo = form.endTime
        form.supportLogDraft.deliveredBy = ""
        form.supportLogDraft.attestedBy = ""
        form.supportLogDraft.attestedAt = Date()
        viewModel.formModel = form

        viewModel.handleSaveButtonTapped()
        await waitForSaveCompletion(viewModel)

        XCTAssertFalse(onSaveCompletedCalled)
        XCTAssertTrue(viewModel.persistenceError?.contains("Support log required fields are missing") == true)

        let sessions = try await unitOfWork.sessions.fetchAll()
        XCTAssertEqual(sessions.count, 1)

        guard let savedSession = sessions.first else {
            XCTFail("Expected created session to exist")
            return
        }
        let logs = try await unitOfWork.supportLogs.fetchBySession(savedSession.id)
        XCTAssertTrue(logs.isEmpty)
    }

    private func waitForInitialLoad(_ viewModel: NewSessionViewModel) async {
        for _ in 0..<80 {
            if !viewModel.availableClients.isEmpty {
                break
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    private func waitForSaveCompletion(_ viewModel: NewSessionViewModel) async {
        for _ in 0..<120 {
            if !viewModel.isSaving {
                break
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    private func insertClientAndService() throws -> (ClientEntity, ClientServiceEntity) {
        let client = ClientEntity(
            id: UUID(),
            ndisNumber: "NDIS-\(UUID().uuidString.prefix(8))",
            fullName: "Support Log Test Client",
            status: .active
        )

        let service = ClientServiceEntity(
            id: UUID(),
            serviceName: "Personal Support",
            unit: "hour",
            rate: 120
        )
        service.client = client

        modelContext.insert(client)
        modelContext.insert(service)
        try modelContext.save()

        return (client, service)
    }
}
