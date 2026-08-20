import PersistenceModels
@testable import SharedUI
import Testing
import CoreTesting

@Suite(.tags(.unit))
struct FoldPaperSelectionRevealTests {
    private func makeTree() -> [TreeItem] {
        [
            TreeItem(
                id: "category_a",
                title: "Category A",
                children: [
                    TreeItem(
                        id: "group_a1",
                        title: "Group A1",
                        children: [
                            TreeItem(id: "invoice_1", title: "Invoice 1", entityID: "invoice_1", entityType: "invoice"),
                            TreeItem(id: "invoice_2", title: "Invoice 2", entityID: "invoice_2", entityType: "invoice")
                        ]
                    )
                ]
            ),
            TreeItem(
                id: "category_b",
                title: "Category B",
                children: [
                    TreeItem(id: "invoice_3", title: "Invoice 3", entityID: "invoice_3", entityType: "invoice")
                ]
            )
        ]
    }

    @Test func pathRevealsNestedLeafTwoLevelsDeep() {
        let path = FoldPaperSelectionReveal.path(toReveal: ["invoice_1"], in: makeTree())
        #expect(path == ["category_a", "group_a1"])
    }

    @Test func pathRevealsLeafOneLevelDeep() {
        let path = FoldPaperSelectionReveal.path(toReveal: ["invoice_3"], in: makeTree())
        #expect(path == ["category_b"])
    }

    @Test func pathReturnsNilWhenTargetNotFound() {
        #expect(FoldPaperSelectionReveal.path(toReveal: ["missing"], in: makeTree()) == nil)
    }

    @Test func pathReturnsNilForEmptyTargets() {
        #expect(FoldPaperSelectionReveal.path(toReveal: [], in: makeTree()) == nil)
    }

    @Test func pathMatchesFirstFoundTargetWhenMultipleIDsProvided() {
        let path = FoldPaperSelectionReveal.path(toReveal: ["invoice_3", "invoice_1"], in: makeTree())
        // Depth-first, top-to-bottom traversal reaches invoice_1 before invoice_3.
        #expect(path == ["category_a", "group_a1"])
    }
}
