# Handoff Report — Styling Audit

This handoff report summarizes the read-only investigation of the InvoicingApplication packages to identify unnecessary custom styling, non-native shadows, custom hover effects, and custom selection highlights that interfere with standard macOS native UI behaviors.

## 1. Observation
The following key styling occurrences were directly observed in the codebase:
- **Sidebar Selection Foreground Style**:
  - File: `Packages/SharedUI/Sources/SharedUI/Components/SidebarItemRow.swift`
  - Line 18: `.foregroundStyle(isSelected ? StyleGuide.Colors.primary : StyleGuide.Colors.textSecondary)`
  - Line 23: `.foregroundStyle(isSelected ? StyleGuide.Colors.primary : StyleGuide.Colors.text)`
- **Hover Scale Effects**:
  - File: `Packages/Feature.Clients/Sources/Feature_Clients/Layouts/RelationshipsLayouts.swift`
  - Line 42: `.scaleEffect(isHovered ? 1.02 : 1.0)`
  - Line 239: `.scaleEffect(isHovered ? 1.02 : 1.0)`
  - File: `Packages/Feature.Clients/Sources/Feature_Clients/Views/ClientDetailServiceAgreementsCard.swift`
  - Line 132: `.scaleEffect(isHovered ? 1.01 : 1.0)`
  - File: `Packages/Feature.Clients/Sources/Feature_Clients/Views/ServiceAssignmentSheetView.swift`
  - Line 422: `.scaleEffect(isSelected ? (isHovered ? 1.03 : 1.02) : (isHovered ? 1.01 : 1.0))`
  - File: `Packages/Feature.Clients/Sources/Feature_Clients/Views/ServiceBulkEditorView.swift`
  - Line 268: `.scaleEffect(isHovered ? 1.15 : 1.0)`
- **Heavy Custom Drop Shadows**:
  - File: `Packages/Feature.Calendar/Sources/Feature_Calendar/Views/MonthView/MonthView.swift`
  - Line 22-27: `.shadow(color: StyleGuide.shadowColor.opacity(StyleGuide.Opacity.strong), radius: StyleGuide.Shadows.darkRadius, x: 0, y: StyleGuide.Shadows.darkOffsetY)`
  - File: `Packages/Feature.Calendar/Sources/Feature_Calendar/Views/WeekView/WeekView.swift`
  - Line 27: `.shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)`
  - File: `Packages/SharedUI/Sources/SharedUI/ViewModifiers.swift`
  - Line 197: `.shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1.5)` (applied on `EnhancedGroupBoxStyle`)
  - File: `Packages/SharedUI/Sources/SharedUI/Components/InfoChip.swift`
  - Line 43: `.shadow(...)`
- **Custom Selection Highlight / Hover on Custom Card Layouts**:
  - File: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISCatalogueCards.swift`
  - Line 88 & 278: Border highlights on focus/selection (`ColorSystem.Primary.blue`).
  - File: `Packages/Feature.NDIS/Sources/Feature_NDIS/Views/NDISDetailCards.swift`
  - Line 292: Background fill highlight on selection (`ColorSystem.Primary.blue.opacity(...)`).
  - File: `Packages/Feature.Clients/Sources/Feature_Clients/Views/ServiceAssignmentSheetView.swift`
  - Line 411: Background fill and stroke changes on selection (`Color.accentColor.opacity(...)`).
  - File: `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterPopoverContent.swift`
  - Line 259 & 319: Custom selection backgrounds for filter chips.
- **Canvas-Specific Shadows & Hover**:
  - File: `Packages/Feature.InvoiceTemplateEditor/Sources/...`
  - Various: Editor canvas elements use custom shadows (`ContentRectangleView.swift:242, 337`, `ImageComponent.swift:55`, `InvoiceCanvasView.swift:68`) and hover controls (`ResizableDivider.swift:84`) to enable drag-drop and customize invoice layouts.

## 2. Logic Chain
1. **Observation 1 (Sidebar Selection)**: Native macOS sidebar selection highlight automatically inverts text and icon colors to white to remain legible. However, `SidebarItemRow` overrides foreground styles by checking `isSelected` and hardcoding `StyleGuide.Colors.primary` (accent color, e.g. blue).
   - *Reasoning*: Hardcoded selected text color (blue) on a selected highlight background (blue) causes extremely low contrast, violating native accessibility and macOS design norms.
2. **Observation 2 (Hover Scale Effects)**: Various elements scale up when hovered (e.g. relationship group card 1.02x, service agreements card 1.01x, delete button 1.15x).
   - *Reasoning*: Native macOS applications use system cursors and subtle background/border color changes to show hover state; scale transitions on hover are atypical and mimic mobile/web styling rather than native macOS desktop standards.
3. **Observation 3 (Heavy Drop Shadows)**: Calendar month and week grids, info chips, and custom groupboxes apply explicit drop shadows to flat surfaces.
   - *Reasoning*: Standard macOS app elements are flat or rely on system window shadows; applying explicit drop shadows to nested grid sections and info items creates unnecessary visual noise.
4. **Observation 4 (Canvas Editor)**: Custom canvas elements in `Feature.InvoiceTemplateEditor` rely on custom shadows and hover-state handles.
   - *Reasoning*: Since the template editor is a graphic document builder tool, these shadows represent document page rendering and layout tools rather than standard macOS UI, and therefore should be retained.

## 3. Caveats
- Checked all SwiftUI View files under `Packages/`. Did not scan resources, mock data, or test files for styling unless they were part of active package UI.
- The custom canvas elements (`Feature.InvoiceTemplateEditor`) are treated as essential domain-specific UI where non-native drag shadows and bounding box overlays are expected behavior.
- Standard settings view (`SettingsView.swift`) is verified as native with no custom selection highlight overrides.

## 4. Conclusion
The InvoicingApplication codebase contains styling elements that diverge from macOS native guidelines. 
- **Critical Action**: Remove the hardcoded foreground color overrides in `SidebarItemRow.swift` so that text/icons invert correctly to white upon sidebar selection.
- **Medium Actions**: Remove non-native `.scaleEffect` modifiers on hovers across features (NDIS cards, relationship layouts, service sheets) and simplify custom drop shadows in calendar views (`MonthView`, `WeekView`) and custom groupboxes (`EnhancedGroupBoxStyle`).
- **Low Actions**: Simplify chip selection background colors in popovers (`InvoiceFilterPopoverContent.swift`) to align with standard system colors.

## 5. Verification Method
1. **Inspect Code Locations**:
   - Open `/Users/user/Developer/InvoicingApplication/InvoicingApplication/Packages/SharedUI/Sources/SharedUI/Components/SidebarItemRow.swift` and check lines 18 and 23.
   - Open `/Users/user/Developer/InvoicingApplication/InvoicingApplication/Packages/Feature.Clients/Sources/Feature_Clients/Layouts/RelationshipsLayouts.swift` and check lines 42 and 239.
   - Open `/Users/user/Developer/InvoicingApplication/InvoicingApplication/Packages/Feature.Calendar/Sources/Feature_Calendar/Views/MonthView/MonthView.swift` and check lines 22-27.
2. **Invalidation Condition**: If standard macOS selection colors are dynamically adjusted by system colors and `SidebarItemRow` text is legible on selection, confirm if `StyleGuide.Colors.primary` matches the system selection color (which is unlikely to work correctly across different user accent color settings).
