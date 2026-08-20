import Testing
import CoreTesting
@testable import Feature_BillingHub

@Suite(.tags(.integration))
struct KanbanBoardDisplayStateTests {
    @Test func displayStateTracksSearchAndFilterSlices() {
        let state = KanbanBoardDisplayState(searchText: "alex", hasActiveFilters: true)
        #expect(state.searchText == "alex")
        #expect(state.hasActiveFilters)

        let cleared = KanbanBoardDisplayState(searchText: "", hasActiveFilters: false)
        #expect(state != cleared)
    }
}
