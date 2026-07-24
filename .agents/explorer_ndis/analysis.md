# Feature.NDIS Visual Refresh — Migration Analysis
_Generated: 2026-06-05T23:25:49+10:00_

## Summary
Feature.NDIS has **zero** `standardPanelShell` usage, **zero** `EnhancedGroupBoxStyle` application, local chip/badge implementations duplicating `StatusBadge`, extensive raw numeric literals for padding/cornerRadius/font-size, and several raw SwiftUI named colors. Migration scope spans 7 view files.

---

## Scope

### Files Audited
| File | Size | Role |
|---|---|---|
| `Views/NDISCatalogueCards.swift` | 287 lines | Content grid cards |
| `Views/NDISCatalogueColumns.swift` | 198 lines | Column wrappers (content + detail) |
| `Views/NDISCatalogueNavigationView.swift` | 251 lines | Grid navigation + scroll container |
| `Views/NDISCatalogueBreadcrumbBar.swift` | 122 lines | Breadcrumb navigation bar |
| `Views/NDISChangesSummaryView.swift` | 441 lines | Historical changes sheet |
| `Views/NDISDetailCards.swift` | 377 lines | Detail panel card components |
| `Views/EnhancedSupportItemDetailView.swift` | 91 lines | Outermost detail view |
| `Layouts/NDISCatalogueLayouts.swift` | 80 lines | Text-width estimator utility |

---

## 1. Raw Literal Audit

### 1.1 Raw Numeric Padding — `.padding(<number>)`

| File | Line | Raw Value | Proposed Token |
|---|---|---|---|
| `NDISCatalogueCards.swift` | 70 | `.padding(18)` | `StyleGuide.Dimensions.paddingLarge` (16) or new `paddingCard` (18) |
| `NDISCatalogueCards.swift` | 247 | `.padding(20)` | New token `paddingCardLarge` (20) or `paddingXLarge` (24) — needs design decision |
| `NDISDetailCards.swift` | 277 | `.padding(10)` | New token `paddingChip` (10) or `paddingMediumLarge` (12) |
| `NDISDetailCards.swift` | 307 | `.padding(20)` | New token `paddingCardLarge` (20) |

### 1.2 Raw Directional Padding — `.padding(.<edge>, <number>)`

| File | Line(s) | Raw Value | Proposed Token |
|---|---|---|---|
| `NDISCatalogueCards.swift` | 232 | `.padding(.vertical, 4)` | `paddingXSmall` (4) ✓ |
| `NDISCatalogueCards.swift` | 280–281 | `.padding(.horizontal, 8)` / `.padding(.vertical, 4)` | `paddingMedium` (8) / `paddingXSmall` (4) ✓ |
| `EnhancedSupportItemDetailView.swift` | 86 | `.padding(.horizontal, 24)` | `paddingXLarge` (24) ✓ |
| `EnhancedSupportItemDetailView.swift` | 87 | `.padding(.top, 20)` | New `paddingCardLarge` (20) |
| `EnhancedSupportItemDetailView.swift` | 88 | `.padding(.bottom, 8)` | `paddingMedium` (8) ✓ |
| `NDISChangesSummaryView.swift` | 136 | `.padding(.top, 8)` | `paddingMedium` (8) ✓ |
| `NDISChangesSummaryView.swift` | 386–387 | `.padding(.horizontal, 8)` / `.padding(.vertical, 4)` | `paddingMedium` / `paddingXSmall` ✓ |
| `NDISChangesSummaryView.swift` | 396–397 | `.padding(.horizontal, 8)` / `.padding(.vertical, 4)` | `paddingMedium` / `paddingXSmall` ✓ |
| `NDISDetailCards.swift` | 136–137 | `.padding(.horizontal, 10)` / `.padding(.vertical, 8)` | New `paddingInfoRow` (10) / `paddingMedium` ✓ |
| `NDISDetailCards.swift` | 152–153 | `.padding(.horizontal, 10)` / `.padding(.vertical, 8)` | New `paddingInfoRow` (10) / `paddingMedium` ✓ |
| `NDISDetailCards.swift` | 221–222 | `.padding(.horizontal, 12)` / `.padding(.vertical, 8)` | `paddingMediumLarge` (12) ✓ / `paddingMedium` ✓ |
| `NDISDetailCards.swift` | 359–360 | `.padding(.horizontal, 12)` / `.padding(.vertical, 8)` | `paddingMediumLarge` (12) ✓ / `paddingMedium` ✓ |
| `NDISCatalogueBreadcrumbBar.swift` | 68–69 | `.padding(.vertical, 6)` / `.padding(.horizontal, 14)` | `paddingSmall` (6) ✓ / New `paddingBreadcrumb` (14) |
| `NDISCatalogueColumns.swift` | 191–192 | `.padding(.horizontal, 24)` / `.padding(.vertical, 40)` | `paddingXLarge` (24) ✓ / New `paddingEmptyState` (40) |

