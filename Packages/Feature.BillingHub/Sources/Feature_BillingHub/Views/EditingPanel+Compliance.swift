import SwiftUI
import Core
import SharedUI

extension EditingPanel {
    
    @ViewBuilder
    internal var complianceChecklistContent: some View {
        if isLoadingCompliance {
            HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking invoice compliance…")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(BillingHubTheme.Palette.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Checking invoice compliance")
        } else if let complianceLoadError,
           !complianceLoadError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
                Label(complianceLoadError, systemImage: "exclamationmark.triangle.fill")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(ColorSystem.Status.error)

                Button("Retry Compliance Check", systemImage: "arrow.clockwise") {
                    Task { await loadComplianceData() }
                }
                .buttonStyle(.bordered)
            }
        } else if complianceBlockers.isEmpty && complianceWarnings.isEmpty {
            Label("Ready for approval", systemImage: "checkmark.shield.fill")
                .foregroundStyle(ColorSystem.Status.success)
                .accessibilityLabel("Compliance check passed. Ready for approval.")
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
        isLoadingCompliance = true
        defer { isLoadingCompliance = false }

        switch card {
        case .session(let sessionData):
            if let supportLog = await viewModel.fetchSupportLog(forSessionId: sessionData.sessionId) {
                supportLogDraft = supportLogDraft(from: supportLog)
            }
        case .invoice(let invoiceData) where card.columnType == .reviewDrafts:
            do {
                guard let result = try await viewModel.fetchComplianceChecklist(for: invoiceData.invoiceId) else {
                    complianceLoadError = "Compliance checks are unavailable. Approval remains locked."
                    return
                }
                complianceWarnings = result.warnings
                complianceBlockers = result.blockers
            } catch {
                complianceLoadError = "Compliance check couldn’t load. Approval remains locked."
            }
        case .invoice:
            break
        }
    }
}
