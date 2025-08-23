import SwiftUI
import Charts
import UniformTypeIdentifiers

struct TaxSummaryView: View {
    @ObservedObject var viewModel: TaxContainerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Financial Summary")
                    .font(.title)
                    .fontWeight(.bold)

                HStack {
                    Spacer()
                    
                    Button(action: {
                        viewModel.exportTaxSummaryToCSV()
                    }) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                }

                // Main Summary Cards
                HStack {
                    SummaryCard(title: "Total Income", value: viewModel.totalIncome, color: .green)
                    SummaryCard(title: "Taxable Profit", value: viewModel.taxableOperatingProfit, color: .blue)
                    SummaryCard(title: "Net Cash Position", value: viewModel.netCashPosition, color: .purple)
                }

                // Detailed Sections
                incomeDetails
                
                GroupBox(label: Label("Deductions", systemImage: "arrow.down.circle.fill")) {
                    SummaryRow(label: "Operating Expenses", value: viewModel.totalOperatingExpenses)
                    SummaryRow(label: "Depreciation Claim", value: viewModel.totalDepreciationClaim)
                }
                
                GroupBox(label: Label("Capital Purchases", systemImage: "desktopcomputer")) {
                    let capitalExpenses = viewModel.allExpenses.filter { $0.isCapitalExpense }
                    if capitalExpenses.isEmpty {
                        Text("No capital expenses recorded for this period.")
                    } else {
                        VStack {
                            ForEach(capitalExpenses) { expense in
                                SummaryRow(label: expense.name, value: expense.amount + expense.gstAmount)
                            }
                        }
                    }
                }
                
                gstDetails

            }
            .padding()
        }
        .onAppear {
            viewModel.calculateSummary()
        }
    }
    
    private var incomeDetails: some View {
        GroupBox(label: Label("Income Details", systemImage: "dollarsign.circle.fill")) {
            VStack(spacing: 10) {
                SummaryRow(label: "Taxable Income", value: viewModel.totalTaxableIncome)
                SummaryRow(label: "GST-Free Income", value: viewModel.totalGSTFreeIncome)
            }
        }
    }

    private var gstDetails: some View {
        GroupBox(label: Label("GST Summary", systemImage: "percent")) {
            VStack(spacing: 10) {
                SummaryRow(label: "GST Collected", value: viewModel.gstCollected)
                SummaryRow(label: "GST Paid (on expenses)", value: viewModel.gstPaid)
                Divider()
                SummaryRow(label: "GST Balance", value: viewModel.gstBalance, isBold: true)
            }
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: Double
    let color: Color

    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
            Text(value, format: .currency(code: "AUD"))
                .font(.title)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.2))
        .cornerRadius(10)
    }
}

struct SummaryRow: View {
    let label: String
    let value: Double
    var isBold: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .fontWeight(isBold ? .bold : .regular)
            Spacer()
            Text(value, format: .currency(code: "AUD"))
                .fontWeight(isBold ? .bold : .regular)
        }
    }
} 