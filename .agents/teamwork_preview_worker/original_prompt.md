## 2026-06-12T00:37:25Z
You are teamwork_preview_worker. Your task is to standardise the UI design throughout all of the application's remaining features:
1. Feature.Invoices (build and verification check, then fix remaining issues)
2. Feature.BillingHub & Feature.Calendar
3. Feature.Settings & Feature.InvoiceTemplateEditor
4. AppShell
Unify spacing, typography, colors, panel shells. Follow the execution sequence: for each package, perform token migration + visual refresh + PanelShell adoption, and then verify build/test using xcodebuild/scripts.

Let's start by analyzing what worker_invoices_gen9 and worker_invoices_gen10 did, if anything, and continue implementing.
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Please execute the required changes, run the build and test verify commands, and report the details back.

## 2026-06-12T00:56:58Z
Fix visual design system compliance errors listed in audit report:
1. Feature.Calendar:
   - MonthDayCellView.swift: Lines 224, 229, 358, 359, 407, 408 (raw padding), Line 226 (raw calculation: StyleGuide.Dimensions.cornerRadiusXSmall - 1). Replace with correct StyleGuide.Dimensions tokens or clean them up.
   - MonthHeaderComponents.swift: Line 72 (.padding(.vertical, 4)).
2. Feature.InvoiceTemplateEditor:
   - ModernCanvasOverlays.swift: Line 414 (.cornerRadius(8)).
   - DocumentGridComponent.swift: Line 304 (.cornerRadius(4)), Line 305 (.cornerRadius(0)).
   - ImageComponent.swift: Line 78, 90 (.cornerRadius(8)), Line 103 (.cornerRadius(12)).
   - InvoiceCanvasView.swift: Line 164 (.cornerRadius(8)).
   - RulerView.swift: Line 99 (.font(.system(size: 8...))).
3. Feature.BillingHub:
   - BillingHubCardColumnChrome.swift: Line 123 (.padding(.horizontal, isEmpty ? 32 : 12)).
   - BillingHubDragContainerColumns.swift: Lines 65, 66, 87, 234, 235, 267 (raw padding).
4. Feature.Settings:
   - SystemHealthView.swift: Line 97 (.padding(.leading, 32)).


## 2026-06-12T01:04:48Z
Fix visual design system compliance errors listed in audit report:
1. Feature.Calendar:
   - NativeSessionFormView.swift: Line 69 (.padding(.bottom, 20)), Line 97 (.padding(.horizontal, 16)), Line 98 (.padding(.bottom, 16)). Replace with StyleGuide.Dimensions tokens.
   - NativeSessionFormRecurrenceSection.swift: Line 56 (.padding(.leading, 86)), Line 267 (.padding(.vertical, 2)). Replace with StyleGuide.Dimensions tokens.
2. Feature.Settings:
   - CalendarSettingsView.swift: Line 69 (.padding(.top, 16)), Line 387 (.padding(.top, 4)). Replace with StyleGuide.Dimensions tokens.
   - ImportExportView.swift: Line 76 (.padding(.bottom, 8)), Line 136 (.padding(.bottom, 8)). Replace with StyleGuide.Dimensions tokens.
   - ClaimBatchBuildWizardView.swift: Line 175 (.padding(.horizontal, 16)), Line 176 (.padding(.vertical, 10)), Line 281 (.padding(.horizontal, 16)), Line 282 (.padding(.vertical, 10)). Replace with StyleGuide.Dimensions tokens.
   - ClaimBatchesHomeView.swift: Line 62 (.padding(.vertical, 4)). Replace with StyleGuide.Dimensions tokens.
   - ImportExportView+Claims.swift: Line 223 (.padding(.vertical, 4)). Replace with StyleGuide.Dimensions tokens.
3. Feature.InvoiceTemplateEditor:
   - DocumentGridComponent.swift: Line 309 (RoundedRectangle(cornerRadius: 4)). Replace with StyleGuide.Dimensions.cornerRadiusSmall or appropriate token.


## 2026-06-12T01:19:41Z
You are teamwork_preview_worker. The parent agent reports a build failure:
Error: cannot find 'StyleGuide' in scope in ImageComponent.swift.
Missing 'import SharedUI' on line 1 of Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/ImageComponent.swift.

You MUST NOT cheat, hardcode test results, or bypass verification. All changes must be genuine.
Your task is to:
1. Open Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/ImageComponent.swift and add `import SharedUI` at the top of the file so that `StyleGuide` is available in scope.
2. Compile Feature.InvoiceTemplateEditor to make sure it compiles cleanly.
3. Report the result in handoff.md.
