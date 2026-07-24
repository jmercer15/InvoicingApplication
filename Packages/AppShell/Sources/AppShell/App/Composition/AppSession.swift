import Foundation
import SwiftUI
import os

public struct AppStartupError: Identifiable, LocalizedError {
    public let id = UUID()
    public let underlyingError: any Error

    public var errorDescription: String? {
        "Failed to start InvoicingApplication."
    }

    public var recoverySuggestion: String? {
        underlyingError.localizedDescription
    }
}

@MainActor
@Observable
public final class AppSession {
    public enum Phase {
        case starting
        case ready(AppRuntime)
        case failed(AppStartupError)
    }

    private static let startupSignpostLog = OSLog(
        subsystem: "com.invoicingapplication.app",
        category: "startup"
    )

    private let bootstrapper: AppBootstrapper
    private(set) var phase: Phase = .starting
    private var isBootstrapping = false

    public convenience init() {
        self.init(bootstrapper: .production)
    }

    init(bootstrapper: AppBootstrapper) {
        self.bootstrapper = bootstrapper
    }

    public func bootstrap() async {
        guard !isBootstrapping else { return }
        if case .ready = phase { return }

        isBootstrapping = true
        phase = .starting
        defer { isBootstrapping = false }

        #if DEBUG
        let initializeSignpostID = OSSignpostID(log: Self.startupSignpostLog)
        os_signpost(
            .begin,
            log: Self.startupSignpostLog,
            name: "AppInitialize",
            signpostID: initializeSignpostID,
            "%{public}s",
            "launch"
        )
        #endif

        do {
            let runtime = try await bootstrapper.makeRuntime(Self.startupSignpostLog)

            withAnimation {
                phase = .ready(runtime)
            }

            #if DEBUG
            os_signpost(
                .end,
                log: Self.startupSignpostLog,
                name: "AppInitialize",
                signpostID: initializeSignpostID,
                "%{public}s",
                "complete"
            )
            #endif
        } catch {
            phase = .failed(AppStartupError(underlyingError: error))
            #if DEBUG
            os_signpost(
                .end,
                log: Self.startupSignpostLog,
                name: "AppInitialize",
                signpostID: initializeSignpostID,
                "%{public}s",
                "failed"
            )
            #endif
        }
    }
}