### 1.3 Raw `cornerRadius(<number>)`

| File | Line(s) | Raw Value | Proposed Token |
|---|---|---|---|
| `NDISCatalogueCards.swift` | 29, 208 | `cornerRadius: 12` | `cornerRadiusMedium` (12) ✓ |
| `NDISChangesSummaryView.swift` | 187, 190, 336, 339, 431, 434, 438 | `cornerRadius: 8` | `cornerRadiusSmall` (8) ✓ |
| `NDISChangesSummaryView.swift` | 389, 399 | `cornerRadius: 4` | `cornerRadiusXSmall` (4) ✓ |
| `NDISCatalogueNavigationView.swift` | 72, 84 | `cornerRadius: 16` | `cornerRadiusLarge` (16) ✓ |
| `NDISDetailCards.swift` | 158, 161 | `cornerRadius: 8` | `cornerRadiusSmall` (8) ✓ |
| `NDISDetailCards.swift` | 224, 228, 279, 283, 362, 366 | `cornerRadius: 8` | `cornerRadiusSmall` (8) ✓ |
| `NDISDetailCards.swift` | 309, 313 | `cornerRadius: 12` | `cornerRadiusMedium` (12) ✓ |
| `NDISCatalogueBreadcrumbBar.swift` | 27, 55 | `cornerRadius: 10` | New `cornerRadiusBreadcrumb` (10) — no existing match |

### 1.4 Raw Font Sizes — `.font(.system(size:))`

| File | Line | Raw Value | Proposed Token / Semantic Font |
|---|---|---|---|
| `NDISCatalogueCards.swift` | 38 | `.font(.system(size: 16, weight: .semibold))` | `.font(.callout.weight(.semibold))` or new `StyleGuide.Fonts.cardIcon` |
| `NDISCatalogueCards.swift` | 66 | `.font(.system(size: 14, weight: .semibold))` | `.font(.subheadline.weight(.semibold))` |
| `EnhancedSupportItemDetailView.swift` | 74 | `.font(.system(size: 16, weight: .medium))` | `.font(.callout.weight(.medium))` or `StyleGuide.Header.titleFont` |
| `EnhancedSupportItemDetailView.swift` | 79 | `.font(.system(size: 24, weight: .bold))` | `.font(.title.bold())` or new `StyleGuide.Fonts.detailTitle` |
| `NDISDetailCards.swift` | 124, 131, 146 | `.font(.system(size: 12 / 12))` | `.font(.caption)` |
| `NDISDetailCards.swift` | 141 | `.font(.system(size: 11, weight: .semibold))` | `.font(.caption2.weight(.semibold))` |
| `NDISCatalogueBreadcrumbBar.swift` | 38 | `.font(.system(size: 15, weight: .semibold, design: .rounded))` | New `StyleGuide.Fonts.breadcrumbBack` or `.font(.subheadline.weight(.semibold))` |

### 1.5 Raw RGB Colors — `Color(red:)`
**None found** in Feature.NDIS views. (ColorSystem.swift itself has some in Calendar/Accessibility, but these are in SharedUI not NDIS.)

### 1.6 Named SwiftUI Colors (not from ColorSystem)

