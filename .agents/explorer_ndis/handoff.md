# Handoff — Feature.NDIS Visual Refresh Exploration
_Type: Hard | Generated: 2026-06-05T23:30:00+10:00_

---

## 1. Observation

### Files Read (all verbatim confirmed via `view_file`)

**Design system (SharedUI):**
- `Packages/SharedUI/Sources/SharedUI/StyleGuide.swift` — Dimensions: paddingXSmall=4, paddingSmall=6, paddingMedium=8, paddingMediumLarge=12, paddingLarge=16, paddingXLarge=24, paddingXXLarge=32; cornerRadiusXSmall=4, Small=8, Medium=12, Large=16
- `Packages/SharedUI/Sources/SharedUI/Theme/ColorSystem.swift` — Primary/Secondary/Status/Neutral/Client/Payee namespaces; raw `Color(red:)` only in Calendar + Accessibility sections
- `Packages/SharedUI/Sources/SharedUI/Layout/PanelShellTokens.swift` — panelHorizontalPadding=16, panelVerticalPadding=12, panelCornerRadius=10, contentListGridSpacing=16
- `Packages/SharedUI/Sources/SharedUI/Layout/PanelShellModifiers.swift` — `standardPanelShell(role:)`, `standardPanelContentPadding()`, `standardContentPanelListInsets()`
- `Packages/SharedUI/Sources/SharedUI/Layout/PanelShellStyle.swift` — roles: `.contentPanel`, `.detailPanel`, `.singlePanel`
- `Packages/SharedUI/Sources/SharedUI/ViewModifiers.swift` — `FormField`, `StatusBadge`, `EnhancedGroupBoxStyle`
- `Packages/SharedUI/Sources/SharedUI/Components/DetailSectionComponents.swift` — `DetailSectionTokens`, `DetailSectionHeader`, `DetailCardsLayout`

**Feature.NDIS views (all 7 files read verbatim):**
- `Views/NDISCatalogueCards.swift` (287 lines)
- `Views/NDISCatalogueColumns.swift` (198 lines)
- `Views/NDISCatalogueNavigationView.swift` (251 lines)
- `Views/NDISCatalogueBreadcrumbBar.swift` (122 lines)
- `Views/NDISChangesSummaryView.swift` (441 lines)
- `Views/NDISDetailCards.swift` (377 lines)
- `Views/EnhancedSupportItemDetailView.swift` (91 lines)
- `Layouts/NDISCatalogueLayouts.swift` (80 lines — utility, no styling)

**Shell commands run:**
```
grep -rn ".padding([0-9" Views/   → 4 hits
grep -rn "RoundedRectangle(cornerRadius:" Views/  → 26 hits
grep -rn "font(.system(size:" Views/  → 9 hits
grep -rn "\.blue\b|\.green\b..." Views/  → 18 hits (named SwiftUI colors)
grep -rn "standardPanelShell|PanelShellRole" Sources/ → none
grep -rn "StatusBadge|FormField|EnhancedGroupBoxStyle" Sources/ → none
grep -rn "GroupBox" Views/  → 4 hits (all in NDISDetailCards.swift)
```

---

## 2. Logic Chain

1. **No panel shells** — `grep standardPanelShell Sources/` returned zero results. `NDISCatalogueContentColumn` and `NDISCatalogueDetailColumn` are the outermost views placed in the app's NavigationSplitView columns. Neither applies `.standardPanelShell(role:)`, meaning they lack the standardized background treatment.

2. **No `EnhancedGroupBoxStyle`** — All 4 `GroupBox` usages in `NDISDetailCards.swift` (lines 11, 67, 180, 238) use the system default `GroupBox` style. `EnhancedGroupBoxStyle` exists in `SharedUI/ViewModifiers.swift:156`.

3. **Local chip reimplementation** — `NDISCatalogueCards.swift:274–285` defines a private `chip(text:icon:tint:)` function producing `HStack+Text+Image` with capsule shape and opacity-keyed background. `StatusBadge` in `ViewModifiers.swift:25` does the same. The chip function diverges only by (a) having an optional leading icon and (b) using `Capsule()` vs `cornerRadius`. Consolidation is possible if `StatusBadge` gains an optional `icon` parameter.

4. **Three parallel chip structs** — `ModernServiceDeliveryChip`, `ModernPriceChip`, `ModernFeatureChip` in `NDISDetailCards.swift` all share identical layout: `HStack + .padding(.horizontal,12).padding(.vertical,8) + RoundedRectangle(8) fill/stroke`. No shared base in SharedUI. These represent a candidate for a new `SharedUI.InfoChip` component.

5. **`formSectionBackground()` extension** — `NDISChangesSummaryView.swift:426–439` defines a local `View` extension duplicating the visual role of `EnhancedGroupBoxStyle` (background + border + clip). This must either be moved to SharedUI or replaced.

6. **Raw numeric padding** — 4 uniform `.padding(<n>)` calls use values (18, 20, 10, 20) not present in `StyleGuide.Dimensions`. 14+ directional padding usages with raw values; most map to existing tokens, but 10, 14, 40, 18, 20 are gaps.

7. **Raw cornerRadius** — All 26 raw cornerRadius values map to existing tokens (4→XSmall, 8→Small, 12→Medium, 16→Large) **except** 10 (breadcrumb shapes), which has no current token (PanelShellTokens.panelCornerRadius=10 exists but is not in StyleGuide.Dimensions).

