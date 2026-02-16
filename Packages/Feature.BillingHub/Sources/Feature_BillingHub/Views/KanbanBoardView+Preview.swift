//
//  KanbanBoardView+Preview.swift
//  InvoicingApplication
//
//  Preview helpers for KanbanBoardView - isolated to avoid Data import in main View files
//

import SwiftUI
import SwiftData
import SharedUI
import Data
import Core

#Preview("Billing Hub – Full Kanban Board") {
    FullKanbanBoardPreview()
}

// MARK: - Preparing Sessions Preview
private struct PreparingSessionsColumnPreview: View {
    @StateObject private var viewModel: BillingHubViewModel
    @State private var container: ModelContainer
    @State private var selectedCard: KanbanCardData? = nil
    @State private var isEditingPanelVisible: Bool = false
    @State private var isCollapsed: Bool = false

    init() {
        // Build an in-memory SwiftData container for previews
        let container = try! ModelContainerFactory.makeInMemoryContainer()
        _container = State(initialValue: container)
        let context = ModelContext(container)

        // Seed mock data
        let client = ClientEntity(id: UUID(), ndisNumber: "410000000", fullName: "Alex Rivers", status: .active)
        let service = ClientServiceEntity(id: UUID(), serviceName: "Personal Care", unit: "hour", rate: 88.0)
        service.client = client

        func makeSession(title: String, start: Date, end: Date, status: String) -> SessionEntity {
            let s = SessionEntity(id: UUID())
            s.title = title
            s.client = client
            s.clientService = service
            s.startTime = start
            s.endTime = end
            s.status = SessionStatus(normalized: status) ?? .scheduled
            return s
        }

        let now = Date()
        let sessions: [SessionEntity] = [
            makeSession(title: "Morning Support", start: now.addingTimeInterval(-3*3600), end: now.addingTimeInterval(-2*3600), status: "completed"),
            makeSession(title: "Community Access", start: now.addingTimeInterval(-26*3600), end: now.addingTimeInterval(-24*3600), status: "completed"),
            makeSession(title: "Meal Prep", start: now.addingTimeInterval(-50*3600), end: now.addingTimeInterval(-49*3600), status: "grouped")
        ]

        context.insert(client)
        context.insert(service)
        sessions.forEach { context.insert($0) }
        try? context.save()

        // Create repositories for preview
        let sessionsRepository = SessionsRepositorySwiftData(modelContext: context)
        let invoicesRepository = InvoicesRepositorySwiftData(modelContext: context)
        let clientsRepository = ClientsRepositorySwiftData(modelContext: context)
        let clientServicesRepository = ClientServicesRepositorySwiftData(modelContext: context)
        let travelChargeRepository = TravelChargeRepositorySwiftData(modelContext: context)
        let businessRepository = BusinessRepositorySwiftData(modelContext: context)
        let ndisItemRepository = NDISItemRepositorySwiftData(modelContext: context)
        
        let unitOfWork = SwiftDataUnitOfWork(modelContext: context, modelContainer: container)
        let billingService = NDISBillingService(modelContext: context, repository: ndisItemRepository)
        
        let ndisBillingIntegrationService = NDISBillingIntegrationService(
            invoicesRepository: invoicesRepository,
            clientsRepository: clientsRepository,
            businessRepository: businessRepository,
            clientServicesRepository: clientServicesRepository,
            ndisItemsRepository: ndisItemRepository,
            billingService: billingService,
            unitOfWork: unitOfWork
        )
        
        _viewModel = StateObject(wrappedValue: BillingHubViewModel(
            sessionsRepository: sessionsRepository,
            invoicesRepository: invoicesRepository,
            clientsRepository: clientsRepository,
            clientServicesRepository: clientServicesRepository,
            travelChargeRepository: travelChargeRepository,
            ndisBillingIntegrationService: ndisBillingIntegrationService
        ))
    }

