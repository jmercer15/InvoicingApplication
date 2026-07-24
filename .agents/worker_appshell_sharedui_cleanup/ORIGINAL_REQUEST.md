## 2026-06-15T09:45:11+10:00

You are the AppShell and SharedUI Styling Cleanup Worker. Your working directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_appshell_sharedui_cleanup/`.
Your mission is to clean up non-native custom styling (such as custom selection highlights, manual hover states, custom shadows, and non-native button layouts) in `AppShell` and `SharedUI` packages, restoring macOS native UI behaviors.

Please perform the following changes:

In `SharedUI` package:
1. In `Packages/SharedUI/Sources/SharedUI/Components/SidebarItemRow.swift`:
   - Remove the conditional selection override for foreground style (lines 18 and 23). Re-style the icon with `.foregroundStyle(.secondary)` and the title with `.foregroundStyle(.primary)`. This allows native macOS sidebar list selection to automatically handle foreground color inversion on selected rows.
2. In `Packages/SharedUI/Sources/SharedUI/Components/NavigationListRow.swift`:
   - Remove `.scaleEffect(isHighlighted ? 1.2 : 1.0)` (line 72).
   - Simplify titleColor in line 61: replace the conditional override `isHighlighted ? Color.accentColor : StyleGuide.Colors.text` with a flat `StyleGuide.Colors.text` or `Color.primary` without conditional check.
3. In `Packages/SharedUI/Sources/SharedUI/ViewModifiers.swift`:
   - In `EnhancedGroupBoxStyle` (line 197), remove the custom shadow modifier `.shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1.5)`.
4. In `Packages/SharedUI/Sources/SharedUI/Components/InfoChip.swift`:
   - Remove the `.shadow(...)` modifier from the background (lines 43-48).
5. In `Packages/SharedUI/Sources/SharedUI/Components/AppBreadcrumbComponents.swift`:
   - In `AppBreadcrumbBackButton`: remove the custom `.shadow(...)` modifier (lines 32-37) and `.onHover` block (lines 43-47). Remove `isHovered` state. Set the overlay stroke border to a constant, standard style (e.g. `Color.accentColor.opacity(0.45)`).
   - In `AppBreadcrumbSegmentButton`: remove the `.onHover` modifier (lines 112-116) and `isHovered` state. Re-style background fill with flat `backgroundColor` and overlay stroke with constant `Color.primary.opacity(StyleGuide.Opacity.light)`.

In `AppShell` package:
6. In `Packages/AppShell/Sources/AppShell/App/Scenes/Startup/SessionPhaseRoot.swift`:
   - Replace the plain Button (lines 78-96) with a native prominent Button view:
     ```swift
     Button(action: {
         Task { await retry() }
     }) {
         Text("Retry")
     }
     .buttonStyle(.borderedProminent)
     ```
   - Remove the `isHovered` state.
7. In `Packages/AppShell/Sources/AppShell/App/Components/CloudKitSyncSidebarIndicator.swift`:
   - Remove the `isHovered` state and the `.onHover { hovering in isHovered = hovering }` modifier.
   - Remove the hover background fill `.fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)`.

Verification:
- Compile the modified codebase using `swift build` or `xcodebuild` targeting macOS.
- Run the automated tests (`swift test` or `./scripts/refactor-verify.sh`).
- Confirm that the project compiles cleanly with zero new errors and all tests pass.
- Write your handoff report in `handoff.md` detailing the exact modifications made, compile status, and test results.
- Send a message to the orchestrator reporting your results.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
