# Changes Summary

This document summarizes the changes made to the Feature.NDIS UI components for visual refinement, state polish, visual feedback/affordances, and accessibility improvements.

## Modified Files

### 1. NDISContainerViewModel.swift
- Added `@ObservationTracked public var hasLoadedCatalogue = false` and error tracking properties `@ObservationTracked public var loadError: Error? = nil` and `@ObservationTracked public var changesError: Error? = nil`.
- Wrapped `loadCatalogue(force:)` call in notification observer in a main actor-isolated `Task` to fix a compiler warning.
- Updated `loadCatalogue(force:)` to set `hasLoadedCatalogue = true`, reset/capture `loadError`.

### 2. NDISContainerViewModel+Fetching.swift
- Cleared `loadError = nil` when calling `refreshItems`.
- Set `changesError = nil` before starting and tracked errors in `fetchChangesSummary`.

### 3. AppBreadcrumbComponents.swift (SharedUI)
- Implemented hover (`isHovered`) and focus (`isFocused`) states on `AppBreadcrumbBackButton` and `AppBreadcrumbSegmentButton` to provide visual highlights.
- Added explicit `.accessibilityLabel("Back")` to `AppBreadcrumbBackButton`.

### 4. NDISCatalogueNavigationView.swift
- Added a native `Divider()` below the breadcrumb bar to separate it from the main content.
- Displayed a loading `ProgressView` if the catalog has not loaded yet.
- Rendered a polished error state view if `viewModel.loadError` is non-nil, with a "Retry" button.
- Replaced raw text opacity background fills with `PanelShellTokens.panelSecondaryBackground`.

### 5. NDISCatalogueCards.swift
- Added hover highlights and custom keyboard focus ring overlays via `.onHover`, `@FocusState`, and `.focusable()` to `NDISCatalogueNavigationNodeCard` and `NDISCatalogueCard`.
- Darkened the orange color for `.quoteRequired` state to guarantee >= 4.5:1 contrast ratio.
- Added `.shadow(...)` modifier for standard card elevation.
- Provided explicit `.accessibilityLabel(...)` and `.accessibilityHint(...)` to eliminate noisy VoiceOver speech.

### 6. NDISDetailCards.swift
- Implemented hover highlights, custom keyboard focus rings, and explicit VoiceOver annotations on `ModernPriceChip`.
- Wrapped button click handling directly within `ModernPriceChip` instead of the parent grid cells.
- Replaced raw text opacity background fills with `PanelShellTokens.panelSecondaryBackground`.
- Darkened the warning orange color for the "Quote Required" detail cell value.

### 7. EnhancedSupportItemDetailView.swift
- Increased vertical spacing in `detailHeader` (VStack spacing to `StyleGuide.Dimensions.paddingLarge` and bottom padding to `StyleGuide.Dimensions.paddingXLarge`).

### 8. NDISChangesSummaryView.swift
- Refactored `NDISChangesSummaryCard` background to use `PanelShellTokens.panelSecondaryBackground`.
- Grouped statistics in `NDISChangesSummaryCard` to be read as a single element in VoiceOver.
- Wrapped loading `ProgressView` in an elevated panel with larger spinner.
- Implemented a polished error container if analysis fails or changesSummary is nil after loading, with a Retry button.
- Styled `OLD` and `NEW` badges as solid colored badges with white text foregrounds (`ColorSystem.Status.error` and `ColorSystem.Status.success` respectively).
- Grouped and simplified `ChangeRow` with natural-language accessibility labels and `.accessibilityElement(children: .ignore)`.
- Grouped `ChangeCard` using `.accessibilityElement(children: .combine)`.

### 9. NDISContainerViewModelTests.swift
- Added `testLoadCatalogueStateChanges` to verify catalog load state transitions.
