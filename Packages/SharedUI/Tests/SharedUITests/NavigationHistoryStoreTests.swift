import Core
@testable import SharedUI
import XCTest

final class NavigationHistoryStoreTests: XCTestCase {
    func testAddToHistoryDeduplicatesCurrentEntry() {
        var store = NavigationHistoryStore()

        store.addToHistory(tab: .invoices, context: nil)
        store.addToHistory(tab: .invoices, context: nil)

        XCTAssertEqual(store.recentHistory.count, 1)
        XCTAssertFalse(store.canNavigateBack)
    }

    func testBackAndForwardReturnEntries() {
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
        XCTAssertEqual(backEntry?.tab, .invoices)
        XCTAssertEqual(backEntry?.context?.targetEntity, invoiceID)
        XCTAssertTrue(store.canNavigateForward)

        let forwardEntry = store.navigateForward()
        XCTAssertEqual(forwardEntry?.tab, .relationships)
        XCTAssertFalse(store.canNavigateForward)
    }

    func testAddingAfterBackPrunesForwardHistory() {
        var store = NavigationHistoryStore()

        store.addToHistory(tab: .invoices, context: nil)
        store.addToHistory(tab: .relationships, context: nil)
        store.addToHistory(tab: .calendar, context: nil)
        _ = store.navigateBack()

        store.addToHistory(tab: .billingHub, context: nil)

        XCTAssertFalse(store.canNavigateForward)
        XCTAssertEqual(store.currentHistoryEntry?.tab, .billingHub)
    }

    func testReplaceCurrentEntryRewritesCursorWithoutGrowingStack() {
        var store = NavigationHistoryStore()

        store.addToHistory(tab: .invoices, context: nil)
        store.addToHistory(tab: .relationships, context: nil)
        XCTAssertEqual(store.recentHistory.count, 2)

        store.replaceCurrentEntry(tab: .calendar, context: nil)

        XCTAssertEqual(store.recentHistory.count, 2)
        XCTAssertEqual(store.currentHistoryEntry?.tab, .calendar)
        XCTAssertTrue(store.canNavigateBack)
    }

    func testReplaceCurrentEntryTruncatesForwardBranch() {
        var store = NavigationHistoryStore()

        store.addToHistory(tab: .invoices, context: nil)
        store.addToHistory(tab: .relationships, context: nil)
        store.addToHistory(tab: .calendar, context: nil)
        _ = store.navigateBack()

        XCTAssertTrue(store.canNavigateForward)

        store.replaceCurrentEntry(tab: .billingHub, context: nil)

        XCTAssertFalse(store.canNavigateForward)
        XCTAssertEqual(store.currentHistoryEntry?.tab, .billingHub)
    }
}
