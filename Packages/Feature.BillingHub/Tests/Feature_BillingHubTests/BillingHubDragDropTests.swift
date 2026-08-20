import Core
import PersistenceModels
import Foundation
import SwiftUI
import Testing
import CoreTesting
@testable import Feature_BillingHub

@MainActor
@Suite(.tags(.integration))
struct BillingHubDragDropTests {
    @Test func dragDropCoordinatorValidatesSessionAndInvoiceMoves() {
        let sourceSessionID = UUID()
        let targetSessionID = UUID()
        let sourceInvoiceID = UUID()

        let projection = BillingHubBoardProjection(
            sessionsByStatus: [
                .completed: [
                    .session(makeSessionCard(sessionID: sourceSessionID, columnType: .completed))
                ],
                .grouped: [
                    .session(makeSessionCard(sessionID: targetSessionID, columnType: .grouped))
                ]
            ],
            invoicesByStatus: [
                .reviewDrafts: [
                    .invoice(makeInvoiceCard(invoiceID: sourceInvoiceID, columnType: .reviewDrafts))
                ],
                .readyToSend: [
                    .invoice(makeInvoiceCard(invoiceID: UUID(), columnType: .readyToSend))
                ]
            ],
            groupedSessions: [],
            clientSummaries: []
        )
        let coordinator = BillingHubDragDropCoordinator(projection: projection)

        #expect(coordinator.canAcceptCardDrop(.session(sourceSessionID), into: .grouped, before: nil))
        #expect(coordinator.canAcceptCardDrop(.session(sourceSessionID), into: .readyToSend, before: nil) == false)
        #expect(coordinator.canAcceptCardDrop(.session(sourceSessionID), into: .grouped, before: sourceSessionID) == false)
        #expect(coordinator.canAcceptCardDrop(.invoice(sourceInvoiceID), into: .readyToSend, before: nil))
        #expect(coordinator.canAcceptCardDrop(.invoice(sourceInvoiceID), into: .pending, before: nil) == false)
    }

    @Test func dragDropCoordinatorRejectsCrossClientGroupAdds() {
        let clientAID = UUID()
        let clientBID = UUID()
        let groupID = UUID()
        let groupedMemberID = UUID()
        let sameClientSourceID = UUID()
        let differentClientSourceID = UUID()

        let groupedMember = makeSessionCard(sessionID: groupedMemberID, columnType: .grouped, clientID: clientAID)
        let projection = BillingHubBoardProjection(
            sessionsByStatus: [
                .completed: [
                    .session(makeSessionCard(sessionID: sameClientSourceID, columnType: .completed, clientID: clientAID)),
                    .session(makeSessionCard(sessionID: differentClientSourceID, columnType: .completed, clientID: clientBID))
                ]
            ],
            invoicesByStatus: [:],
            groupedSessions: [SessionGroup(groupID: groupID, sessions: [.session(groupedMember)])],
            clientSummaries: [])
        let coordinator = BillingHubDragDropCoordinator(projection: projection)

        #expect(coordinator.canAcceptSessionDropInGroup(
                sourceID: sameClientSourceID, beforeTargetID: nil,
                scopeGroupID: groupID))
        #expect(coordinator.canAcceptSessionDropInGroup(
                sourceID: differentClientSourceID, beforeTargetID: nil,
                scopeGroupID: groupID) == false)
    }
}

private func makeSessionCard(
    sessionID: UUID,
    columnType: KanbanCardData.BillingColumnType,
    clientID: UUID = UUID()
) -> SessionKanbanCardData {
    SessionKanbanCardData(
        sessionId: sessionID,
        clientID: clientID,
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
        startTime: ModelFixtures.referenceDate,
        endTime: ModelFixtures.referenceDate.addingTimeInterval(3600),
        groupID: nil
    )
}

private func makeInvoiceCard(
    invoiceID: UUID,
    columnType: KanbanCardData.BillingColumnType
) -> InvoiceKanbanCardData {
    InvoiceKanbanCardData(
        invoiceId: invoiceID,
        title: "Invoice",
        clientName: "Client",
        serviceName: "Service",
        priority: .medium,
        accentColor: .green,
        amount: "$100.00",
        date: "today",
        workflowStatus: .draftReview,
        columnType: columnType,
        isOverdue: false,
        daysOverdue: nil,
        rawDate: ModelFixtures.referenceDate
    )
}
