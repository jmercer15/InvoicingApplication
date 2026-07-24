# NDIS Feature UI Refinement Analysis

This report analyzes the current visual and accessibility state of NDIS catalogue UI components in `Feature.NDIS` views and view models, focusing on hierarchy, states, interaction affordances, and WCAG AA compliance.

---

## 1. Component Elevation & Visual Hierarchy

### Issue: Section & Card Background Collision
*   **File**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISChangesSummaryView.swift`
*   **Line Range**: 162-195 (`NDISChangesSummaryCard`)
*   **Observation**: 
    The `NDISChangesSummaryCard` uses `StyleGuide.Colors.background` for its card fill. It is nested inside the parent `summarySection` which is styled with `.formSectionBackground()`, also using `StyleGuide.Colors.background`.
*   **Impact**: 
    The cards blend directly into their parent section background, lacking clear depth/elevation cues.
*   **Suggested Fix**:
    Change the card fill in `NDISChangesSummaryCard` to a secondary background or a subtle material (e.g. `.regularMaterial` or `Color.listHoverBackground`).

### Issue: Missing Breadcrumb Separator
*   **File**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueNavigationView.swift`
*   **Line Range**: 57-63
*   **Observation**: 
    A vertical `VStack(spacing: 0)` groups `NDISCatalogueBreadcrumbBar` and the main catalogue body. There is no line divider or shadow separation between the breadcrumb bar and content.
*   **Impact**:
    No visual separation between the persistent navigation header and dynamic content panels.
*   **Suggested Fix**:
    Add a native `Divider()` or a subtle bottom shadow/border below the breadcrumb bar to anchor the navigation header.

---

## 2. State Polish (Loading, Error, & Empty States)

### Issue: Missing Loading State in Catalogue Navigation View
*   **File**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueNavigationView.swift`
*   **Line Range**: 64-103
*   **Observation**: 
    The main catalogue body only checks `projection.totalItemCount == 0` to display an empty state. It does not check if the catalogue has completed loading from the database (`viewModel.hasLoadedCatalogue`).
*   **Impact**:
    When the app is initially loading NDIS items asynchronously, it shows "No NDIS Items Available" momentarily before populating, creating a jarring UX.
*   **Suggested Fix**:
    Check `viewModel.hasLoadedCatalogue` before displaying the empty state. Show a standard `ProgressView` loading indicator if loading is still in progress.

### Issue: Missing Error and Retry UI in Catalogue Navigation View
*   **File**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueNavigationView.swift` & `NDISContainerViewModel.swift`
*   **Line Range**: `NDISContainerViewModel.swift` 130-142, `NDISCatalogueNavigationView.swift` 64-103
*   **Observation**: 
    If fetching NDIS snapshots from the database fails (throws an error), the error is logged to the console, but the UI remains in the default "No NDIS Items Available" empty state.
*   **Impact**:
    Users cannot differentiate between an empty catalogue and a system failure, and there is no way to retry loading.
*   **Suggested Fix**:
    1. Add a `loadingError: Error?` published property to `NDISContainerViewModel`.
    2. Capture database fetching errors and populate `loadingError`.
    3. Update the view to check if `loadingError` is non-nil and show an error state view with a "Retry" button.

### Issue: Missing Error and Retry UI in Changes Summary
*   **File**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISChangesSummaryView.swift` & `NDISContainerViewModel+Fetching.swift`
*   **Line Range**: `NDISChangesSummaryView.swift` 44-98, `NDISContainerViewModel+Fetching.swift` 38-50
*   **Observation**: 
    If the historical changes analysis fails, `changesSummary` is left `nil` and `isLoading` is set to `false`. The view renders a blank section containing only the header "NDIS Catalogue Overview" and no content.
*   **Impact**:
    UI breaks silently without feedback or recovery actions.
*   **Suggested Fix**:
    Introduce a dedicated error card in the view body when `changesSummary` is nil after loading, providing an explanation and a "Retry" action.

---

## 3. Visual Feedback & Affordances

### Issue: Missing Hover Highlights & Focus Rings on Navigation Node Cards and Catalogue Cards
*   **File**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueCards.swift`
*   **Line Range**: 5-94 (`NDISCatalogueNavigationNodeCard`), 96-278 (`NDISCatalogueCard`)
*   **Observation**: 
    Both card views represent major interactive elements in the catalogue navigation but use `.buttonStyle(.plain)` without any custom hover styling or focus ring implementations.
*   **Impact**:
    Clicking cards feels unresponsive on macOS (no active scale or color highlight). Focus navigation (tabbing) is completely invisible to keyboard users.
*   **Suggested Fix**:
    1. Implement a custom hover state utilizing `.onHover` to modify the card stroke color or background opacity.
    2. Add `@FocusState` to track keyboard focus and render a standard focus ring border (or blue highlight) when focused.

