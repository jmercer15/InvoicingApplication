import SwiftUI
import Data
import Core
import SharedUI

struct ViolationDetailsView: View {
    let detailedReview: DetailedReviewItem
    let onOverride: ((DetailedReviewItem, String, String?) -> Void)? = nil
    let onSkip: ((DetailedReviewItem, String?) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOverride: String = ""
    @State private var overrideReason: String = ""
    
    var body: some View {
        ScrollView {
        VStack(spacing: 16) {
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session: \(detailedReview.session.title)")
                        .font(.headline)
                    if let clientName = detailedReview.clientName {
                        Text("Client: \(clientName)")
                            .font(.body)
                    }
                    Text("Date: \(detailedReview.timestamp, formatter: DateFormatter())")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }
            }
            
            // Violations List
            GroupBox("Violations") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(detailedReview.violations, id: \.rule) { violation in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: violation.severity == .warning ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                                    .foregroundColor(violation.severity == .warning ? .orange : .red)
                                Text(violation.rule)
                                    .font(.headline)
                                    .foregroundColor(violation.severity == .warning ? .orange : .red)
                                Spacer()
                            }
                            
                            Text(violation.description)
                                .font(.body)
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                            
                            HStack {
                                Text("Current: \(violation.currentValue)")
                                    .font(.caption)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                Spacer()
                                Text("Limit: \(violation.limit)")
                                    .font(.caption)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            }
                            
                            // Special styling for distance adjustments
                            if violation.rule == "Distance Adjustment" {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text("This automatic adjustment prevents overcharging and ensures compliance with business rules.")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .italic()
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .background(
                            violation.rule == "Distance Adjustment" ? Color.green.opacity(0.1) :
                            violation.severity == .warning ? Color.orange.opacity(0.1) : 
                            Color.red.opacity(0.1)
                        )
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
                    }
                }
            }
            
            // Override Options
            if !detailedReview.overrideOptions.isEmpty {
                GroupBox("Override Options") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select an override option if you want to proceed despite violations:")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        
                        ForEach(detailedReview.overrideOptions, id: \.self) { option in
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
                                .contentShape(Rectangle())
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
            if !detailedReview.suggestedActions.isEmpty {
                GroupBox("Suggested Actions") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(detailedReview.suggestedActions, id: \.self) { action in
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
                .pointerStyle(.link)
                
                Spacer()
                
                if !selectedOverride.isEmpty {
                    Button("Override and Create") {
                        handleOverrideAction()
                    }
                    .buttonStyle(.glassProminent)
                    .pointerStyle(.link)
                }
                
                Button("Skip Charge") {
                    handleSkipAction()
                }
                .buttonStyle(.glass)
                .pointerStyle(.link)
            }
        }
        .padding()
        }
        .frame(minWidth: 500, minHeight: 600)
    }
    
    private func handleOverrideAction() {
        let overrideDetails = """
        Override Details:
        - Selected Override: \(selectedOverride)
        - Reason: \(overrideReason.isEmpty ? "No reason provided" : overrideReason)
        - Session: \(detailedReview.session.title)
        - Violations: \(detailedReview.violations.map { $0.rule }.joined(separator: ", "))
        """
        
        print("[ViolationDetails] Creating travel charge with override:")
        print("[ViolationDetails] \(overrideDetails)")

        onOverride?(
            detailedReview,
            selectedOverride,
            overrideReason.isEmpty ? nil : overrideReason
        )
        
        dismiss()
    }
    
    private func handleSkipAction() {
        let skipDetails = """
        Skipped Travel Charge:
        - Session: \(detailedReview.session.title)
        - Reason: User chose to skip due to violations
        - Violations: \(detailedReview.violations.map { $0.rule }.joined(separator: ", "))
        """
        
        print("[ViolationDetails] Skipping travel charge:")
        print("[ViolationDetails] \(skipDetails)")

        onSkip?(detailedReview, "User chose to skip due to violations")
        
        dismiss()
    }
} 
