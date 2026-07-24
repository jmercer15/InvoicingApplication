# NDIS UI Components Analysis

This report identifies the current state of UI components under `Feature.NDIS` based on read-only exploration.

---

## 1. Component Elevation & Visual Hierarchy

### Issue 1.1: Flat Design and Lack of Depth Cues in Navigation Cards
* **File & Lines**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueCards.swift` (Lines 5–94, 96–278)
* **Description**: `NDISCatalogueNavigationNodeCard` and `NDISCatalogueCard` rely strictly on a flat stroke border (`StyleGuide.Colors.border`) and subtle background fill. They lack shadows, depth cues, or layered styling when rendered on the parent panel canvas, which makes the workspace feel flat.
* **Suggested Fix**: 
  Apply standard `StyleGuide.Shadows` elevation shadows to the card shapes. For example, add a trailing shadow modifier:
  ```swift
  .shadow(
      color: StyleGuide.shadowColor.opacity(0.15),
      radius: StyleGuide.Shadows.lightRadius,
      x: 0,
      y: StyleGuide.Shadows.lightOffsetY
  )
  ```

### Issue 1.2: Flat Separator and Layout Spacing in Detail View Header
* **File & Lines**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/EnhancedSupportItemDetailView.swift` (Lines 70–101)
* **Description**: The `detailHeader` uses a standard flat `Divider()` without any elevation cues or distinct grouping. In addition, the vertical stack spacing between the metadata (item number) and the main title lacks clear hierarchical prominence.
* **Suggested Fix**:
  Replace the flat `Divider` with a custom styled border/divider that aligns with the card border style rules. Group the header contents into a visually elevated card structure using `GroupBox` or a custom background with shadow to clearly separate the header from the detail sections.

---

## 2. State Polish