    var body: some View {
        let completedCount = viewModel.sessionsByStatus[.completed]?.count ?? 0
        let groupedCount = viewModel.sessionsByStatus[.grouped]?.count ?? 0

        return HStack(spacing: 0) {
            PreparingSessionsColumn(
                viewModel: viewModel,
                selectedCard: $selectedCard,
                isEditingPanelVisible: $isEditingPanelVisible,
                completedSessionsCount: completedCount,
                groupedSessionsCount: groupedCount,
                width: 420,
                isCollapsed: $isCollapsed
            )
        }
        .frame(height: 520)
        .padding()
        .background(StyleGuide.Colors.secondary)
        .environmentObject(viewModel)
    }
}

private struct FullKanbanBoardPreview: View {
    @StateObject private var viewModel: BillingHubViewModel
    @State private var container: ModelContainer
    @State private var selectedCard: KanbanCardData? = nil
    @State private var isEditingPanelVisible: Bool = false

    init() {
        // In‑memory SwiftData store
        let container = try! ModelContainerFactory.makeInMemoryContainer()
        _container = State(initialValue: container)
        let context = ModelContext(container)

        // Mock data
        let clientA = ClientEntity(id: UUID(), ndisNumber: "410000001", fullName: "Alex Rivers", status: .active)
        let clientB = ClientEntity(id: UUID(), ndisNumber: "410000002", fullName: "Jamie Lee", status: .active)

        let serviceA = ClientServiceEntity(id: UUID(), serviceName: "Personal Care", unit: "hour", rate: 88.0)
        let serviceB = ClientServiceEntity(id: UUID(), serviceName: "Community Access", unit: "hour", rate: 75.0)
        serviceA.client = clientA
        serviceB.client = clientB

        func makeSession(client: ClientEntity, svc: ClientServiceEntity, title: String, start: Date, end: Date, status: String, groupID: UUID? = nil) -> SessionEntity {
            let s = SessionEntity(id: UUID())
            s.title = title
            s.client = client
            s.clientService = svc
            s.startTime = start
            s.endTime = end
            s.status = SessionStatus(normalized: status) ?? .scheduled
            s.groupID = groupID
            return s
        }

        func makeInvoice(client: ClientEntity, number: String, status: String, amount: Double, firstItemDesc: String) -> InvoiceEntity {
            let inv = InvoiceEntity(id: UUID(), invoiceNumber: number)
            inv.client = client
            inv.status = InvoiceStatus(rawValue: status) ?? .reviewDraft
            inv.issueDate = Date()
            inv.dueDate = Calendar.current.date(byAdding: .day, value: 14, to: Date())
            inv.totalAmount = amount
            let item = InvoiceItemEntity(id: UUID(), itemDescription: firstItemDesc)
            item.quantity = 1
            item.rate = amount
            item.invoice = inv
            inv.items.append(item)
            return inv
        }

        let now = Date()

        // Completed sessions
        let completed = [
            makeSession(client: clientA, svc: serviceA, title: "Morning Support", start: now.addingTimeInterval(-3*3600), end: now.addingTimeInterval(-2*3600), status: "completed"),
            makeSession(client: clientB, svc: serviceB, title: "Community Access", start: now.addingTimeInterval(-28*3600), end: now.addingTimeInterval(-26*3600), status: "completed"),
            makeSession(client: clientA, svc: serviceA, title: "Meal Prep", start: now.addingTimeInterval(-50*3600), end: now.addingTimeInterval(-49*3600), status: "completed")
        ]

        // Grouped sessions (mix grouped and ungrouped within Grouped column)
        let g1 = UUID()
        let grouped = [
            makeSession(client: clientA, svc: serviceA, title: "AM Support", start: now.addingTimeInterval(-70*3600), end: now.addingTimeInterval(-69*3600), status: "grouped", groupID: g1),
            makeSession(client: clientA, svc: serviceA, title: "PM Support", start: now.addingTimeInterval(-68*3600), end: now.addingTimeInterval(-67*3600), status: "grouped", groupID: g1),
            makeSession(client: clientB, svc: serviceB, title: "Transport", start: now.addingTimeInterval(-40*3600), end: now.addingTimeInterval(-39*3600), status: "grouped", groupID: nil),
            makeSession(client: clientB, svc: serviceB, title: "Community Visit", start: now.addingTimeInterval(-38*3600), end: now.addingTimeInterval(-37*3600), status: "grouped", groupID: nil)
        ]

        // Add Travel
        let needsTravel = [
            makeSession(client: clientA, svc: serviceA, title: "Transport to Appointment", start: now.addingTimeInterval(-8*3600), end: now.addingTimeInterval(-7.5*3600), status: "needs_travel"),
            makeSession(client: clientB, svc: serviceB, title: "Community Event", start: now.addingTimeInterval(-7*3600), end: now.addingTimeInterval(-6.5*3600), status: "needs_travel")
        ]

        // Review Draft/Ready To Send/Pending/Received invoices
        let invoices: [InvoiceEntity] = [
            makeInvoice(client: clientA, number: "INV-TEST-0001", status: "review_draft", amount: 220.0, firstItemDesc: "Support Hours"),
            makeInvoice(client: clientB, number: "INV-TEST-0002", status: "review_draft", amount: 140.0, firstItemDesc: "Transport"),
            makeInvoice(client: clientA, number: "INV-TEST-0003", status: "ready_to_send", amount: 310.0, firstItemDesc: "Support + Travel"),
            makeInvoice(client: clientB, number: "INV-TEST-0004", status: "ready_to_send", amount: 95.0, firstItemDesc: "Community Access"),
            makeInvoice(client: clientA, number: "INV-TEST-0005", status: "pending", amount: 175.0, firstItemDesc: "Support"),
            makeInvoice(client: clientB, number: "INV-TEST-0006", status: "pending", amount: 260.0, firstItemDesc: "Support Services"),
            makeInvoice(client: clientA, number: "INV-TEST-0007", status: "received", amount: 420.0, firstItemDesc: "Support Bundle"),
            makeInvoice(client: clientB, number: "INV-TEST-0008", status: "received", amount: 80.0, firstItemDesc: "Transport Fee")
        ]

        // Persist
        context.insert(clientA)
        context.insert(clientB)
        context.insert(serviceA)
        context.insert(serviceB)
        (completed + grouped + needsTravel).forEach { context.insert($0) }
        invoices.forEach { context.insert($0) }
        try? context.save()

        // Create repositories for preview
        let sessionsRepository = SessionsRepositorySwiftData(modelContext: context)
        let invoicesRepository = InvoicesRepositorySwiftData(modelContext: context)
        let clientsRepository = ClientsRepositorySwiftData(modelContext: context)
        let clientServicesRepository = ClientServicesRepositorySwiftData(modelContext: context)
        let travelChargeRepository = TravelChargeRepositorySwiftData(modelContext: context)
        let businessRepository = BusinessRepositorySwiftData(modelContext: context)
        let ndisItemRepository = NDISItemRepositorySwiftData(modelContext: context)
        
        let unitOfWork = SwiftDataUnitOfWork(modelContext: context, modelContainer: container)
        let billingService = NDISBillingService(modelContext: context, repository: ndisItemRepository)
        
        let ndisBillingIntegrationService = NDISBillingIntegrationService(
            invoicesRepository: invoicesRepository,
            clientsRepository: clientsRepository,
            businessRepository: businessRepository,
            clientServicesRepository: clientServicesRepository,
            ndisItemsRepository: ndisItemRepository,
            billingService: billingService,
            unitOfWork: unitOfWork
        )
        
        _viewModel = StateObject(wrappedValue: BillingHubViewModel(
            sessionsRepository: sessionsRepository,
            invoicesRepository: invoicesRepository,
            clientsRepository: clientsRepository,
            clientServicesRepository: clientServicesRepository,
            travelChargeRepository: travelChargeRepository,
            ndisBillingIntegrationService: ndisBillingIntegrationService
        ))
    }

    var body: some View {
        KanbanBoardView(
            viewModel: viewModel,
            selectedCard: $selectedCard,
            isEditingPanelVisible: $isEditingPanelVisible
        )
        .frame(minHeight: 680)
        .padding()
        .background(StyleGuide.Colors.secondary)
        .environmentObject(viewModel)
    }
}
