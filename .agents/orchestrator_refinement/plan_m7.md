# AppShell UI Refinement Plan

This document outlines the UI refinements for the `AppShell` package according to requirements R1-R4:
- **R1. Component Elevation & Visual Hierarchy** (depth, separation, spacing)
- **R2. Empty, Error, Loading State Polish**
- **R3. Visual Feedback & Interactive Affordances** (highlights, cursor, active states)
- **R4. Accessibility & Contrast** (WCAG compliance, labels, hints)

---

## 1. ActivityPlaceholderView.swift
* **[R2] ActivityPlaceholderLoadingView Polish**: 
  - Wrap in a card with a subtle border/shadow (`StyleGuide.Colors.border` and modern background materials) rather than a bare VStack.
  - Standardize vertical spacing to `StyleGuide.Dimensions.paddingLarge` to match details pane loading states.
* **[R4] Accessibility Labels**: 
  - Add explicit accessibility elements to loading state: `.accessibilityLabel("Loading Activity Monitor")`.

## 2. Components/CloudKitSyncSidebarIndicator.swift
* **[R1] Visual Alignment**:
  - Adjust margins to perfectly align horizontal padding with native list items in the sidebar (`.padding(.horizontal, 16)` instead of custom/variable spacing).
* **[R3] Interactive Affordance**:
  - Add hover state highlights when sync monitor reports error.
  - Support tap/click action to retry sync or show detailed error popup.
* **[R4] Dynamic Type & Contrast**:
  - Check contrast of `secondaryText` using `.caption2` with `StyleGuide.Colors.textSecondary`. Switch to a slightly higher contrast token if needed under light/dark modes.
  - Set custom accessibility label: e.g. `iCloud Sync status: [statusText], [secondaryText]`.

## 3. Scenes/Startup/SessionPhaseRoot.swift
* **[R1] Elevation & Depth**:
  - Wrap `StartupFailureView` contents inside an elevated surface card (using shadow and rounded corners) to distinguish from the background app shell.
* **[R2] Error & Loading Polish**:
  - Upgrade `WorkspaceStartupLoadingView` to display a styled logo or app icon alongside the spinner.
  - Enhance `StartupFailureView` layout with a clear alert icon, error title hierarchy, and structured recovery section.
* **[R3] Interactive Affordances**:
  - Style the "Retry" button as a prominent action button with hover and click state transformations.
* **[R4] Accessibility**:
  - Tag the error text with `.accessibilityElement(children: .combine)`.
  - Add accessibility hint to "Retry" button: "Attempts to reconnect to the database and initialize the application."

## 4. Scenes/Workspace/SmartInspectorResolverView.swift
* **[R2] Loading Overlay Refinement**:
  - Smooth the transitions for the ultra-thin material overlay in `relationshipInspector`.
  - Add scale/fade animations on the loading spinner and label when shifting between detail states.

## 5. Scenes/Workspace/WorkspaceSidebarView.swift
* **[R1] Sidebar Spacing**:
  - Define explicit item spacing inside list rows.
* **[R3] Active Focus & Selection**:
  - Apply custom hover background styling to list items.
  - Ensure selection highlight utilizes brand colors with appropriate contrast.
* **[R4] Accessibility Details**:
  - Add accessibility value or trait (`.selected`) explicitly mapped to the active tab state for screen readers.

## 6. Scenes/Workspace/WorkspaceSplitView.swift
* **[R1] Border & Separator Polish**:
  - Ensure correct separator/divider rendering across dark and light modes between the Sidebar, Content Column, and Detail Column.
