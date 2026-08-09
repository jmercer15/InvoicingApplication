import Data
import SwiftUI
import SharedUI
import Observation

/// A compact, persistent indicator of CloudKit sync status designed to be placed
/// at the bottom of a sidebar.
public struct CloudKitSyncSidebarIndicator: View {
    @Bindable public var monitor: CloudKitSyncMonitor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var presentedSyncError: CloudKitSyncError?

    private var isSyncErrorPresented: Binding<Bool> {
        Binding(
            get: { presentedSyncError != nil },
            set: { if !$0 { presentedSyncError = nil } }
        )
    }

    public init(monitor: CloudKitSyncMonitor) {
        self.monitor = monitor
    }

    public var body: some View {
        Group {
            if monitor.syncState.isError {
                Button {
                    if let error = monitor.lastError {
                        presentedSyncError = error
                    }
                } label: {
                    indicatorContent
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityText)
                .accessibilityHint("Shows sync error details and retry options.")
            } else {
                indicatorContent
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(accessibilityText)
            }
        }
        .confirmationDialog(
            "CloudKit Sync Issue",
            isPresented: isSyncErrorPresented,
            titleVisibility: .visible,
            presenting: presentedSyncError,
            actions: { _ in
                Button("Retry") {
                    monitor.refreshAccountStatus()
                }
                Button("Dismiss", role: .cancel) {
                    monitor.dismissError()
                }
            },
            message: { error in
                Text(error.message)
            }
        )
    }

    private var indicatorContent: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            icon

            VStack(alignment: .leading, spacing: DetailToolbarTokens.titleSubtitleSpacing) {
                Text(statusText)
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(StyleGuide.Colors.text)

                if let subtext = secondaryText {
                    Text(subtext)
                        .font(.caption2)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var icon: some View {
        if monitor.syncState.isActive {
            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                .symbolEffect(.rotate, isActive: !reduceMotion)
                .foregroundStyle(ColorSystem.Status.info)
                .imageScale(.medium)
        } else if monitor.syncState.isError {
            Image(systemName: "exclamationmark.icloud.fill")
                .foregroundStyle(ColorSystem.Status.error)
                .imageScale(.medium)
        } else if monitor.accountStatus.isAvailable {
            Image(systemName: "checkmark.icloud")
                .foregroundStyle(StyleGuide.Colors.textSecondary)
                .imageScale(.medium)
        } else {
            Image(systemName: "icloud.slash")
                .foregroundStyle(StyleGuide.Colors.textSecondary)
                .imageScale(.medium)
        }
    }

    private var statusText: String {
        if monitor.syncState.isActive {
            return "Syncing iCloud…"
        } else if case .persistentError = monitor.syncState {
            return "Sync Issue"
        } else if case .error = monitor.syncState {
            return "Sync Error"
        } else if !monitor.accountStatus.isAvailable {
            return monitor.accountStatus.displayText
        } else {
            return "iCloud Synchronized"
        }
    }

    private var secondaryText: String? {
        if monitor.syncState.isActive {
            return nil
        } else if case .error(let msg) = monitor.syncState {
            return msg
        } else if case .persistentError(let msg) = monitor.syncState {
            return msg
        } else if let date = monitor.lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.dateTimeStyle = .named
            return "Updated \(formatter.localizedString(for: date, relativeTo: Date()))"
        }
        return nil
    }

    private var accessibilityText: String {
        if let secondary = secondaryText {
            return "\(statusText), \(secondary)"
        }
        return statusText
    }
}
