## 2026-06-09T15:49:18Z
You are worker_clients_gen2. Your working directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_clients_gen2`.

Objective: Unify spacing, typography, corner radii, and color choices in `Packages/Feature.Clients` module using the design-token systems (`StyleGuide`, `ColorSystem`, `PanelShellTokens`).
Scope boundaries: Make UI surface-level changes only. Do not touch SwiftData schemas or core data behaviors.
Input information:
- Refer to the Clients token audit report at `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_clients_gen2/handoff.md` for specific files, line numbers, and recommendation patterns.
- Specifically modify:
  1. `ClientDetailBillingInfoCard.swift`
  2. `ClientDetailClientInformationCard.swift`
  3. `ClientDetailView.swift`
  4. `PayeeDetailView.swift`
  5. `PlanManagerDetailView.swift`
  6. `PlanManagerDetailInformationCard.swift`
  7. `ServiceAssignmentSheetView.swift`
  8. `ServiceAssignmentSheetContainer.swift`
  9. `ServiceBulkEditorView.swift`
  10. `ServiceAssignmentFilterBar.swift`
  11. `RelationshipsDetailColumn.swift`
  12. `ClientDetailServiceAgreementsCard.swift`
  13. `ServiceAgreementEditorSheet.swift`
  14. `RelationshipsLayouts.swift`
- Verification commands (run individually, as scripts execution is restricted):
  - Swift package tests: `swift test --package-path Packages/SharedUI` and `swift test --package-path Packages/Feature.Settings`
  - Build checks: `swift build --package-path Packages/Feature.Calendar`
  - App target build: `xcodebuild -project InvoicingApplication.xcodeproj -scheme InvoicingApplication -configuration Debug -destination 'platform=macOS' build`

Output requirements: Write a handoff report at `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_clients_gen2/handoff.md` documenting:
- List of modified files
- Output of the build/test verification steps
- Any design patterns adopted (like card styles or shell modifiers)

Completion criteria:
- All package files build successfully and tests pass.
- The app builds successfully.
- Code conforms to token systems with no raw styling literals in modified lines.
