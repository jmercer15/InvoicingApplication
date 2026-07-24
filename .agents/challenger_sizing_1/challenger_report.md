# Challenger Report: Sizing Refactor Empirical Validation

## Challenge Summary

**Overall risk assessment**: **LOW**

The sizing refactor introduces a deterministic, CoreText-driven layout engine for document grids alongside a robust SwiftUI reconciliation system. Based on empirical test coverage and source code analysis, the refactor is highly stable, backward-compatible, and resilient to layout loop oscillations. All package and application tests pass cleanly.

---

## Challenges

### [Medium] Challenge 1: Fixed Ratio Overflow Handling in FlexibleSizeCalculator
- **Assumption challenged**: That the sum of column/row ratios matches or fits within the container's total size without exceeding bounds.
- **Attack scenario**: If fixed column ratios are configured such that their sum exceeds `1.0` (e.g., two columns at `0.6` each) and expand/flexible columns are also present, `FlexibleSizeCalculator` does not downscale the fixed columns. It allocates the full `0.6 * totalSize` to each fixed column, resulting in the table overflowing the container's bounds.
- **Blast radius**: The layout overflows horizontally or vertically beyond the container size, causing visual clipping or broken page boundaries.
- **Mitigation**: Add normalization/scaling code in `FlexibleSizeCalculator` to downscale fixed ratios proportionally when their sum exceeds `1.0`, regardless of the presence of auto/expand sizing modes.

### [Low] Challenge 2: Missing CoreText Font Mappings on Host System
- **Assumption challenged**: That all fonts specified in templates (e.g., custom user fonts) exist on the rendering host system.
- **Attack scenario**: If a document uses a font not present on the host system, CoreText falls back to a system default (e.g., `Helvetica` or `.SFNS-Regular`), which has different glyph widths and kerning. This changes the text measurement dynamically during export.
- **Blast radius**: Slight changes in text heights/wrapping, potentially causing page overflow during PDF export compared to the screen design.
- **Mitigation**: The code resolved this by using a deterministic fallback (`Helvetica` or system design names) and exposing `FontCapabilityDetector` to restrict font selections in the UI to active/available CoreText families.

---

## Stress Test Results

- **Zero Container Width** → `FlexibleSizeCalculator` returns a flat array of zero sizes without nan/inf division errors. → **PASS**
- **Negative Intrinsic Size** → Clamped safely to `0` and does not expand container layout. → **PASS**
- **NaN/Infinity Deltas on Resizing** → Clamped to valid proportions (`0.05` to `0.95`), maintaining ratio sums of `1.0`. → **PASS**
- **Partial/Oscillating Pref Height Signals** → `DocumentGridContentHeight.reconciledGridHeight` rejects partial/incomplete row measurements, using the deterministic analytic height until all row heights are available. → **PASS**
- **Geometry Reader preference loop prevention** → Layout updates are deferred using `Task { @MainActor in await Task.yield() }` and layout changes below `TemplateLayoutEngine.sizeEpsilon` (0.01) are ignored. Previews and views render without infinite loops. → **PASS**
- **Backward Compatibility (Legacy JSON)** → Serialized JSON files lacking newer attributes (`sectionSplits`, `pageSize`, `sectionHeightRatios`) decode successfully, restoring defaults (`[1.0]` for height ratios, `[:]` for splits). `TableAxisConfiguration` maps legacy keys `width` and `height` to `size` successfully. → **PASS**

---

## Package Test Execution Summary

A total of 395 tests were executed across all packages and the main application target, with a 100% success rate:

| Package / Target | Tests Run | Failures | Skipped | Status |
|---|---|---|---|---|
| **SharedUI** | 27 | 0 | 0 | **PASS** |
| **Feature.Settings** | 6 | 0 | 0 | **PASS** |
| **Core** | 15 | 0 | 0 | **PASS** |
| **Data** | 119 | 0 | 2 | **PASS** (2 EventKit/host-specific tests skipped) |
| **Feature.BillingHub** | 3 | 0 | 0 | **PASS** |
| **Feature.Clients** | 4 | 0 | 0 | **PASS** |
| **Feature.InvoiceTemplateEditor** | 160 | 0 | 0 | **PASS** |
| **Feature.Invoices** | 32 | 0 | 0 | **PASS** |
| **Feature.NDIS** | 12 | 0 | 0 | **PASS** |
| **AppShell** | 14 | 0 | 0 | **PASS** |
| **InvoicingApplication** | 3 | 0 | 0 | **PASS** |
| **Total** | **395** | **0** | **2** | **PASS** |

---

## Unchallenged Areas

- **Platform-Specific Font Rendering Engine Differences** — Not challenged because testing is confined to the macOS target platforms running native Apple CoreText APIs.
