## 2026-06-10T01:36:15Z
Objective: Unify spacing, typography, corner radii, and color choices in Packages/Feature.NDIS module using the design-token systems (StyleGuide, ColorSystem, PanelShellTokens).
Scope boundaries: Make UI surface-level changes only. Do not touch SwiftData schemas or core data behaviors.
Input information:
- Refer to the NDIS token audit report at /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_ndis_gen2/handoff.md for specific files, line numbers, and recommendation patterns.
- Specifically modify:
  1. Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISChangesSummaryView.swift
  2. Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISDetailCards.swift
  3. Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueCards.swift
  4. Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueBreadcrumbBar.swift
  5. Packages/Feature.NDIS/Sources/Feature_NDIS/Layouts/NDISCatalogueLayouts.swift
  6. Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueNavigationView.swift
- Verification commands:
  - Swift package tests: swift test --package-path Packages/SharedUI and swift test --package-path Packages/Feature.Settings
  - Build checks: swift build --package-path Packages/Feature.Calendar
  - App target build: xcodebuild -project InvoicingApplication.xcodeproj -scheme InvoicingApplication -configuration Debug -destination 'platform=macOS' build
