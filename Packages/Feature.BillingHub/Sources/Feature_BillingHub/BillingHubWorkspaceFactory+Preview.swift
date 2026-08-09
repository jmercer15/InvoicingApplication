import Core
import PersistenceModels
import DataInterfaces
import Foundation
import SwiftData

private struct PreviewBillingIntegrationService: NDISBillingIntegrationServiceProtocol {
    func generateNDISInvoice(for sessionIds: [UUID], clientId: UUID    ) async throws -> Core.NDISBillingReport {
        Core.NDISBillingReport(
            invoice: nil,
            processedSessionsCount: 0,
            successfulSessionsCount: 0,
            failedSessions: [],
            warnings: []
        )
    }
}

private struct PreviewBillingDraftBuilder: BillingDraftBuilding {
    func buildDraft(
        sessionId: UUID,
        clientId: UUID,
        serviceId: UUID,
        billingContext: NDISBillingContext
    ) async throws -> BillableDraftSnapshot {
        BillableDraftSnapshot(
            id: UUID(),
            sessionId: sessionId,
            clientId: clientId,
            serviceId: serviceId,
            computedAt: Date(),
            billingContextSnapshot: Data(),
            draftStatus: DraftStatus.open.rawValue,
            createdAt: Date()
        )
    }

    func buildDrafts(_ requests: [BillingDraftBuildRequest]) async throws -> [UUID] { [] }
}

extension BillingHubWorkspaceFactory {
    struct PreviewSeedData {
        let sessions: [Session]
        let invoices: [Invoice]
        let drafts: [BillableDraft]
        let draftIDs: [UUID]
        let clients: [Client]
        let clientServices: [ClientService]
    }

    struct PreviewPayload {
        let viewModel: BillingHubViewModel
        let seedData: PreviewSeedData
    }

    struct DraftsPreviewPayload {
        let container: ModelContainer
        let viewModel: BillableDraftsViewModel
        let seedData: PreviewSeedData
    }

    static func makePreviewPayload() throws -> PreviewPayload {
        let container = try makePreviewContainer()
        let context = makeManualSavePreviewContext(for: container)
        let seedData = try populatePreviewData(in: context)

        return PreviewPayload(
            viewModel: makePreviewViewModel(context: context),
            seedData: seedData
        )
    }

    static func makeDraftsPreviewPayload() throws -> DraftsPreviewPayload {
        let container = try makePreviewContainer()
        let context = makeManualSavePreviewContext(for: container)
        let seedData = try populatePreviewData(in: context)

        return DraftsPreviewPayload(
            container: container,
            viewModel: makePreviewDraftsViewModel(context: context),
            seedData: seedData
        )
    }

