import SwiftUI
import Core
import SharedUI

extension EditingPanel {
    
    // MARK: - Session Details Content
    internal var sessionDetailsContent: some View {
        Group {
            serviceTypeField
            durationAmountRow
            clientField
        }
    }
    
    // MARK: - Priority Status Content
    internal var priorityStatusContent: some View {
        Group {
            priorityLevelSection
            currentStatusSection
            sessionInfoCard
        }
    }

    // MARK: - Invoice Details Content
    internal var invoiceDetailsContent: some View {
        Group {
            serviceTypeField
            durationAmountRow
            clientField
        }
    }

    // MARK: - Invoice Status Content
    internal var invoiceStatusContent: some View {
        Group {
            if case .invoice(let data) = card {
                HStack {
                    Text("Current Status")
                        .font(StyleGuide.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                    Spacer()
                    StatusIndicator(
                        color: data.accentColor,
                        label: "", // Label managed by HStack
                        count: data.workflowStatus.rawValue.capitalized
                    )
                    .lineLimit(1)
                    .truncationMode(.tail)
                }
                
                LabeledContent {
                    Text(data.date)
                } label: {
                    Text("Date")
                        .fontWeight(.medium)
                }
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help("The issuance date of this invoice")
                
                if let days = data.daysOverdue, days > 0 {
                    LabeledContent {
                         Text("\(days) days")
                             .lineLimit(1)
                             .foregroundStyle(ColorSystem.Status.error)
                             .fontWeight(.bold)
                             .monospacedDigit()
                    } label: {
                        Text("Overdue")
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }

    internal var currentStatusSection: some View {
        LabeledContent {
            Text(statusText(for: card.currentWorkflowStatus))
                .lineLimit(1)
                .truncationMode(.tail)
        } label: {
            Text("Current Status")
                .fontWeight(.medium)
        }
        .help("View the current position of this record in the billing workflow")
    }
    
    internal var sessionInfoCard: some View {
        Group {
            if case .session(let sessionData) = card {
                LabeledContent {
                    Text(sessionData.date)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } label: {
                    Text("Date")
                        .fontWeight(.medium)
                }
                
                LabeledContent {
                    Text(sessionData.startTime?.formatted(date: .omitted, time: .shortened) ?? "-")
                        .monospacedDigit()
                        .lineLimit(1)
                } label: {
                    Text("Start Time")
                        .fontWeight(.medium)
                }
                
                LabeledContent {
                    Text(sessionData.endTime?.formatted(date: .omitted, time: .shortened) ?? "-")
                        .monospacedDigit()
                        .lineLimit(1)
                } label: {
                    Text("End Time")
                        .fontWeight(.medium)
                }
            }
        }
    }
}
