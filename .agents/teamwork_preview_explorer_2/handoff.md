# Handoff Report: InvoiceTemplateEditor Analysis

## Observation

### 1. Current Architecture & Models in `Packages/Feature.InvoiceTemplateEditor`
- **Domain Persistence Model**: `InvoiceDocument` (`Sources/InvoiceTableLayoutEditor/Models/InvoiceDocument.swift:3-601`). Holds invoice content + formatting fields (`accentThemeRaw`, `customAccentRed/Green/Blue/Opacity`, `marginPresetRaw`, `customMarginPoints`, `customPageWidthPoints`, `customPageHeightPoints`, `typographyDensityRaw`, `customTypographyScale`, `headerStyleRaw`, `partyLayoutRaw`, `tableStyleRaw`, `fontFamilyRaw`, `logoPlacementRaw`, `borderWeightRaw`, `currencyDisplayStyleRaw`, `totalsEmphasisRaw`).
- **Configuration Snapshot**: `InvoiceTemplateConfiguration` (`Sources/InvoiceTableLayoutEditor/Models/InvoiceEnums.swift:770-828`). `Codable & Equatable` struct wrapping all formatting fields. Features resilient decoding (`InvoiceEnums.swift:897-980`) with key-by-key fallbacks and range clamping via `InvoiceTemplateLayoutLimits` (`InvoiceEnums.swift:832-874`).
- **Preset Serialization & Store**:
  - `InvoiceTemplatePreset` (`InvoiceEnums.swift:686-767`): Static `enum` (`.classic`, `.compact`, `.minimal`, `.modern`) with hardcoded `configuration` getters.
  - `InvoiceTemplateDefaults` (`Data/InvoiceTemplatePreferenceStore.swift:6-96`): Envelope holding `version: Int = 2`, `paperSize`, `pageOrientation`, `configuration`.
  - `InvoiceTemplatePreferenceStore` (`Data/InvoiceTemplatePreferenceStore.swift:99-141`): Manages persistence to `UserDefaults` under key `"InvoiceTemplateEditor.TemplateConfiguration.v1"`.
- **Editor State & View Model**:
  - `InvoiceEditorViewModel` (`Views/InvoiceEditorViewModel.swift:47-450`): `@Observable @MainActor` store holding draft attributes, pagination status, status messages, activity states, and published properties for visual settings.
  - `InvoiceTemplateRibbon` (`Views/InvoiceTemplateRibbon.swift:112-726`): Form inspector categorized into 5 sections (`.template`, `.layout`, `.design`, `.content`, `.lineItems`).
- **Document Preview & Pagination**:
  - `InvoiceDocumentPreview` (`Views/InvoiceDocumentPreview.swift:7-178`): Scaled preview with geometry calculation, pinch/command-scroll zoom, and off-screen `InvoicePaginationMeasurer` (`Views/InvoicePaginationMeasurer.swift:9-154`).
  - `InvoiceDocumentPreviewPage` (`Views/InvoiceDocumentPreview.swift:377-553`): Card renderer applying margins, borders, shadows, headers (`InvoiceDocumentSections.swift:97-200`), parties, line items table, and payment footer.
  - `InvoicePagination` (`Views/InvoicePagination.swift:17-314`): Pure pagination algorithm computing content bounds, page breaks, and footer positioning.

---

## Logic Chain

### 2. Implementing Template Preset Management
- **Observation**: `InvoiceTemplatePreset` (`InvoiceEnums.swift:686`) is currently a fixed hardcoded enum. `InvoiceTemplatePreferenceStore` (`InvoiceTemplatePreferenceStore.swift:99`) only saves default settings, not user-saved preset collections.
- **Logic**:
  1. Define `struct InvoiceCustomTemplatePreset: Identifiable, Codable, Equatable`:
     - Fields: `id: UUID`, `name: String`, `paperSize: PaperSize`, `pageOrientation: PageOrientation`, `configuration: InvoiceTemplateConfiguration`, `createdAt: Date`.
  2. Storage Layer:
     - Add `InvoiceCustomPresetStore` (or extend `InvoiceTemplatePreferenceStore`) with `UserDefaults` key `"InvoiceTemplateEditor.CustomPresets.v1"`.
     - Implement `loadCustomPresets() -> [InvoiceCustomTemplatePreset]` and `saveCustomPresets(_ presets: [InvoiceCustomTemplatePreset])`.
  3. View Model Integration:
     - Add `customPresets: [InvoiceCustomTemplatePreset]` to `InvoiceEditorViewModel`.
     - Expose `saveCurrentAsPreset(named: String)`, `deleteCustomPreset(id: UUID)`, `applyCustomPreset(_ preset: InvoiceCustomTemplatePreset)`.
  4. Ribbon UI (`InvoiceTemplateRibbon.swift:335-377`):
     - Replace single-enum picker with grouped menu in `templateTab`: Built-in (`Classic`, `Compact`, `Minimal`, `Modern`) + User Presets.
     - Add "Save Current Preset..." button opening name-prompt sheet.
     - Add "Manage Custom Presets..." modal sheet for preset deletion/renaming.

