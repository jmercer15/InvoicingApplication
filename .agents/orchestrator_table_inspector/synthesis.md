# Table & Table-Cell Inspector UX Synthesis & Design Blueprint

## 1. Table Inspector Refinement (ComponentPropertyEditor+Table.swift)
- **Separate Accordions**: Split the massive "Appearance" and typography section into 8 focused collapsible sections:
  1. **Structure** (`.tableLayoutStructure`): Table direction, headers presence, cell & header padding.
  2. **Colors & Fills** (`.tableFill`): Cell fill, alternating row colors, header fill.
  3. **Grid & Borders** (`.tableBorders`): Outer borders, row separators, header separators, inner cell borders (exposing previously hidden model capabilities).
  4. **Shadow** (`.tableShadow`): Table shadow toggle, color, opacity, offsets, radius.
  5. **Typography** (`.tableTypography`): Global font family, size, weight, line/letter spacing (strict table-wide settings, no misleading column/row selection dropdown).
  6. **Rows** (`.tableRows`): Row selection, height mode, fixed height, and row line limit.
  7. **Columns** (`.tableColumns`): Column selection, width mode, fixed width, alignment, and column line limit.
  8. **Section Title** (`.sectionTitle`): Section title string, alignment, and typography.
- **Unifying Typography**: Remove the confusing column/row selection from Typography; typography is global. Move `lineLimit` to the Column and Row sections.

## 2. Cell-Level Inspector Refinement (TableElementPropertyEditor.swift & Extensions)
- **Section Consolidation**: Consolidate the Cell selection inspector into two sections:
  1. **Text & Styling**: AlignmentGridPicker, font size stepper, weight/transform pickers, text/background colors.
  2. **Cell Layout & Sizing**: Sizing mode picker (Flexible, Auto-Size, Fixed), conditional width/height steppers, padding override, line limits.
- **Dimension Controls**: Replace text fields with Segmented Pickers ("Flexible", "Auto-Size", "Fixed Width/Height") and point steppers. Mode changes must update the model appropriately.
- **Cell Alignment**: Embed `AlignmentGridPicker` (3x3 Grid Matrix) instead of dual dropdown menus.
- **Cell Padding Override**: Add a toggle for "Override Table Padding" and stepper for cell-level padding.
- **Reset Styles Action**: Move the "Reset Styles" button to a gear or top-right toolbar action instead of keeping a separate section.

## 3. Component & Design Token Polish (AlignmentGridPicker.swift & Steppers)
- **Token Compliance**: Remove NSColor/AppKit calls and raw opacity/color overrides. Use `ColorSystem.Primary.blue`, `Color.secondaryText`, `PanelShellTokens.panelSecondaryBackground`, etc.
- **Visual Grid alignment**: Wrap `AlignmentGridPicker` in `InspectorGridCell` to align labels.
- **HIG Buttons**: Refactor grid buttons in `AlignmentButton` to use native `Button` with plain style so they are keyboard focusable and support VoiceOver.
- **Visual Stability**: In Row/Column details, disable/fade dependent fields instead of hiding them dynamically (flexible disables autoSize/stepper; autoSize disables stepper).
- **Accessibility**: Pass accessibility labels to text fields, add hidden traits to decorative images, and fix the down-right icon typo.
