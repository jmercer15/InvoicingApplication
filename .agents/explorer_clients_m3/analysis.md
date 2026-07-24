# Gap Analysis Report — UI Refinement (Pass 3)

**Target Directory:** `Packages/Feature.Clients/Sources/Feature_Clients/`
**Milestone:** Milestone 3 (Feature.Clients UI Refinement)
**Objective:** Analyze all SwiftUI views under `Feature.Clients` and identify gaps across four specific UI Refinement criteria: Component Elevation & Visual Hierarchy, Empty/Error/Loading State Polish, Visual Feedback & Interactive Affordances, and Accessibility & Contrast.

---

## Executive Summary

The analysis of the 27 views and layouts in `Feature.Clients` revealed systematic patterns of custom UI implementations that bypass standard design tokens and modifiers from the `SharedUI` package. 
* **Component Elevation & Visual Hierarchy:** Numerous views define raw `RoundedRectangle` borders, fills, and custom backgrounds instead of adopting `.standardCardStyle()`, `.standardSectionStyle()`, or `HierarchySectionCard`. Additionally, detail header bars are duplicated rather than centralized, and custom scrollable list layouts do not use standard rows like `NavigationListRow`.
* **State Polish:** Loading states depend on raw, un-styled `ProgressView` elements without standard containers or overlay presentation. Empty/blank states are present but occasionally implemented as plain text blocks, and template removal lacks clean fallback empty states.
* **Interactive Feedback:** Custom interactive elements (like `RelationshipGroupCard`, `RelationshipCard`, and service assignment rows) lack hover states, scale transitions, and background selection highlights, resulting in a flat feel.
* **Accessibility:** Multiple interactive components—including icon-only buttons (copy-to-clipboard, map, pencil, plus, close, remove) and custom interactive cards—completely lack `.accessibilityLabel(_:)` and `.accessibilityHint(_:)` modifiers.

---

## Detailed Gap Catalog

