import SwiftUI
import Core
import SharedUI

extension EditingPanel {
    
    @ViewBuilder
    internal var complianceChecklistContent: some View {
        if let complianceLoadError,
           !complianceLoadError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(complianceLoadError)
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(ColorSystem.Status.error)
        }

        if complianceBlockers.isEmpty && complianceWarnings.isEmpty {
            Text("No compliance issues detected.")
                .foregroundStyle(StyleGuide.Colors.textSecondary)
        } else {
            if !complianceBlockers.isEmpty {
                Text("Blockers")
                    .font(StyleGuide.Typography.itemTitle)
                    .foregroundStyle(ColorSystem.Status.error)
                ForEach(complianceBlockers, id: \.self) { issue in
                    HStack(alignment: .top, spacing: StyleGuide.Dimensions.paddingMedium) {
                        Image(systemName: "xmark.octagon.fill")
                            .foregroundStyle(ColorSystem.Status.error)
                        Text("[\(issue.id)] \(issue.message)")
                            .font(StyleGuide.Typography.itemSubtitle)
                    }
                }
            }

            if !complianceWarnings.isEmpty {
                Text("Warnings")
                    .font(StyleGuide.Typography.itemTitle)
                    .foregroundStyle(ColorSystem.Status.warning)
                ForEach(complianceWarnings, id: \.self) { issue in
                    HStack(alignment: .top, spacing: StyleGuide.Dimensions.paddingMedium) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(ColorSystem.Status.warning)
                        Text("[\(issue.id)] \(issue.message)")
                            .font(StyleGuide.Typography.itemSubtitle)
                    }
                }
            }
        }
    }

    internal func loadComplianceData() async {
        supportLogError = nil
        complianceLoadError = nil
        complianceWarnings = []
        complianceBlockers = []

        switch card {
        case .session(let sessionData):
            if let supportLog = await viewModel.fetchSupportLog(forSessionId: sessionData.sessionId) {
                supportLogDraft = supportLogDraft(from: supportLog)
            }
        case .invoice(let invoiceData):
            if let result = await viewModel.fetchComplianceChecklist(for: invoiceData.invoiceId) {
                complianceWarnings = result.warnings
                complianceBlockers = result.blockers
            }
        }
    }
}
