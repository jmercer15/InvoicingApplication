import SwiftUI
import SharedUI

struct CompletedPanel: View {
    let card: KanbanCardData
    let viewModel: BillingHubViewModel
    @State private var flagged: Bool = false
    @State private var tags: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            Section {
                Text("This session is marked Completed. You can optionally tag or flag it before grouping.")
                    .font(StyleGuide.Typography.bodyMedium)
                    .foregroundStyle(BillingHubTheme.Palette.textSecondary)

                Toggle("Flag for follow-up", isOn: $flagged)
                    .toggleStyle(.switch)
                    .help("Mark this session as needing special attention or further review")
                TextField("Tags (comma-separated)", text: $tags, prompt: Text("urgent, home-visit"))
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
            }

            Button("Move to Grouped") {
                Task {
                    viewModel.moveSessionToGrouped(sessionID: card.id)
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .help("Move this completed session to the grouping stage")
            .accessibilityLabel("Move to grouped")
            .accessibilityHint("Prepares the session for inclusion in a draft invoice.")

            Button("Clear Flags") {
                flagged = false
                tags = ""
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help("Reset tags and follow-up flags")
            .accessibilityLabel("Clear flags and tags")
        }
    }
}
