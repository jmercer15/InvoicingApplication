import SwiftUI
import SwiftData
import Data
import Core
import SharedUI

// MARK: - System Health View

struct SystemHealthView: View {
    @Environment(\.modelContext) private var viewContext
    @State private var healthChecks: [HealthCheck] = []
    @State private var isRunning = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    headerSection
                    actionButtonsSection
                }
                .padding(20)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 12) {
                    resultsSection
                }
                .padding(20)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))
            }
            .padding(.vertical, StyleGuide.Dimensions.paddingXXLarge)
            .padding(.horizontal, StyleGuide.Dimensions.paddingXLarge)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        #if os(macOS)
        .scrollIndicators(.visible)
        #endif
        .onAppear { runHealthChecks() }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("System Health Check")
                .font(.title.bold())
            Text("Verify system configuration and data integrity")
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
        }
    }

    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Health Check Results")
                .font(.headline)
            
            if healthChecks.isEmpty {
                Text("No health checks run yet")
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(healthChecks, id: \.id) { check in
                            healthCheckRow(check)
                        }
                    }
                }
            }
        }
    }
    
    private func healthCheckRow(_ check: HealthCheck) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
                    Button(action) { onAction(action, check) }.buttonStyle(.glass).controlSize(.small)
                }
            }
            Text(check.details).font(.caption).foregroundColor(Color("TextSecondary", bundle: .sharedUI)).padding(.leading, 32)
        }
        .padding()
        .background(Color.accentColor.opacity(StyleGuide.Opacity.faint))
        .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
    }
    
    private func runHealthChecks() {
        isRunning = true
        healthChecks.removeAll()
        
        // Simulate health checks
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            healthChecks = [
                HealthCheck(
                    title: "Database Connection",
                    description: "Core Data stack",
                    status: .success,
                    details: "Successfully connected to local database",
                    action: nil
                ),
                HealthCheck(
                    title: "Calendar Permissions",
                    description: "EventKit access",
                    status: .warning,
                    details: "Calendar access granted but sync is disabled",
                    action: "Enable Sync"
                ),
                HealthCheck(
                    title: "File System",
                    description: "Document directory",
                    status: .success,
                    details: "All required directories accessible",
                    action: nil
                )
            ]
            isRunning = false
        }
    }
    
    private func onAction(_ action: String, _ check: HealthCheck) {
        // Handle health check actions
        print("Health check action: \(action) for \(check.title)")
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
