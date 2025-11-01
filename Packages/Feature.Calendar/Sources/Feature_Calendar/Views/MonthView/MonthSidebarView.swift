import SwiftUI
import SharedUI


// ─────────────────────────────────────────────────────────────
// MARK: - Month View Sidebar
// ─────────────────────────────────────────────────────────────

struct MonthSidebarView: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                summarySection()
            }
            .padding(12)
        }
        .background(Color.clear)
    }

    @ViewBuilder private func summarySection() -> some View {
        VStack(spacing: 10) {
            // Visible Sessions (all instances)
                VStack(spacing: 4) {
                    Text("VISIBLE SESSIONS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        .tracking(1)
                let visibleSessionCount = viewModel.visibleSessionInstances.count
                Text("\(visibleSessionCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
                // Total Billable Hours
                VStack(spacing: 4) {
                    Text("BILLABLE HOURS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        .tracking(1)
                Text(String(format: "%.1f h", viewModel.visibleBillableHours))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
                // Total Gross Income
                VStack(spacing: 4) {
                    Text("GROSS INCOME")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        .tracking(1)
                Text(viewModel.formatCurrency(viewModel.visibleGrossIncome))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
            }
        }
    }