| File Name | Location (Lines) | Gap Type | Description | Recommended Fix / Refactoring Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **RelationshipsColumns.swift** | 74-81 | Visual Hierarchy | `EmptyStateView` uses raw background fill and overlay stroke instead of standard panel/card modifiers. | Replace raw `.background(...)` and `.overlay(...)` with `.standardSectionStyle()`. |
| **ServiceAssignmentFilterBar.swift** | 50-57 | Visual Hierarchy | Custom background and border stroke on filter bar container. | Replace raw `RoundedRectangle` border/fill with `.standardCardStyle()`. |
| **ServiceAssignmentSheetView.swift** | 173-180 | Visual Hierarchy | Search/count header card uses custom background and overlay border. | Replace custom background overlay with `.standardCardStyle()`. |
| **ServiceAssignmentSheetView.swift** | 236-243 | Visual Hierarchy | Custom background and border overlay on individual NDIS item selection rows. | Refactor to utilize a standard row style or apply `.standardCardStyle()` modified for selection state. |
| **ServiceBulkEditorView.swift** | 242-249 | Visual Hierarchy | `ServiceTemplateRow` container defines raw background and double overlay border. | Replace raw background/borders with `.standardCardStyle()`. |
| **ClientDetailBillingInfoCard.swift** | 107-109 | Visual Hierarchy | Section header "Invoice Email Recipients" uses raw font and bottom padding. | Replace with `.formSectionTitleStyle()` from `SharedUI`. |
| **ClientDetailServiceAgreementsCard.swift** | 23-69 | Visual Hierarchy | Custom list row implementation for service agreements; lacks structured row style. | Refactor rows to use a standard list row component or a structured `CompactRowView` variant. |
| **RelationshipsColumns.swift** | 223-361 | Visual Hierarchy | Custom `RelationshipGroupCard` and `RelationshipCard` views used in list style (`isListStyle`) rather than standard navigation rows. | Update list layouts to utilize `NavigationListRow` from `SharedUI` when in list representation. |
| **RelationshipsDetailColumn.swift** | 43, 56, 69 | State Polish | Raw `ProgressView()` inside conditional group when resolving entities. | Replace with `LoadingView` or utilize `.loadingOverlay(isLoading:)` modifier. |
| **ServiceAssignmentSheetContainer.swift** | 34-35 | State Polish | Raw `ProgressView()` in custom ZStack for sheet loading animation. | Replace custom container with `LoadingView` from `SharedUI`. |
| **ServiceAssignmentSheetView.swift** | 44 | State Polish | Raw `ProgressView("Loading catalog...")` with no standard styling. | Replace with `LoadingView("Loading catalog...")` from `SharedUI`. |
| **ClientDetailBillingInfoCard.swift** | 183-189 | State Polish | Raw `Text` block displaying static message when email addresses are missing. | Wrap in a scaled-down, clean helper view or standardized empty message block. |
| **ServiceBulkEditorView.swift** | 81-116 | State Polish | Removing all templates leaves an empty ScrollView with no fallback empty state UI. | Add a conditional check for `templates.isEmpty` and show `EmptyStateView` with appropriate icon and instructions. |
| **ServiceAgreementEditorSheet.swift** | 108-110 | State Polish | Validation error displays as raw `Text` with `ColorSystem.Status.error` and custom font. | Replace with `.formErrorStyle()` modifier from `SharedUI`. |
| **PayeeDetailInformationCard.swift** | 39-42, 73-76, 107-110 | State Polish | Raw text error validation blocks under Name, Email, and Phone fields. | Replace custom text errors with `.formErrorStyle()`. |
| **PlanManagerDetailInformationCard.swift** | 39-42, 69-72, 103-106, 138-141 | State Polish | Raw text error validation blocks under Name, ABN, Email, and Phone fields. | Replace custom text errors with `.formErrorStyle()`. |
| **RelationshipsLayouts.swift** | 30-43 | Interactive Feedback | `RelationshipGroupCard` wraps grid/list button in a plain button style and has no hover state adjustments. | Add `.onHover` to animate fill opacity and stroke, and add hover scale scaling. |
| **RelationshipsLayouts.swift** | 206-219 | Interactive Feedback | `RelationshipCard` wraps grid/list button in a plain button style, lacking hover scale/border animations and selection background. | Add `.onHover` feedback and support selection styling (e.g. distinct background highlight or border thickness). |
| **ClientDetailServiceAgreementsCard.swift** | 23-69 | Interactive Feedback | Service agreement rows have zero hover states or interactive affordances. | Add hover highlighting on the container card for a responsive feel. |
| **ServiceAssignmentSheetView.swift** | 213-268 | Interactive Feedback | Custom selected items row has scale effect on select, but no hover highlights. | Add `.onHover` to adjust card border/shadow and provide consistent hover feedback. |
| **ServiceBulkEditorView.swift** | 97-112 | Interactive Feedback | Red delete button circle lacks hover scaling or interactive pressed state animations. | Add hover scale animation or use a standardized interactive circular button style. |
| **ClientDetailClientInformationCard.swift** | 30, 52, 74, 117 | Accessibility | Icon-only copy-to-clipboard buttons lack accessibility labels. | Add `.accessibilityLabel("Copy name")`, `.accessibilityHint("Copies value to pasteboard")` etc. |
| **ClientDetailBillingInfoCard.swift** | 93 | Accessibility | Icon-only copy-to-clipboard button lacks accessibility label. | Add `.accessibilityLabel("Copy credit amount")` and accessibility hint. |
| **PayeeDetailInformationCard.swift** | 29, 63, 97 | Accessibility | Icon-only copy-to-clipboard buttons lack accessibility labels. | Add `.accessibilityLabel(_:)` and `.accessibilityHint(_:)` for all copy actions. |
| **PlanManagerDetailInformationCard.swift** | 30, 60, 94, 128 | Accessibility | Icon-only copy-to-clipboard buttons lack accessibility labels. | Add `.accessibilityLabel(_:)` and `.accessibilityHint(_:)` for all copy actions. |
| **ClientDetailServiceAgreementsCard.swift** | 64 | Accessibility | Ellipsis action menu button has no accessibility label. | Add `.accessibilityLabel("Agreement actions")`. |
| **RelationshipDetailAddressRow.swift** | 38, 49, 61 | Accessibility | Icon-only Map ("map"), Edit ("pencil"), and Add ("plus") buttons lack accessibility metadata. | Add `.accessibilityLabel("View address on map")`, `.accessibilityLabel("Edit address")`, `.accessibilityLabel("Add address")` with proper hints. |
| **RelationshipsLayouts.swift** | 5-159 | Accessibility | Custom interactive `RelationshipGroupCard` lacks accessibility definition. | Add `.accessibilityElement(children: .combine)`, `.accessibilityLabel(node.title)`, `.accessibilityHint("Double tap to browse this group")`. |
| **RelationshipsLayouts.swift** | 162-344 | Accessibility | Custom interactive `RelationshipCard` lacks accessibility description. | Add `.accessibilityElement(children: .combine)`, `.accessibilityLabel("\(title), \(entityType), \(status ?? "")")`. |
| **ServiceAssignmentFilterBar.swift** | 186 | Accessibility | Close button ("xmark.circle.fill") on active filter chips has no accessibility label. | Add `.accessibilityLabel("Remove filter \(filter.label)")`. |
| **ServiceAssignmentSheetView.swift** | 253-265 | Accessibility | Clickable row overlay transparent button hijacks screen readers and lacks labels. | Refactor row to be a proper Button or set `.accessibilityElement(children: .combine)` and add label/hint. |
| **ServiceBulkEditorView.swift** | 97 | Accessibility | Delete service template button ("xmark") lacks accessibility description. | Add `.accessibilityLabel("Remove service template")`. |

