# Handoff Report

## 1. Observation
I scanned `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/` and related workspace layout code:
- **`InvoicesDetailColumn.swift` (lines 69-70)**: Adopts `.standardPanelShell(role: .detailPanel)` and `.standardPanelTransition()` locally.
- **`WorkspaceSplitView.swift` (line 119)**: Adopts `.standardPanelShell(role: role)` to wrap `WorkspaceFeatureDetailColumn` (which hosts `InvoicesDetailColumn`).
- **`SmartInspectorResolverView.swift` (lines 18-34)**: Renders detail columns (`InvoicesDetailColumn`, `RelationshipsDetailColumn`, `NDISCatalogueDetailColumn`) in the inspector side panel without wrapping them in `.standardPanelShell`.
- **`ClientDetailView.swift` (line 89)**: Adopts `.standardPanelShell(role: .detailPanel)` locally.
- **`EnhancedSupportItemDetailView.swift` (lines 59-67)**: Does **not** adopt `.standardPanelShell` locally.
- **`InvoiceInspectorFormView.swift` (`InvoiceEditorFormContent`, lines 17-27)**: Uses monolithic grouped `Form` with `.formStyle(.grouped)` layout.
- **Column Sizing**: Ripgrep search for width literals returned no raw integers in view files; all dimensions utilize tokens from `StyleGuide.Dimensions`.

## 2. Logic Chain
1. Since `WorkspaceSplitView` applies `.standardPanelShell` at the container level for split-view detail columns, and `InvoicesDetailColumn` / `ClientDetailView` also apply `.standardPanelShell` locally, these views are double-wrapped in the split view layout, producing nested backgrounds.
2. Since `SmartInspectorResolverView` does not apply `.standardPanelShell` at the container level, any detail view presented there requires a panel shell to render with standard styling. Since `InvoicesDetailColumn` and `ClientDetailView` apply it locally, they render correctly in the inspector. However, since `EnhancedSupportItemDetailView` (NDIS) does not apply it locally, it renders without the standardized background styling inside the inspector.
3. Therefore, applying `.standardPanelShell(role: .detailPanel)` inside the inspector container (e.g. `SmartInspectorResolverView`) and removing it from individual detail columns (`InvoicesDetailColumn`, `ClientDetailView`) unifies styling, resolves double-wrapping in the split view, and fixes the missing panel style on NDIS views in the inspector.
4. Regarding the inspector form, since other feature detail columns (`ClientDetailView`, `EnhancedSupportItemDetailView`) use `DetailCardsLayout` with modular card components rather than monolithic grouped Forms, refactoring `InvoiceEditorFormContent` to separate cards inside `DetailCardsLayout` aligns `Feature.Invoices` with the standard visual language.

## 3. Caveats
- I assumed the double-shell layout in SplitView is redundant but safe; removing it locally might alter visual padding/inset characteristics if container structures mismatch.
- I did not test actual visual display of the inspector panel due to CODE_ONLY network mode restrictions limiting preview rendering.

## 4. Conclusion
We have identified two architectural issues:
1. Duplicate/nested panel shell wraps on Invoice detail view inside `WorkspaceSplitView`, and missing shell styling on NDIS details inside `SmartInspectorResolverView`.
   - **Fix Strategy**: Apply `.standardPanelShell` inside `SmartInspectorResolverView` (or inspector wrapper in `ContentView`) and strip it from individual views (`InvoicesDetailColumn`, `ClientDetailView`, etc.).
2. The invoice inspector editing form uses a monolithic grouped `Form` instead of the standard `DetailCardsLayout` cards.
   - **Fix Strategy**: Refactor `InvoiceEditorFormContent` into 8 separate `GroupBox` card structures and place them inside `DetailCardsLayout`.

No column sizing layout issue using raw width/minWidth literals was identified.

## 5. Verification Method
- **Inspect Files**: Confirm structural observations in:
  - `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesDetailColumn.swift`
  - `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceInspectorFormView.swift`
- **Build & Compile Verification**: Run this command to verify compilation integrity before making edits:
  ```bash
  xcodebuild build -scheme Feature_Invoices -destination "platform=macOS"
  ```
- **Validation check**: After implementing container-level shell placement and card layout refactoring, verify that both the split view details and the inspector details render with standard backgrounds and spacing, and that `xcodebuild` succeeds.
