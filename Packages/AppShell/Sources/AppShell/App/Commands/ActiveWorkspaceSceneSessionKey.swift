import SwiftUI

struct ActiveWorkspaceSceneSessionKey: FocusedValueKey {
    typealias Value = WorkspaceSceneSession
}

extension FocusedValues {
    var activeWorkspaceSceneSession: WorkspaceSceneSession? {
        get { self[ActiveWorkspaceSceneSessionKey.self] }
        set { self[ActiveWorkspaceSceneSessionKey.self] = newValue }
    }
}
