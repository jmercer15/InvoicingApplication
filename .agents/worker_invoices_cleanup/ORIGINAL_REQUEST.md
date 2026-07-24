You are the Invoices Styling Cleanup Worker. Your working directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_cleanup/`.
Your mission is to clean up non-native custom styling (such as custom selection highlights, manual hover states, and custom background highlights) in the `Feature.Invoices` package, restoring macOS native UI behaviors.

Please perform the following changes:
1. In `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterPopoverContent.swift`:
   - Simplify `StatusFilterButton` and `ClientFilterButton`: remove the `isHovered` state and the `.onHover { hovering in isHovered = hovering }` modifier blocks.
   - Replace the hover-based background opacity and border stroke logic (lines 257-266, 318-327) with flat backgrounds and constant overlays (e.g. flat `ColorSystem.Primary.blue` or status color when selected, and standard neutral backgrounds when not, with no hover transitions).
2. In `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceLineItemsSection.swift`:
   - Simplify the "Add Line Item" button: remove `isAddHovered` state and `.onHover` block (lines 136-138). Make the background fill and border stroke constant/flat.
   - For the edit (pencil) and delete (trash) buttons (lines 202-211, 221-230): remove `hoveredButtonId` state and `.onHover` modifiers. Replace the manual `.foregroundStyle(...)` hover highlight color check with standard, flat colors (e.g. standard `ColorSystem.Primary.blue` for edit and `ColorSystem.Status.error` or `Color.red` for delete, or rely on standard system button styles).
3. In `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesView.swift`:
   - In the multi-select bottom action toolbar (lines 221-290): Replace the custom `.buttonStyle(.plain)` buttons and manually managed `.onHover` tracking (`hoveredButton`) with standard native buttons using macOS style modifiers:
     - Cancel: `Button("Cancel", action: ...) { ... }` with `.buttonStyle(.bordered)` or native border.
     - Delete: `Button(action: ...) { ... }` with `.buttonStyle(.borderedProminent)` and `.tint(.red)`.
     - Export PDFs: `Button(action: ...) { ... }` with `.buttonStyle(.borderedProminent)` and `.tint(.blue)`.
     - Email Selected: `Button(action: ...) { ... }` with `.buttonStyle(.borderedProminent)` and `.tint(.blue)`.
   - Remove the `hoveredButton` state and all associated `.onHover` blocks from these toolbar buttons.

Verification:
- Compile the modified codebase using `swift build` or `xcodebuild` targeting macOS.
- Run the automated tests (`swift test` or `./scripts/refactor-verify.sh`).
- Confirm that the project compiles cleanly with zero new errors and all tests pass.
- Write your handoff report in `handoff.md` detailing the exact modifications made, compile status, and test results.
- Send a message to the orchestrator reporting your results.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
