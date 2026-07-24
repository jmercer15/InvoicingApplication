# Plan: Document Grid Layout Math Sizing Tests

## Objective
Verify the correctness, interactions, and edge cases of the document grid layout math column/row sizing modes (Flexible, Fit, Fixed) within `DocumentGridLayoutMath` by writing comprehensive unit tests.

## Target Test File
`Packages/Feature.InvoiceTemplateEditor/Tests/Feature_InvoiceTemplateEditorTests/DocumentGridLayoutMathTests.swift`

## Verification Command
`swift test --package-path Packages/Feature.InvoiceTemplateEditor`

## Steps
1. **Implement Test Suite**:
   - Create `DocumentGridLayoutMathTests.swift` containing comprehensive unit tests covering:
     - All Flexible columns (standard distribution, larger content width, extra large content width).
     - All Fixed columns (sum less than container, sum exceeding container).
     - All Fit columns (standard, zero/missing width fallback, exceeding container).
     - Mixed configurations (Fixed + Fit + Flexible: standard, flexible shrinking, flexible + fit shrinking).
     - Edge Cases (zero width, zero column count, fixed exceeding container, extremely constrained space).
     - Row heights & border calculations (row height floors, row heights overflow, horizontal border accumulation).
2. **Execute and Verify**:
   - Run swift test command on the local Swift Package to verify that all new tests compile and pass successfully, and no existing tests regress.
3. **Review**:
   - Code review to check correctness, alignment with original layout logic, and robustness.
4. **Challenge**:
   - Run adversarial checks for additional layout constraints and correctness validation.
5. **Forensic Audit**:
   - Perform static/integrity checks to ensure no cheating or mock/hardcoded answers exist.
6. **Handoff**:
   - Write final handoff.md and notify Sentinel.