---

## Recommended Fix/Refactoring Strategy

### 1. Visual Hierarchy & Elevation Alignments
* **Standard Card & Section Modifiers:** Replace raw card border overlays in `ServiceAssignmentFilterBar.swift`, `ServiceAssignmentSheetView.swift`, and `ServiceBulkEditorView.swift` with `.standardCardStyle()` or `.standardSectionStyle()`.
* **Standardize Section Headings:** Refactor custom subheadings (like in `ClientDetailBillingInfoCard.swift`) to use `.formSectionTitleStyle()`.
* **Centralize Detail Headers:** Replace duplicate header code in `ClientDetailView` with the shared `RelationshipDetailHeaderBar`, expanding it to accept status badges or custom trailing views.

### 2. Poland State Polish (Loading, Empty, Errors)
* **Adopt SharedUI loading states:** Migrate raw `ProgressView` blocks in `RelationshipsDetailColumn`, `ServiceAssignmentSheetContainer`, and `ServiceAssignmentSheetView` to standard `LoadingView`.
* **Adopt SharedUI Form Error Modifiers:** Swap out all custom error `Text` colors/fonts in `ServiceAgreementEditorSheet` and the various detail information cards for the standard `.formErrorStyle()` modifier.
* **Graceful Bulk Editor Empty State:** Add a fallback view using `EmptyStateView` inside `ServiceBulkEditorView` for when all template rows are deleted.

### 3. Polish Affordances & Visual Feedback
* **Add Hover and Active Modifiers:** Implement hover scaling and color opacity animations using `.onHover` in `RelationshipGroupCard` and `RelationshipCard`.
* **Standardize Row Selection Highlights:** When selected, apply a subtle background highlight color (such as `.accentColor.opacity(0.1)`) and border enhancement to the cards to clearly indicate active selection, rather than just showing a checkmark.

### 4. Accessibility Compliance
* **Accessibility Labels & Hints:** Add clear, descriptive `.accessibilityLabel` and `.accessibilityHint` modifiers to all copy-to-clipboard, delete, add, map, and menu button icons.
* **Custom Interaction Semantics:** Combine children elements on interactive group and leaf relationship cards to form a single cohesive accessibility element, ensuring screen readers announce names, roles, and current statuses clearly.
