# Adversarial Review Report — NDIS design token integration

## Challenge Summary

**Overall risk assessment**: LOW

## Challenges

### [Low] Challenge 1: Layout Overflow on Deep Navigation Hierarchy
- **Assumption challenged**: The breadcrumb trail in `NDISCatalogueBreadcrumbBar` and card layouts fit within ordinary window bounds without causing truncated labels or text clipping.
- **Attack scenario**: A user navigates down a deeply nested item path structure with lengthy category/group names.
- **Blast radius**: Cosmetic breadcrumb truncation.
- **Mitigation**: Standard breadcrumbs handle layout flow via `.lineLimit(2)` and standard layout padding limits. The views adopt `ViewThatFits` and scrollable lists to handle constraints gracefully.

### [Low] Challenge 2: Missing Pricing / Region Identifier Mismatch
- **Assumption challenged**: Every support item has a complete set of regional prices and matches standard regional identifiers (e.g. NSW, NATIONAL).
- **Attack scenario**: An item is parsed with no price entries or with region tags containing non-standard spacing/casing.
- **Blast radius**: Visual card formatting breaks or fails to show fallback values.
- **Mitigation**: Resolved via normalized casing comparison (using `normalizedPreferredRegion` in `NDISCatalogueCards.swift` lines 145-150) and rendering a standardized `NoPriceCard` when no prices are available.

## Stress Test Results

- **Scenario 1**: Missing pricing data → expectation: display fallback card safely without runtime crashes.
  - Result: Correctly displays `NoPriceCard` containing unified warning styling. (PASS)
- **Scenario 2**: Duplicate items with conflicting start dates → expectation: keep only the latest version.
  - Result: Deduplicated correctly per query logic tests. (PASS)

## Unchallenged Areas

- Core database logic and SwiftData schemas were out of scope for token integration and remain unchallenged.
