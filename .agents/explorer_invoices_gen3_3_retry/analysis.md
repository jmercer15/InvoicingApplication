# Token Compliance Analysis: Feature.Invoices Component Views

## Summary
- Target directory: `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/Components/`
- Target files:
  1. `InvoiceEditUndoWindowInstaller.swift`
  2. `InvoiceEditorUndoComponents.swift`
  3. `InvoiceShareToolbarItem.swift`
  4. `InvoicesDetailToolbar.swift`
  5. `WritingToolsTextEditor.swift`
- Compliance status: **100% Compliant**. No raw numeric literals for padding, corner-radius, spacing, or local custom/hardcoded colors found. All views correctly utilize `StyleGuide`, `ColorSystem`, or leverage system styles/standard styling modifiers.

---

## File-by-File Analysis

### 1. `InvoiceEditUndoWindowInstaller.swift`
- **Purpose**: Installs undo manager on `NSWindow` responder chain.
- **Layout / Styling Scan**:
  - Hidden frame uses `StyleGuide.Dimensions.hiddenFrameWidth` and `StyleGuide.Dimensions.hiddenFrameHeight`.
- **Gaps**: None.

### 2. `InvoiceEditorUndoComponents.swift`
- **Purpose**: Implements undo-aware text/double fields and modifier-based form undo registration.
- **Layout / Styling Scan**:
  - `TextField` uses standard `.textFieldStyle(.roundedBorder)`.
  - No custom layout padding, spacing, corner radius, or color values.
- **Gaps**: None.

### 3. `InvoiceShareToolbarItem.swift`
- **Purpose**: Provides a menu/button structure for sharing invoice PDFs.
- **Layout / Styling Scan**:
  - No custom layout padding, spacing, corner radius, or color values.
  - Relies on system-standard `ShareLink` and `Menu` styling.
- **Gaps**: None.

### 4. `InvoicesDetailToolbar.swift`
- **Purpose**: Renders the toolbar at the top of the invoice detail pane (title, edit button, document and workflow status dropdowns).
- **Layout / Styling Scan**:
  - **Padding/Spacing**:
    - `HStack(spacing: StyleGuide.Dimensions.paddingSmall)` on Line 104.
    - `StyleGuide.Dimensions.unsavedIndicatorSize` on Line 113.
  - **Colors**:
    - `ColorSystem.Status.warning` for warning indicator (Lines 111, 199).
    - `ColorSystem.Status.error` for blocker warning indicator (Line 199).
    - `ColorSystem.Invoice.statusColor(for:)` via mapping helper `InvoiceStatusStyle.color` (Line 225).
  - **Animations**:
    - `StyleGuide.Animations.durationMedium` for transition duration (Lines 48, 96).
- **Gaps**: None.

### 5. `WritingToolsTextEditor.swift`
- **Purpose**: Wraps NSTextView to enable macOS 15 Writing Tools integration.
- **Layout / Styling Scan**:
  - Uses standard `.bezelBorder` and system font sizes (`NSFont.systemFontSize`).
  - No raw custom colors or layout spacing/padding/corner-radius numbers.
- **Gaps**: None.

---

## Mapping Recommendation Strategy

Since the existing components are already fully compliant, the recommendation strategy focuses on maintaining compliance and applying lessons to any future components:

| Element Type | Legacy/Raw Pattern | Token Mapping | Purpose / Target |
| :--- | :--- | :--- | :--- |
| **Padding** | Raw CGFloat (e.g. `8`, `12`, `16`) | `StyleGuide.Dimensions.paddingSmall/Medium/Large` | Uniform margins and layout alignment. |
| **Corner Radius** | Raw CGFloat (e.g. `8`, `10`, `12`) | `StyleGuide.Dimensions.cornerRadiusSmall/Medium/Large` or `PanelShellTokens.panelCornerRadius` | Standardized card and container borders. |
| **Spacing** | Raw CGFloat in HStack/VStack | `StyleGuide.Dimensions.paddingXSmall` through `paddingXXLarge` | Consistent inter-element gaps. |
| **Color** | Custom `Color(...)` or hardcoded Hex | `ColorSystem.Status`, `ColorSystem.Invoice`, or `ColorSystem.Neutral` | Accessible light/dark theme adaptation. |
| **Animation Durations** | Raw `Double` duration in `withAnimation` | `StyleGuide.Animations.durationShort/Medium/Long` | Consistent feedback speed across views. |
