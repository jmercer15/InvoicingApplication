import Foundation
import Testing
@testable import Feature_BillingHub

@Suite(.tags(.unit))
struct BillingHubDurationParserTests {
    @Test func supportsHourMinuteAndBareMinutes() {
        #expect(BillingHubDurationParser.totalMinutes(from: "1h 30m") == 90)
        #expect(BillingHubDurationParser.totalMinutes(from: "1h30m") == 90)
        #expect(BillingHubDurationParser.totalMinutes(from: "90m") == 90)
        #expect(BillingHubDurationParser.totalMinutes(from: "1.5h") == 90)
        #expect(BillingHubDurationParser.totalMinutes(from: "1:30") == 90)
        #expect(BillingHubDurationParser.totalMinutes(from: "45") == 45)
        #expect(BillingHubDurationParser.totalMinutes(from: "") == nil)
        #expect(BillingHubDurationParser.totalMinutes(from: "nope") == nil)
    }
}
