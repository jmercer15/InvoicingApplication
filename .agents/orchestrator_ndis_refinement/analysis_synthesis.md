# NDIS UI Refinement Analysis Synthesis

We have synthesized the findings of three Explorer subagents. The primary areas requiring refinement are:

## 1. Component Elevation & Visual Hierarchy
- **Breadcrumb Separator**: Add a native `Divider` or shadow between the `NDISCatalogueBreadcrumbBar` and the main body panels in `NDISCatalogueNavigationView.swift`.
- **Card Elevation**: Apply shadow depth cues and borders to `NDISCatalogueNavigationNodeCard` and `NDISCatalogueCard` in `NDISCatalogueCards.swift` so they appear visually elevated.
- **Inconsistent Backgrounds**: Replace generic `StyleGuide` opacity text backgrounds with semantic panel tokens in `NDISCatalogueNavigationView.swift` and `NDISDetailCards.swift`.
- **Vertical Spacing**: Increase vertical title spacing proportions in `EnhancedSupportItemDetailView.swift` to align with column margins.
- **Summary Form Background Collision**: Resolve cards blending into their form background in `NDISChangesSummaryView.swift` by using secondary panel backgrounds or Material fills.

## 2. State Polish
- **View Model States**:
  - Expose `hasLoadedCatalogue` and `loadError` in `NDISContainerViewModel`.
  - Expose `changesError` or proper error reporting in `NDISContainerViewModel` for the changes summary view.
- **Navigation View States**:
  - Render a loading `ProgressView` in `NDISCatalogueNavigationView` when `!viewModel.hasLoadedCatalogue`.
  - Render an error state view with a "Retry" button when `viewModel.loadError` is non-nil.
- **Changes Summary View States**:
  - Polish loading view styling (add appropriate container size, centering, margins).
  - Add an error state display with a retry action if analyzing changes fails.

## 3. Visual Feedback & Affordances
- **Hover Highlights**:
  - Implement `@State private var isHovered` and `.onHover` to provide background and border highlight cues on `NDISCatalogueNavigationNodeCard`, `NDISCatalogueCard`, and `ModernPriceChip`.
- **Focus Rings**:
  - Add `.focusable()` and track `@FocusState` to render custom outline rings when navigated via keyboard/accessibility shortcuts on `NDISCatalogueNavigationNodeCard`, `NDISCatalogueCard`, and `ModernPriceChip`.

## 4. Accessibility & WCAG AA Compliance
- **Color Contrast**:
  - Make "OLD" and "NEW" overlays in `NDISChangesSummaryView` solid badges with white text foregrounds instead of low-contrast status text on translucent status backgrounds.
  - Darken orange text or use a solid status badge for quote-required pricing status in `NDISCatalogueCards.swift` / `NDISDetailCards.swift` to meet the 4.5:1 ratio.
- **Screen Reader Labels & Hints**:
  - Add explicit VoiceOver labels and hints for `NDISCatalogueNavigationNodeCard`, `NDISCatalogueCard`, and `ModernPriceChip` to prevent redundant reading and provide action hints.
  - Use `.accessibilityElement(children: .ignore)` and construct natural-language labels for `ChangeRow` in `NDISChangesSummaryView` (e.g., "Changed unit price from X to Y").
  - Group statistics in `NDISChangesSummaryCard` to be read as a single element.

---

## Retiring Explorer Subagents
The Explorer subagents are now retired.
- Explorer 1 (4fb0a346-5038-4fbf-b34f-ef9d8cb43b99): Retired.
- Explorer 2 (a76029b2-608a-403f-8fd2-bf3645115e7b): Retired.
- Explorer 3 (e6be3353-34e2-4d6e-b092-008272759ca1): Retired.