| File | Lines | Raw Colors | Proposed Token |
|---|---|---|---|
| `NDISCatalogueCards.swift` | 17–18 | `Color.indigo`, `Color.purple` | `ColorSystem.Secondary.purple` (purple), no indigo token → new `ColorSystem.Navigation.groupTint` / `.categoryTint` |
| `NDISChangesSummaryView.swift` | 56–91 | `.blue`, `.green`, `.orange`, `.purple`, `.red`, `.indigo` | `ColorSystem.Primary.blue`, `ColorSystem.Secondary.green/orange/purple`, `ColorSystem.Status.error` (red), `ColorSystem.Secondary.purple` (indigo) |
| `NDISChangesSummaryView.swift` | 347–357 | `.blue`, `.orange`, `.green`, `.purple`, `.yellow`, `.mint`, `.gray`, `.red`, `.indigo`, `.teal` | Map to `ColorSystem.Status.*` and `ColorSystem.Secondary.*`; `.mint`, `.teal` have no ColorSystem token → new `ColorSystem.Status.new` / `.groupChange` needed |
| `NDISCatalogueBreadcrumbBar.swift` | 104–105 | `Color.purple.opacity(0.15)`, `Color.indigo.opacity(0.15)` | New `ColorSystem.Navigation.*` or re-use category/group tint pattern |

### 1.7 Raw Frame Width — `.frame(width: <number>)`

| File | Line | Raw Value | Proposed Token |
|---|---|---|---|
| `NDISCatalogueCards.swift` | 35 | `.frame(width: 32, height: 32)` | New `StyleGuide.Dimensions.iconCircleSize` (32) |
| `NDISCatalogueBreadcrumbBar.swift` | 31 | `.frame(width: 42)` | New `StyleGuide.Dimensions.backButtonWidth` (42) |

---

## 2. Panel Shell Audit

**None of the NDIS views apply `.standardPanelShell(role:)`.**

| View | Is Outermost Panel? | Required Role | Current Background |
|---|---|---|---|
| `NDISCatalogueContentColumn` | Yes — content list panel | `.contentPanel` | None (transparent, toolbar-hosted) |
| `NDISCatalogueDetailColumn` | Yes — detail panel | `.detailPanel` | None (transparent) |
| `NDISCatalogueNavigationView` | Sub-view of content | Not directly — defer to column | `.background(.clear)` |
| `EnhancedSupportItemDetailView` | Sub-view of detail column | Not directly — defer to column | `.background(.clear)` |
| `NDISChangesSummaryView` | Sheet — separate modal | `.singlePanel` | `NavigationStack` default |

**Action:** Apply `.standardPanelShell(role: .contentPanel)` to `NDISCatalogueContentColumn.body` and `.standardPanelShell(role: .detailPanel)` to `NDISCatalogueDetailColumn.body`. Apply `.standardPanelShell(role: .singlePanel)` to the root `VStack` in `NDISChangesSummaryView`.

---

## 3. Component Duplication

### 3.1 Local Chip Functions vs `StatusBadge`

**`NDISCatalogueCards.swift` lines 274–285** — private `chip(text:icon:tint:)` function:
```swift
private func chip(text: String, icon: String, tint: Color) -> some View {
    HStack(spacing: 4) {
        Image(systemName: icon)
        Text(text)
    }
    .font(.caption2.weight(.semibold))
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(tint.opacity(colorScheme == .dark ? 0.2 : 0.12))
    .foregroundColor(colorScheme == .dark ? tint.opacity(0.9) : tint)
    .clipShape(Capsule())
}
```
This is a local badge reimplementation. `StatusBadge` from SharedUI covers the same pattern (tinted background, foreground color, corner clip). **Replace with `StatusBadge("Historical", color: tint)`** or extend `StatusBadge` to support an optional leading icon.

### 3.2 `ModernServiceDeliveryChip`, `ModernPriceChip`, `ModernFeatureChip` (NDISDetailCards.swift)

These three local structs (lines 199–232, 255–287, 319–370) each:
- Apply `.padding(.horizontal, 12).padding(.vertical, 8)`
- Use `RoundedRectangle(cornerRadius: 8)`
- Apply `.fill(someColor.opacity(0.1))` + `.stroke(someColor.opacity(0.3))`

**Pattern is consistent** with a generalized `TintedChip(label:icon:color:available:)` component that should live in SharedUI. `StatusBadge` currently uses `Capsule` shape; these chips use `RoundedRectangle(8)` — different shape family, warrants a new `SharedUI.TintedChip` or `SharedUI.InfoChip` component.

### 3.3 `formSectionBackground()` Extension (NDISChangesSummaryView.swift lines 426–439)

