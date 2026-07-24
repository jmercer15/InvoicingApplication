# Feature.Invoices View Layout & Panel Shell Analysis

## Executive Summary
This analysis investigates the SwiftUI views in `Feature.Invoices` (`Packages/Feature.Invoices/Sources/Feature_Invoices/Views/`) to identify structural layout and panel shell issues, and proposes a clean fix strategy.

Key findings:
- **Panel Shell Adoption**: 
  - `InvoicesContentColumn` does not adopt `.standardPanelShell` locally; it is correctly wrapped by `WorkspaceSplitView`'s container `WorkspaceFeatureContentColumn`.
  - `InvoicesDetailColumn` applies `.standardPanelShell(role: .detailPanel)` and `.standardPanelTransition()` locally. Since `WorkspaceSplitView` also wraps the detail column with `.standardPanelShell` at the container level, this results in **duplicate/nested panel shell wrapping** in the main split view interface.
  - In contrast, the inspector panel (`SmartInspectorResolverView`) does not apply `.standardPanelShell` at the container level. This forces `ClientDetailView` and `InvoicesDetailColumn` to apply it locally, while `NDISCatalogueDetailColumn`/`EnhancedSupportItemDetailView` does not, resulting in an **un-styled detail panel inside the inspector for NDIS**.
- **Column Sizing**: Zero raw width or minWidth literals were found in any view files. Standard tokens from `StyleGuide.Dimensions` are strictly used.
- **Detail Panels Layout**: 
  - `InvoiceEditor` renders a simulated A4 document sheet preview (`InvoiceTemplateRendererView`), where `DetailCardsLayout` is inappropriate.
  - `InvoiceEditorFormContent` (the inspector form) is built as a monolithic, grouped `Form`. This breaks styling consistency with `Feature.Clients` and `Feature.NDIS` detail views which use `DetailCardsLayout` with modular `GroupBox` cards.

---

## 1. Panel Shell Adoption Scan

### 1.1 Content Column
- **File**: `Sources/Feature_Invoices/Views/InvoicesColumns.swift` (`InvoicesContentColumn`)
- **Observation**: Does not apply `.standardPanelShell`.
- **Verdict**: Correct. Wrapped globally by `WorkspaceSplitView`'s `WorkspaceFeatureContentColumn` (AppShell) which applies `.standardPanelShell(role: .contentPanel)`.
- **List Insets**: The inner `ScrollableInvoicesList` correctly delegates to `FoldPaperContainer` (which adopts `.standardContentPanelListInsets()`) and empty states apply `.standardContentPanelListInsets()`.

### 1.2 Detail Column (Primary & Inspector)
- **File**: `Sources/Feature_Invoices/Views/InvoicesDetailColumn.swift` (`InvoicesDetailColumn`)
- **Observation**:
  ```swift
  .standardPanelShell(role: .detailPanel)
  .standardPanelTransition()
  ```
- **Verdict**: Redundant double-wrapping in the main split view. 
  - `WorkspaceSplitView.swift` applies `.standardPanelShell(role: role)` to the outer `WorkspaceFeatureDetailColumn`.
  - However, in the Inspector pane (`SmartInspectorResolverView.swift`), the container itself does **not** apply `.standardPanelShell`.
  - Consequently, if local panel shells are removed to fix the Split View redundancy, the inspector form will lose its shell style. NDIS detail view already lacks this shell style in the inspector because it does not apply it locally.

---

## 2. Column Sizing Scan

All frame width properties in `Feature.Invoices` use centralized design tokens. No raw numeric literals (e.g. `200` or `350` for widths) were found.

| Component / View | Frame Usage | Token Reference |
|---|---|---|
| `InvoiceEditUndoWindowInstaller` | `.frame(width:hiddenFrameWidth)` | `StyleGuide.Dimensions.hiddenFrameWidth` |
| `InvoicesDetailToolbar` | `.frame(width:unsavedIndicatorSize)` | `StyleGuide.Dimensions.unsavedIndicatorSize` |
| `InvoiceFilterPopoverContent` | `.frame(width:filterPopoverWidth)` | `StyleGuide.Dimensions.filterPopoverWidth` |
| `InvoiceFilterPopoverContent` | `.frame(width:filterAmountFieldWidth)` | `StyleGuide.Dimensions.filterAmountFieldWidth` |
| `InvoiceEditorFormContent` | `.frame(width:inspectorPercentFieldWidth)` | `StyleGuide.Dimensions.inspectorPercentFieldWidth` |
| `InvoiceEditorFormContent` | `.frame(width:inspectorCurrencyFieldWidth)` | `StyleGuide.Dimensions.inspectorCurrencyFieldWidth` |
| `LineItemEditor` | `.frame(width:lineItemEditorWidth)` | `StyleGuide.Dimensions.lineItemEditorWidth` |

---

## 3. Detail Panels & `DetailCardsLayout` Scan

- **File**: `Sources/Feature_Invoices/Views/InvoiceInspectorFormView.swift` (`InvoiceEditorFormContent`)
- **Observation**: Uses `Form` with style `.grouped` instead of `DetailCardsLayout`.
- **Verdict**: Non-compliant with visual language standard set by `Feature.Clients` (`ClientDetailView`) and `Feature.NDIS` (`EnhancedSupportItemDetailView`) which lay out modular, standalone cards.

---

## 4. Proposed Fix Strategy

### Phase 1: Unify Panel Shell at Container level
To eliminate nested shells in the Split View and fix missing shells in the Inspector:
1. **Modify AppShell** (`SmartInspectorResolverView.swift`): Wrap the body of `SmartInspectorResolverView` (or the `.inspector` view content in `ContentView.swift`) in `.standardPanelShell(role: .detailPanel)`.
2. **Clean up Feature.Invoices** (`InvoicesDetailColumn.swift`): Remove the local `.standardPanelShell(role: .detailPanel)` and `.standardPanelTransition()` modifiers.
3. **Clean up Feature.Clients** (`ClientDetailView.swift`, `PayeeDetailView.swift`, `PlanManagerDetailView.swift`): Remove local `.standardPanelShell(role: .detailPanel)` modifiers.

### Phase 2: Refactor Invoice Inspector Form to Cards
Convert `InvoiceEditorFormContent` from a monolithic `Form` into `DetailCardsLayout` containing individual `GroupBox` cards styled with `EnhancedGroupBoxStyle`:
1. Create separate sub-components for each section:
   - `InvoiceDetailsCard` (Invoice Number, dates, status, template)
   - `BusinessDetailsCard` (ABN, contact, address - read-only)
   - `ParticipantCard` (Client picker and contact summary)
   - `BillingDetailsCard` (Method, payee/plan-manager pickers, bill-to summary)
   - `PaymentDetailsCard` (Bank credentials)
   - `LineItemsCard` (Line items grid and add button)
   - `FinancialsCard` (Discount, tax rate, credit fields + totals)
   - `NotesCard` (Payment terms and custom notes text editors)
2. Wrap these cards in `DetailCardsLayout` in `InvoiceEditorFormContent`:
   ```swift
   DetailCardsLayout(minCardWidth: DetailSectionTokens.detailCardMinimumWidth) {
       InvoiceDetailsCard(viewModel: viewModel)
       BusinessDetailsCard(invoice: viewModel.invoice)
       ParticipantCard(viewModel: viewModel)
       BillingDetailsCard(viewModel: viewModel)
       PaymentDetailsCard(invoice: viewModel.invoice)
       LineItemsCard(viewModel: viewModel)
       FinancialsCard(viewModel: viewModel)
       NotesCard(viewModel: viewModel)
   }
   ```
