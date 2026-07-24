# Scope: Milestone 6 — Settings & Invoice Template Editor UI Refinement

## Architecture
- **Feature.Settings**: Wires `ProfileViewModel`, `CompanyViewModel`, `CalendarSettingsViewModel`, and others. Integrates with SwiftData. We will clean up `SettingsRow` label width computations to support Dynamic Type and align custom row backgrounds/borders to `SharedUI` standards.
- **Feature.InvoiceTemplateEditor**: Uses `ModernTemplateManagementView` switching between `TemplateLibraryGrid` and `ModernTemplateEditor`. Wires `InvoiceTemplateEditorViewModel` with `InvoiceDocument`. We will add template validation feedback, keyboard shortcuts (Cmd+S, Cmd+Z, Cmd+Shift+Z, Delete), Empty state for empty selection & empty library grid, and accessibility labeling/hints for inspector controls.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Dynamic Type Row Sizing | Update `SettingsRow.swift` to use `@ScaledMetric` for labels to resize dynamically | None | PLANNED |
| 2 | Property Inspector Empty State | Add template metadata editor and validation errors display to `.empty` state in `PropertyInspector.swift` | None | PLANNED |
| 3 | Library Grid Empty State | Implement placeholder view in `TemplateLibraryGrid.swift` when list is empty | None | PLANNED |
| 4 | Settings Validation Rendering | Bind and display VM validation errors in `ProfileView.swift` | None | PLANNED |
| 5 | Keyboard Shortcuts | Add Cmd+Z (Undo), Cmd+Shift+Z (Redo), Cmd+S (Save), and Delete component shortcuts to the template editor | None | PLANNED |
| 6 | Accessibility Enhancements | Add accessibility attributes (`.accessibilityLabel`, `.accessibilityHint`) to inspector controls in `InspectorControlDescriptor.swift` | None | PLANNED |
| 7 | SharedUI Styling Conformance | Refactor manual backgrounds/borders in settings and travel charge views to use `.standardCardStyle()` and `.standardSectionStyle()` | None | PLANNED |

## Interface Contracts
### Feature.Settings ↔ SharedUI
- Leverages `.standardCardStyle()` and `.standardSectionStyle()` modifiers from `SharedUI` components.
### Feature.InvoiceTemplateEditor ↔ SharedUI
- Leverages `.standardCardStyle()` and `.standardSectionStyle()` modifiers from `SharedUI` components.
