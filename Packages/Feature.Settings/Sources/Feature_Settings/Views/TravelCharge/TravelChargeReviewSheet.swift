import SwiftUI
import Core
import SharedUI

struct TravelChargeReviewSheet: View {
    let chargeSummaries: [String]
    let reviewSummaries: [String]
    let detailedReviewItems: [Core.DetailedReviewItem]

    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @State private var showingDetailedReview = false
    @State private var selectedReviewItem: String = ""
    @State private var showingViolationDetails = false
    @State private var selectedDetailedReview: Core.DetailedReviewItem?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: FormSectionTokens.fieldStackSpacing) {
                HStack {
                    Text("Travel Charge Review")
                        .font(.title2.bold())
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.glass)
                    .pointerStyle(.link)
                }
                
                Text("Review automation results and resolve any issues")
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color("Background", bundle: .sharedUI))
            
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
                    .fluidTransition()
                
                // Reviews Tab
                reviewsTab
                    .tag(1)
                    .fluidTransition()
                
                // Detailed Reviews Tab
                detailedReviewsTab
                    .tag(2)
                    .fluidTransition()
            }
            .tabViewStyle(.automatic)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: selectedTab)
        }
        .frame(minWidth: StyleGuide.Dimensions.settingsSheetLargeMinWidth, minHeight: StyleGuide.Dimensions.settingsSheetLargeMinHeight)
        .sheet(isPresented: $showingDetailedReview) {
            DetailedReviewView(reviewItem: selectedReviewItem)
            .fluidSheetTransition()
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showingDetailedReview)
        }
        .sheet(isPresented: $showingViolationDetails) {
            if let detailedReview = selectedDetailedReview {
                ViolationDetailsView(detailedReview: detailedReview)
                .fluidSheetTransition()
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showingViolationDetails)
            }
        }
    }
    
    // MARK: - Tab Views
    
    private var chargesTab: some View {
        VStack(spacing: FormSectionTokens.formGroupSpacing) {
            if chargeSummaries.isEmpty {
                VStack(spacing: FormSectionTokens.formGroupSpacing) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(StyleGuide.Typography.emptyStateIcon)
                        .foregroundColor(Color("Active", bundle: .sharedUI))
                    Text("No Travel Charges Created")
                        .font(.title2.bold())
                    Text("All sessions passed validation and no travel charges were needed.")
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                    Text("Travel Charges Would Be Created:")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVStack(spacing: FormSectionTokens.fieldStackSpacing) {
                            ForEach(chargeSummaries, id: \.self) { summary in
                                VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                                    Text(summary)
                                        .font(.body)
                                        .padding()
                                        .background(Color.green.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous))
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
        VStack(spacing: FormSectionTokens.formGroupSpacing) {
            if reviewSummaries.isEmpty {
                VStack(spacing: FormSectionTokens.formGroupSpacing) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(StyleGuide.Typography.emptyStateIcon)
                        .foregroundColor(Color("Active", bundle: .sharedUI))
                    Text("No Review Items")
                        .font(.title2.bold())
                    Text("All sessions passed validation without issues.")
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                    Text("Review Items Requiring Attention:")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVStack(spacing: FormSectionTokens.fieldStackSpacing) {
                            ForEach(reviewSummaries, id: \.self) { summary in
                                Button(action: {
                                    selectedReviewItem = summary
                                    showingDetailedReview = true
                                }) {
                                    VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                                        Text(summary)
                                            .font(.body)
                                            .foregroundColor(Color("Text", bundle: .sharedUI))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding()
                                    .background(Color.orange.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous))
                                    .contentShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous))
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
        VStack(spacing: FormSectionTokens.formGroupSpacing) {
            if detailedReviewItems.isEmpty {
                VStack(spacing: FormSectionTokens.formGroupSpacing) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(StyleGuide.Typography.emptyStateIcon)
                        .foregroundColor(Color("Active", bundle: .sharedUI))
                    Text("No Detailed Reviews")
                        .font(.title2.bold())
                    Text("No compliance violations were detected.")
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                    Text("Compliance Violations:")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVStack(spacing: FormSectionTokens.fieldStackSpacing) {
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
    
    private func detailedReviewItemView(_ reviewItem: Core.DetailedReviewItem) -> some View {
        Button(action: {
            selectedDetailedReview = reviewItem
            showingViolationDetails = true
        }) {
            VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                HStack {
                    Text(reviewItem.sessionTitle)
                        .font(.headline)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    Spacer()
                    Text("\(reviewItem.violations.count) violations")
                        .font(.caption)
                        .foregroundColor(Color("Cancelled", bundle: .sharedUI))
                }
                
                if let clientName = reviewItem.clientName {
                    Text("Client: \(clientName)")
                        .font(.body)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }
                
                Text("Date: \(DateFormatting.mediumDateTime(reviewItem.timestamp))")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                
                // Show first violation as preview
                if let firstViolation = reviewItem.violations.first {
                    HStack {
                        Image(systemName: firstViolation.severity == .warning ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(firstViolation.severity == .warning ? Color("Inactive", bundle: .sharedUI) : Color("Cancelled", bundle: .sharedUI))
                            .font(.caption)
                        Text(firstViolation.rule)
                            .font(.caption)
                            .foregroundColor(firstViolation.severity == .warning ? Color("Inactive", bundle: .sharedUI) : Color("Cancelled", bundle: .sharedUI))
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous))
        }
        .buttonStyle(.plain)
    }
} 
