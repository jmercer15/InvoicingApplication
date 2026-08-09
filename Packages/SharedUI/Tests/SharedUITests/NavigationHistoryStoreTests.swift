import Core
@testable import SharedUI
import Foundation
import Testing
@Suite struct NavigationHistoryStoreTests {
    @Test func AddToHistoryDeduplicatesCurrentEntry() {
        var store = NavigationHistoryStore()

        store.addToHistory(tab: .invoices, context: nil)
        store.addToHistory(tab: .invoices, context: nil)

        #expect(store.recentHistory.count == 1)
        #expect(!(store.canNavigateBack))
    }

    @Test func BackAndForwardReturnEntries() {
        var store = NavigationHistoryStore()
        let invoiceID = UUID()
        let invoiceContext = NavigationContext(
            targetEntity: invoiceID,
            targetEntityType: .invoice
        )

        store.addToHistory(tab: .invoices, context: nil)
        store.addToHistory(tab: .invoices, context: invoiceContext)
        store.addToHistory(tab: .relationships, context: nil)

        let backEntry = store.navigateBack()
        #expect(backEntry?.tab == .invoices)
        #expect(backEntry?.context?.targetEntity == invoiceID)
        #expect(store.canNavigateForward)

        let forwardEntry = store.navigateForward()
        #expect(forwardEntry?.tab == .relationships)
        #expect(!(store.canNavigateForward))
    }

    @Test func AddingAfterBackPrunesForwardHistory() {
        var store = NavigationHistoryStore()

        store.addToHistory(tab: .invoices, context: nil)
        store.addToHistory(tab: .relationships, context: nil)
        store.addToHistory(tab: .calendar, context: nil)
        _ = store.navigateBack()

        store.addToHistory(tab: .billingHub, context: nil)

        #expect(!(store.canNavigateForward))
        #expect(store.currentHistoryEntry?.tab == .billingHub)
    }

    @Test func ReplaceCurrentEntryRewritesCursorWithoutGrowingStack() {
        var store = NavigationHistoryStore()

        store.addToHistory(tab: .invoices, context: nil)
        store.addToHistory(tab: .relationships, context: nil)
        #expect(store.recentHistory.count == 2)

        store.replaceCurrentEntry(tab: .calendar, context: nil)

        #expect(store.recentHistory.count == 2)
        #expect(store.currentHistoryEntry?.tab == .calendar)
        #expect(store.canNavigateBack)
    }

    @Test func ReplaceCurrentEntryTruncatesForwardBranch() {
        var store = NavigationHistoryStore()

        store.addToHistory(tab: .invoices, context: nil)
        store.addToHistory(tab: .relationships, context: nil)
        store.addToHistory(tab: .calendar, context: nil)
        _ = store.navigateBack()

        #expect(store.canNavigateForward)

        store.replaceCurrentEntry(tab: .billingHub, context: nil)

        #expect(!(store.canNavigateForward))
        #expect(store.currentHistoryEntry?.tab == .billingHub)
    }
}