8. **Raw font sizes** — 9 `.font(.system(size:))` calls. All can be replaced by semantic SwiftUI text styles (`.caption`, `.caption2`, `.callout`, `.title`) or `StyleGuide.Header.titleFont`. The 24pt bold heading in `EnhancedSupportItemDetailView.swift:79` maps to `.title.bold()`.

9. **Named SwiftUI colors not from ColorSystem** — 18 occurrences across 3 files: `.blue`, `.green`, `.orange`, `.purple`, `.red`, `.indigo`, `.yellow`, `.mint`, `.teal`, `.gray`. Most map to existing `ColorSystem` tokens. `.indigo`, `.mint`, `.teal` have no current `ColorSystem` member → require new tokens.

10. **Raw frame widths** — `.frame(width: 32)` (icon circle) and `.frame(width: 42)` (back button) in 2 files. No existing tokens.

---

## 3. Caveats

- **ViewModels not audited** — `NDISContainerViewModel.swift` and extensions are non-visual but may contain color/style logic not captured here.
- **`NDISCatalogueLayouts.swift`** — Contains only a text-width estimator (`IntrinsicContentMeasurer`) with hard-coded character-width estimates (CGFloat 8–24). These are not visual tokens but could be refined separately.
- **`cornerRadius: 10` overlap** — `PanelShellTokens.panelCornerRadius = 10` already exists. A new `StyleGuide.Dimensions.cornerRadiusBreadcrumb = 10` would duplicate the value. Workers should consider whether to reference `PanelShellTokens.panelCornerRadius` directly or add the Dimensions token.
- **`paddingChip` vs `paddingInfoRow`** — Both raw values are `10`. Workers may unify into a single token.
- **`NSColor.systemIndigo`** — Not a guaranteed AppKit system color. ColorSystem.Navigation.groupTint may need to use a different NSColor or hardcode sRGB. Needs verification at implementation.
- **`StatusBadge` icon extension** — Extending `StatusBadge` requires modifying SharedUI. Worker must verify no existing uses break.
- **`standardPanelShell` on sheet views** — `NDISChangesSummaryView` is a sheet (`.sheet` presenter). Panel shell may conflict with `NavigationStack` background. Test on device before committing.

---

## 4. Conclusion

**Feature.NDIS has comprehensive adoption gaps against the SharedUI design system:**

1. **0/3 outermost panels** apply `standardPanelShell`.
2. **0/4 GroupBox usages** apply `EnhancedGroupBoxStyle`.
3. **4 files** contain raw numeric `.padding()` calls unmapped to tokens.
4. **26 occurrences** of raw `cornerRadius` values (all map to existing tokens except `10`).
5. **9 occurrences** of `.font(.system(size:))` replaceable by semantic styles.
6. **18 occurrences** of named SwiftUI colors not routed through `ColorSystem`; `.indigo`, `.mint`, `.teal` have no current `ColorSystem` token.
7. **3 local chip structs** + **1 private chip function** duplicate `StatusBadge`/badge patterns.
8. **1 local `formSectionBackground()` extension** duplicates `EnhancedGroupBoxStyle`.
9. **11 new StyleGuide.Dimensions tokens** and **4 new ColorSystem tokens** required.

Migration is high-volume but mechanical once new tokens exist. Recommended work order: tokens first, SharedUI component additions second, then per-file literal substitution.

---

## 5. Verification Method

### Commands to Verify Raw Literal Removal After Implementation

```bash
# No raw numeric padding (uniform)
grep -rn '\.padding([0-9]' Packages/Feature.NDIS/Sources/Feature_NDIS/Views/

# No raw cornerRadius literals
grep -rn 'cornerRadius: [0-9]' Packages/Feature.NDIS/Sources/Feature_NDIS/Views/

# No raw font sizes
grep -rn 'font(.system(size:' Packages/Feature.NDIS/Sources/Feature_NDIS/Views/

# No named SwiftUI colors (should all route via ColorSystem)
grep -rn '\.blue\b\|\.green\b\|\.red\b\|\.orange\b\|\.purple\b\|\.indigo\b\|\.teal\b\|\.mint\b\|\.gray\b\|\.yellow\b' \
  Packages/Feature.NDIS/Sources/Feature_NDIS/Views/

# Confirm panel shells applied
grep -rn 'standardPanelShell' Packages/Feature.NDIS/Sources/Feature_NDIS/

# Confirm EnhancedGroupBoxStyle applied
grep -rn 'EnhancedGroupBoxStyle' Packages/Feature.NDIS/Sources/Feature_NDIS/
```

### Build Verification
```bash
# After any changes, build Feature.NDIS module
xcodebuild -scheme InvoicingApplication -destination 'platform=macOS' build 2>&1 | tail -20
```

### Invalidation Conditions
- If `StyleGuide.Dimensions` gains new tokens between exploration and implementation, token name map may shift — re-read StyleGuide.swift before coding.
- If `NDISCatalogueColumns.swift` has been refactored to use different outermost view types, panel shell targets change.

---

## Artifact Index
- Full analysis: `.agents/explorer_ndis/analysis.md`
- This handoff: `.agents/explorer_ndis/handoff.md`
