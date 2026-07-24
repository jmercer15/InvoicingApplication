# NDIS Codebase Design-Token and Layout Standardization Report

This report presents direct observations and findings regarding the unification of design-tokens (spacing, padding, corner-radius, color, and typography) and panel shell layouts under the `Packages/Feature.NDIS` module.

---

## 1. Observation

All direct observations and file references within `Packages/Feature.NDIS`:

### A. Raw Spacing, Padding, and Shape Dimensions Literals
The following files contain raw numeric spacing or padding values, or shape dimensions:
1. **`Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISChangesSummaryView.swift`**
   - **Line 22**: `VStack(spacing: 20) {` — Raw spacing height `20`.
   - **Line 26**: `.padding()` — Uses system default padding without specific tokens.
   - **Line 217**: `.padding(.horizontal)` — Uses system default padding.
   - **Line 228**: `.padding()` — Uses system default padding.
   - **Line 235**: `.padding()` — Uses system default padding.
   - **Line 375**: `VStack(alignment: .leading, spacing: 4) {` — Raw spacing height `4`.
2. **`Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISDetailCards.swift`**
   - **Line 211**: `.padding(.top, 1)` — Raw numeric padding offset `1`.
   - **Line 363**: `.padding(.top, 1)` — Raw numeric padding offset `1`.
3. **`Packages/Feature.NDIS/Sources/Feature_NDIS/Layouts/NDISCatalogueLayouts.swift`**
   - **Line 14**: `padding: CGFloat = 18` — Raw layout padding parameter default.
   - **Line 21**: `let minReadableWidth: CGFloat = 200` — Raw layout constant `200`.
   - **Line 63**: `padding: CGFloat = 18` — Raw layout padding parameter default.
   - **Line 74**: `let minCardWidth: CGFloat = 240` — Raw layout constant `240`.
   - **Line 75**: `let maxCardWidth: CGFloat = 400` — Raw layout constant `400`.
4. **`Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueNavigationView.swift`**
   - **Line 21**: `private static let cardMinimumWidth: CGFloat = 260` — Raw grid item packaging layout constant.

---

### B. Raw Colors, Hexes, and Opacity/LineWidth Modifiers
The following files contain raw SwiftUI colors, legacy color extensions, direct modifier offsets, or raw line widths:
1. **`Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueCards.swift`**
   - **Line 34**: `.fill(tint.opacity(0.16))` — Raw opacity multiplier `0.16`.
   - **Line 48**: `.foregroundColor(.primary)` — Raw SwiftUI semantic color `.primary`.
   - **Line 53**: `.foregroundColor(.secondary)` — Raw SwiftUI semantic color `.secondary`.
   - **Line 70**: `.foregroundColor(.secondary)` — Raw SwiftUI semantic color `.secondary`.
   - **Line 82**: `.fill(tint.opacity(0.06))` — Raw opacity multiplier `0.06`.
   - **Line 85**: `.stroke(tint.opacity(StyleGuide.Opacity.medium), lineWidth: 0.8)` — Raw stroke line width `0.8`.
   - **Line 249**: `.foregroundColor(subtitleColor.opacity(0.7))` — Raw opacity multiplier `0.7`.
   - **Line 264**: `.stroke(StyleGuide.Colors.border, lineWidth: 0.6)` — Raw stroke line width `0.6`.
   - **Line 269**: `shape.stroke(Color.accentColor, lineWidth: 2)` — Raw accent color reference and stroke width `2`.
2. **`Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISDetailCards.swift`**
   - **Line 114**: `valueColor: item.quoteRequired == true ? ColorSystem.Status.warning : Color.statusActive` — Uses `Color.statusActive`, which is a legacy/un-unified `Color` extension.
   - **Line 210**: `.foregroundStyle(isAvailable ? Color.statusActive : Color.statusCancelled)` — Uses legacy `Color.statusActive` and `Color.statusCancelled` extensions.
   - **Line 292**: `.fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05))` — Uses `Color.accentColor` directly, and raw opacities `0.12` and `0.05`.
   - **Line 298**: `lineWidth: 1` — Raw stroke line width.
   - **Line 329**: `.stroke(ColorSystem.Status.inactive.opacity(StyleGuide.Opacity.strong), lineWidth: 1)` — Raw stroke line width.
   - **Line 382**: `.stroke(ColorSystem.Secondary.green.opacity(StyleGuide.Opacity.strong), lineWidth: 1)` — Raw stroke line width.
3. **`Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueNavigationView.swift`**
   - **Line 73**: `.fill(Color.primary.opacity(StyleGuide.Opacity.faint - 0.02))` — Uses subtraction offset on opacity tokens.
   - **Line 85**: `.fill(Color.primary.opacity(StyleGuide.Opacity.faint - 0.02))` — Uses subtraction offset on opacity tokens.