Local View extension defining background + border + clipShape with `cornerRadius: 8`. This duplicates the visual role of `EnhancedGroupBoxStyle`. Should either:
- Be replaced by `GroupBox { } .groupBoxStyle(EnhancedGroupBoxStyle())`
- Or extracted to SharedUI as a named modifier

### 3.4 `GroupBox` Usages Without `EnhancedGroupBoxStyle` (NDISDetailCards.swift)

Four `GroupBox` usages at lines 11, 67, 180, 238 use the default `GroupBox` style. Each should receive `.groupBoxStyle(EnhancedGroupBoxStyle())` to get the standard fill/stroke/shadow treatment.

---

## 4. Token Gaps

The following raw values have **no current StyleGuide.Dimensions match**:

| Raw Value | Context | Proposed New Token |
|---|---|---|
| `18` (uniform padding) | Navigation node card outer padding | `StyleGuide.Dimensions.paddingCard` = 18 |
| `20` (uniform padding) | Item card outer padding, NoPriceCard padding | `StyleGuide.Dimensions.paddingCardLarge` = 20 |
| `10` (uniform padding) | ModernPriceChip outer padding | `StyleGuide.Dimensions.paddingChip` = 10 |
| `10` (horizontal padding) | infoRow horizontal padding | `StyleGuide.Dimensions.paddingInfoRow` = 10 |
| `14` (horizontal padding) | Breadcrumb segment horizontal padding | `StyleGuide.Dimensions.paddingBreadcrumbH` = 14 |
| `40` (vertical padding) | Empty state vertical padding | `StyleGuide.Dimensions.paddingEmptyState` = 40 |
| `10` (cornerRadius) | Breadcrumb back button + segment shapes | `StyleGuide.Dimensions.cornerRadiusBreadcrumb` = 10 |
| `32` (frame size) | Icon circle in navigation node card | `StyleGuide.Dimensions.iconCircleSize` = 32 |
| `42` (frame width) | Back button width in breadcrumb | `StyleGuide.Dimensions.backButtonWidth` = 42 |
| `110` / `160` (minHeight) | Card minimum heights | `StyleGuide.Dimensions.cardMinHeightSmall` = 110, `cardMinHeight` = 160 |
| `Color.indigo` / `Color.teal` / `Color.mint` | Navigation tints, change type colors | `ColorSystem.Navigation.categoryTint`, `ColorSystem.Navigation.groupTint`, `ColorSystem.Status.new`, `ColorSystem.Status.groupChange` |

---

## 5. Concrete Change Plan

### `NDISCatalogueCards.swift`

| Location | Current | Replace With |
|---|---|---|
| L17–18 | `Color.indigo` / `Color.purple` | `ColorSystem.Navigation.groupTint` / `ColorSystem.Navigation.categoryTint` (new tokens) |
| L29, L208 | `RoundedRectangle(cornerRadius: 12, ...)` | `StyleGuide.Dimensions.cornerRadiusMedium` |
| L35 | `.frame(width: 32, height: 32)` | `StyleGuide.Dimensions.iconCircleSize` |
| L38 | `.font(.system(size: 16, weight: .semibold))` | `.font(.callout.weight(.semibold))` |
| L66 | `.font(.system(size: 14, weight: .semibold))` | `.font(.subheadline.weight(.semibold))` |
| L70 | `.padding(18)` | `.padding(StyleGuide.Dimensions.paddingCard)` (new token = 18) |
| L82 | `tint.opacity(0.2)` (stroke) | Stays — no existing opacity token at 0.2; use `StyleGuide.Opacity.medium` (0.2) ✓ |
| L232 | `.padding(.vertical, 4)` | `.padding(.vertical, StyleGuide.Dimensions.paddingXSmall)` |
| L247 | `.padding(20)` | `.padding(StyleGuide.Dimensions.paddingCardLarge)` (new token = 20) |
| L250 | `minHeight: 160` | `minHeight: StyleGuide.Dimensions.cardMinHeight` (new token = 160) |
| L73 | `minHeight: 110` | `minHeight: StyleGuide.Dimensions.cardMinHeightSmall` (new token = 110) |
| L274–285 | Local `chip()` function | Replace call at L221 with `StatusBadge("Historical", color: tint)` (extend StatusBadge to support icon) |
| L280–281 | `.padding(.horizontal, 8)` / `.padding(.vertical, 4)` | `paddingMedium` / `paddingXSmall` ✓ (only if chip not removed) |

