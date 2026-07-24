# Default Invoice Template Analysis

This report analyzes the `Feature.InvoiceTemplateEditor` package's component structure, the `SectionSplit` layout engine, and details the requirements for implementing a default print-optimized invoice template.

---

## 1. Invoice Component Creation, Styling, and Layout

### Component Representation
* **Model**: Represented by the `InvoiceComponent` struct in `InvoiceComponent.swift`.
* **Properties**: 
  - `id: UUID`: Unique identifier.
  - `type: InvoiceComponentType`: Enum representing elements like `.companyName`, `.companyLogo`, `.billTo`, `.participant`, `.servicesTable`, `.totals`, `.paymentDetails`, `.paymentTerms`, `.notes`.
  - `position: CGPoint` & `size: CGSize`: Define its bounds.
  - `style: ComponentStyle`: Governs typography, margins, padding, colors, borders, and shape configurations.

### Styling System
* **Model**: Defined in `InvoiceComponentStyle.swift` as `ComponentStyle`.
* **Builders**: Property modifiers are defined in `InvoiceComponentStyle+Builders.swift`.
* **Default Styles**: Resolved using `ComponentStyle.defaultStyle(for: InvoiceComponentType)`. Examples:
  - `.companyName`: Derived from `modernHeader` style, using bold 20pt size, dark grey color (`#1F2937`), and leading text alignment.
  - `.servicesTable`: Derived from `cleanTable` style, using 10pt size, `#374151` text, `#F9FAFB` header background, `#FFFFFF` row background, `#D1D5DB` borders, and horizontal table direction.
  - `.totals`: Derived from `cleanTable` style, utilizing a vertical table layout (tableDirection = .vertical), 10pt font size, and grid columns configured to 2.

### Layout & Placement
* **Legacy Mode**: Components are positioned absolutely on the page via their `position: CGPoint` and `size: CGSize`.
* **Modern Mode (SectionSplits)**: Components are bound to a leaf child cell of a `SectionSplit`. The rendering engine calculates the layout cell's bounding box and positions the component inside it:
  - First component in the leaf slot's list is rendered.
  - Alignment is handled via `calculateAlignedComponentRect(_:within:alignment:)` using `SectionSplit.LeafAlignment` (horizontal `.leading` | `.center` | `.trailing` and vertical `.top` | `.center` | `.bottom`).
  - Size is constrained to the cell bounds: `min(size.width, bounds.width)` and `min(size.height, bounds.height)`.

---

## 2. SectionSplit Layout Hierarchy System

### Layout Hierarchy Representation
* **Model**: Defined in `SectionSplit.swift`.
* **Structure**: Represents a node in a recursive layout tree.
  - `direction: SplitDirection`: Can be `.horizontal`, `.vertical`, or `.grid`.
  - `splitRatios: [CGFloat]`: Specifies division ratios along the split axis.
  - `children: [SectionSplit?]`: Nested sub-sections. `nil` represents a leaf subsection.
  - `childComponents: [Int: [InvoiceComponent]]`: Maps child indices to their contained components (for leaf cells).
  - `childLabels: [Int: String]`: Custom human-readable labels per cell.
  - `childAlignments: [Int: LeafAlignment]`: Alignment settings per leaf cell.
  - `childWidthSizingModes: [SizingMode]` and `childHeightSizingModes: [SizingMode]`: Sizing behaviors (`.fixed` / ratio-based, `.expand` / take remaining space, `.shrink` / shrink to content).
  - `gridRows` & `gridColumns`: Define grid dimensions when `direction == .grid`.

### Sizing and Spacing Calculations
* Sizing computations are defined in `FlexibleSizeCalculator.swift` under `calculateSizes`.
* It handles spacing (`childSpacing`), cell padding (`childPaddings`), and outer margin (`margin`) / padding (`padding`).
* Linear partitions are recursively resolved in `ExportService+SectionLayout.swift` (`calculateChildRects(for:within:)`), yielding precise bounding rectangles for each sub-section cell in the layout hierarchy.

---

## 3. Current Default Template Loading and Integration Gaps

