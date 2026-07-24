# UI Token and Component Standardization Compliance Audit

**Target Package**: `Feature.Invoices`
**Target Directory**: `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/`
**Date**: 2026-06-10

This document outlines the visual design system token violations found within the views of the `Feature.Invoices` package. All findings are categorized by file with line numbers, code snippets, and suggested token-based remediations.

---

## 1. Summary of Gaps

| File Path | Violations Count | Gap Types |
| :--- | :---: | :--- |
| `InvoiceInspectorFormView.swift` | 6 | Raw padding (4), frame heights (60), raw spacing (2, 6) |
| `InvoiceFilterPopoverContent.swift` | 2 | Raw frame height (120), modified token offset (+1) |
| `InvoiceLineItemsSection.swift` | 10 | Raw horizontal/vertical grid spacing (4, 10), raw stack spacing (4, 6, 8, 12, 16) |
| `InvoicesView.swift` | 9 | Raw stack spacing (2), raw padding values (6, 8, 12) |

Total Compliance Violations Detected: **27**

---

## 2. Detailed Findings

### A. `InvoiceInspectorFormView.swift`

1. **Line 199: Raw Padding Literal**
   - **Code**:
     ```swift
     .padding(.top, 4)
     ```
   - **Remediation**: Use `StyleGuide.Dimensions.paddingXSmall` (4.0).

2. **Line 212 & 218: Raw Frame Heights**
   - **Code**:
     ```swift
     .frame(minHeight: 60)
     ```
   - **Remediation**: Declare a new token in `StyleGuide.Dimensions` (e.g., `inspectorTextEditorMinHeight: CGFloat = 60.0`) or map to `StyleGuide.Dimensions.inspectorCurrencyFieldWidth` if logically aligned.

3. **Line 239 & 263: Raw Stack Spacing**
   - **Code**:
     ```swift
     HStack(spacing: 2)
     ```
   - **Remediation**: Use `StyleGuide.Dimensions.paddingXXSmall` (2.0).

4. **Line 378: Raw Stack Spacing**
   - **Code**:
     ```swift
     HStack(spacing: 6)
     ```
   - **Remediation**: Use `StyleGuide.Dimensions.paddingSmall` (6.0).

---

### B. `InvoiceFilterPopoverContent.swift`

1. **Line 227: Raw Frame Height**
   - **Code**:
     ```swift
     .frame(maxHeight: 120)
     ```
   - **Remediation**: Declare a new token in `StyleGuide.Dimensions` (e.g., `filterClientListMaxHeight: CGFloat = 120.0`).

2. **Line 250: Token Arithmetic with Raw Literal Offset**
   - **Code**:
     ```swift
     .padding(.vertical, StyleGuide.Dimensions.paddingSmall + 1)
     ```
   - **Remediation**: Avoid inline arithmetic. Use a dedicated padding token or define a custom height token.

---

### C. `InvoiceLineItemsSection.swift`

1. **Line 46: Raw Grid Spacing**
   - **Code**:
     ```swift
     Grid(horizontalSpacing: 4, verticalSpacing: 10)
     ```
   - **Remediation**: Replace with `Grid(horizontalSpacing: StyleGuide.Dimensions.paddingXSmall, verticalSpacing: StyleGuide.Dimensions.paddingXMedium)`.

2. **Line 126: Raw Stack Spacing**
   - **Code**:
     ```swift
     HStack(spacing: 6)
     ```
   - **Remediation**: Use `StyleGuide.Dimensions.paddingSmall` (6.0).

3. **Line 184: Raw Stack Spacing**
   - **Code**:
     ```swift
     HStack(spacing: 8)
     ```
   - **Remediation**: Use `StyleGuide.Dimensions.paddingMedium` (8.0).

4. **Line 216: Raw Stack Spacing**
   - **Code**:
     ```swift
     VStack(alignment: .leading, spacing: 16)
     ```
   - **Remediation**: Use `StyleGuide.Dimensions.paddingLarge` (16.0).

5. **Line 220, 229 & 238: Raw Stack Spacing**
   - **Code**:
     ```swift
     VStack(alignment: .leading, spacing: 8)
     ```
   - **Remediation**: Use `StyleGuide.Dimensions.paddingMedium` (8.0).

6. **Line 228: Raw Stack Spacing**
   - **Code**:
     ```swift
     HStack(spacing: 12)
     ```
   - **Remediation**: Use `StyleGuide.Dimensions.paddingMediumLarge` (12.0).

7. **Line 242: Raw Stack Spacing**
   - **Code**:
     ```swift
     HStack(spacing: 4)
     ```
   - **Remediation**: Use `StyleGuide.Dimensions.paddingXSmall` (4.0).

---

### D. `InvoicesView.swift`

1. **Line 210: Raw Stack Spacing**
   - **Code**:
     ```swift
     VStack(alignment: .leading, spacing: 2)
     ```
   - **Remediation**: Use `StyleGuide.Dimensions.paddingXXSmall` (2.0).

2. **Line 239 & 273: Raw Padding**
   - **Code**:
     ```swift
     .padding(.trailing, 8)
     ```
   - **Remediation**: Use `StyleGuide.Dimensions.paddingMedium` (8.0).

3. **Line 247, 264 & 281: Raw Padding**
   - **Code**:
     ```swift
     .padding(.horizontal, 12)
     ```
   - **Remediation**: Use `StyleGuide.Dimensions.paddingMediumLarge` (12.0).

4. **Line 248, 265 & 282: Raw Padding**
   - **Code**:
     ```swift
     .padding(.vertical, 6)
     ```
   - **Remediation**: Use `StyleGuide.Dimensions.paddingSmall` (6.0).
