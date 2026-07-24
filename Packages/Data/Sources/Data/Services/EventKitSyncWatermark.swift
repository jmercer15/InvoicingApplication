import Foundation

public enum EventKitSyncWatermark {
    public enum RemoteFreshnessState: Equatable {
        case changed
        case unchanged
        case unknown
    }

    public static let defaultToleranceSeconds: TimeInterval = 2

    public static func isTimestampNewer(
        _ candidate: Date?,
        than baseline: Date?,
        toleranceSeconds: TimeInterval = defaultToleranceSeconds
    ) -> Bool {
        guard let candidate else { return false }
        guard let baseline else { return true }
        return candidate.timeIntervalSince(baseline) > toleranceSeconds
    }

    public static func didRemoteChange(
        remoteLastModified: Date?,
        watermark: Date?,
        previousFingerprint: String?,
        currentFingerprint: String,
        toleranceSeconds: TimeInterval = defaultToleranceSeconds
    ) -> Bool {
        classifyRemoteFreshness(
            remoteLastModified: remoteLastModified,
            watermark: watermark,
            previousObservedRemoteModified: nil,
            previousFingerprint: previousFingerprint,
            currentFingerprint: currentFingerprint,
            toleranceSeconds: toleranceSeconds
        ) == .changed
    }

    public static func classifyRemoteFreshness(
        remoteLastModified: Date?,
        watermark: Date?,
        previousObservedRemoteModified: Date?,
        previousFingerprint: String?,
        currentFingerprint: String,
        toleranceSeconds: TimeInterval = defaultToleranceSeconds
    ) -> RemoteFreshnessState {
        if let remoteLastModified {
            return isTimestampNewer(
                remoteLastModified,
                than: watermark,
                toleranceSeconds: toleranceSeconds
            ) ? .changed : .unchanged
        }

        if let previousFingerprint, previousFingerprint != currentFingerprint {
            return .changed
        }

        if let previousObservedRemoteModified,
           isTimestampNewer(
               previousObservedRemoteModified,
               than: watermark,
               toleranceSeconds: toleranceSeconds
           ) {
            return .unknown
        }

        return .unknown
    }
}