### Current Integration
* **File**: `InvoiceTemplateEditorViewModel.swift`
* **Method**: `loadDefaultTemplate()` (lines 302-343)
* **Current Implementation**:
  - Instantiates a hardcoded list of flat components (`companyName`, `companyLogo`, `invoiceNumberAndDates`, `billTo`, `servicesTable`, `totals`) with fixed absolute positions and sizes.
  - Sequentially appends them to the document using `document.add(component)`.
  - **Limitation**: This populates the legacy flat array `document.components`. It does NOT establish any `SectionSplit` hierarchy, which leaves the modern layout tree empty by default.

### Required Integration Changes
To support the modern structured layout system by default:
1. Extract default document construction to a dedicated domain helper class: `DefaultInvoiceTemplate.swift`.
2. Refactor `InvoiceTemplateEditorViewModel.swift`'s `loadDefaultTemplate()` to clean up the absolute positioning and load the new structured document via `DefaultInvoiceTemplate.createDefaultDocument()`.
3. Set `hasUnsavedChanges = false` and capture initial state after loading.

---

## 4. Suggested Print-Optimized A4/Letter Layout Structure

### Document Specifications
* **Page Dimensions**: A4 is 595.2 x 841.8 pt. Letter is 612.0 x 792.0 pt.
* **Margins**: 36 pt (0.5 inches) for balanced padding.
* **Layout Sizing Mode**: Relative height ratios on the top-level section split adapt seamlessly to both A4 and Letter heights.

### Layout Tree Configuration
We propose a 4-section layout partition with vertical height ratios `[0.15, 0.20, 0.45, 0.20]`.

#### Section 0: Header (Index 0, Ratio 0.15)
* **Type**: Horizontal Split `[0.6, 0.4]`
* **Columns**:
  - **Column 0 (Ratio 0.6)**: Vertical Split `[0.6, 0.4]`
    - Row 0 (Ratio 0.6): `.companyName` (Size: 300x40, Alignment: Leading/Top)
    - Row 1 (Ratio 0.4): `.companyABN` (Size: 300x20, Alignment: Leading/Top)
  - **Column 1 (Ratio 0.4)**: Vertical Split `[0.6, 0.4]`
    - Row 0 (Ratio 0.6): `.companyLogo` (Size: 100x40, Alignment: Trailing/Top)
    - Row 1 (Ratio 0.4): `.invoiceTitle` (Size: 150x30, Alignment: Trailing/Top)

#### Section 1: Billing & Invoice Info (Index 1, Ratio 0.20)
* **Type**: Horizontal Split `[0.5, 0.5]`
* **Columns**:
  - **Column 0 (Ratio 0.5)**: Vertical Split `[0.5, 0.5]`
    - Row 0 (Ratio 0.5): `.billTo` (Size: 250x60, Alignment: Leading/Top)
    - Row 1 (Ratio 0.5): `.participant` (Size: 250x40, Alignment: Leading/Top)
  - **Column 1 (Ratio 0.5)**: Vertical Split `[0.5, 0.5]`
    - Row 0 (Ratio 0.5): `.invoiceNumberAndDates` (Size: 200x50, Alignment: Trailing/Top)
    - Row 1 (Ratio 0.5): Spacer/Empty (Or textbox if custom note needed; Size: 200x30, Alignment: Trailing/Top)

#### Section 2: Services List (Index 2, Ratio 0.45)
* **Type**: Horizontal Split `[1.0]` (Single Cell)
* **Content**: `.servicesTable` (Size: 523.2x300, Alignment: Leading/Top) - Note: 523.2pt represents full printable A4 width (595.2 - 72).

#### Section 3: Footer, Totals & Notes (Index 3, Ratio 0.20)
* **Type**: Horizontal Split `[0.5, 0.5]`
* **Columns**:
  - **Column 0 (Ratio 0.5)**: Vertical Split `[0.5, 0.5]`
    - Row 0 (Ratio 0.5): `.paymentDetails` (Size: 250x50, Alignment: Leading/Top)
    - Row 1 (Ratio 0.5): `.paymentTerms` (Size: 250x40, Alignment: Leading/Top)
  - **Column 1 (Ratio 0.5)**: Vertical Split `[0.5, 0.5]`
    - Row 0 (Ratio 0.5): `.totals` (Size: 200x60, Alignment: Trailing/Top)
    - Row 1 (Ratio 0.5): `.notes` (Size: 200x40, Alignment: Trailing/Top)
