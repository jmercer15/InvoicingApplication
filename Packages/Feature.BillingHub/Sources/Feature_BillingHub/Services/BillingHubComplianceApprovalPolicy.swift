enum BillingHubComplianceApprovalPolicy {
    static func canApprove(
        isBusy: Bool,
        hasBlockers: Bool,
        checkCompleted: Bool
    ) -> Bool {
        !isBusy && !hasBlockers && checkCompleted
    }
}
