# BRIEFING — 2026-06-22T04:24:00Z

## Mission
Perform read-only investigation of InvoicingApplication codebase to prepare for multi-window compliance and SwiftData thread safety refactoring.

## 🔒 My Identity
- Archetype: Explorer
- Roles: Investigator, Reporter
- Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_explorer_investigation
- Original parent: 07f18ffe-f64a-4d10-8bcc-7566387a5d41
- Milestone: Multi-window and SwiftData investigation

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- CODE_ONLY network mode: no external web access, no HTTP client calls
- Must follow Handoff Protocol and produce analysis.md and handoff.md in working directory
- Communicate results via send_message to original parent ID

## Current Parent
- Conversation ID: 07f18ffe-f64a-4d10-8bcc-7566387a5d41
- Updated: 2026-06-22T04:24:00Z

## Investigation State
- **Explored paths**:
  - `InvoicingApplication/InvoicingApplicationApp.swift`
  - `Packages/AppShell/Sources/AppShell/App/Scenes/InvoicingApplicationApp.swift`
  - `Packages/AppShell/Sources/AppShell/App/Scenes/Workspace/WorkspaceWindowRoot.swift`
  - `Packages/AppShell/Sources/AppShell/App/Scenes/Workspace/ContentView.swift`
  - `Packages/AppShell/Sources/AppShell/App/Scenes/Tools/ToolWindowSceneRoots.swift`
  - `Packages/AppShell/Sources/AppShell/App/Composition/ToolWindowPresenceRegistry.swift`
  - `Packages/AppShell/Sources/AppShell/App/Composition/AppSceneSessions.swift`
  - `Packages/AppShell/Sources/AppShell/App/Composition/ProductionRuntimeAssembly.swift`
  - `Packages/Data/Sources/Data/Persistence/AppDatabase.swift`
  - `Packages/Data/Sources/Data/Persistence/ModelContainerFactory.swift`
  - `Packages/Data/Sources/Data/Actors/BulkClaimWorkspaceOperations.swift`
  - `Packages/Feature.Clients/Sources/Feature_Clients/Models/RelationshipsProjectionActor.swift`
  - `InvoicingApplicationTests/AppSessionTests.swift`
  - `Packages/AppShell/Tests/AppShellTests/` (all tests)
- **Key findings**:
  - All windows share a single `ModelContainer` instance through a globally shared `AppRuntime` loaded at boot.
  - Workspace windows isolate selection and navigation states inside a window-specific `WorkspaceSceneSession`.
  - Standalone utility windows (Inspector, Activity) also spawn isolated sessions, leading to broken selection syncing and command routing.
  - Concurrency violation: `BulkClaimWorkspaceOperations` (actor) instantiates local `ModelContext` and accesses it across async suspension points without `@ModelActor` protection.
- **Unexplored areas**:
  - No unexplored areas. Complete codebase investigation finished.

## Key Decisions Made
- Confirmed that `UtilityWindow` is a custom Scene type provided by SwiftUI (part of target SDK).
- Pinpointed specific concurrency vulnerability in `BulkClaimWorkspaceOperations`.
- Identified specific design gap where standalone utility windows cannot sync selection or navigation context with active workspace windows.

## Artifact Index
- ORIGINAL_REQUEST.md — Original request details.
- BRIEFING.md — My persistent working memory.
- progress.md — Liveness heartbeat.
- analysis.md — Detailed structured analysis report of findings.
- handoff.md — Handoff report following protocol.
