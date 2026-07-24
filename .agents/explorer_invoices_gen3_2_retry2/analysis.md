# Token Compliance Gap Analysis: Feature.Invoices Views

This report presents the findings from an audit of the four target SwiftUI view files in the `Feature.Invoices` package at `/Users/user/Developer/InvoicingApplication/InvoicingApplication/Packages/Feature.Invoices/Sources/Feature_Invoices/Views/`. 

The objective is to identify any raw numeric literals for padding, corner-radius, spacing, or local custom/hardcoded colors, and map them to design tokens from `StyleGuide`, `ColorSystem`, and `PanelShellTokens`.

---

## 1. Executive Summary
- **Target Views Audited**: 4
- **Fully Compliant Views**: 3 (`InvoiceTemplateRendererView.swift`, `InvoicesColumns.swift`, `InvoicesDetailColumn.swift`)
- **Non-Compliant Views**: 1 (`InvoicesView.swift`)
- **Total Gaps Identified**: 3 distinct styling/layout gaps (comprising 8 total occurrences of raw/hardcoded values in `InvoicesView.swift`).

---

## 2. File-by-File Detailed Findings

### I. InvoiceTemplateRendererView.swift
- **Path**: `Sources/Feature_Invoices/Views/InvoiceTemplateRendererView.swift`
- **Findings**: **No gaps found.**
- **Details**: This view acts solely as a controller/wrapper around `InvoiceCanvasView`. It manages data loading, template selection, and SwiftData state integration. It contains no styling modifiers (`.padding`, `.background`, `.foregroundColor`, `.cornerRadius`) or raw layout metrics.
- **Compliance Status**: **Fully Compliant**

### II. InvoicesColumns.swift
- **Path**: `Sources/Feature_Invoices/Views/InvoicesColumns.swift`
- **Findings**: **No gaps found.**
- **Details**: Defines `InvoicesContentColumn`, which serves as a layout integration point wrapping `InvoicesView` or `ProgressView`. The only numeric literal is a sleep duration (`150` milliseconds in `Task.sleep`), which is a timing logic parameter, not a layout/styling literal.
- **Compliance Status**: **Fully Compliant**

### III. InvoicesDetailColumn.swift
- **Path**: `Sources/Feature_Invoices/Views/InvoicesDetailColumn.swift`
- **Findings**: **No gaps found.**
- **Details**: Renders the main detail editor (`InvoiceEditor`) or inspector form (`InvoiceEditorFormContent`). It uses standard framework components and has no styling custom overrides, hardcoded colors, or layout literals.
- **Compliance Status**: **Fully Compliant**

### IV. InvoicesView.swift
- **Path**: `Sources/Feature_Invoices/Views/InvoicesView.swift`
- **Findings**: **3 design token gaps identified** (8 total literal occurrences).
- **Compliance Status**: **Non-Compliant**

#### Gap Breakdown in `InvoicesView.swift`:

| # | Type | Verbatim Literal / Code | Location (Line) | Issue Description | Recommended Token / Fix |
|---|---|---|---|---|---|
| 1 | Color | `Color.white` | 212, 229, 245, 262, 279 | Hardcoded white foreground color for text and buttons in the multi-select toolbar overlay. | Use `StyleGuide.Colors.text` or create a semantic token in `StyleGuide` (e.g. `StyleGuide.Colors.textLight` or `textOnAccent`) for high-contrast text on dark/glass overlays. |
| 2 | Color | `Color.white.opacity(0.8)` | 215 | Hardcoded secondary white foreground color for helper text. | Use `StyleGuide.Colors.textSecondary` or create a semantic token like `StyleGuide.Colors.textLightSecondary`. |
| 3 | Duration | `0.2` (in `.easeOut(duration: 0.2)`) | 171 | Raw duration literal for the invoice list row selection animation transition. | Replace with standard duration/transition: `StyleGuide.Animations.durationShort` (0.1s), `StyleGuide.Animations.durationMedium` (0.3s), or use `PanelShellTokens.shellTransition`. |
| 4 | Spacing | `spacing: 0` (in `VStack(spacing: 0)`) | 66, 192 | Raw `0` literal used as layout spacing. | Map to `StyleGuide.Dimensions.zeroPadding` for token alignment, though raw `0` is typically tolerated as a layout sentinel. |

---

## 3. Recommended Fix Strategy

To resolve the gaps in `InvoicesView.swift`, apply the following refactoring steps:

1. **Toolbar Text Foreground Colors (Lines 212, 215, 229, 245, 262, 279)**:
   - *Current Code*: `.foregroundColor(Color.white)` and `.foregroundColor(Color.white.opacity(0.8))`
   - *Problem*: Using hardcoded `Color.white` on a glass effect panel might lead to readability issues depending on the user's system appearance (since `.glassEffect` adapts to light/dark themes).
   - *Strategy*: Update the text elements to use `StyleGuide.Colors.text` and `StyleGuide.Colors.textSecondary` to support adaptive themes, or define new token variables `StyleGuide.Colors.textContrastPrimary` and `StyleGuide.Colors.textContrastSecondary` if the overlay must always present light text regardless of system light/dark settings.

2. **Row Selection Transition Duration (Line 171)**:
   - *Current Code*: `withAnimation(.easeOut(duration: 0.2)) { ... }`
   - *Problem*: Raw numeric animation timing.
   - *Strategy*: Replace with a standard animation duration from `StyleGuide.Animations`. E.g., `withAnimation(.easeOut(duration: StyleGuide.Animations.durationMedium))` (0.3s) or introduce a standard short transition token.

3. **Layout Sentinel Alignment (Lines 66, 192)**:
   - *Current Code*: `VStack(spacing: 0)`
   - *Strategy*: Change to `VStack(spacing: StyleGuide.Dimensions.zeroPadding)` to ensure total alignment with layout tokens.
