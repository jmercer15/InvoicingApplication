import SwiftUI
import SharedUI

struct DetailedReviewView: View {
    let reviewItem: String
    
    @Environment(\.dismiss) var dismiss
    @State private var suggestedAction = "Fix Location"
    @State private var notes = ""
    
    private let actions = ["Fix Location", "Override Compliance", "Skip", "Manual Charge"]
    
    private static let itemDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    var body: some View {
        ScrollView {
        VStack(spacing: FormSectionTokens.formGroupSpacing) {
            // Header
            VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                Text("Detailed Review")
                    .font(.title2.bold())
                Text("Review and resolve the flagged item")
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Review Item Details
            GroupBox("Review Item") {
                VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                    Text(reviewItem)
                        .font(.body)
                        .foregroundColor(ColorSystem.Status.warning)
                    
                    // Parse the review item to show structured information
                    if let parsedInfo = parseReviewItem(reviewItem) {
                        VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                            Text("Session: \(parsedInfo.sessionTitle)")
                            Text("Client: \(parsedInfo.clientName)")
                            Text("Issue: \(parsedInfo.reason)")
                            if let date = parsedInfo.date {
                                Text("Date: \(date, formatter: Self.itemDateFormatter)")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    }
                }
            }
            
            // Action Selection
            GroupBox("Suggested Action") {
                VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                    Picker("Action", selection: $suggestedAction) {
                        ForEach(actions, id: \.self) { action in
                            Text(action).tag(action)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text("Notes")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    
                    TextEditor(text: $notes)
                        .frame(height: 100)
                        .border(Color.gray.opacity(0.3))
                }
            }
            
            // Action Buttons
            HStack(spacing: FormSectionTokens.formGroupSpacing) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.glass)
                .pointerStyle(.link)
                
                Spacer()
                
                Button("Simulate Action") {
                    applyAction()
                }
                .buttonStyle(.glassProminent)
                .pointerStyle(.link)
            }
            
            Spacer(minLength: 0)
        }
        .padding()
        }
        .frame(minWidth: StyleGuide.Dimensions.settingsSheetStandardMinWidth, minHeight: StyleGuide.Dimensions.settingsSheetStandardMinHeight)
    }
    
    private func parseReviewItem(_ item: String) -> ReviewItemInfo? {
        // Parse "Session: [Title], Reason: [Reason]" format
        let components = item.components(separatedBy: ", ")
        
        var sessionTitle = "Unknown"
        var clientName = "Unknown"
        var reason = "Unknown"
        let date: Date? = nil
        
        for component in components {
            if component.hasPrefix("Session: ") {
                sessionTitle = String(component.dropFirst("Session: ".count))
            } else if component.hasPrefix("Client: ") {
                clientName = String(component.dropFirst("Client: ".count))
            } else if component.hasPrefix("Reason: ") {
                reason = String(component.dropFirst("Reason: ".count))
            }
        }
        
        return ReviewItemInfo(
            sessionTitle: sessionTitle,
            clientName: clientName,
            reason: reason,
            date: date
        )
    }
    
    private func applyAction() {
        print("Simulating action '\(suggestedAction)' for review item: \(reviewItem)")
        print("Notes: \(notes)")
        
        // Simulate action application (test mode only)
        let simulationResult = """
        SIMULATION: Would apply action '\(suggestedAction)' for:
        - Review Item: \(reviewItem)
        - Notes: \(notes)
        - Result: Action would be processed in production
        """
        
        print(simulationResult)
        
        // In production, this would:
        // - Fix Location: Open session editor
        // - Override Compliance: Create charge with override
        // - Skip: Mark as reviewed
        // - Manual Charge: Open charge creation form
        
        dismiss()
    }
}

struct ReviewItemInfo {
    let sessionTitle: String
    let clientName: String
    let reason: String
    let date: Date?
}