### 3. Implementing Brand Accent & Logo Customization
- **Observation**: Accent colors are controlled via `InvoiceAccentTheme` enum (`InvoiceEnums.swift:156`) or `customAccentColor: InvoiceCustomAccentColor?` (`InvoiceEnums.swift:983`) edited by `ColorPicker` in `designTab` (`InvoiceTemplateRibbon.swift:456`). Logo support is limited to `logoPlacement: InvoiceLogoPlacement` (`InvoiceEnums.swift:614`) rendering monogram initials via `InvoiceBrandMark` (`Views/InvoiceBrandMark.swift:3-12`).
- **Logic**:
  1. Accent Color Extensions:
     - Add brand palette presets (swatches) + Hex string input (`#HEX`) in `designTab`.
     - Add optional `secondaryAccentColor` or derived tinting for zebra rows, table borders, and header backgrounds.
  2. Logo Customization:
     - Extend `InvoiceTemplateConfiguration` with `logoStyle: InvoiceLogoStyle` (`.monogram`, `.customImage`), `logoImageData: Data?`, and `logoScale: Double` (range `0.5...2.0`).
     - Update `InvoiceDocumentSections.businessMark` (`InvoiceDocumentSections.swift:97-200`) to render `NSImage(data: logoImageData)` if `.customImage` selected, falling back to `InvoiceBrandMark.initials`.
     - Expand `logoPlacement` options to support `.leading`, `.trailing`, `.centerAboveTitle`, `.hidden`.
     - Add a "Branding & Logo" control card in `InvoiceTemplateRibbon` with image picker button, placement dropdown, and scale slider.

### 4. Implementing Page Margin & Pagination Controls
- **Observation**: Margins are set via `marginPreset` or `customMarginPoints` (`InvoiceEnums.swift:192`) in text field (`InvoiceTemplateRibbon.swift:422`). Document preview (`InvoiceDocumentPreviewPage`, `InvoiceDocumentPreview.swift:377`) applies static `.padding(margin)`. Pagination is computed silently off-screen without breakpoint indicators.
- **Logic**:
  1. Interactive Page Margin Adjustments:
     - In `InvoiceDocumentPreviewPage` (`InvoiceDocumentPreview.swift:413`), overlay interactive dashed margin guide lines when layout mode or hover is active.
     - Add `DragGesture` on top/bottom/left/right margin handles inside preview.
     - Translate drag gesture translation in points into updated `customMarginPoints`, clamped live via `InvoiceTemplateLayoutLimits.effectiveMargin(requested, pageSize: pageSize)`.
  2. Pagination Breakpoint Markers:
     - In `InvoiceDocumentPreview`, calculate cumulative line-item heights vs `printableHeight`.
     - Overlay visual breakpoint markers: dashed accent lines with badges (e.g., `Page 1 Break (88% filled)`) between table rows in preview.
     - Support optional manual page break flags (`forcePageBreakBefore: Bool` on `InvoiceLineItem`) and pass to `InvoicePagination.splitLineItemsAcrossPages`.

### 5. Unit Test Strategy
- **Observation**: Existing tests cover pagination row splitting (`InvoicePaginationTests.swift`), error presentation, double input parsing, filename escaping, and command context (`InvoiceEditorSeparationTests.swift`).
- **Logic**: New features require dedicated unit tests:
  1. Preset Management:
     - Test custom preset encoding/decoding resilience.
     - Test saving, loading, and deleting custom presets in `InvoiceTemplatePreferenceStore`.
     - Test applying custom preset updates all `InvoiceEditorViewModel` configuration properties cleanly.
  2. Brand Accent & Logo:
     - Test hex color parsing and `InvoiceCustomAccentColor` conversion.
     - Test logo image data serialization resilience in `InvoiceTemplateConfiguration`.
     - Test `InvoiceDocumentSections.businessMark` rendering selection (custom image vs monogram fallback).
  3. Interactive Margins & Pagination Breakpoints:
     - Test margin drag gesture delta conversion and `InvoiceTemplateLayoutLimits` clamping.
     - Test calculation of page break row indices in `InvoicePagination.paginate`.
     - Test manual page break insertion flags (`forcePageBreakBefore`).

---

## Caveats
- No source code modifications executed per read-only task assignment.
- AppKit dependency (`NSImage`, `NSColor`, `NSHostingView`) requires tests running on macOS target.
- PDF export/print features depend on PDFKit frame calculations, which must remain synchronized with SwiftUI measurement passes.

---

## Conclusion
- Current architecture in `Packages/Feature.InvoiceTemplateEditor` provides clean separation between `InvoiceDocument` persistence, `InvoiceTemplateConfiguration` snapshotting, `InvoiceEditorViewModel` state management, and `InvoicePagination` engine.
- Implementation of Template Preset Management, Brand Accent & Logo Customization, and Interactive Page Margin/Pagination Controls can be achieved by expanding `InvoiceTemplateConfiguration`, `InvoiceTemplatePreferenceStore`, `InvoiceEditorViewModel`, `InvoiceTemplateRibbon`, `InvoiceDocumentPreview`, and `InvoicePagination` without breaking existing schema or migration compatibility.

---

## Verification Method
- **Inspect Files**:
  - `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Models/InvoiceDocument.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Models/InvoiceEnums.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Data/InvoiceTemplatePreferenceStore.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceEditorViewModel.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceTemplateRibbon.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceDocumentPreview.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoicePagination.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Tests/InvoiceTableLayoutEditorTests/InvoicePaginationTests.swift`
- **Build & Test Command**:
  - `swift test --package-path Packages/Feature.InvoiceTemplateEditor`
