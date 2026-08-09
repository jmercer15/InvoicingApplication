@testable import SharedUI
import Testing
@Suite struct FoldPaperKeyboardNavigationTests {
    @Test func KeyboardNavigationStartsAtDirectionalEdge() {
        let ids = ["first", "middle", "last"]

        #expect(FoldPaperKeyboardNavigation.adjacentItemID(
                currentID: nil,
                itemIDs: ids,
                move: .next
            ) == "first")
        #expect(FoldPaperKeyboardNavigation.adjacentItemID(
                currentID: nil,
                itemIDs: ids,
                move: .previous
            ) == "last")
    }

    @Test func KeyboardNavigationMovesAndClampsWithinVisibleRows() {
        let ids = ["first", "middle", "last"]

        #expect(FoldPaperKeyboardNavigation.adjacentItemID(
                currentID: "middle",
                itemIDs: ids,
                move: .next
            ) == "last")
        #expect(FoldPaperKeyboardNavigation.adjacentItemID(
                currentID: "first",
                itemIDs: ids,
                move: .previous
            ) == "first")
        #expect(FoldPaperKeyboardNavigation.adjacentItemID(
                currentID: nil,
                itemIDs: [],
                move: .next
            ) == nil)
    }
}