### `NDISCatalogueNavigationView.swift`

| Location | Current | Replace With |
|---|---|---|
| L72, L84 | `RoundedRectangle(cornerRadius: 16, ...)` | `StyleGuide.Dimensions.cornerRadiusLarge` |
| Body of `NDISCatalogueContentColumn` | No panel shell | Add `.standardPanelShell(role: .contentPanel)` to root view |

### `NDISCatalogueBreadcrumbBar.swift`

| Location | Current | Replace With |
|---|---|---|
| L27, L55 | `RoundedRectangle(cornerRadius: 10, ...)` | `StyleGuide.Dimensions.cornerRadiusBreadcrumb` (new = 10) |
| L31 | `.frame(width: 42)` | `StyleGuide.Dimensions.backButtonWidth` (new = 42) |
| L38 | `.font(.system(size: 15, weight: .semibold, design: .rounded))` | `.font(.subheadline.weight(.semibold))` (drop exact size) |
| L68–69 | `.padding(.vertical, 6)` / `.padding(.horizontal, 14)` | `paddingSmall` / `paddingBreadcrumbH` (new = 14) |
| L104–105 | `Color.purple.opacity(0.15)` / `Color.indigo.opacity(0.15)` | `ColorSystem.Navigation.categoryTint.opacity(StyleGuide.Opacity.light)` / `ColorSystem.Navigation.groupTint.opacity(StyleGuide.Opacity.light)` |
| L106 | `Color.primary.opacity(0.08)` | `Color.primary.opacity(StyleGuide.Opacity.faint)` (0.08) ✓ |

### `NDISChangesSummaryView.swift`

| Location | Current | Replace With |
|---|---|---|
| L56, L63, L70, L77, L84, L91 | `.blue`, `.green`, `.orange`, `.purple`, `.red`, `.indigo` | `ColorSystem.Primary.blue`, `ColorSystem.Secondary.green`, `ColorSystem.Secondary.orange`, `ColorSystem.Secondary.purple`, `ColorSystem.Status.error`, `ColorSystem.Secondary.purple` |
| L187, L190, L336, L339, L431, L434, L438 | `cornerRadius: 8` | `StyleGuide.Dimensions.cornerRadiusSmall` |
| L389, L399 | `cornerRadius: 4` | `StyleGuide.Dimensions.cornerRadiusXSmall` |
| L347–357 | `.blue`, `.orange`, `.green`, `.purple`, `.yellow`, `.mint`, `.gray`, `.red`, `.indigo`, `.teal` | Map to `ColorSystem.Status.*` / `ColorSystem.Secondary.*`; add `ColorSystem.Status.new` (.mint), `.groupChange` (.teal) |
| L426–439 | Local `formSectionBackground()` extension | Move to SharedUI as `formSectionBackground()` or replace with `.groupBoxStyle(EnhancedGroupBoxStyle())` |
| L96, L139 | `.formSectionBackground()` calls | Update call-site once moved |
| Root `VStack` | No panel shell | `.standardPanelShell(role: .singlePanel)` |

### `NDISDetailCards.swift`

| Location | Current | Replace With |
|---|---|---|
| L11, L67, L180, L238 | `GroupBox { }` (default style) | `GroupBox { }.groupBoxStyle(EnhancedGroupBoxStyle())` |
| L124 | `.font(.system(size: 12, weight: .semibold))` | `.font(.caption.weight(.semibold))` |
| L131, L146 | `.font(.system(size: 12))` | `.font(.caption)` |
| L141 | `.font(.system(size: 11, weight: .semibold))` | `.font(.caption2.weight(.semibold))` |
| L136–137, L152–153 | `.padding(.horizontal, 10)` / `.padding(.vertical, 8)` | `paddingInfoRow` (new = 10) / `paddingMedium` ✓ |
| L158, L161 | `cornerRadius: 8` | `StyleGuide.Dimensions.cornerRadiusSmall` |
| L204 | `HStack(alignment: .top, spacing: 6)` | spacing: `StyleGuide.Dimensions.paddingSmall` (6) ✓ |
| L221–222, L359–360 | `.padding(.horizontal, 12)` / `.padding(.vertical, 8)` | `paddingMediumLarge` / `paddingMedium` ✓ |
| L224, L228, L279, L283, L362, L366 | `cornerRadius: 8` | `StyleGuide.Dimensions.cornerRadiusSmall` |
| L277 | `.padding(10)` | `StyleGuide.Dimensions.paddingChip` (new = 10) |
| L307 | `.padding(20)` | `StyleGuide.Dimensions.paddingCardLarge` (new = 20) |
| L309, L313 | `cornerRadius: 12` | `StyleGuide.Dimensions.cornerRadiusMedium` |
| L199–232, L255–287, L319–370 | `ModernServiceDeliveryChip`, `ModernPriceChip`, `ModernFeatureChip` | Extract common pattern to new `SharedUI.InfoChip(label:icon:color:available:)` |

