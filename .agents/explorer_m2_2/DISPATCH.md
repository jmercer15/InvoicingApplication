# DISPATCH — Explorer M2 Area 2 (Address Form Standardization & Shadowing Elimination)

## Objective
Investigate Area 2 standardization:
- Files:
  1. `Packages/WorkspaceUI/Sources/WorkspaceUI/AddressEditingSheet.swift` (lines 5–290)
  2. `Packages/WorkspaceUI/Sources/WorkspaceUI/AddressFormSheet.swift` (lines 5–51)
  3. `Packages/Feature.Calendar/Sources/Feature_Calendar/Views/SessionEditor/SessionAddressEditingSheet.swift` (lines 8–52)
- Inspect how `Feature.Calendar` shadows `WorkspaceUI.AddressEditingSheet` and how `Feature.Clients` uses `AddressFormSheet`.
- Design changes to refactor `SessionAddressEditingSheet.swift` in `Feature.Calendar` to consume `WorkspaceUI.AddressFormSheet` with `@Bindable state: AddressFormState`.
- Map out renaming local struct from `AddressEditingSheet` to `SessionAddressEditingSheet` in `Feature.Calendar` to eliminate shadowing.

## References
- `REFACTOR_PLAN.md` Section 4 Area 2
- Original Request: `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/ORIGINAL_REQUEST.md`

## Output
Write findings and recommended patch strategy to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_m2_2/handoff.md`.

## 2026-08-12T11:33:33Z
Read /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_m2_2/DISPATCH.md and /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/ORIGINAL_REQUEST.md. Working directory is /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_m2_2. Investigate Area 2 and write report to handoff.md.

