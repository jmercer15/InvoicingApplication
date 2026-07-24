import CloudKit
import Data
import SwiftUI
import SharedUI
import Observation

/// A polished Settings section displaying CloudKit sync state, data freshness,
/// and iCloud account status with actionable controls.
///
/// Drop it anywhere in the Settings UI:
/// ```swift
/// CloudKitSyncStatusView(monitor: syncMonitor)
/// ```
public struct CloudKitSyncStatusView: View {
    @Bindable public var monitor: CloudKitSyncMonitor

    public init(monitor: CloudKitSyncMonitor) {
        self.monitor = monitor
    }

    public var body: some View {
        Form {
            Section {
                // Primary status row
                syncStatusRow

                // Data freshness row
                if let lastSync = monitor.lastSyncDate {
                    freshnessRow(lastSync: lastSync)
                }

                // Account info row
                accountRow

                // Error detail row (persistent, dismissible)
                if let error = monitor.lastError, !monitor.isErrorDismissed {
                    errorRow(error: error)
                }
            } header: {
                HStack {
                    Text("iCloud")
                    Spacer()
                    if monitor.accountStatus.isAvailable {
                        Button {
                            monitor.refreshAccountStatus()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } // End Form
        .formStyle(.grouped)
        .frame(maxWidth: 700)
    }

    // MARK: - Subviews

    private var syncStatusRow: some View {
        HStack(spacing: 10) {
            syncIcon
                .frame(width: StyleGuide.Dimensions.entityListIconWidth, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text("iCloud Sync")
                    .font(.body)
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if monitor.syncState.isActive {
                Text("Syncing")
                    .font(.caption)
                    .foregroundStyle(ColorSystem.Status.info)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.blue.opacity(0.1), in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var syncIcon: some View {
        if monitor.syncState.isActive {
            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                .symbolEffect(.rotate, isActive: true)
                .foregroundStyle(ColorSystem.Status.info)
                .imageScale(.large)
        } else if monitor.syncState.isError {
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(ColorSystem.Status.error)
                .imageScale(.large)
        } else if monitor.accountStatus.isAvailable {
            Image(systemName: "checkmark.icloud.fill")
                .foregroundStyle(ColorSystem.Status.success)
                .imageScale(.large)
        } else {
            Image(systemName: "icloud.slash")
                .foregroundStyle(.secondary)
                .imageScale(.large)
        }
    }

    private func freshnessRow(lastSync: Date) -> some View {
        HStack {
            Label("Last synced", systemImage: "clock")
                .foregroundStyle(.secondary)
                .font(.caption)
            Spacer()
            Text(lastSync, style: .relative)
                .foregroundStyle(freshnessColor(for: lastSync))
                .font(.caption)
        }
    }

    private var accountRow: some View {
        HStack {
            Label("Account", systemImage: "person.icloud")
                .foregroundStyle(.secondary)
                .font(.caption)
            Spacer()
            Text(monitor.accountStatus.displayText)
                .font(.caption)
                .foregroundStyle(accountColor)
        }
    }

    private func errorRow(error: CloudKitSyncError) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ColorSystem.Status.warning)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sync Error (\(error.eventType))")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(error.message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                    Text(error.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button {
                    monitor.dismissError()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(ColorSystem.Status.warning.opacity(0.05), in: RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact))
    }

    // MARK: - Helpers

    private var statusLine: String {
        if case .persistentError = monitor.syncState {
            return "Repeated sync failures detected"
        }
        if case .error = monitor.syncState {
            return monitor.syncState.displayText
        }
        return monitor.accountStatus.displayText
    }

    private func freshnessColor(for date: Date) -> Color {
        let elapsed = Date().timeIntervalSince(date)
        switch elapsed {
        case ..<300: return .green        // < 5 minutes
        case ..<3600: return .orange      // < 1 hour
        default: return .red              // > 1 hour
        }
    }

    private var accountColor: Color {
        switch monitor.accountStatus {
        case .available: return .green
        case .noAccount: return .red
        case .restricted, .temporarilyUnavailable: return .orange
        default: return .secondary
        }
    }
}
