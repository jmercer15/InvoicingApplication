import Testing
import CoreTesting
@testable import SharedUI

@Suite(.tags(.unit))
struct BillingPipelineProgressTests {
    @Test func pipelineStagesRemainInUserJourneyOrder() {
        #expect(BillingPipelineStage.allCases == [.session, .prepare, .review, .send, .payment, .paid]
        )
    }

    @Test func pipelineStagesHaveDistinctReadableLabelsAndSymbols() {
        let stages = BillingPipelineStage.allCases
        #expect(Set(stages.map(\.title)).count == stages.count)
        #expect(Set(stages.map(\.symbolName)).count == stages.count)
        #expect(stages.allSatisfy { !$0.title.isEmpty && !$0.symbolName.isEmpty })
    }
}
