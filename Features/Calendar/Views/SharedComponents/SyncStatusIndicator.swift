import SwiftUI

struct SyncStatusIndicator: View {
    @ObservedObject var eventKitService: EventKitSyncService
    
    var body: some View {
        HStack(spacing: 4) {
            // Sync status icon
            Image(systemName: eventKitService.syncStatus.icon)
                .foregroundColor(eventKitService.syncStatus.color)
                .font(.system(size: 12))
            
            // Sync status text (only show if not idle)
            if eventKitService.syncStatus != .idle {
                Text(eventKitService.syncStatus.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Last sync time (if available)
            if let lastSync = eventKitService.lastSyncDate {
                Text("Last: \(lastSync, style: .time)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .rect(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(eventKitService.syncStatus.color.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    SyncStatusIndicator(eventKitService: EventKitSyncService.shared)
        .preferredColorScheme(.dark)
} 