### `EnhancedSupportItemDetailView.swift`

| Location | Current | Replace With |
|---|---|---|
| L74 | `.font(.system(size: 16, weight: .medium))` | `.font(.callout.weight(.medium))` |
| L79 | `.font(.system(size: 24, weight: .bold))` | `.font(.title.bold())` |
| L86 | `.padding(.horizontal, 24)` | `StyleGuide.Dimensions.paddingXLarge` ✓ |
| L87 | `.padding(.top, 20)` | `StyleGuide.Dimensions.paddingCardLarge` (new = 20) |
| L88 | `.padding(.bottom, 8)` | `StyleGuide.Dimensions.paddingMedium` ✓ |

### `NDISCatalogueColumns.swift`

| Location | Current | Replace With |
|---|---|---|
| L191–192 | `.padding(.horizontal, 24)` / `.padding(.vertical, 40)` | `paddingXLarge` ✓ / `paddingEmptyState` (new = 40) |
| `NDISCatalogueContentColumn.body` | No panel shell | `.standardPanelShell(role: .contentPanel)` |
| `NDISCatalogueDetailColumn.body` | No panel shell | `.standardPanelShell(role: .detailPanel)` |

---

## 6. New Tokens Required in StyleGuide.Dimensions

```swift
// Proposed additions to StyleGuide.Dimensions
public static let paddingCard: CGFloat = 18.0
public static let paddingCardLarge: CGFloat = 20.0
public static let paddingChip: CGFloat = 10.0
public static let paddingInfoRow: CGFloat = 10.0        // same value as paddingChip — consider merging
public static let paddingBreadcrumbH: CGFloat = 14.0
public static let paddingEmptyState: CGFloat = 40.0
public static let cornerRadiusBreadcrumb: CGFloat = 10.0
public static let iconCircleSize: CGFloat = 32.0
public static let backButtonWidth: CGFloat = 42.0
public static let cardMinHeightSmall: CGFloat = 110.0
public static let cardMinHeight: CGFloat = 160.0
```

## 7. New Tokens Required in ColorSystem

```swift
// Proposed additions to ColorSystem.Navigation (new namespace)
public struct Navigation {
    public static let categoryTint = Color(NSColor.systemPurple)
    public static let groupTint = Color(NSColor.systemIndigo)  // NSColor.systemIndigo may not exist; use .systemBlue with purple hue
}

// Proposed additions to ColorSystem.Status
public static let new = Color(NSColor.systemMint)    // for .newItem change type
public static let groupChange = Color(NSColor.systemTeal)  // for grouped change types
```

---

## 8. Files With Zero Raw Literal Issues (clean)

- `Layouts/NDISCatalogueLayouts.swift` — utility only, no SwiftUI styling
- `NDISWorkspaceFactory.swift` — factory only

---

## Priority Order for Worker

1. **New tokens** — Add to StyleGuide.Dimensions + ColorSystem before any view work
2. **SharedUI components** — Migrate `formSectionBackground()` to SharedUI; create `InfoChip`; consider extending `StatusBadge` with icon support  
3. **Panel shells** — Apply to NDISCatalogueContentColumn, NDISCatalogueDetailColumn, NDISChangesSummaryView
4. **GroupBox styles** — Apply `EnhancedGroupBoxStyle` to 4 GroupBox usages in NDISDetailCards.swift
5. **Per-file literal substitution** — In order: NDISDetailCards.swift → NDISCatalogueCards.swift → NDISCatalogueBreadcrumbBar.swift → NDISChangesSummaryView.swift → EnhancedSupportItemDetailView.swift → NDISCatalogueColumns.swift
