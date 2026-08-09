import Foundation
import Core
import PersistenceModels
import Data
import SwiftData
@testable import Feature_BillingHub

enum BillingHubPhase2HonestyFixtures {
    static func makeContext() throws -> (ModelContainer, ModelContext) {
        try ModelContainerFactory.makeInMemoryContext()
    }

    static func makeSession() -> Session {
        let session = Session(id: UUID())
        session.title = "Honesty Session"
        session.status = .completed
        session.startTime = Date()
        session.endTime = Date().addingTimeInterval(3600)
        return session
    }

    static func makeSessionCard(
        sessionID: UUID = UUID(),
        columnType: KanbanCardData.BillingColumnType,
        clientID: UUID? = nil
    ) -> SessionKanbanCardData {
        SessionKanbanCardData(
            sessionId: sessionID,
            clientID: clientID ?? UUID(),
            title: "Session",
            clientName: "Client",
            serviceName: "Service",
            travelRate: nil,
            travelRateUnit: nil,
            suggestedTravelDistanceKM: nil,
            suggestedTravelTimeMinutes: nil,
            priority: .low,
            accentColor: .blue,
            duration: "60m",
            date: "today",
            hasIssues: false,
            workflowStatus: .readyToInvoice,
            columnType: columnType,
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            groupID: nil
        )
    }

    static func makeInvoiceCard(
        invoiceID: UUID = UUID(),
        columnType: KanbanCardData.BillingColumnType
    ) -> InvoiceKanbanCardData {
        InvoiceKanbanCardData(
            invoiceId: invoiceID,
            title: "Invoice",
            clientName: "Client",
            serviceName: "Service",
            priority: .medium,
            accentColor: .green,
            amount: "$10.00",
            date: "today",
            workflowStatus: .readyToSend,
            columnType: columnType,
            isOverdue: false,
            daysOverdue: nil,
            rawDate: Date()
        )
    }
}
