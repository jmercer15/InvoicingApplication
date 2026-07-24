# NDIS UI Refinement Analysis

This report identifies the current state of NDIS UI components inside `Packages/Feature.NDIS` across four specific design categories, detailing issues and providing recommended fix strategies.

---

## 1. Component Elevation & Visual Hierarchy

### Issue 1.1: Missing Separator Between Navigation Breadcrumbs and Content Grid
* **File:** `Sources/Feature_NDIS/Views/NDISCatalogueNavigationView.swift`
* **Lines:** 57–63
* **Description:** The breadcrumb bar (`NDISCatalogueBreadcrumbBar`) is stacked directly above the content grid inside a `VStack(spacing: 0)` without any divider or layout separator. When content is scrolled, cards scroll directly under the breadcrumbs, creating a flat and messy overlapping visual layout.
* **Suggested Fix Strategy:** Add a thin horizontal separator below the breadcrumb bar:
  ```swift
  NDISCatalogueBreadcrumbBar(...)
  Divider()
      .foregroundStyle(StyleGuide.Colors.border)
  ```

### Issue 1.2: Flat Card Components Lack Elevation & Depth Cues
* **File:** `Sources/Feature_NDIS/Views/NDISCatalogueCards.swift`
* **Lines:** 29–87 (Navigation Node Card), 209–272 (Catalogue Card)
* **Description:** The category navigation cards and support item cards are rendered completely flat, using only a background color fill and a thin border stroke. There are no shadows or depth cues to distinguish them as clickable elevated components.
* **Suggested Fix Strategy:** Apply a subtle shadow using theme tokens to give cards proper elevation:
  ```swift
  .shadow(
      color: StyleGuide.shadowColor.opacity(0.04),
      radius: StyleGuide.Shadows.lightRadius,
      x: 0,
      y: StyleGuide.Shadows.lightOffsetY
  )
  ```

### Issue 1.3: Semantically Inconsistent Background Fills
* **Files:**
  - `Sources/Feature_NDIS/Views/NDISCatalogueNavigationView.swift` (lines 73, 85)
  - `Sources/Feature_NDIS/Views/NDISDetailCards.swift` (lines 290)
* **Description:** Background fills for the empty state screens and non-selected price chips use `StyleGuide.Colors.text.opacity(StyleGuide.Opacity.subtle)`. Utilizing the text color as a background fill is semantically incorrect and leads to unpredictable colors across system light/dark theme shifts.
* **Suggested Fix Strategy:** Standardize these backgrounds to use secondary panel/control background tokens:
  ```swift
  // Replace:
  .fill(StyleGuide.Colors.text.opacity(StyleGuide.Opacity.subtle))
  // With:
  .fill(PanelShellTokens.panelSecondaryBackground)
  ```

### Issue 1.4: Cramped Header Layout Spacing in Detail Column
* **File:** `Sources/Feature_NDIS/Views/EnhancedSupportItemDetailView.swift`
* **Lines:** 70–101
* **Description:** The header stack `detailHeader` uses a spacing of `StyleGuide.Dimensions.paddingMedium` (8pt) and a bottom padding of `StyleGuide.Dimensions.paddingMedium` (8pt) before the divider. Compared to the generous outer column margins (24pt), this results in a cramped vertical title section.
* **Suggested Fix Strategy:** Increase vertical margins to improve spacing proportions:
  ```swift
  VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMediumLarge) { // 12pt
      ...
  }
  .padding(.horizontal, StyleGuide.Dimensions.paddingXLarge) // 24pt
  .padding(.top, StyleGuide.Dimensions.paddingXLarge)        // 24pt
  .padding(.bottom, StyleGuide.Dimensions.paddingLarge)      // 16pt
  ```

---

## 2. State Polish

### Issue 2.1: Navigation View Lacks Loading State (Flashes Empty State)
* **File:** `Sources/Feature_NDIS/Views/NDISCatalogueNavigationView.swift`
* **Lines:** 64–88
* **Description:** If the NDIS catalogue is loading asynchronously on startup, `projection.totalItemCount` is 0. The view immediately renders the "No NDIS Items Available" empty state. Once loaded, the list replaces it, causing a jarring layout flash.
* **Suggested Fix Strategy:** Condition the empty state display on the load status in `NDISContainerViewModel`:
  ```swift
  if !viewModel.hasLoadedCatalogue {
      ProgressView("Loading NDIS Catalogue...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
  } else if projection.totalItemCount == 0 {
      EmptyStateView(...)
  }
  ```

### Issue 2.2: Swallowed Database Fetch Errors (No Visual Error State)
* **File:** `Sources/Feature_NDIS/ViewModels/NDISContainerViewModel.swift`
* **Lines:** 137–140
* **Description:** Database errors encountered during asynchronous catalogue loading are logged to the console via `print` and swallowed. The view model does not publish an error state, leaving the user looking at a permanent empty list with no visual indication that something failed.
* **Suggested Fix Strategy:** 
  1. Add an `@Observable` property `var loadError: Error?` to the view model.
  2. Populate it in the catch block: `self.loadError = error`.
  3. In `NDISCatalogueNavigationView.swift`, check if `viewModel.loadError != nil` and display an `EmptyStateView` with an error icon, error details, and a "Retry" button that calls `viewModel.loadCatalogue(force: true)`.

---

## 3. Visual Feedback & Affordances

