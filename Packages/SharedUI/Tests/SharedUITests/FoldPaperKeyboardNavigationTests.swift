@testable import SharedUI
import XCTest

final class FoldPaperKeyboardNavigationTests: XCTestCase {
    func testKeyboardNavigationStartsAtDirectionalEdge() {
        let ids = ["first", "middle", "last"]

        XCTAssertEqual(
            FoldPaperKeyboardNavigation.adjacentItemID(
                currentID: nil,
                itemIDs: ids,
                move: .next
            ),
            "first"
        )
        XCTAssertEqual(
            FoldPaperKeyboardNavigation.adjacentItemID(
                currentID: nil,
                itemIDs: ids,
                move: .previous
            ),
            "last"
        )
    }

    func testKeyboardNavigationMovesAndClampsWithinVisibleRows() {
        let ids = ["first", "middle", "last"]

        XCTAssertEqual(
            FoldPaperKeyboardNavigation.adjacentItemID(
                currentID: "middle",
                itemIDs: ids,
                move: .next
            ),
            "last"
        )
        XCTAssertEqual(
            FoldPaperKeyboardNavigation.adjacentItemID(
                currentID: "first",
                itemIDs: ids,
                move: .previous
            ),
            "first"
        )
        XCTAssertNil(
            FoldPaperKeyboardNavigation.adjacentItemID(
                currentID: nil,
                itemIDs: [],
                move: .next
            )
        )
    }
}
