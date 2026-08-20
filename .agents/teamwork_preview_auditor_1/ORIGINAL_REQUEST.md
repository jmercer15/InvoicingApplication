## 2026-06-17T02:54:19Z
You are teamwork_preview_auditor_1.
Your task is to run forensic integrity and correctness checks on the default invoice template implementation.
Specifically:
1. Verify that the implementation in DefaultInvoiceTemplate.swift, InvoiceTemplateEditorViewModel.swift, and DefaultInvoiceTemplateTests.swift is authentic and complete.
2. Verify that there are NO hardcoded expected test results, fake mock implementations that bypass tests, or other cheating behaviors.
3. Verify that the layout conforms to the print-optimized A4 specifications (595.2 x 841.8) and margins (36 pt).
4. Run static analysis/checks on the new files and changed files.
5. Run the verification test commands:
   - For the package: `swift test --package-path Packages/Feature.InvoiceTemplateEditor`
   - For the main application: `xcodebuild test -project InvoicingApplication.xcodeproj -scheme InvoicingApplication -destination 'platform=macOS'`
Ensure they compile and pass with zero new warnings/errors.
Write a detailed audit report in handoff.md inside your directory, listing all static analysis details, run commands, output logs, and your final verdict (CLEAN or INTEGRITY VIOLATION).
Your parent conversation ID is bbb26730-0fd0-4742-b086-da8de7728d75.