### Issue 3.1: Interactive Card Buttons Lack Hover States
* **File:** `Sources/Feature_NDIS/Views/NDISCatalogueCards.swift`
* **Lines:** 5–94 (Navigation Node Card), 209–272 (Catalogue Card)
* **Description:** On macOS, plain button cards must adapt visually to mouse hover (e.g. outline/background change) to denote interactivity. Currently, hovering over these cards produces no visual feedback.
* **Suggested Fix Strategy:** Add local hover tracking and highlight the border on hover using existing tokens:
  ```swift
  @State private var isHovered = false
  
  // Inside body structure:
  .onHover { hovering in
      isHovered = hovering
  }
  .background(
      shape
          .fill(isHovered ? StyleGuide.Colors.background.opacity(0.85) : StyleGuide.Colors.background)
          .overlay(
              shape.stroke(
                  isHovered ? ColorSystem.Primary.blue.opacity(ListRowTokens.hoverStrokeOpacity) : StyleGuide.Colors.border,
                  lineWidth: ListRowTokens.defaultStrokeWidth
              )
          )
  )
  ```

### Issue 3.2: Missing Keyboard Focus Ring Indicators
* **Files:**
  - `Sources/Feature_NDIS/Views/NDISCatalogueCards.swift` (Node Cards & Catalogue Cards)
  - `Sources/Feature_NDIS/Views/NDISDetailCards.swift` (Price selection chips)
* **Description:** Interactive card buttons are styled with `.buttonStyle(.plain)`. Plain buttons do not render focus rings automatically when navigated via keyboard tab navigation on macOS, violating keyboard accessibility guidelines.
* **Suggested Fix Strategy:** Add `.focusable()` and render custom focus indicators:
  ```swift
  @FocusState private var isFocused: Bool
  
  // In body:
  .focusable()
  .focused($isFocused)
  .overlay {
      if isFocused {
          shape
              .stroke(Color.accentColor, lineWidth: 2)
              .padding(2)
      }
  }
  ```

---

## 4. Accessibility

### Issue 4.1: Low-Contrast Badges & Status Indicators (WCAG AA Contrast Failures)
* **Files:**
  - `Sources/Feature_NDIS/Views/NDISChangesSummaryView.swift` (lines 385, 395)
  - `Sources/Feature_NDIS/Views/NDISDetailCards.swift` (lines 207–209, 357–359)
* **Description:** 
  1. The "OLD" and "NEW" tags in the change summary overlay text with the bright `ColorSystem.Status.error` / `success` foreground color directly on top of 0.3 opacity matching background fills.
  2. Green checkmark icons (`ColorSystem.Status.success` or `ColorSystem.Secondary.green`) are rendered on light green backgrounds.
  These combinations create a contrast ratio of less than 2:1, far below the WCAG AA minimum of 4.5:1 for small text.
* **Suggested Fix Strategy:** Use a solid, highly-contrasting text color (like white text on solid red/green badges), or select darker semantic colors for text overlay:
  ```swift
  // For ChangeRow overlay badge:
  Text("OLD")
      .font(StyleGuide.Typography.caption)
      .foregroundColor(.white)
      .padding(.horizontal, 4)
      .background(ColorSystem.Status.error) // Solid red background
  ```

### Issue 4.2: Pricing Grid Elements Hidden from Screen Readers
* **File:** `Sources/Feature_NDIS/Views/NDISDetailCards.swift`
* **Lines:** 50–52
* **Description:** `ModernCombinedPricingCard` wraps its container GroupBox with `.accessibilityElement(children: .combine)`. Combining children on a group container collapses all nested child components into a single static label, hiding all interactive region buttons from VoiceOver users.
* **Suggested Fix Strategy:** Remove the top-level `.accessibilityElement(children: .combine)` to expose regional button chips. Label each individual button chip with its price and region name, and add an accessibility action trait:
  ```swift
  // For ModernPriceChip:
  .accessibilityElement(children: .ignore)
  .accessibilityLabel("\(region) region, \(price.currencyString)")
  .accessibilityAddTraits(.isButton)
  .accessibilityHint("Selects \(region) as the active region price")
  ```

### Issue 4.3: Info Grid Readout Lacks Granularity
* **File:** `Sources/Feature_NDIS/Views/NDISDetailCards.swift`
* **Lines:** 76–78
* **Description:** `ModernCombinedInfoCard` groups all key-value classification items using `.accessibilityElement(children: .combine)`. VoiceOver reads the entire layout in a single block, making it difficult for users to inspect specific information fields like "Registration Group Number".
* **Suggested Fix Strategy:** Remove the container-level `.accessibilityElement(children: .combine)` and instead combine items at the row level (`infoRow`):
  ```swift
  // In infoRow structure:
  .accessibilityElement(children: .combine)
  .accessibilityLabel("\(label): \(value)")
  ```

### Issue 4.4: Missing Accessibility Labels and Hints in Cards
* **File:** `Sources/Feature_NDIS/Views/NDISCatalogueCards.swift`
* **Lines:** 275–277
* **Description:** `NDISCatalogueCard` groups children but does not provide an explicit accessibility label or hint. VoiceOver will read the concatenated raw text fields, which is confusing, and will give no indication of card action.
* **Suggested Fix Strategy:** Provide structured labels and hints:
  ```swift
  .accessibilityLabel("Support item \(item.name), number \(item.itemNumber), \(priceText)")
  .accessibilityHint("Double tap to select this item and view its details")
  ```
