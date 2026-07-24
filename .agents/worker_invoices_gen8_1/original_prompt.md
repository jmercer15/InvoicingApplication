## 2026-06-10T13:19:38Z
Resume token migration and verification for Feature.Invoices.
Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication
Your folder: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_gen8_1
Identity: worker_invoices_gen8_1

Tasks:
1. Run scripts/refactor-verify.sh script and check if it compiles and tests pass.
2. Scan Packages/Feature.Invoices/Sources/Feature_Invoices/Views/ for any remaining raw numeric literals for padding, corner-radius, spacing, or system/hex colors.
3. Migrate any remaining raw values to StyleGuide/ColorSystem/PanelShellTokens.
4. Verify using scripts/refactor-verify.sh.
5. Write a handoff.md report in your folder /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_invoices_gen8_1/ explaining:
   - What was found
   - What was migrated
   - Build/test verification command and output

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
