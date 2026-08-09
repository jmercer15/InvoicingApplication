import SwiftUI
import SharedUI

struct CompletedPanel: View {
    let card: KanbanCardData
    let viewModel: BillingHubViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isMoving = false

    var body: some View {
        Group {
            Section {
                Text("This session is marked Completed. Move it to Grouped to prepare it for a draft invoice.")
                    .font(StyleGuide.Typography.bodyMedium)
                    .foregroundStyle(BillingHubTheme.Palette.textSecondary)
            }

            Button {
                guard !isMoving else { return }
                isMoving = true
                Task {
                    let result = await viewModel.moveSession(card.id, to: .grouped)
                    isMoving = false
                    if result?.isSuccess == true {
                        dismiss()
                    }
                }
            } label: {
                if isMoving {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Move to Grouped", systemImage: "rectangle.stack.badge.plus")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isMoving)
            .help("Move this completed session to the grouping stage")
            .accessibilityLabel("Move to grouped")
            .accessibilityHint("Prepares the session for inclusion in a draft invoice.")
        }
    }
}
