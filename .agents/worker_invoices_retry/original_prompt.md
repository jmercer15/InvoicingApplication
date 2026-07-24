## 2026-06-10T13:19:04Z
You are Invoices Worker (Retry). Your working directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_retry`.
Please implement the following token migrations and refactoring in `Packages/Feature.Invoices`:

1. In `Sources/Feature_Invoices/Views/InvoiceEditor.swift`:
   Replace `.background(Color(NSColor.controlBackgroundColor))` on line 87 with `.background(StyleGuide.Colors.background)`.

2. In `Sources/Feature_Invoices/Views/Components/InvoicesDetailToolbar.swift`:
   Replace `.font(.caption)` on line 198 with `.font(StyleGuide.Typography.caption)`.

3. In `Sources/Feature_Invoices/Views/InvoiceLineItemsSection.swift` (inside `LineItemEditor`):
   Refactor the Description, Quantity, and Rate vertical label/input blocks to use the `FormField` component from `SharedUI`. For example:
   ```swift
   FormField("Description") {
       TextField("Description", text: $item.itemDescription)
           .textFieldStyle(.roundedBorder)
   }
   ```
   (And similarly for Quantity and Rate fields, preserving formatters/alignments/modifiers).

Verification:
Run the verification script `bash scripts/refactor-verify.sh` and ensure it exits with code 0.
Write your changes to `changes.md` and handoff report to `handoff.md` in your working directory.

MANDATORY INTEGRITY WARNING:
> DO NOT CHEAT. All implementations must be genuine. DO NOT
> hardcode test results, create dummy/facade implementations, or
> circumvent the intended task. A Forensic Auditor will independently
> verify your work. Integrity violations WILL be detected and your
> work WILL be rejected.
