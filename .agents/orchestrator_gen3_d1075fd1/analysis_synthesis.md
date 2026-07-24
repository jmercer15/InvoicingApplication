# Style Token Migration Synthesis: Feature.Invoices

This document compiles the style token compliance audit findings from all Explorers for `Packages/Feature.Invoices`.

## Findings

### 1. `Sources/Feature_Invoices/Views/InvoiceEditor.swift`
- **Location:** Line 87
- **Target:** `.background(Color(NSColor.controlBackgroundColor))`
- **Remediation:** Replace with `.background(StyleGuide.Colors.background)` or `.background(ColorSystem.Neutral.white)` to align with the design system.

### 2. `Sources/Feature_Invoices/Views/Components/InvoicesDetailToolbar.swift`
- **Location:** Line 198
- **Target:** `.font(.caption)` in the compliance message text block.
- **Remediation:** Replace with `.font(StyleGuide.Typography.caption)`.

### 3. `Sources/Feature_Invoices/Views/InvoiceLineItemsSection.swift`
- **Location:** Lines 210–238 (inside `LineItemEditor`)
- **Target:** Custom `VStack` layout blocks duplicating the form field layout.
- **Remediation:** Refactor to use the `FormField` component from `SharedUI`:
  - Replace Description input layout with `FormField("Description")`
  - Replace Quantity input layout with `FormField("Quantity")`
  - Replace Rate input layout with `FormField("Rate")`

## Verification Command
```bash
bash scripts/refactor-verify.sh
```
