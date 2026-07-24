# Implementation Specification: InvoicingApplication Multi-Window & SwiftData Compliance

## 1. SwiftData Thread Safety: `BulkClaimWorkspaceOperations` Concurrency Refactor
To correct the thread safety violation where a standard actor accesses local `ModelContext` instances across `await` suspension points:
1. Refactor `BulkClaimWorkspaceOperations` (in `Packages/Data/Sources/Data/Actors/BulkClaimWorkspaceOperations.swift`) to conform to the `ModelActor` protocol:
   ```swift
   import Foundation
   import Core
   import SwiftData

   actor BulkClaimWorkspaceOperations: ModelActor {
       nonisolated public let modelContainer: ModelContainer
       nonisolated public let modelExecutor: any ModelExecutor
       private let bulkClaimBuilderActor: BulkClaimBuilderActor

       init(bulkClaimBuilderActor: BulkClaimBuilderActor, modelContainer: ModelContainer) {
           self.bulkClaimBuilderActor = bulkClaimBuilderActor
           self.modelContainer = modelContainer
           let context = ModelContext(modelContainer)
           self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
       }
       ...
   }
   ```
2. Replace local context initialization `let modelContext = ModelContext(modelContainer)` with the actor's native serial context `self.modelContext` in all functions of `BulkClaimWorkspaceOperations`.
3. In `applyClaimReconciliation(...)`, update:
   `let service = ClaimReconciliationService(modelContext: ModelContext(modelContainer))`
   to:
   `let service = ClaimReconciliationService(modelContext: self.modelContext)`

---

## 2. Multi-Window Workspace Synchronization & Focused Scene Values
To address the sync gap between utility windows (Inspector, Activity) and the active workspace without bleeding state:
1. Create a new file `Packages/AppShell/Sources/AppShell/App/Commands/ActiveWorkspaceSceneSessionKey.swift` defining a focused scene value key for `WorkspaceSceneSession`:
   ```swift
   import SwiftUI

   struct ActiveWorkspaceSceneSessionKey: FocusedValueKey {
       typealias Value = WorkspaceSceneSession
   }

   extension FocusedValues {
       public var activeWorkspaceSceneSession: WorkspaceSceneSession? {
           get { self[ActiveWorkspaceSceneSessionKey.self] }
           set { self[ActiveWorkspaceSceneSessionKey.self] = newValue }
       }
   }
   ```
2. Publish `sceneSession` as a focused scene value in `WorkspaceWindowRoot` (`Packages/AppShell/Sources/AppShell/App/Scenes/Workspace/WorkspaceWindowRoot.swift`):
   Apply `.focusedSceneValue(\.activeWorkspaceSceneSession, sceneSession)` on the main view hierarchy (e.g. at line 24/25 under `.withAppDependencies(dependencies)`).
3. Update `InspectorSceneRoot` and `ActivitySceneRoot` in `Packages/AppShell/Sources/AppShell/App/Scenes/Tools/ToolWindowSceneRoots.swift`:
   - Declare `@FocusedValue(\.activeWorkspaceSceneSession) private var activeSession`.
   - Rename `@State private var sceneSession` to `@State private var fallbackSession`.
   - In `body`, resolve the session using `let session = activeSession ?? fallbackSession`.
   - In `task` blocks, guard and initialize `fallbackSession` instead of `sceneSession`.
   - Pass `session` (instead of `sceneSession`) to child views like `InspectorPlaceholderView` and `ActivityPlaceholderView`.

---

## 3. Verification & Testing
1. Implement a unit test in `Packages/AppShell/Tests/AppShellTests/WorkspaceCompositionTests.swift` that verifies the `activeWorkspaceSceneSession` FocusedValue key behaves correctly.
2. Build and run all package tests:
   ```bash
   for pkg in Packages/*; do
       if [ -d "$pkg/Tests" ]; then
           swift test --package-path "$pkg"
       fi
   done
   ```
3. Build and run app target tests:
   ```bash
   xcodebuild test -project InvoicingApplication.xcodeproj -scheme InvoicingApplication -destination 'platform=macOS'
   ```
