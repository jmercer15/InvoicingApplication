import os

@MainActor
struct AppBootstrapper {
    var makeRuntime: @MainActor (OSLog) async throws -> AppRuntime

    static let production = AppBootstrapper { log in
        try await ProductionRuntimeAssembly.makeAppRuntime(startupLog: log)
    }
}

/// Central scene identifiers for openWindow(id:) and scene declaration.
enum AppSceneID: String {
    case workspace
    case inspector
    case activity
}
