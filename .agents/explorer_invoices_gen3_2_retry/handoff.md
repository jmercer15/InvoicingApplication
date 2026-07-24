# Handoff Report — Feature.Invoices Design Token Compliance

## 1. Observation
I performed a read-only code audit of the views in the `Feature.Invoices` package under `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/`. The following specific instances of token/color compliance issues were observed:

1. **`InvoicesContentToolbar.swift` (Line 72)**:
   ```swift
   .foregroundStyle(Color("Primary", bundle: .sharedUI))
   ```
2. **`InvoicesView.swift` (Line 171)**:
   ```swift
   withAnimation(.easeOut(duration: 0.2)) {
   ```
3. **`InvoiceEditor.swift` (Line 87)**:
   ```swift
   .background(Color(NSColor.controlBackgroundColor))
   ```
4. **`InvoicesView.swift` (Lines 212, 215, 229, 245, 262, 279)**:
   - Uses hardcoded `Color.white` and `Color.white.opacity(0.8)` for labels displayed inside the dark glass selection container.

All other views (`InvoiceTemplateRendererView.swift`, `InvoicesColumns.swift`, `InvoicesDetailColumn.swift`, `InvoiceFilterPopoverContent.swift`, `InvoiceInspectorFormView.swift`, and `InvoiceLineItemsSection.swift`) are fully compliant and correctly use `StyleGuide` and `ColorSystem` tokens.

## 2. Logic Chain
- **Observation 1 & 3**: Custom string resource lookup `Color("Primary", bundle: .sharedUI)` and AppKit color `Color(NSColor.controlBackgroundColor)` directly violate design token guidelines by bypassing the centralized styling layer.
- **Observation 2**: The raw literal duration `0.2` used for list selection transition bypasses animation tokens.
- **Reference to token definitions**:
  - `StyleGuide.Colors.primary` is defined as `Color("Primary", bundle: .sharedUI)`. Therefore, `InvoicesContentToolbar.swift` should directly reference `StyleGuide.Colors.primary`.
  - `PanelShellTokens.panelSecondaryBackground` maps to `Color(NSColor.controlBackgroundColor).opacity(0.35)`. `InvoiceEditor.swift` should utilize this secondary background token or similar to avoid calling AppKit system colors directly.
  - `StyleGuide.Animations.durationMedium` is defined as `0.3`, which matches other view-state transitions. Changing the hardcoded `0.2` to `StyleGuide.Animations.durationMedium` enforces systemic animation parity.

## 3. Caveats
- Hardcoded `Color.white` inside the dark selection glass-card of `InvoicesView.swift` was left as-is, since the current `ColorSystem.Neutral.white` resolves to `windowBackgroundColor` (which is gray/adaptive and unsuitable for a dark overlay label). Introducing a new semantic color token (e.g. `ColorSystem.Neutral.textLightHighContrast`) is recommended.

## 4. Conclusion
The views within `Feature.Invoices` are highly compliant with only four localized gaps:
1. `InvoicesContentToolbar.swift` line 72 should map to `StyleGuide.Colors.primary`.
2. `InvoicesView.swift` line 171 should map to `StyleGuide.Animations.durationMedium`.
3. `InvoiceEditor.swift` line 87 should map to `PanelShellTokens.panelSecondaryBackground` or another suitable background token.
4. Hardcoded `Color.white` labels on glass card highlights could benefit from a dedicated high-contrast semantic light text token in `ColorSystem`.

## 5. Verification Method
1. Inspect files directly to confirm these occurrences and proposed replacements.
2. Build the project using `swift build` or Xcode commands once the changes are implemented by the implementer to ensure compilation success.
