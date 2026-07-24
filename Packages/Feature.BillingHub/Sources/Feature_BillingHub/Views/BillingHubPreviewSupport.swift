import Foundation
import SwiftUI
import SwiftData
import Data
import Core
import SharedUI
import WorkspaceUI

@MainActor
enum BillingHubPreviewSupport {
    struct SeedData {
        let sessions: [Session]
        let invoices: [Invoice]
        let drafts: [BillableDraft]
        let draftIDs: [UUID]
        let clients: [Client]
        let clientServices: [ClientService]
    }

    @MainActor
    struct Payload {
        let viewModel: BillingHubViewModel
        let seedData: SeedData

        var projection: BillingHubBoardProjection {
            BillingHubProjectionBuilder.project(
                sessions: seedData.sessions,
                invoices: seedData.invoices,
                clients: seedData.clients,
                clientServices: seedData.clientServices,
                searchText: viewModel.searchText,
                selectedClientID: viewModel.selectedClientID,
                sortOptions: viewModel.columnSortOptions
            )
        }
    }

    @MainActor
    struct DraftsPayload {
        let container: ModelContainer
        let viewModel: BillableDraftsViewModel
        let seedData: SeedData
    }

    struct PreviewLoader<Content: View>: View {
        let minHeight: CGFloat
        @ViewBuilder let content: (Payload) -> Content

        @State private var payload: Payload?
        @State private var errorMessage: String?

        var body: some View {
            Group {
                if let payload {
                    content(payload)
                } else if let errorMessage {
                    PreviewErrorView(message: errorMessage)
                } else {
                    ProgressView("Loading Billing Hub Preview...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(minHeight: minHeight)
                        .task {
                            await loadIfNeeded()
                        }
                }
            }
        }

        private func loadIfNeeded() async {
            guard payload == nil, errorMessage == nil else { return }
            do {
                let payload = try makePayload()
                self.payload = payload
            } catch {
                errorMessage = String(describing: error)
            }
        }
    }

    struct DraftsPreviewLoader<Content: View>: View {
        let minHeight: CGFloat
        @ViewBuilder let content: (DraftsPayload) -> Content

        @State private var payload: DraftsPayload?
        @State private var errorMessage: String?

        var body: some View {
            Group {
                if let payload {
                    content(payload)
                } else if let errorMessage {
                    PreviewErrorView(message: errorMessage)
                } else {
                    ProgressView("Loading Billing Drafts Preview...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(minHeight: minHeight)
                        .task {
                            await loadIfNeeded()
                        }
                }
            }
        }

        private func loadIfNeeded() async {
            guard payload == nil, errorMessage == nil else { return }
            do {
                let payload = try makeDraftsPayload()
                self.payload = payload
            } catch {
                errorMessage = String(describing: error)
            }
        }
    }

    private struct PreviewErrorView: View {
        let message: String

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Label("Billing Hub Preview Failed", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(StyleGuide.Dimensions.paddingXLarge)
        }
    }

    static func makePayload() throws -> Payload {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = makeManualSaveContext(for: container)
        let seedData = try populatePreviewData(in: context)

        return Payload(
            viewModel: makeViewModel(context: context),
            seedData: seedData
        )
    }

    static func makeDraftsPayload() throws -> DraftsPayload {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let context = makeManualSaveContext(for: container)
        let seedData = try populatePreviewData(in: context)

        return DraftsPayload(
            container: container,
            viewModel: makeDraftsViewModel(context: context),
            seedData: seedData
        )
    }

    /// Mirror `AppDatabase.makeMainContext()` so previews exercise the same manual-save policy as
    /// production UI rather than the autosaving `container.mainContext` default.
    private static func makeManualSaveContext(for container: ModelContainer) -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private static func makeViewModel(context: ModelContext) -> BillingHubViewModel {
        let geocodingService = WorkspacePreviewServices.makeSwiftDataGeocodingService()
        let mmmZoneLookup = Core.MMMZoneLookup()
        let ndisBillingIntegration = NDISBillingIntegrationService(
            modelContainer: context.container,
            geocodingService: geocodingService,
            mmmZoneLookup: mmmZoneLookup
        )
        return BillingHubViewModel(
            modelContext: context,
            modelContainer: context.container,
            ndisBillingIntegrationService: ndisBillingIntegration
        )
    }

    private static func makeDraftsViewModel(context: ModelContext) -> BillableDraftsViewModel {
        let geocodingService = WorkspacePreviewServices.makeSwiftDataGeocodingService()
        let mmmZoneLookup = Core.MMMZoneLookup()
        let ndisBillingIntegration = NDISBillingIntegrationService(
            modelContainer: context.container,
            geocodingService: geocodingService,
            mmmZoneLookup: mmmZoneLookup
        )
        let draftBuilder = BillingDraftBuilderService(
            ndisBillingIntegration: ndisBillingIntegration,
            modelContainer: context.container,
            mmmZoneLookup: mmmZoneLookup
        )
        return BillableDraftsViewModel(
            modelContext: context,
            draftBuilder: draftBuilder
        )
    }

    private static func populatePreviewData(in context: ModelContext) throws -> SeedData {
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
            invoice.totalAmount = amount

            let item = InvoiceItem(id: UUID(), itemDescription: firstItemDescription)
            item.quantity = 1
            item.rate = amount
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

        let snapshotData = Data("preview-billing-context".utf8)

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
            quantityDecimal: nil,
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
            quantityDecimal: 12,
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

        return SeedData(
            sessions: sessions,
            invoices: invoices,
            drafts: drafts,
            draftIDs: drafts.map(\.id),
            clients: [clientA, clientB],
            clientServices: [serviceA, serviceB]
        )
    }
}
