import SwiftUI
import SwiftData
import Data
// import Core  // Removed to avoid type ambiguity with TravelChargeReviewItem
import SharedUI

struct TravelChargeReviewView: View {
    @Environment(\.modelContext) private var viewContext
    @Query(sort: \TravelChargeReviewItem.timestamp, order: .reverse) private var reviewItems: [TravelChargeReviewItem]
    
    @State private var selectedReviewItem: TravelChargeReviewItem?
    @State private var showingViolationDetails = false
    @State private var showingReviewSheet = false
    @State private var filterStatus: ReviewStatusFilter = .all
    
    enum ReviewStatusFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case resolved = "Resolved"
        case overridden = "Overridden"
        case skipped = "Skipped"
    }
    
    var filteredReviewItems: [TravelChargeReviewItem] {
        switch filterStatus {
        case .all:
            return reviewItems
        case .pending:
            return reviewItems.filter { $0.status == "pending" }
        case .resolved:
            return reviewItems.filter { $0.status == "resolved" }
        case .overridden:
            return reviewItems.filter { $0.status == "overridden" }
        case .skipped:
            return reviewItems.filter { $0.status == "skipped" }
        }
    }
    
    var body: some View {
        VStack(spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Travel Charge Review")
                            .font(.title2.bold())
                        Spacer()
                        Button("Review All Pending") {
                            showingReviewSheet = true
                        }
                        .buttonStyle(.glassProminent)
                        .appInteractiveCursor()
                        .disabled(reviewItems.filter { $0.status == "pending" }.isEmpty)
                    }
                    
                    Text("Review and resolve travel charge compliance violations")
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }
                .padding(.horizontal)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))
                
                // Status Filter
                HStack {
                    Text("Filter:")
                        .font(.headline)
                    
                    Picker("Status", selection: $filterStatus) {
                        ForEach(ReviewStatusFilter.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Filter by status")
                    .accessibilityHint("Filter review items by their status")
                    
                    Spacer()
                    
                    Text("\(filteredReviewItems.count) items")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }
                .padding(.horizontal)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))
                
                // Review Items List
                if filteredReviewItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text("No Review Items")
                            .font(.title2.bold())
                        Text("All travel charges are compliant or have been resolved.")
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredReviewItems, id: \.id) { reviewItem in
                                ReviewItemCard(reviewItem: reviewItem) {
                                    selectedReviewItem = reviewItem
                                    showingViolationDetails = true
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
        }
        .sheet(isPresented: $showingViolationDetails) {
            if let reviewItem = selectedReviewItem {
                TravelChargeViolationDetailsView(reviewItem: reviewItem)
            }
        }
        .sheet(isPresented: $showingReviewSheet) {
            TravelChargeReviewSheetView()
        }
    }
}

