# Plan: Default Invoice Template Implementation

This plan details the implementation of a print-optimized default invoice template with structured splits and proper layouts.

## Milestones

### Milestone 1: Exploration
- **Objectives**: Inspect layout definitions, existing components, and test targets.
- **Verification**: Ensure the existing project compiles and tests pass.
- **Worker**: Explorer

### Milestone 2: Implement Default Invoice Template
- **Objectives**: Create `DefaultInvoiceTemplate.swift` under `Models/Domain/` in `Packages/Feature.InvoiceTemplateEditor`.
- **Details**:
  - Implement `public static func createDefaultDocument() -> InvoiceDocument` returning a layout with:
    - Fixed A4 dimensions: 595.2 x 841.8.
    - Default margins: 36 pt.
    - Section height ratios: `[0.15, 0.20, 0.45, 0.20]`.
    - Section 0 (Header): Horizontal split [0.6, 0.4].
      - Column 0: Vertical split [0.6, 0.4] containing `.companyName` and `.companyABN`.
      - Column 1: Vertical split [0.6, 0.4] containing `.companyLogo` and `.invoiceTitle`.
    - Section 1 (Billing/Info): Horizontal split [0.5, 0.5].
      - Column 0: Vertical split [0.5, 0.5] containing `.billTo` and `.participant`.
      - Column 1: Vertical split [0.5, 0.5] containing `.invoiceNumberAndDates` and a blank spacer/text box.
    - Section 2 (Services): Horizontal split [1.0] containing `.servicesTable`.
    - Section 3 (Footer): Horizontal split [0.5, 0.5].
      - Column 0: Vertical split [0.5, 0.5] containing `.paymentDetails` and `.paymentTerms`.
      - Column 1: Vertical split [0.5, 0.5] containing `.totals` and `.notes`.
- **Verification**: Clean compilation of the new file.
- **Worker**: Worker

### Milestone 3: Integration
- **Objectives**: Replace the inline absolute positioning in `InvoiceTemplateEditorViewModel.swift`'s `loadDefaultTemplate()` with `DefaultInvoiceTemplate.createDefaultDocument()`.
- **Verification**: Run build and verify no compiler errors.
- **Worker**: Worker

### Milestone 4: Verification Testing
- **Objectives**: Create `DefaultInvoiceTemplateTests.swift` under `Tests/Feature_InvoiceTemplateEditorTests/`.
- **Details**:
  - Verify that the created `InvoiceDocument` has `pageSize == A4` (595.2 x 841.8) and `margins` of 36.
  - Verify that the component roster is complete: `.companyName`, `.companyABN`, `.companyLogo`, `.invoiceTitle`, `.billTo`, `.participant`, `.invoiceNumberAndDates`, `.servicesTable`, `.totals`, `.paymentDetails`, `.paymentTerms`, `.notes`.
  - Verify that all these exist within `sectionSplits` or are correctly registered.
- **Verification**: Run package tests using `swift test`.
- **Worker**: Worker

### Milestone 5: Forensic Audit
- **Objectives**: Verify layout compliance, check that no tests are hardcoded, and run all app-wide tests.
- **Verification**: Runs `swift test` and `xcodebuild test` to ensure clean build and 100% test pass. Perform integrity check with the Forensic Auditor.
- **Worker**: Reviewer & Forensic Auditor