    private static func makeManualSavePreviewContext(for container: ModelContainer) -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private static func makePreviewContainer() throws -> ModelContainer {
        let schema = Schema(PersistenceSchema.appModels)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func makePreviewViewModel(context: ModelContext) -> BillingHubViewModel {
        BillingHubViewModel(
            modelContext: context,
            modelContainer: context.container,
            ndisBillingIntegrationService: PreviewBillingIntegrationService()
        )
    }

    private static func makePreviewDraftsViewModel(context: ModelContext) -> BillableDraftsViewModel {
        BillableDraftsViewModel(
            modelContext: context,
            draftBuilder: PreviewBillingDraftBuilder()
        )
    }

    private static func populatePreviewData(in context: ModelContext) throws -> PreviewSeedData {
        let clientA = Client(id: UUID(), ndisNumber: "410000010", fullName: "Alex Rivers", status: .active)
        let clientB = Client(id: UUID(), ndisNumber: "410000011", fullName: "Jamie Lee", status: .active)

        let serviceA = ClientService(id: UUID(), serviceName: "Personal Care", unit: "hour", rate: 88.0)
        let serviceB = ClientService(id: UUID(), serviceName: "Community Access", unit: "hour", rate: 75.0)
        serviceA.client = clientA
        serviceB.client = clientB

        func makeSession(
            client: Client,
            svc: ClientService,
            title: String,
            start: Date,
            end: Date,
            status: String,
            groupID: UUID? = nil
        ) -> Session {
            let session = Session(id: UUID())
            session.title = title
            session.client = client
            session.clientService = svc
            session.startTime = start
            session.endTime = end
            session.status = SessionStatus(normalized: status) ?? .scheduled
            session.groupID = groupID
            return session
        }

        func makeInvoice(
            client: Client,
            number: String,
            status: String,
            amount: Double,
            firstItemDescription: String
        ) -> Invoice {
            let invoice = Invoice(id: UUID(), invoiceNumber: number)
            invoice.client = client
            invoice.status = InvoiceStatus(rawValue: status) ?? .reviewDraft
            invoice.issueDate = Date()
            invoice.dueDate = Calendar.current.date(byAdding: .day, value: 14, to: Date())
            invoice.totalAmount = Decimal(amount)

            let item = InvoiceItem(id: UUID(), itemDescription: firstItemDescription)
            item.quantity = 1
            item.rate = Decimal(amount)
            item.invoice = invoice
            invoice.items = [item]
            return invoice
        }

        let now = Date()
        let groupedClusterID = UUID()

        let sessions: [Session] = [
            makeSession(client: clientA, svc: serviceA, title: "Morning Support", start: now.addingTimeInterval(-3 * 3600), end: now.addingTimeInterval(-2 * 3600), status: "completed"),
            makeSession(client: clientB, svc: serviceB, title: "Community Access", start: now.addingTimeInterval(-28 * 3600), end: now.addingTimeInterval(-26 * 3600), status: "completed"),
            makeSession(client: clientA, svc: serviceA, title: "AM Support", start: now.addingTimeInterval(-70 * 3600), end: now.addingTimeInterval(-69 * 3600), status: "grouped", groupID: groupedClusterID),
            makeSession(client: clientA, svc: serviceA, title: "PM Support", start: now.addingTimeInterval(-68 * 3600), end: now.addingTimeInterval(-67 * 3600), status: "grouped", groupID: groupedClusterID),
            makeSession(client: clientB, svc: serviceB, title: "Transport", start: now.addingTimeInterval(-40 * 3600), end: now.addingTimeInterval(-39 * 3600), status: "grouped"),
            makeSession(client: clientB, svc: serviceB, title: "Community Visit", start: now.addingTimeInterval(-38 * 3600), end: now.addingTimeInterval(-37 * 3600), status: "grouped"),
            makeSession(client: clientA, svc: serviceA, title: "Household Tasks", start: now.addingTimeInterval(-10 * 3600), end: now.addingTimeInterval(-9 * 3600), status: "needs_travel"),
            makeSession(client: clientB, svc: serviceB, title: "Meal Planning", start: now.addingTimeInterval(-12 * 3600), end: now.addingTimeInterval(-11 * 3600), status: "needs_travel"),
            makeSession(client: clientA, svc: serviceA, title: "Transport to Appointment", start: now.addingTimeInterval(-8 * 3600), end: now.addingTimeInterval(-7.5 * 3600), status: "needs_travel"),
            makeSession(client: clientB, svc: serviceB, title: "Community Event", start: now.addingTimeInterval(-7 * 3600), end: now.addingTimeInterval(-6.5 * 3600), status: "needs_travel")
        ]

        let invoices: [Invoice] = [
            makeInvoice(client: clientA, number: "INV-PREV-0001", status: "review_draft", amount: 220.0, firstItemDescription: "Support Hours"),
            makeInvoice(client: clientB, number: "INV-PREV-0002", status: "review_draft", amount: 140.0, firstItemDescription: "Transport"),
            makeInvoice(client: clientA, number: "INV-PREV-0003", status: "ready_to_send", amount: 310.0, firstItemDescription: "Support + Travel"),
            makeInvoice(client: clientB, number: "INV-PREV-0004", status: "ready_to_send", amount: 95.0, firstItemDescription: "Community Access"),
            makeInvoice(client: clientA, number: "INV-PREV-0005", status: "pending", amount: 175.0, firstItemDescription: "Support"),
            makeInvoice(client: clientB, number: "INV-PREV-0006", status: "pending", amount: 260.0, firstItemDescription: "Support Services"),
            makeInvoice(client: clientA, number: "INV-PREV-0007", status: "received", amount: 420.0, firstItemDescription: "Support Bundle"),
            makeInvoice(client: clientB, number: "INV-PREV-0008", status: "received", amount: 80.0, firstItemDescription: "Transport Fee")
        ]

        let snapshotData = Foundation.Data("preview-billing-context".utf8)

        let readyDraft = BillableDraft(
            id: UUID(),
            sessionId: sessions[0].id,
            clientId: clientA.id,
            serviceId: serviceA.id,
            computedAt: now.addingTimeInterval(-2 * 3600),
            billingContextSnapshot: snapshotData,
            draftStatus: DraftStatus.ready.rawValue,
            createdAt: now.addingTimeInterval(-2 * 3600)
        )
        readyDraft.session = sessions[0]
        readyDraft.client = clientA
        readyDraft.service = serviceA

        let readyLine = ClaimableLine(
            id: UUID(),
            draftId: readyDraft.id,
            claimType: "CoreSupport",
            supportItemNumber: "01_011_0107_1_1",
            serviceFrom: now.addingTimeInterval(-3 * 3600),
            serviceTo: now.addingTimeInterval(-2 * 3600),
            quantity: nil,
            hoursHHHMM: "001:00",
            unitPrice: 88,
            gstCode: GSTCode.p2.rawValue,
            claimReference: "PREVIEW-READY-1"
        )
        readyLine.draft = readyDraft
        readyDraft.items = [readyLine]

        let needsReviewDraft = BillableDraft(
            id: UUID(),
            sessionId: sessions[6].id,
            clientId: clientA.id,
            serviceId: serviceA.id,
            computedAt: now.addingTimeInterval(-90 * 60),
            billingContextSnapshot: snapshotData,
            draftStatus: DraftStatus.needsReview.rawValue,
            createdAt: now.addingTimeInterval(-90 * 60)
        )
        needsReviewDraft.session = sessions[6]
        needsReviewDraft.client = clientA
        needsReviewDraft.service = serviceA

        let reviewLine = ClaimableLine(
            id: UUID(),
            draftId: needsReviewDraft.id,
            claimType: "ProviderTravel",
            supportItemNumber: "04_590_0125_6_1",
            serviceFrom: now.addingTimeInterval(-10 * 3600),
            serviceTo: now.addingTimeInterval(-9 * 3600),
            quantity: 12,
            hoursHHHMM: nil,
            unitPrice: 1.10,
            gstCode: GSTCode.p2.rawValue,
            travelKM: 12,
            claimReference: "PREVIEW-REVIEW-1"
        )
        reviewLine.draft = needsReviewDraft

        let reviewIssue = DraftIssue(
            id: UUID(),
            draftId: needsReviewDraft.id,
            severity: .warning,
            code: "travel-evidence",
            message: "Travel evidence should be reviewed before claiming.",
            resolutionKind: .userInput,
            createdAt: now.addingTimeInterval(-80 * 60)
        )
        reviewIssue.draft = needsReviewDraft
        needsReviewDraft.items = [reviewLine]
        needsReviewDraft.issues = [reviewIssue]

        let drafts = [readyDraft, needsReviewDraft]

        [clientA, clientB].forEach(context.insert)
        [serviceA, serviceB].forEach(context.insert)
        sessions.forEach(context.insert)
        invoices.forEach(context.insert)
        drafts.forEach(context.insert)
        [readyLine, reviewLine].forEach(context.insert)
        [reviewIssue].forEach(context.insert)
        try context.save()

        return PreviewSeedData(
            sessions: sessions,
            invoices: invoices,
            drafts: drafts,
            draftIDs: drafts.map(\.id),
            clients: [clientA, clientB],
            clientServices: [serviceA, serviceB]
        )
    }
}