struct ReviewItemCard: View {
    let reviewItem: TravelChargeReviewItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reviewItem.session?.title ?? "Unknown Session")
                            .font(.headline)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        
                        if let client = reviewItem.session?.client {
                            Text("Client: \(client.fullName)")
                                .font(.body)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        }
                    }
                    
                    Spacer()
                    
                    StatusBadge(status: reviewItem.status)
                }
                
                if let reason = reviewItem.reason {
                    Text(reason)
                        .font(.body)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .lineLimit(2)
                }
                
                HStack {
                    if reviewItem.hasViolations {
                        Label("\(reviewItem.violationCount) violations", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    if let timestamp = reviewItem.timestamp {
                        Text(timestamp, style: .relative)
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    }
                }
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        switch reviewItem.status {
        case "pending":
            return Color.orange.opacity(0.1)
        case "overridden":
            return Color.blue.opacity(0.1)
        case "skipped":
            return Color.gray.opacity(0.1)
        case "resolved":
            return Color.green.opacity(0.1)
        default:
            return Color.secondary.opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        switch reviewItem.status {
        case "pending":
            return Color.orange.opacity(0.3)
        case "overridden":
            return Color.blue.opacity(0.3)
        case "skipped":
            return Color.gray.opacity(0.3)
        case "resolved":
            return Color.green.opacity(0.3)
        default:
            return Color.secondary.opacity(0.3)
        }
    }
}

// Note: StatusBadge is already defined in ViewStyles.swift

struct TravelChargeViolationDetailsView: View {
    let reviewItem: TravelChargeReviewItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var viewContext
    
    @State private var selectedOverride: String = ""
    @State private var overrideReason: String = ""
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Compliance Violations")
                            .font(.title2.bold())
                        Text("Review and resolve compliance violations for this travel charge")
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Session Information
                    GroupBox("Session Details") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Session: \(reviewItem.session?.title ?? "Unknown")")
                                .font(.headline)
                            if let client = reviewItem.session?.client {
                                Text("Client: \(client.fullName)")
                                    .font(.body)
                            }
                            if let timestamp = reviewItem.timestamp {
                                Text("Date: \(timestamp, formatter: DateFormatter())")
                                    .font(.caption)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            }
                        }
                    }
                    
                    // Violations List
                    if let violations = reviewItem.violationDetails, !violations.isEmpty {
                        GroupBox("Violations") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(violations, id: \.self) { violation in
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                        Text(violation)
                                            .font(.body)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    
                    // Override Options
                    if let overrideOptions = reviewItem.overrideOptions, !overrideOptions.isEmpty {
                        GroupBox("Override Options") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Select an override option if you want to proceed despite violations:")
                                    .font(.caption)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                
                                ForEach(overrideOptions, id: \.self) { option in
                                    Button(action: {
                                        selectedOverride = option
                                    }) {
                                        HStack {
                                            Image(systemName: selectedOverride == option ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedOverride == option ? .accentColor : .secondary)
                                            Text(option)
                                                .foregroundColor(Color("Text", bundle: .sharedUI))
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                if !selectedOverride.isEmpty {
                                    TextField("Reason for override (optional)", text: $overrideReason, axis: .vertical)
                                        .textFieldStyle(.roundedBorder)
                                        .lineLimit(3...6)
                                }
                            }
                        }
                    }
                    
                    // Suggested Actions
                    if let suggestedActions = reviewItem.suggestedActions, !suggestedActions.isEmpty {
                        GroupBox("Suggested Actions") {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(suggestedActions, id: \.self) { action in
                                    HStack {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .foregroundColor(.blue)
                                        Text(action)
                                            .font(.body)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.glass)
                        .appInteractiveCursor()
                        
                        Spacer()
                        
                        if !selectedOverride.isEmpty {
                            Button("Override and Create") {
                                handleOverrideAction()
                            }
                            .buttonStyle(.glassProminent)
                            .appInteractiveCursor()
                            .disabled(isProcessing)
                        }
                        
                        Button("Skip Charge") {
                            handleSkipAction()
                        }
                        .buttonStyle(.glass)
                        .appInteractiveCursor()
                        .disabled(isProcessing)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }
    
    private func handleOverrideAction() {
        isProcessing = true
        
        Task {
            do {
                let automationService = TravelChargeAutomationService(
                    context: viewContext,
                    businessRules: BusinessRules(),
                    userPreferences: UserPreferences(),
                    mmmZoneTable: MMMZoneTable()
                )
                
                let reviewItemToResolve = reviewItem
                try await automationService.resolveReviewWithOverride(
                    reviewItemToResolve,
                    overrideType: selectedOverride,
                    overrideReason: overrideReason.isEmpty ? nil : overrideReason
                )
                
                await MainActor.run {
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    print("Error applying override: \(error)")
                }
            }
        }
    }
    
    private func handleSkipAction() {
        isProcessing = true
        
        Task {
            do {
                let automationService = TravelChargeAutomationService(
                    context: viewContext,
                    businessRules: BusinessRules(),
                    userPreferences: UserPreferences(),
                    mmmZoneTable: MMMZoneTable()
                )
                
                let reviewItemToSkip = reviewItem
                try await automationService.resolveReviewBySkipping(reviewItemToSkip)
                
                await MainActor.run {
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    print("Error skipping review: \(error)")
                }
            }
        }
    }
}

struct TravelChargeReviewSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<TravelChargeReviewItem> { $0.status == "pending" }, sort: \TravelChargeReviewItem.timestamp) private var pendingReviews: [TravelChargeReviewItem]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Pending Reviews")
                            .font(.title2.bold())
                        Spacer()
                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.glass)
                        .appInteractiveCursor()
                    }
                    
                    Text("\(pendingReviews.count) items require attention")
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }
                .padding(.horizontal)
                
                // Pending Reviews List
                if pendingReviews.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text("No Pending Reviews")
                            .font(.title2.bold())
                        Text("All travel charge reviews have been resolved.")
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(pendingReviews, id: \.id) { reviewItem in
                                ReviewItemCard(reviewItem: reviewItem) {
                                    // Navigate to violation details
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

// MARK: - Supporting Types
// Note: BusinessRules, UserPreferences, and MMMZone are defined in TravelChargeAutomationService.swift