### Issue: Missing Focus Rings and Hover States on Region Price Chips
*   **File**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISDetailCards.swift`
*   **Line Range**: 18-34, 265-300 (`ModernPriceChip`)
*   **Observation**: 
    The price chips allow users to toggle regions. They are wrapped in a plain button style, which hides macOS default focus highlights, and they don't define any custom focus or hover behavior.
*   **Impact**:
    Keyboard users cannot determine which region chip is currently focused during keyboard navigation.
*   **Suggested Fix**:
    Add hover and focus visual states using `.onHover` and focus rings/borders to ensure standard macOS button behaviors.

### Issue: Missing Focus Rings and Hover States on Breadcrumbs
*   **File**: `Packages/SharedUI/Sources/SharedUI/Components/AppBreadcrumbComponents.swift`
*   **Line Range**: 41-97 (`AppBreadcrumbSegmentButton`), 4-39 (`AppBreadcrumbBackButton`)
*   **Observation**: 
    Breadcrumb segment buttons and back button use plain styling with no hover animations or keyboard focus states.
*   **Impact**:
    Breaks keyboard navigation and reduces the tactile feedback of clicking navigation items.
*   **Suggested Fix**:
    Add active scale effects on click and focus/hover outlines to segment buttons.

---

## 4. Accessibility & WCAG AA Compliance

### Issue: Color Contrast Violations in ChangeRow Overlays
*   **File**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISChangesSummaryView.swift`
*   **Line Range**: 383-385 (OLD label overlay) and 393-395 (NEW label overlay)
*   **Observation**: 
    *   The "OLD" overlay is text styled with `ColorSystem.Status.error` (red) on a background of `ColorSystem.Status.error.opacity(0.3)` (light pink). Contrast ratio is ~2.1:1.
    *   The "NEW" overlay is text styled with `ColorSystem.Status.success` (green) on a background of `ColorSystem.Status.success.opacity(0.2)` (light green). Contrast ratio is ~2.3:1.
*   **Impact**:
    Fails WCAG AA minimum contrast ratio (4.5:1 for normal text). Text is unreadable for visually impaired users.
*   **Suggested Fix**:
    Style the overlays as solid badges: use white text (`.white`) on solid status backgrounds (`ColorSystem.Status.error` / `ColorSystem.Status.success`). This guarantees a contrast ratio > 4.5:1.

### Issue: No Accessibility Label on Breadcrumb Back Button
*   **File**: `Packages/SharedUI/Sources/SharedUI/Components/AppBreadcrumbComponents.swift`
*   **Line Range**: 4-39 (`AppBreadcrumbBackButton`)
*   **Observation**: 
    The back button uses an SF symbol chevron as its sole content without defining an accessibility label.
*   **Impact**:
    VoiceOver reads it as "chevron backward, button" instead of communicating its action ("Back").
*   **Suggested Fix**:
    Add `.accessibilityLabel("Back")` or `.accessibilityLabel("Go back to previous category")` to the button.

### Issue: Incomplete Accessibility Support on Changes Summary Cards
*   **File**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISChangesSummaryView.swift`
*   **Line Range**: 162-195 (`NDISChangesSummaryCard`)
*   **Observation**: 
    The stats cards display numbers and label text but do not group themselves as single accessibility elements with unified readouts.
*   **Impact**:
    VoiceOver reads the cards fragmentedly, reading label, value, and subtitle in separate voice focus passes.
*   **Suggested Fix**:
    Add `.accessibilityElement(children: .combine)` and define a descriptive label: `.accessibilityLabel("\(title): \(value). \(subtitle)")`.

### Issue: Incomplete Accessibility Support on Change Detail Cards
*   **File**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISChangesSummaryView.swift`
*   **Line Range**: 240-338 (`ChangeCard`), 368-399 (`ChangeRow`)
*   **Observation**: 
    Change records list attributes and old/new values. They lack descriptive accessibility labels.
*   **Impact**:
    VoiceOver reads rows disjointedly, reading raw arrow icons and text tags ("Name, OLD name, arrow.right, NEW name") without structured explanation.
*   **Suggested Fix**:
    Add custom accessibility elements for each `ChangeRow`:
    `.accessibilityElement(children: .ignore)`
    `.accessibilityLabel("Changed \(label) from \(oldValue) to \(newValue)")`

### Issue: Redundant / Noisy Card Accessibility Labels
*   **File**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueCards.swift`
*   **Line Range**: 5-94 (`NDISCatalogueNavigationNodeCard`), 96-278 (`NDISCatalogueCard`)
*   **Observation**: 
    `NDISCatalogueCard` and `NDISCatalogueNavigationNodeCard` use `.accessibilityElement(children: .combine)` but combine internal divider lines and chevron symbols in the screen-reader output. `NDISCatalogueNavigationNodeCard` also double-reads the item count (once in the subtitle, once in the bottom button layout).
*   **Impact**:
    Produces cluttered and repetitive VoiceOver announcements.
*   **Suggested Fix**:
    Replace `.accessibilityElement(children: .combine)` with:
    1. For `NDISCatalogueNavigationNodeCard`:
       `.accessibilityLabel("Category: \(node.title), contains \(count) items")`
       `.accessibilityHint("Double click to open category")`
    2. For `NDISCatalogueCard`:
       `.accessibilityLabel("Support Item: \(item.name), Item Number: \(item.itemNumber)")`
       `.accessibilityValue("Pricing: \(priceText)")`
       `.accessibilityHint("Double click to view details")`
