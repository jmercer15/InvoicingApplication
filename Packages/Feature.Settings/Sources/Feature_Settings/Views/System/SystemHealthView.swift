import SwiftUI
import SwiftData
import SharedUI
import EventKit
import Core
import DataInterfaces
#if os(macOS)
import AppKit
#endif

// MARK: - System Health View

struct SystemHealthView: View {
    @Environment(\.databaseHealthChecking) private var databaseHealthChecking
    @State private var healthChecks: [HealthCheck] = []
    @State private var isRunning = false
    
    @ScaledMetric(relativeTo: .body) private var paddingXXLarge = StyleGuide.Dimensions.paddingXXLarge
    @ScaledMetric(relativeTo: .body) private var paddingXLarge = StyleGuide.Dimensions.paddingXLarge

    var body: some View {
        ScrollView {
            VStack(spacing: StyleGuide.Dimensions.paddingXXLarge) {
                VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
                    headerSection
                    actionButtonsSection
                }
                .standardSectionStyle()

                VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMediumLarge) {
                    resultsSection
                }
                .standardSectionStyle()
            }
            .padding(.vertical, paddingXXLarge)
            .padding(.horizontal, paddingXLarge)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        #if os(macOS)
        .scrollIndicators(.visible)
        #endif
        .onAppear { runHealthChecks() }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
            Text("System Health Check")
                .font(StyleGuide.Typography.hero)
            Text("Verify system configuration and data integrity")
                .foregroundStyle(StyleGuide.Colors.textSecondary)
        }
    }

    private var actionButtonsSection: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingLarge) {
            Button(action: runHealthChecks) {
                Label("Run Health Check", systemImage: "heart.fill")
            }
            .disabled(isRunning)
            .buttonStyle(.glassProminent)

            if isRunning {
                ProgressView("Running checks...")
            }
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
            Text("Health Check Results")
                .font(.headline)
            
            if healthChecks.isEmpty {
                Text("No health checks run yet")
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            } else {
                LazyVStack(spacing: FormSectionTokens.fieldStackSpacing) {
                    ForEach(healthChecks, id: \.id) { check in
                        healthCheckRow(check)
                    }
                }
            }
        }
    }
    
    private func healthCheckRow(_ check: HealthCheck) -> some View {
        VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
            HStack {
                Image(systemName: check.status.icon)
                    .foregroundColor(check.status.color)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(check.title).font(.headline)
                    Text(check.description).font(.caption).foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }
                Spacer()
                if let action = check.action {
                    Button(action) { onAction(action) }.buttonStyle(.glass).controlSize(.small)
                }
            }
            Text(check.details).font(.caption).foregroundColor(Color("TextSecondary", bundle: .sharedUI)).padding(.leading, StyleGuide.Dimensions.paddingXXLarge)
        }
        .standardCardStyle()
    }
    
    private func runHealthChecks() {
        isRunning = true
        healthChecks.removeAll()

        // 1. Database Connection check
        let dbCheck: HealthCheck
        do {
            if let checker = databaseHealthChecking {
                try checker.verifyConnection()
            }
            dbCheck = HealthCheck(
                title: "Database Connection",
                description: "Core Data stack",
                status: .success,
                details: "Successfully connected to local database and queried Business entities.",
                action: nil
            )
        } catch {
            dbCheck = HealthCheck(
                title: "Database Connection",
                description: "Core Data stack",
                status: databaseHealthChecking == nil ? .warning : .error,
                details: databaseHealthChecking == nil
                    ? "Database health checker is not configured for this window."
                    : "Failed to query database: \(error.localizedDescription)",
                action: nil
            )
        }

        // 2. Calendar Permissions check
        let calendarStatus = EKEventStore.authorizationStatus(for: .event)
        let calendarCheck: HealthCheck
        switch calendarStatus {
        case .authorized:
            calendarCheck = HealthCheck(
                title: "Calendar Permissions",
                description: "EventKit access",
                status: .success,
                details: "Calendar access is authorized.",
                action: nil
            )
        case .notDetermined:
            let actionName: String
            if #available(iOS 17.0, macOS 14.0, *) {
                actionName = "Request Full Access"
            } else {
                actionName = "Request Access"
            }
            calendarCheck = HealthCheck(
                title: "Calendar Permissions",
                description: "EventKit access",
                status: .warning,
                details: "Calendar access has not been determined.",
                action: actionName
            )
        case .denied:
            calendarCheck = HealthCheck(
                title: "Calendar Permissions",
                description: "EventKit access",
                status: .error,
                details: "Calendar access is denied.",
                action: "Open Settings"
            )
        case .restricted:
            calendarCheck = HealthCheck(
                title: "Calendar Permissions",
                description: "EventKit access",
                status: .error,
                details: "Calendar access is restricted.",
                action: "Open Settings"
            )
        #if compiler(>=5.9)
        case .fullAccess:
            calendarCheck = HealthCheck(
                title: "Calendar Permissions",
                description: "EventKit access",
                status: .success,
                details: "Calendar full access is authorized.",
                action: nil
            )
        case .writeOnly:
            calendarCheck = HealthCheck(
                title: "Calendar Permissions",
                description: "EventKit access",
                status: .warning,
                details: "Calendar access is write-only.",
                action: "Request Full Access"
            )
        #endif
        @unknown default:
            calendarCheck = HealthCheck(
                title: "Calendar Permissions",
                description: "EventKit access",
                status: .warning,
                details: "Unknown calendar authorization status.",
                action: nil
            )
        }

        // 3. File System check
        let fsCheck: HealthCheck
        do {
            let fileManager = FileManager.default
            if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let tempFileURL = documentsURL.appendingPathComponent("health_check_temp_\(UUID().uuidString).txt")
                let testContent = "System Health Check: \(Date())"
                try testContent.write(to: tempFileURL, atomically: true, encoding: .utf8)
                let readContent = try String(contentsOf: tempFileURL, encoding: .utf8)
                if readContent == testContent {
                    try fileManager.removeItem(at: tempFileURL)
                    fsCheck = HealthCheck(
                        title: "File System",
                        description: "Document directory",
                        status: .success,
                        details: "Read, write, and delete tests succeeded in the documents directory.",
                        action: nil
                    )
                } else {
                    fsCheck = HealthCheck(
                        title: "File System",
                        description: "Document directory",
                        status: .error,
                        details: "Data mismatch during read/write test.",
                        action: nil
                    )
                }
            } else {
                fsCheck = HealthCheck(
                    title: "File System",
                    description: "Document directory",
                    status: .error,
                    details: "Documents directory could not be located.",
                    action: nil
                )
            }
        } catch {
            fsCheck = HealthCheck(
                title: "File System",
                description: "Document directory",
                status: .error,
                details: "File system test failed: \(error.localizedDescription)",
                action: nil
            )
        }

        healthChecks = [dbCheck, calendarCheck, fsCheck]
        isRunning = false
    }
    
    private func onAction(_ action: String) {
        if action == "Request Access" || action == "Request Full Access" {
            requestCalendarAccessAndRefresh()
        } else if action == "Open Settings" {
            #if os(macOS)
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                NSWorkspace.shared.open(url)
            }
            #endif
        }
    }

    private func requestCalendarAccessAndRefresh() {
        let store = EKEventStore()
        if #available(iOS 17.0, macOS 14.0, *) {
            store.requestFullAccessToEvents { _, _ in
                Task { @MainActor in
                    runHealthChecks()
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct HealthCheck {
    let id = UUID()
    let title: String
    let description: String
    let status: HealthStatus
    let details: String
    let action: String?
}

enum HealthStatus {
    case success
    case warning
    case error
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}
