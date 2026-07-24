# Adversarial Review — Multi-Window & SwiftData Compliance

## Challenge Summary

**Overall risk assessment**: LOW

## Challenges

### [Low] Challenge 1: SwiftData Concurrency & PersistentModel Leakage
- **Assumption challenged**: That making `BulkClaimWorkspaceOperations` a `ModelActor` is sufficient for thread safety.
- **Attack scenario**: If the actor returns raw `BulkClaimLine` or `BulkClaimBatch` (subclasses of `PersistentModel`) to the caller on the main thread, the main thread might access or mutate their properties, triggering a concurrency violation crash since those objects belong to the actor's private context.
- **Blast radius**: Concurrency violation crash (SwiftData thread-safety assertions).
- **Mitigation**: The implementation is robust because `BulkClaimWorkspaceOperations` maps all models to and from value-type snapshots (`BulkClaimLineSnapshot` and `BulkClaimValidationSummary`) before transferring them across actor boundaries. No raw `PersistentModel` instances are returned by the actor's async methods.

### [Low] Challenge 2: FocusedValue Focus-Loss State Sync
- **Assumption challenged**: Standalone utility windows will always have an active workspace to track.
- **Attack scenario**: When a user closes all workspace windows but keeps the standalone Inspector window open, the focused scene value key `activeWorkspaceSceneSession` becomes `nil`.
- **Blast radius**: The utility window could crash or display incorrect, stale state.
- **Mitigation**: The code resolves this via `activeSession ?? fallbackSession`, utilizing a local `fallbackSession` to display safe loading or placeholder screens when no workspace is focused.

### [Low] Challenge 3: Scene Storage State Restoration Conflicts
- **Assumption challenged**: SwiftUI's `@SceneStorage` uniquely identifies each workspace window session.
- **Attack scenario**: If multiple workspace windows are restored from a terminated state, their `@SceneStorage` keys might overlap or restore identical states.
- **Blast radius**: Multiple windows opening with identical selections.
- **Mitigation**: SwiftUI automatically partitions `@SceneStorage` namespaces per window session identifier under the hood, ensuring macOS manages window-specific states independently.
