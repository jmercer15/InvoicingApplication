import SwiftUI
import SharedUI

struct GroupedPanel: View {
    let card: KanbanCardData
    let viewModel: BillingHubViewModel
    let openInvoice: (UUID) -> Void
    @State private var creationFeedback: CreationFeedback?
    @State private var createdInvoiceID: UUID?
    @State private var isRemovingFromGroup = false
    @Environment(\.dismiss) var dismiss

    /// Shared with bulk Create Draft so panel + board cannot race two creates.
    private var isCreating: Bool { viewModel.bulkProgress.isCreatingDrafts }

    private var groupMembers: [KanbanCardData] {
        guard case .session(let data) = card else { return [card] }
        guard let groupID = data.groupID,
              let group = viewModel.boardProjection.groupedSessions.first(where: { $0.groupID == groupID })
        else {
            return [card]
        }
        return group.sessions
    }

    private var memberCount: Int { groupMembers.count }

    /// A partial create immediately changes the board: invoiced sessions leave Grouped and the
    /// skipped session(s) remain there. Do not keep offering actions against this panel's stale
    /// group snapshot; send the user back to the live lane instead.
    private var hasPartialDraftCreation: Bool { createdInvoiceID != nil }

    private struct CreationFeedback: Equatable {
        enum Tone: Equatable { case warning, error }
        let message: String
        let tone: Tone
    }

    var body: some View {
        Group {
            if hasPartialDraftCreation {
                Section {
                    Text("Review the created draft, then resolve the skipped session in Grouped before creating another invoice.")
                        .font(StyleGuide.Typography.bodyMedium)
                        .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text("Next Step")
                }
            } else {
                Section {
                    Text(memberSummary)
                        .font(StyleGuide.Typography.bodyMedium)
                        .foregroundStyle(BillingHubTheme.Palette.textSecondary)

                    ForEach(groupMembers.prefix(6)) { member in
                        Label(memberTitle(for: member), systemImage: "calendar")
                            .font(StyleGuide.Typography.itemSubtitle)
                            .foregroundStyle(BillingHubTheme.Palette.textPrimary)
                            .lineLimit(1)
                    }
                    if memberCount > 6 {
                        Text("+\(memberCount - 6) more")
                            .font(StyleGuide.Typography.itemSubtitle)
                            .foregroundStyle(BillingHubTheme.Palette.textMuted)
                    }
                } header: {
                    Text(memberCount == 1 ? "Session" : "Group (\(memberCount) sessions)")
                }
            }

            if let creationFeedback {
                Section {
                    Label(
                        creationFeedback.message,
                        systemImage: creationFeedback.tone == .warning
                            ? "exclamationmark.triangle.fill"
                            : "xmark.circle.fill"
                    )
                        .font(StyleGuide.Typography.bodyMedium)
                        .foregroundStyle(
                            creationFeedback.tone == .warning
                                ? ColorSystem.Status.warning
                                : ColorSystem.Status.error
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                }
            }

            if let createdInvoiceID {
                Button {
                    openInvoice(createdInvoiceID)
                    dismiss()
                } label: {
                    Label("Open Created Draft", systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isCreating || isRemovingFromGroup)
                .help("Review the draft that was created from the valid sessions")
            }

            if hasPartialDraftCreation {
                Button {
                    dismiss()
                } label: {
                    Label("Return to Grouped", systemImage: "rectangle.stack")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isCreating || isRemovingFromGroup)
                .help("Return to the live Grouped lane and resolve skipped sessions")
            } else {
                Button {
                    createDraftInvoice()
                } label: {
                    if isCreating {
                        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                            ProgressView()
                                .controlSize(.small)
                            Text(viewModel.bulkProgress.bulkActionProgressMessage ?? "Creating draft…")
                                .lineLimit(1)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Label(
                            memberCount > 1 ? "Create Draft Invoice for Group" : "Create Draft Invoice",
                            systemImage: "doc.badge.plus"
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isCreating || isRemovingFromGroup)
                .help(
                    memberCount > 1
                        ? "Generate one draft invoice covering all \(memberCount) sessions in this group"
                        : "Generate a new draft invoice from this session"
                )
                .accessibilityLabel("Create draft invoice")
                .accessibilityHint("Creates a draft invoice from this group's sessions. Sessions that fail validation are reported instead of silently dropped.")

                Button {
                    removeFromGroup()
                } label: {
                    Label("Remove From Group", systemImage: "rectangle.stack.badge.minus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isCreating || isRemovingFromGroup || memberCount <= 1)
                .help("Remove only this session from the group. Other sessions stay grouped.")
                .accessibilityLabel("Remove session from group")
                .opacity(memberCount <= 1 ? 0.45 : 1)
            }
        }
    }

    private var memberSummary: String {
        if memberCount <= 1 {
            return "This session will be invoiced on its own."
        }
        return "Create Draft builds one invoice that includes every session listed below."
    }

    private func memberTitle(for member: KanbanCardData) -> String {
        switch member {
        case .session(let data):
            return data.title
        case .invoice(let data):
            return data.title
        }
    }

    private func createDraftInvoice() {
        guard case .session(let data) = card, !isCreating else { return }
        creationFeedback = nil
        Task {
            let outcome: DraftInvoiceCreationOutcome?
            if let groupID = data.groupID {
                outcome = await viewModel.createDraftInvoice(fromGroupID: groupID)
            } else {
                outcome = await viewModel.createInvoiceFromSessions([data.sessionId])
            }

            guard let outcome, outcome.didCreateInvoice, let invoiceID = outcome.invoiceID else {
                // Total failure: keep panel open so reason is visible inline.
                creationFeedback = CreationFeedback(
                    message: outcome.map { failureSummary(for: $0) }
                        ?? "Draft invoice could not be created.",
                    tone: .error
                )
                return
            }

            // Partial success: keep panel open with error; open invoice only on full success.
            if !outcome.failedSessions.isEmpty {
                createdInvoiceID = invoiceID
                creationFeedback = CreationFeedback(
                    message: partialSuccessSummary(for: outcome),
                    tone: .warning
                )
                return
            }

            openInvoice(invoiceID)
            dismiss()
        }
    }

    private func removeFromGroup() {
        guard case .session(let data) = card, !isRemovingFromGroup, !isCreating else { return }
        isRemovingFromGroup = true
        Task {
            let removed = await viewModel.ungroupSession(id: data.sessionId)
            isRemovingFromGroup = false
            if removed {
                dismiss()
            }
            // Soft-lock confirm / failure: keep panel open; feedback already set on VM.
        }
    }

    private func failureSummary(for outcome: DraftInvoiceCreationOutcome) -> String {
        guard !outcome.failedSessions.isEmpty else {
            return "Draft invoice could not be created."
        }
        let reasons = outcome.failedSessions.map { "\($0.sessionTitle): \($0.reason)" }.joined(separator: "\n")
        return "Draft invoice could not be created.\n\(reasons)"
    }

    private func partialSuccessSummary(for outcome: DraftInvoiceCreationOutcome) -> String {
        let reasons = outcome.failedSessions.map { "\($0.sessionTitle): \($0.reason)" }.joined(separator: "\n")
        return "Draft created, but \(outcome.failedSessions.count) session\(outcome.failedSessions.count == 1 ? "" : "s") skipped.\n\(reasons)"
    }
}
