import Foundation
import Core
import PersistenceModels
import Data
import SwiftData
import Testing
@testable import Feature_BillingHub

@MainActor
@Suite(.tags(.integration))
struct BillingHubFocusContinuityTests {
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        try ModelContainerFactory.makeInMemoryContext()
    }

    @Test func queueFocusDeduplicatesPreserveOrder() throws {
        let viewModel = try makeViewModel()
        let first = UUID()
        let second = UUID()

        viewModel.queueFocus(cardIDs: [first, first, second, first])

        #expect(viewModel.pendingFocusCardIDs == [first, second])
    }

    @Test func queueFocusPreservesEarlierPendingHandoff() throws {
        let viewModel = try makeViewModel()
        let calendarSession = UUID()
        let returnedInvoice = UUID()

        viewModel.queueFocus(cardIDs: [calendarSession])
        viewModel.queueFocus(cardIDs: [returnedInvoice, calendarSession])

        #expect(viewModel.pendingFocusCardIDs == [calendarSession, returnedInvoice])
    }

    @Test func consumeFocusPrefersCompletedColumnCard() throws {
        let viewModel = try makeViewModel()
        let completedID = UUID()
        let invoiceID = UUID()
        viewModel.queueFocus(cardIDs: [invoiceID, completedID])

        let projection = BillingHubBoardProjection(
            sessionsByStatus: [
                .completed: [.session(makeSessionCard(sessionID: completedID, columnType: .completed))]
            ], invoicesByStatus: [
                .readyToSend: [.invoice(makeInvoiceCard(invoiceID: invoiceID, columnType: .readyToSend))]
            ],
            groupedSessions: [],
            clientSummaries: [])

        let focused = viewModel.consumeFocusCardID(from: projection)

        #expect(focused == completedID)
        #expect(viewModel.pendingFocusCardIDs == [invoiceID])
    }

    @Test func consumeFocusFallsBackToAnyMatchingCard() throws {
        let viewModel = try makeViewModel()
        let invoiceID = UUID()
        viewModel.queueFocus(cardIDs: [invoiceID])

        let projection = BillingHubBoardProjection(
            sessionsByStatus: [:], invoicesByStatus: [
                .reviewDrafts: [.invoice(makeInvoiceCard(invoiceID: invoiceID, columnType: .reviewDrafts))]
            ],
            groupedSessions: [],
            clientSummaries: [])

        #expect(viewModel.consumeFocusCardID(from: projection) == invoiceID)
        #expect(viewModel.pendingFocusCardIDs.isEmpty)
    }

    @Test func consumeFocusKeepsPendingWhenCardMissingUntilMissReported() throws {
        let viewModel = try makeViewModel()
        let missing = UUID()
        viewModel.queueFocus(cardIDs: [missing])

        let focused = viewModel.consumeFocusCardID(from: .empty)

        #expect(focused == nil)
        #expect(viewModel.pendingFocusCardIDs == [missing])
        #expect(viewModel.bulkActionFeedback == nil)
    }

    @Test func settleFocusFirstMissKeepsPendingAndRequestsRetry() throws {
        let viewModel = try makeViewModel()
        let missing = UUID()
        viewModel.queueFocus(cardIDs: [missing])
        #expect(viewModel.focusAttempts == 0)

        let first = viewModel.settlePendingFocus(from: .empty)

        #expect(first == .retryNeeded)
        #expect(viewModel.pendingFocusCardIDs == [missing])
        #expect(viewModel.focusAttempts == 1)
        #expect(viewModel.bulkActionFeedback == nil)
    }

    @Test func settleFocusSecondMissClearsPendingAndSetsFeedback() throws {
        let viewModel = try makeViewModel()
        let missing = UUID()
        viewModel.queueFocus(cardIDs: [missing])

        #expect(viewModel.settlePendingFocus(from: .empty) == .retryNeeded)
        let second = viewModel.settlePendingFocus(from: .empty)

        #expect(second == .missed)
        #expect(viewModel.pendingFocusCardIDs.isEmpty)
        #expect(viewModel.focusAttempts == 0)
        #expect(viewModel.bulkActionFeedback == BillingHubFocusMissFeedback.message(hasActiveFilters: false))
    }

    @Test func settleFocusResetsAttemptsOnSuccessfulConsume() throws {
        let viewModel = try makeViewModel()
        let completedID = UUID()
        viewModel.queueFocus(cardIDs: [completedID])
        #expect(viewModel.settlePendingFocus(from: .empty) == .retryNeeded)

        let projection = BillingHubBoardProjection(
            sessionsByStatus: [
                .completed: [.session(makeSessionCard(sessionID: completedID, columnType: .completed))]
            ], invoicesByStatus: [:],
            groupedSessions: [],
            clientSummaries: [])

        #expect(viewModel.settlePendingFocus(from: projection) == .focused(completedID))
        #expect(viewModel.focusAttempts == 0)
        #expect(viewModel.pendingFocusCardIDs.isEmpty)
        #expect(viewModel.bulkActionFeedback == nil)
    }

    @Test func reportFocusMissClearsStaleIDsAndSetsFeedback() throws {
        let viewModel = try makeViewModel()
        let missing = UUID()
        viewModel.queueFocus(cardIDs: [missing])

        #expect(viewModel.consumeFocusCardID(from: .empty) == nil)
        viewModel.reportFocusMissIfNeeded()

        #expect(viewModel.pendingFocusCardIDs.isEmpty)
        #expect(viewModel.focusAttempts == 0)
        #expect(viewModel.bulkActionFeedback == BillingHubFocusMissFeedback.message(hasActiveFilters: false))
    }

    @Test func reportFocusMissMentionsClearFiltersWhenFiltersActive() throws {
        let viewModel = try makeViewModel()
        viewModel.searchText = "remote"
        viewModel.queueFocus(cardIDs: [UUID()])

        viewModel.reportFocusMissIfNeeded()

        #expect(viewModel.pendingFocusCardIDs.isEmpty)
        #expect(viewModel.bulkActionFeedback == BillingHubFocusMissFeedback.message(hasActiveFilters: true))
        #expect(viewModel.bulkActionFeedback?.contains("Clear filters") == true)
    }

    @Test func reportFocusMissIsNoOpWhenNothingPending() throws {
        let viewModel = try makeViewModel()
        viewModel.reportFocusMissIfNeeded()
        #expect(viewModel.bulkActionFeedback == nil)
        #expect(viewModel.pendingFocusCardIDs.isEmpty)
    }

    private func makeViewModel() throws -> BillingHubViewModel {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        return BillingHubViewModel(
            modelContext: context, modelContainer: container,
            ndisBillingIntegrationService: StubNDISBillingIntegrationService(
                response: Core.NDISBillingReport(
                    invoice: nil,
                    processedSessionsCount: 0,
                    successfulSessionsCount: 0,
                    failedSessions: [])
            )
        )
    }

    private func makeSessionCard(
        sessionID: UUID,
        columnType: KanbanCardData.BillingColumnType
    ) -> SessionKanbanCardData {
        SessionKanbanCardData(
            sessionId: sessionID,
            clientID: nil,
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
            endTime: Date(),
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
            rawDate: Date()
        )
    }
}