4. **`Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISChangesSummaryView.swift`**
   - **Line 192**: `.stroke(color.opacity(StyleGuide.Opacity.strong), lineWidth: 1)` — Raw stroke width.
   - **Line 336**: `.stroke(colorForChangeType(change.changeType).opacity(StyleGuide.Opacity.strong), lineWidth: 1)` — Raw stroke width.
   - **Line 384**: `.background(ColorSystem.Status.error.opacity(0.29))` — Raw opacity multiplier `0.29`.
   - **Line 394**: `.background(ColorSystem.Status.success.opacity(StyleGuide.Opacity.light + 0.1))` — Uses raw addition offset on opacity token.
5. **`Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueBreadcrumbBar.swift`**
   - **Line 51**: `ColorSystem.Navigation.categoryTint.opacity(StyleGuide.Opacity.light + 0.05)` — Uses raw addition offset on opacity token.
   - **Line 52**: `ColorSystem.Navigation.groupTint.opacity(StyleGuide.Opacity.light + 0.05)` — Uses raw addition offset on opacity token.
   - **Line 53**: `Color.primary.opacity(StyleGuide.Opacity.faint + 0.02)` — Uses raw addition offset on opacity token.

---

### C. Raw Font-Size Literals
- There are **no raw font-size literals** (such as `.font(.system(size: ...))`) in the `Feature.NDIS` module.
- However, standard SwiftUI semantic fonts (e.g. `.font(.headline)`, `.font(.caption)`) are used instead of `StyleGuide.Typography` tokens in several files:
  - **`NDISCatalogueCards.swift`**: Lines 47, 52, 62, 231, 241, 248.
  - **`NDISChangesSummaryView.swift`**: Lines 106, 131, 171, 176, 181, 208, 248, 254, 377, 416.
  - **`NDISDetailCards.swift`**: Lines 275, 284, 308, 312, 317, 361, 365.

---

### D. Gaps in Panel Shell Adoption
- **Outer layout panels** (`NDISCatalogueNavigationView` and `EnhancedSupportItemDetailView`) are correctly encapsulated inside AppShell's `WorkspaceSplitView`, which automatically adopts `.standardPanelShell(role:)`.
- **`NDISChangesSummaryView`** correctly adopts `.standardPanelShell(role: .singlePanel)` on line 30.
- **`ItemHistoryDetailView`** (defined in `NDISChangesSummaryView.swift` line 198) is presented as a sheet but does **not** adopt standard shell content padding or transition structures. It has:
  ```swift
  VStack(spacing: FormSectionTokens.formGroupSpacing) {
      // Header
      HStack { ... }
      .padding(.horizontal)
      ScrollView {
          LazyVStack(alignment: .leading, spacing: FormSectionTokens.formGroupSpacing) {
              ...
          }
          .padding()
      }
  }
  ```
  Instead of utilizing unified panel shell layout elements.

---

## 2. Logic Chain

1. **Standard Design Token Source Identification**: Under the project rules, `StyleGuide.swift` defines unified spacing (e.g., `StyleGuide.Dimensions.padding*`), corner radii, and semantic typography. `ColorSystem.swift` defines primary, secondary, navigation, status, and neutral colors.
2. **Search and Analysis**: Using `grep_search` and manual view inspection of all Swift files in `Packages/Feature.NDIS`, we located references to raw numbers for padding, spacing, opacities, and raw/legacy color values.
3. **Color Gaps Deduction**: Legacy color extensions defined in `Color+Extensions.swift` (such as `Color.statusActive` and `Color.statusCancelled`) were found in `NDISDetailCards.swift`. Since the system provides `ColorSystem.Status.success` and `ColorSystem.Status.error`, using these legacy helpers represents a design token gap.
4. **Opacity Offset Deduction**: Using numeric modifications (e.g. `Opacity.light + 0.05` or `Opacity.faint - 0.02`) bypasses standard token mappings and causes visual inconsistency.
5. **Sheet Layout Deduction**: `ItemHistoryDetailView` uses raw `.padding()` instead of `.standardPanelContentPadding()` or matching list insets, breaking consistent inset rules.

---

## 3. Caveats

- **Scope boundaries**: No files were modified, following the read-only requirement. Only package tests were run to verify build and test status.
- **Assumptions**: We assume the target margins and borders for NDIS catalogue items are expected to align with lists in other modules (e.g. Clients, Relationships), which use standard `ListRowTokens` stroke widths.

---

## 4. Conclusion

The `Packages/Feature.NDIS` module is well-structured and uses design tokens for most features, but contains minor layout and color token gaps. These gaps consist of:
1. **Raw spacing & padding literals** in `NDISChangesSummaryView` and `NDISDetailCards`.
2. **Legacy status colors** (`Color.statusActive` / `Color.statusCancelled`) and raw opacities in `NDISCatalogueCards` and `NDISDetailCards`.
3. **Sub-panel shell margins** in `ItemHistoryDetailView` not utilizing standardized view modifiers.

