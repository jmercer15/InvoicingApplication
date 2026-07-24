## 2026-06-12T05:54:00Z
You are teamwork_preview_worker. Your working directory is /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_billinghub_calendar_settings.
Your task is:
1. Initialize your BRIEFING.md and progress.md in your working directory.
2. Address visual design refresh violations in Feature.BillingHub, Feature.Calendar, and Feature.Settings, specifically:
   - Identify and replace direct `NSColor` references (e.g., `Color(NSColor.secondaryLabelColor)`, `Color(NSColor.tertiaryLabelColor)`, `Color(NSColor.systemRed) / Color(NSColor.systemOrange)`) in `Feature.BillingHub` (specifically `BillableDraftDetailView.swift` and others) with standardized color tokens in `ColorSystem` or `StyleGuide.Colors`.
   - Identify and replace raw/hardcoded `.animation` duration or spring values in `Feature.Calendar` (specifically `CalendarTabView.swift` and `NativeSessionFormLocationSection.swift`) with `StyleGuide.Animations` tokens.
   - Identify and replace raw/hardcoded `.padding` values (e.g., `.padding(.vertical, 2)`, `.padding(.vertical, 4)`) in `Feature.Settings` (specifically `RecurrenceSettingsViews.swift` and `ImportExportView.swift`) with appropriate `StyleGuide.Dimensions` padding tokens (e.g., `StyleGuide.Dimensions.paddingTiny`, `StyleGuide.Dimensions.paddingXSmall` etc.).
   - Standardise layout panel shell usages in these packages where applicable, ensuring they use standard design system margins or layout modifiers.
3. Run builds and tests for `Feature.BillingHub`, `Feature.Calendar`, and `Feature.Settings` to ensure they compile with zero warnings/errors and all tests pass.
   - Use SPM test commands like `swift test --package-path Packages/Feature.Settings` or compile commands like `swift build --package-path Packages/Feature.Calendar`.
4. Create a structured report `handoff.md` in your working directory summarizing:
   - Specific files modified and changes made.
   - Compile and test commands run and their output status.
5. When done, send a message back.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
