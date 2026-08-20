import Testing
import CoreTesting
@testable import Feature_BillingHub

@Suite(.tags(.integration))
struct BillingHubComplianceApprovalPolicyTests {
    @Test func approvalFailsClosedUntilComplianceCheckCompletes() {
        #expect(!(BillingHubComplianceApprovalPolicy.canApprove(
                isBusy: false, hasBlockers: false,
                checkCompleted: false)))
    }

    @Test func approvalRemainsBlockedForComplianceIssues() {
        #expect(!(BillingHubComplianceApprovalPolicy.canApprove(
                isBusy: false, hasBlockers: true,
                checkCompleted: true)))
    }

    @Test func approvalRequiresIdleSuccessfulCheckWithoutBlockers() {
        #expect(!(BillingHubComplianceApprovalPolicy.canApprove(
                isBusy: true, hasBlockers: false,
                checkCompleted: true)))
        #expect(BillingHubComplianceApprovalPolicy.canApprove(
                isBusy: false, hasBlockers: false,
                checkCompleted: true))
    }
}
