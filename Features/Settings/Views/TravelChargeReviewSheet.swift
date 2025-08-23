import SwiftUI

struct TravelChargeReviewSheet: View {
    let chargeSummaries: [String]
    let reviewSummaries: [String]
    let detailedReviewItems: [DetailedReviewItem]
    let reviewService: TravelChargeAutomationService?
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var showingDetailedReview = false
    @State private var selectedReviewItem: String = ""
    @State private var showingViolationDetails = false
    @State private var selectedDetailedReview: DetailedReviewItem?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Text("Travel Charge Review")
                        .font(.title2.bold())
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.glass)
                }
                
                Text("Review automation results and resolve any issues")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .glassEffect(.regular, in: .rect())
            
            // Tab Picker
            Picker("View", selection: $selectedTab) {
                Text("Charges (\(chargeSummaries.count))").tag(0)
                Text("Reviews (\(reviewSummaries.count))").tag(1)
                Text("Detailed (\(detailedReviewItems.count))").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Content based on selected tab
            TabView(selection: $selectedTab) {
                // Charges Tab
                chargesTab
                    .tag(0)
                
                // Reviews Tab
                reviewsTab
                    .tag(1)
                
                // Detailed Reviews Tab
                detailedReviewsTab
                    .tag(2)
            }
            .tabViewStyle(.automatic)
        }
        .frame(minWidth: 600, minHeight: 500)
        .sheet(isPresented: $showingDetailedReview) {
            DetailedReviewView(reviewItem: selectedReviewItem)
        }
        .sheet(isPresented: $showingViolationDetails) {
            if let detailedReview = selectedDetailedReview {
                ViolationDetailsView(detailedReview: detailedReview)
            }
        }
    }
    
    // MARK: - Tab Views
    
    private var chargesTab: some View {
        VStack(spacing: 16) {
            if chargeSummaries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No Travel Charges Created")
                        .font(.title2.bold())
                    Text("All sessions passed validation and no travel charges were needed.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Travel Charges Would Be Created:")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(chargeSummaries, id: \.self) { summary in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(summary)
                                        .font(.body)
                                        .padding()
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private var reviewsTab: some View {
        VStack(spacing: 16) {
            if reviewSummaries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No Review Items")
                        .font(.title2.bold())
                    Text("All sessions passed validation without issues.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Review Items Requiring Attention:")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(reviewSummaries, id: \.self) { summary in
                                Button(action: {
                                    selectedReviewItem = summary
                                    showingDetailedReview = true
                                }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(summary)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding()
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private var detailedReviewsTab: some View {
        VStack(spacing: 16) {
            if detailedReviewItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No Detailed Reviews")
                        .font(.title2.bold())
                    Text("No compliance violations were detected.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Compliance Violations:")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(detailedReviewItems, id: \.id) { reviewItem in
                                detailedReviewItemView(reviewItem)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private func detailedReviewItemView(_ reviewItem: DetailedReviewItem) -> some View {
        Button(action: {
            selectedDetailedReview = reviewItem
            showingViolationDetails = true
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(reviewItem.session.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(reviewItem.violations.count) violations")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                if let client = reviewItem.session.client {
                    Text("Client: \(client.fullName)")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Text("Date: \(reviewItem.timestamp, formatter: DateFormatter())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Show first violation as preview
                if let firstViolation = reviewItem.violations.first {
                    HStack {
                        Image(systemName: firstViolation.severity == .warning ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(firstViolation.severity == .warning ? .orange : .red)
                            .font(.caption)
                        Text(firstViolation.rule)
                            .font(.caption)
                            .foregroundColor(firstViolation.severity == .warning ? .orange : .red)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
} 