### Issue 2.1: Empty State Displayed During Initial Database Load (Jarr/Flash)
* **File & Lines**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueNavigationView.swift` (Lines 64–88)
* **Description**: If the catalog query has not completed (which happens asynchronously on startup via `loadCatalogueIfNeeded()`), `projection.totalItemCount` is `0`. Consequently, the view immediately renders the `EmptyStateView` ("No NDIS Items Available" / "No Matching NDIS Items") before quickly flashing and showing items when the database load finishes.
* **Suggested Fix**:
  Expose `hasLoadedCatalogue` or an `isLoading` boolean state from `NDISContainerViewModel` to the view. Wrap the view's condition as follows:
  ```swift
  if !viewModel.hasLoadedCatalogue {
      ProgressView("Loading NDIS items...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
  } else if projection.totalItemCount == 0 {
      // Show empty state
  }
  ```

### Issue 2.2: Missing User-Facing Error State in ViewModel and UI
* **File & Lines**: `Packages/Feature.NDIS/Sources/Feature_NDIS/ViewModels/NDISContainerViewModel.swift` (Lines 130–142), and `NDISCatalogueNavigationView.swift`
* **Description**: If the SwiftData fetching actor throws an error inside `loadCatalogue(force:)`, it is caught, printed to the console via `print()`, and silently ignored by the UI. The user is left with a perpetual empty state.
* **Suggested Fix**:
  Add an `@ObservationTracked` property `public var errorMessage: String? = nil` in the view model. Set this property in the `catch` block. In the view, inspect `viewModel.errorMessage` and render an `ErrorStateView` with a retry button.

### Issue 2.3: Raw and Unstyled Loading State in Changes Summary View
* **File & Lines**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISChangesSummaryView.swift` (Lines 17–19)
* **Description**: The loading view is a raw `ProgressView("Analyzing NDIS changes...")` with no alignment styling or matching background, which breaks the visual consistency of the application sheet layouts.
* **Suggested Fix**:
  Wrap the progress view inside a container that provides appropriate margins, panel background, and a larger spinner, matching the application's overall loading state patterns.

---

## 3. Visual Feedback & Affordances

### Issue 3.1: Missing Hover and Active States on Navigation and Support Item Cards
* **File & Lines**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueCards.swift` (Lines 30–89, 210–273)
* **Description**: Both card types use `Button(action:)` with `.buttonStyle(.plain)` but do not define custom hover or active state overlays. Hovering with a mouse or clicking yields zero visual response (no background shift, outline change, or depth change).
* **Suggested Fix**:
  Introduce a `@State private var isHovered = false` on both views, appending `.onHover { isHovered = $0 }`. Use `isHovered` to adjust the background fill brightness, add a subtle border glow, or increase shadow radius. Alternatively, use a custom `CardButtonStyle` that manages these states.

### Issue 3.2: Missing Focus Rings on Interactive Cards
* **File & Lines**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueCards.swift` (Lines 30–89, 210–273)
* **Description**: Because the buttons are styled as `.plain`, they do not automatically render standard focus rings when navigated via keyboard/accessibility shortcuts on macOS.
* **Suggested Fix**:
  Add `.focusable()` to the cards, and use `@FocusState` to draw a prominent focus ring (e.g. using a `.stroke(ColorSystem.Primary.blue, lineWidth: 2)` overlay) when the card has keyboard focus.

### Issue 3.3: Selection Outline Lacks Integrated Visual Depth
* **File & Lines**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueCards.swift` (Lines 267–271)
* **Description**: Selection is indicated solely by a thin blue border overlay. Because the card background remains identical, the blue line looks detached and flat against the white workspace.
* **Suggested Fix**:
  When `isSelected` is true, apply a very light tint to the card background (e.g. `ColorSystem.Primary.blue.opacity(0.04)`) to visually ground the selection.

---

## 4. Accessibility

### Issue 4.1: Color Contrast Violation on Naked Orange Status Text
* **File & Lines**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueCards.swift` (Lines 197–201, 240–244), and `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISDetailCards.swift` (Lines 114–115)
* **Description**: For quote-required support items, `priceColor` uses `ColorSystem.Status.warning` (which resolves to `NSColor.systemOrange`). Orange text on a light window/white background has a contrast ratio of ~2.2:1, which severely violates the WCAG AA contrast threshold of 4.5:1.
* **Suggested Fix**:
  Instead of raw colored text, render status flags using status badges (e.g., using `StatusBadge` or custom pill styling with a background fill and a dark, high-contrast text foreground), or darken the warning status color specifically for text.

### Issue 4.2: Color Contrast Violation in Historical Change Badges
* **File & Lines**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISChangesSummaryView.swift` (Lines 380–396)
* **Description**: The "OLD" overlay uses `foregroundColor(ColorSystem.Status.error)` (red) on a `ColorSystem.Status.error.opacity(0.3)` background. The "NEW" overlay uses `foregroundColor(ColorSystem.Status.success)` (green) on a `ColorSystem.Status.success.opacity(0.2)` background. Red-on-light-red and green-on-light-green text fail accessibility contrast rules.
* **Suggested Fix**:
  Use high-contrast white text (or dark label text) on solid status pills (e.g., white text on solid red background for "OLD" and white text on solid green background for "NEW").

### Issue 4.3: Missing Accessibility Hint for Navigation Cards and Catalogue Cards
* **File & Lines**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueCards.swift` (Lines 91–93, 275–277)
* **Description**: The cards combine child text elements but do not specify accessibility hints or values. Screen readers will read the concatenated text without explaining the action (e.g. double-tap to select or browse).
* **Suggested Fix**:
  Add explicit hints:
  ```swift
  .accessibilityHint("Selects this item to view details in the inspector")
  ```
  And add custom traits where applicable.

### Issue 4.4: Missing Accessibility Grouping in Change Cards
* **File & Lines**: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISChangesSummaryView.swift` (Lines 240–338)
* **Description**: `ChangeCard` and `NDISChangesSummaryCard` do not use accessibility grouping or custom labels. Screen readers read separate text fields individually, resulting in confusing, disjointed speech fragments for historical comparisons.
* **Suggested Fix**:
  Combine the change rows and card fields using `.accessibilityElement(children: .combine)` and generate a cohesive, natural-language accessibility label summarizing the change (e.g., "Change to Unit: changed from Hour to Session on June 12, 2026").
