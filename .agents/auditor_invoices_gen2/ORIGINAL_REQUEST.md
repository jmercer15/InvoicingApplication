## 2026-06-13T14:12:18Z
You are a Forensic Auditor spawned to perform integrity verification on the changes made to the Feature.Invoices package.
Your working directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/auditor_invoices_gen2`.

Target Package: `Packages/Feature.Invoices/`

Tasks:
1. Verify that the implementation of Feature.Invoices is authentic and clean.
2. Check for integrity violations or cheating:
   - Verify there is no hardcoding of test results or expected values to bypass tests.
   - Verify there are no dummy/facade implementations or empty functions bypassing logic.
   - Check if any test suite overrides, mocks, or stubs are used improperly.
3. Perform static analysis or checking of the files changed in `Packages/Feature.Invoices/`.
4. Run tests or analyze test code to ensure authentic checks.
5. Document all audit steps, evidence, and your final verdict (CLEAN or VIOLATION DETECTED) in `handoff.md` in your working directory.
