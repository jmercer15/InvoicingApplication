import SwiftUI
import SharedUI

struct GroupedPanel: View {
    let card: KanbanCardData
    let viewModel: BillingHubViewModel
    @State private var groupName: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            Section("Group Details") {
                TextField("Group Name", text: $groupName, prompt: Text("e.g., Morning Sessions"))
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
            }

            Button("Create Draft Invoice") {
                if case .session(let data) = card {
                    Task {
                        if let groupID = data.groupID {
                            await viewModel.createDraftInvoice(fromGroupID: groupID)
                        } else {
                            await viewModel.createInvoiceFromSessions([data.sessionId])
                        }
                        dismiss()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .help("Generate a new draft invoice from this group of sessions")
            .accessibilityLabel("Create draft invoice")
            .accessibilityHint("Creates an editable draft invoice containing all sessions in this group.")

            Button("Ungroup") {
                viewModel.dropIntoGroupedColumn(sessionID: card.id)
                dismiss()
            }
            .buttonStyle(.bordered)
            .tint(ColorSystem.Status.error)
            .help("Remove this session from the group while keeping it in Grouped")
            .accessibilityLabel("Ungroup session in grouped column")
        }
    }
}