---

## 5. Recommendations and Code Patterns

### Spacing and Margin Standardization

#### A. Standardize Spacing in `NDISChangesSummaryView.swift`
- **Before (Lines 22, 375)**:
  ```swift
  VStack(spacing: 20) {
  // ...
  VStack(alignment: .leading, spacing: 4) {
  ```
- **After**:
  ```swift
  VStack(spacing: StyleGuide.Dimensions.paddingSheetContent) {
  // ...
  VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
  ```

#### B. Standardize Padding in `NDISDetailCards.swift`
- **Before (Lines 211, 363)**:
  ```swift
  .padding(.top, 1)
  ```
- **After**: Remove raw `.padding(.top, 1)` or replace with a dedicated layout offset token if fine adjustment is needed.

#### C. Standardize Card Packaging Widths in `NDISCatalogueNavigationView.swift`
- **Before (Line 21)**:
  ```swift
  private static let cardMinimumWidth: CGFloat = 260
  ```
- **After**:
  ```swift
  private static let cardMinimumWidth: CGFloat = DetailSectionTokens.catalogueChipMinWidth // or standard token
  ```

---

### Color and Opacity Standardization

#### A. Replace Legacy Status Colors in `NDISDetailCards.swift`
- **Before (Lines 114, 210)**:
  ```swift
  valueColor: item.quoteRequired == true ? ColorSystem.Status.warning : Color.statusActive
  // ...
  .foregroundStyle(isAvailable ? Color.statusActive : Color.statusCancelled)
  ```
- **After**:
  ```swift
  valueColor: item.quoteRequired == true ? ColorSystem.Status.warning : ColorSystem.Status.success
  // ...
  .foregroundStyle(isAvailable ? ColorSystem.Status.success : ColorSystem.Status.error)
  ```

#### B. Standardize Opacity Values in `NDISCatalogueCards.swift`
- **Before (Lines 34, 82, 249)**:
  ```swift
  .fill(tint.opacity(0.16))
  // ...
  .fill(tint.opacity(0.06))
  // ...
  .foregroundColor(subtitleColor.opacity(0.7))
  ```
- **After**: Use standard opacity levels defined in `StyleGuide.Opacity` (e.g. `StyleGuide.Opacity.subtle`, `StyleGuide.Opacity.light`):
  ```swift
  .fill(tint.opacity(StyleGuide.Opacity.medium))
  // ...
  .fill(tint.opacity(StyleGuide.Opacity.subtle))
  // ...
  .foregroundColor(subtitleColor.opacity(StyleGuide.Opacity.strong)) // or similar
  ```

#### C. Remove Opacity Offset Logic
- **Before (`NDISCatalogueBreadcrumbBar.swift` Lines 51-53)**:
  ```swift
  ColorSystem.Navigation.categoryTint.opacity(StyleGuide.Opacity.light + 0.05)
  ```
- **After**: Use a constant opacity token directly (e.g., `StyleGuide.Opacity.medium`).

---

### Stroke Width Standardization

#### A. Standardize Borders in `NDISCatalogueCards.swift` and `NDISDetailCards.swift`
- **Before**:
  ```swift
  .stroke(StyleGuide.Colors.border, lineWidth: 0.6)
  shape.stroke(Color.accentColor, lineWidth: 2)
  ```
- **After**:
  ```swift
  .stroke(StyleGuide.Colors.border, lineWidth: ListRowTokens.defaultStrokeWidth)
  shape.stroke(ColorSystem.Primary.blue, lineWidth: ListRowTokens.selectedStrokeWidth)
  ```

---

### Sub-Panel Layout Standardization

#### A. Standardize Padding in `ItemHistoryDetailView` (`NDISChangesSummaryView.swift`)
- **Before**:
  ```swift
  VStack(spacing: FormSectionTokens.formGroupSpacing) {
      // Header
      HStack { ... }
      .padding(.horizontal)
      ScrollView {
          LazyVStack(alignment: .leading, spacing: FormSectionTokens.formGroupSpacing) { ... }
          .padding()
      }
  }
  ```
- **After**: Adopt the panel content padding and list layout helpers:
  ```swift
  VStack(spacing: FormSectionTokens.formGroupSpacing) {
      // Header
      HStack { ... }
      .standardPanelContentPadding()
      ScrollView {
          LazyVStack(alignment: .leading, spacing: FormSectionTokens.formGroupSpacing) { ... }
          .standardContentPanelListInsets()
      }
  }
  ```

---

## 6. Verification Method

To independently verify this report's findings:
1. Run package tests to ensure everything builds cleanly:
   ```bash
   swift test --package-path Packages/Feature.NDIS
   ```
2. Inspect the files listed in the **Observation** section of this report (`handoff.md`).
3. Verify that these line numbers and snippets match the raw literals in the current codebase state.
