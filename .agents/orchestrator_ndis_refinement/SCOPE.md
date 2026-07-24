# Scope: Feature.NDIS UI Refinement (Milestone 2)

## Architecture
- Feature.NDIS is a package containing the UI code for querying and viewing the NDIS support catalogue.
- Primary Views:
  - `NDISCatalogueNavigationView`: Main navigation entry point with sidebar/columns layout.
  - `NDISCatalogueColumns`: Spatially arranged grid/columns view.
  - `NDISCatalogueBreadcrumbBar`: Displays current query path.
  - `NDISCatalogueCards`: Individual support items.
  - `EnhancedSupportItemDetailView`: Detailed view of a support item.
  - `NDISChangesSummaryView`: View for changes.
- ViewModels:
  - `NDISContainerViewModel`: Manages loading, state, projections, and interaction logic.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Exploration & Analysis | Run 3 Explorers to identify visual hierarchy, missing states, lack of affordances, accessibility gaps. | none | DONE |
| 2 | Implementation | Worker implements refinements for elevation, hierarchy, polish states, affordances, and accessibility. | M1 | DONE |
| 3 | Verification & Review | Run Reviewers, Challengers, and Forensic Auditor to ensure compliance and pass tests. | M2 | IN_PROGRESS |

## Code Layout
- `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/` — SwiftUI views for NDIS catalogue.
- `Packages/Feature.NDIS/Sources/Feature_NDIS/ViewModels/` — View models for NDIS.
- `Packages/Feature.NDIS/Tests/Feature_NDISTests/` — XCTest files.

## Interface Contracts
- `NDISContainerViewModel` publishes loading, error, and empty states.
- Views bind to view model states and render appropriate UI layouts.
