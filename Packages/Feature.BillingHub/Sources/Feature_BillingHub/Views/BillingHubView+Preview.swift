//
//  BillingHubView+Preview.swift
//  InvoicingApplication
//
//  Preview helpers for BillingHubView - isolated to avoid Data import in main View files
//

import SwiftUI
import SwiftData
import Data
import Core

#Preview("Billing Hub - Full View") {
    BillingHubPreviewView()
}

private struct BillingHubPreviewView: View {
    @StateObject private var viewModel: BillingHubViewModel
    @State private var selectedCard: KanbanCardData? = nil
    @State private var isEditingPanelVisible: Bool = false

    init() {
        // Use an in-memory SwiftData container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: ClientEntity.self,
                 BusinessEntity.self,
                 AddressEntity.self,
                 InvoiceEntity.self,
                 InvoiceItemEntity.self,
                 ClientServiceEntity.self,
                 PayeeEntity.self,
                 PlanManagerEntity.self,
                 SessionEntity.self,
                 TravelChargeEntity.self,
                 TravelChargeAuditLog.self,
                 TravelChargeReviewItem.self,
                 CreditHistoryEntryEntity.self,
                 NDISItemEntity.self,
                 RegionalPriceEntity.self,
            configurations: config
        )
        let context = ModelContext(container)

        // Mock clients and services
        let clientA = ClientEntity(id: UUID(), ndisNumber: "410000010", fullName: "Alex Rivers", status: .active)
        let clientB = ClientEntity(id: UUID(), ndisNumber: "410000011", fullName: "Jamie Lee", status: .active)
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
            s.status = SessionStatus(rawValue: status) ?? .scheduled
            s.groupID = groupID
            return s
        }

        func makeInvoice(client: ClientEntity, number: String, status: String, amount: Double, firstItemDesc: String) -> InvoiceEntity {
            let inv = InvoiceEntity(id: UUID(), invoiceNumber: number)
            inv.client = client
            inv.status = InvoiceStatus(rawValue: status) ?? .draft
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

        // Sessions across subcolumns
        let g1 = UUID()
        let sessions: [SessionEntity] = [
            // Completed
            makeSession(client: clientA, svc: serviceA, title: "Morning Support", start: now.addingTimeInterval(-3*3600), end: now.addingTimeInterval(-2*3600), status: "completed"),
            makeSession(client: clientB, svc: serviceB, title: "Community Access", start: now.addingTimeInterval(-28*3600), end: now.addingTimeInterval(-26*3600), status: "completed"),
            // Grouped (with and without group)
            makeSession(client: clientA, svc: serviceA, title: "AM Support", start: now.addingTimeInterval(-70*3600), end: now.addingTimeInterval(-69*3600), status: "grouped", groupID: g1),
            makeSession(client: clientA, svc: serviceA, title: "PM Support", start: now.addingTimeInterval(-68*3600), end: now.addingTimeInterval(-67*3600), status: "grouped", groupID: g1),
            makeSession(client: clientB, svc: serviceB, title: "Transport", start: now.addingTimeInterval(-40*3600), end: now.addingTimeInterval(-39*3600), status: "grouped", groupID: nil),
            // Needs services / travel
            makeSession(client: clientA, svc: serviceA, title: "Household Tasks", start: now.addingTimeInterval(-10*3600), end: now.addingTimeInterval(-9*3600), status: "needs_services"),
            makeSession(client: clientB, svc: serviceB, title: "Meal Planning", start: now.addingTimeInterval(-12*3600), end: now.addingTimeInterval(-11*3600), status: "needs_services"),
            makeSession(client: clientA, svc: serviceA, title: "Transport to Appointment", start: now.addingTimeInterval(-8*3600), end: now.addingTimeInterval(-7.5*3600), status: "needs_travel"),
            makeSession(client: clientB, svc: serviceB, title: "Community Event", start: now.addingTimeInterval(-7*3600), end: now.addingTimeInterval(-6.5*3600), status: "needs_travel")
        ]

        // Invoices across subcolumns
        let invoices: [InvoiceEntity] = [
            makeInvoice(client: clientA, number: "INV-PREV-0001", status: "draft", amount: 220.0, firstItemDesc: "Support Hours"),
            makeInvoice(client: clientB, number: "INV-PREV-0002", status: "draft", amount: 140.0, firstItemDesc: "Transport"),
            makeInvoice(client: clientA, number: "INV-PREV-0003", status: "ready", amount: 310.0, firstItemDesc: "Support + Travel"),
            makeInvoice(client: clientB, number: "INV-PREV-0004", status: "ready", amount: 95.0, firstItemDesc: "Community Access"),
            makeInvoice(client: clientA, number: "INV-PREV-0005", status: "sent", amount: 175.0, firstItemDesc: "Support"),
            makeInvoice(client: clientB, number: "INV-PREV-0006", status: "sent", amount: 260.0, firstItemDesc: "Support Services"),
            makeInvoice(client: clientA, number: "INV-PREV-0007", status: "paid", amount: 420.0, firstItemDesc: "Support Bundle"),
            makeInvoice(client: clientB, number: "INV-PREV-0008", status: "paid", amount: 80.0, firstItemDesc: "Transport Fee")
        ]

        // Persist
        context.insert(clientA)
        context.insert(clientB)
        context.insert(serviceA)
        context.insert(serviceB)
        sessions.forEach { context.insert($0) }
        invoices.forEach { context.insert($0) }
        try? context.save()

        // Create repositories for preview
        let sessionsRepository = SessionsRepositorySwiftData(modelContext: context)
        let invoicesRepository = InvoicesRepositorySwiftData(modelContext: context)
        let clientsRepository = ClientsRepositorySwiftData(modelContext: context)
        
        _viewModel = StateObject(wrappedValue: BillingHubViewModel(
            sessionsRepository: sessionsRepository,
            invoicesRepository: invoicesRepository,
            clientsRepository: clientsRepository
        ))
    }

    public var body: some View {
        BillingHubView(viewModel: viewModel)
            .frame(minHeight: 720)
    }
}

