## 2026-06-12T05:58:21Z
You are teamwork_preview_worker. Your working directory is /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_ite_appshell_ui.
Your task is:
1. Initialize your BRIEFING.md and progress.md in your working directory.
2. Address visual design refresh violations in Feature.InvoiceTemplateEditor, AppShell, SharedUI, and WorkspaceUI, specifically:
   - Identify and replace raw font size/weight literals with appropriate typography tokens from `StyleGuide.Typography` (or dimensions from `StyleGuide.Dimensions` if necessary) in:
     - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Renderer/InvoiceCanvasView.swift` (line 144)
     - `Packages/SharedUI/Sources/SharedUI/Components/HierarchySectionCard.swift` (line 137)
     - `Packages/WorkspaceUI/Sources/WorkspaceUI/NativeAddressSearchField.swift` (lines 120, 125, 130)
   - Identify and replace raw corner radius literals (like `.cornerRadius(8)`) in:
     - `Packages/WorkspaceUI/Sources/WorkspaceUI/NativeAddressSearchField.swift` (line 153) with `StyleGuide.Dimensions.cornerRadiusSmall`.
   - Identify and replace raw animation duration literals (like `.easeInOut(duration: 0.2)`) in:
     - `Packages/AppShell/Sources/AppShell/Views/SmartInspectorResolverView.swift` (line 80) with `StyleGuide.Animations.durationMedium` or appropriate animation tokens.
   - Scan for any other raw style literals or layout margin violations in these modules and standardize them.
3. Run builds and tests for `Feature.InvoiceTemplateEditor`, `SharedUI`, `WorkspaceUI`, and the main app target (`AppShell` or `InvoicingApplication` app target) to ensure they compile with zero warnings/errors and all tests pass.
   - Use SPM test commands like `swift test --package-path Packages/SharedUI` or `swift build --package-path Packages/Feature.InvoiceTemplateEditor`.
   - Verify that the main app target builds successfully using xcodebuild command (refer to `scripts/refactor-verify.sh`).
4. Create a structured report `handoff.md` in your working directory summarizing:
   - Specific files modified and changes made.
   - Compile and test commands run and their output status.
5. When done, send a message back.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
