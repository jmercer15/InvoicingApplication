## 2026-06-15T09:39:51Z

You are the BillingHub and Calendar Styling Cleanup Worker. Your working directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_billinghub_calendar_cleanup/`.
Your mission is to clean up non-native custom styling (such as custom shadows, hover-based shadows/border/fill shifts, and custom badges/row hover animations) in `Feature.BillingHub` and `Feature.Calendar` packages, restoring macOS native UI behaviors.

Please perform the following changes:

In `Feature.Calendar` package:
1. In `Packages/Feature.Calendar/Sources/Feature_Calendar/Views/MonthView/MonthView.swift`:
   - Remove the `.shadow(...)` modifier from `monthGrid()` (lines 22-27).
2. In `Packages/Feature.Calendar/Sources/Feature_Calendar/Views/WeekView/WeekView.swift`:
   - Remove the `.shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)` modifier from `weekGrid()` (line 27).
3. In `Packages/Feature.Calendar/Sources/Feature_Calendar/Views/MonthView/MonthDayCellView.swift`:
   - In the `.background` circle for `isToday` (line 165), remove the `.shadow(...)` modifier from the circle.
4. In `Packages/Feature.Calendar/Sources/Feature_Calendar/Views/WeekView/WeekHeaderComponents.swift`:
   - In the `.background` circle for `isToday` (line 101), remove the `.shadow(...)` modifier from the circle.

In `Feature.BillingHub` package:
5. In `Packages/Feature.BillingHub/Sources/Feature_BillingHub/Views/BillingHubBoardSectionViews.swift`:
   - In the `background` property (lines 155-163), remove `isHovered` state checks. Use a constant background fill (`BillingHubTheme.Surfaces.subcolumnBase.opacity(0.92)`) and a constant stroke color (`color.opacity(0.20)`). Remove the `.shadow(...)` modifier completely or make it a subtle, non-changing constant shadow.
   - In the `laneBackground` property (lines 235-243), remove the `.shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)` modifier.
   - Remove the `isHovered` state and associated `.onHover` tracking from `BillingHubBoardSectionViews.swift` where appropriate.
6. In `Packages/Feature.BillingHub/Sources/Feature_BillingHub/Views/BillingHubDragDropComponents.swift`:
   - In `cardBackground` property (lines 172-188), remove the hover-based fill opacity transition and simplify the shadow modifier. Use flat `BillingHubTheme.Surfaces.cardBase` for fill, and a subtle constant shadow without hover-state transitions.
   - Remove `isHovering` state and the `.onHover` block.
7. In `Packages/Feature.BillingHub/Sources/Feature_BillingHub/Views/BillingHubGroupedColumnViews.swift`:
   - In `cardBackground` property (lines 231-247), simplify the shadow and fill logic: remove all hover-based fill/shadow opacity transitions. Use a constant flat background and standard shadow without hover effects.
   - Remove `isHovered` state and `.onHover` tracking.
8. In `Packages/Feature.BillingHub/Sources/Feature_BillingHub/Views/StatusIndicator.swift`:
   - In the background modifier (lines 51-65), remove the custom glowing shadow `.shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 6)`.
9. In `Packages/Feature.BillingHub/Sources/Feature_BillingHub/Views/BillableDrafts/BillableDraftsHomeView.swift`:
   - Remove `@State private var isHovering = false`, `.compactRowStyle(isHovering: isHovering)`, and `.onHover { isHovering = $0 }` from `BillableDraftRow`. Apply standard padding instead to preserve row layout structure.
10. In `Packages/Feature.BillingHub/Sources/Feature_BillingHub/Views/BillingHubGroupedSessionRows.swift`:
    - Remove the hover color highlight in the background fill / border check (`isHovered ? ...` at line 106).
    - Remove the `isHovered` state and `.onHover` block from `BillingHubGroupedSessionRow`.

Verification:
- Compile the modified codebase using `swift build` or `xcodebuild` targeting macOS.
- Run the automated tests (`swift test` or `./scripts/refactor-verify.sh`).
- Confirm that the project compiles cleanly with zero new errors and all tests pass.
- Write your handoff report in `handoff.md` detailing the exact modifications made, compile status, and test results.
- Send a message to the orchestrator reporting your results.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
