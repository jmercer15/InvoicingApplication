# BRIEFING — 2026-06-30T18:56:00+10:00

## Mission
Explore layout logic to locate files and details for Bug 1 (vertical layout undercount) and Bug 2 (horizontal layout undercount).

## 🔒 My Identity
- Archetype: explorer
- Roles: Codebase Explorer
- Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_layout/
- Original parent: 559d472d-c50d-473b-b0fa-2fc120ddece9
- Milestone: Layout Bug Investigation

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- CODE_ONLY network mode

## Current Parent
- Conversation ID: 559d472d-c50d-473b-b0fa-2fc120ddece9
- Updated: 2026-06-30T18:56:00+10:00

## Investigation State
- **Explored paths**:
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Support/LeafComponentFrameSizing.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/InvoiceComponent.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridComponent.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridComponent+AnalyticHeight.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridLayout+Preferences.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Canvas/FlexibleSizeCalculator.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/SectionSplit+Operations.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Canvas/LinearSplitView.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Canvas/GridSplitView.swift`
- **Key findings**:
  - `LeafComponentFrameSizing.contentVerticalSize(for:)` fallback ignores table borders, section title text, and section title bottom padding.
  - `minIntrinsicWidth` in `InvoiceComponent.swift` ignores outer table borders (`tableBorderWidth`).
  - `LinearSplitView.swift` and `GridSplitView.swift` use the non-document-aware `intrinsicSizeForChild(at:along:)` which ignores updates to component idealSize stored in the document registry.
- **Unexplored areas**: None. Complete coverage of requested targets achieved.

## Key Decisions Made
- Use document-aware size queries inside SwiftUI canvas split views to align with export layout calculations.

## Artifact Index
- /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_layout/handoff.md — Layout investigation findings
