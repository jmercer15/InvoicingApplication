import SwiftUI

struct BASReportView: View {
    @ObservedObject var viewModel: TaxContainerViewModel
    
    let quarterOptions = ["Jul-Sep", "Oct-Dec", "Jan-Mar", "Apr-Jun"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("BAS Preparation Report")
                    .font(.title)
                    .fontWeight(.bold)
                
                Picker("Quarter", selection: $viewModel.selectedQuarter) {
                    ForEach(quarterOptions, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: viewModel.selectedQuarter) { _, _ in
                    viewModel.calculateBASSummary()
                }

                GroupBox(label: Label("GST on Sales", systemImage: "arrow.up.right.circle.fill")) {
                    BASRow(label: "G1: Total Sales", value: viewModel.basTotalSales)
                    BASRow(label: "1A: GST on sales", value: viewModel.basGstOnSales, isBold: true)
                }
                
                GroupBox(label: Label("GST on Purchases", systemImage: "arrow.down.left.circle.fill")) {
                    BASRow(label: "1B: GST on purchases", value: viewModel.basGstOnPurchases, isBold: true)
                }
                
                GroupBox(label: Label("Summary", systemImage: "sum")) {
                    let balance = viewModel.basGstOnSales - viewModel.basGstOnPurchases
                    let balanceText = balance >= 0 ? "Payment due to ATO" : "Refund from ATO"
                    BASRow(label: "Net GST to Pay/Refund", value: abs(balance), isBold: true)
                    Text(balanceText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .onAppear {
            viewModel.calculateBASSummary()
        }
    }
}

struct BASRow: View {
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
        .padding(.vertical, 4)
    }
} 