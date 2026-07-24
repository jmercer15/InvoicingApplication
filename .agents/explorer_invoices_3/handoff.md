# Handoff Report: Feature.Invoices UI Refinement

This report details the findings and proposals from the read-only investigation of the `Feature.Invoices` views for Milestone 4.

## 1. Observation

### 1.1 Custom Toggle Buttons Lack Affordance and Accessibility
In `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterPopoverContent.swift`:
* `StatusFilterButton` utilizes a static background and border with `.buttonStyle(.plain)` and `.pointerStyle(.link)` (Lines 256-264):
```swift
            .background(isSelected ? statusColor.opacity(StyleGuide.Opacity.light) : StyleGuide.Colors.secondary.opacity(StyleGuide.Opacity.faint))
            .clipShape(shape)
            .overlay(
                shape
                    .strokeBorder(isSelected ? statusColor.opacity(StyleGuide.Opacity.strong) : Color.clear, lineWidth: 1)
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
```
* `ClientFilterButton` is structured identically with no interactive styles (Lines 311-314):
```swift
        .buttonStyle(.plain)
        .pointerStyle(.link)
```
* There are no `.accessibilityLabel`, `.accessibilityHint`, or `.accessibilityAddTraits` modifiers applied to either struct.

### 1.2 Improper Layout Token Hygiene
In `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterPopoverContent.swift` (Line 10):
```swift
    @ScaledMetric private var clientListMaxHeight: CGFloat = DetailSectionTokens.sortPickerWidth
```
This maps the maximum height of a list to `sortPickerWidth` (which is `120`).

### 1.3 Disabled Multi-Select Action Styling Issues
In `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesView.swift` (Lines 236-249):
```swift
                    Button(action: deleteSelectedInvoices) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .foregroundStyle(ColorSystem.Neutral.white)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(ColorSystem.Status.error, in: actionButtonShape)
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .disabled(selectedInvoices.isEmpty)
```
When `selectedInvoices.isEmpty` is true, the button is disabled, but its background color remains fully saturated `ColorSystem.Status.error` with a `.link` cursor style, providing no visual indication that the action is disabled.

### 1.4 Missing Text Labels and Selection Counts in Toolbar
In `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesContentToolbar.swift`:
* `organizeMenu` uses default link style (Line 99):
```swift
        .appToolbarLinkStyle(help: "Group and sort invoices")
```
* `filterButton` uses default link style (Line 119):
```swift
        .appToolbarLinkStyle(help: filterHelpText)
```
On macOS, `appToolbarLinkStyle` applies `.labelStyle(.iconOnly)` unless `compactLabels: false` is specified, hiding the dynamic title text and active filter selection counts.

### 1.5 Missing Loading States in Template Preview
In `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceTemplateRendererView.swift` (Lines 90-114), `loadTemplate()` executes asynchronous loading without any local state tracking to show a loading overlay or error view:
```swift
    private func loadTemplate() {
        Task {
            await templateDataService.setSelectedInvoice(invoice, items: invoiceItems)

            let templatesList = await templateManager.browseTemplates()
            ...
            if let metadata = selectedMetadata,
               let data = await templateManager.loadTemplate(metadata: metadata) {
                await MainActor.run {
                    document.loadTemplate(data)
                    lastTemplateId = resolvedTemplateId
                }
            }
        }
    }
```

### 1.6 Gesture-only Custom Interactive Elements
In `Packages/SharedUI/Sources/SharedUI/Components/NavigationListRow.swift` (Lines 41-44):
```swift
        .glassEffect(.regular.interactive(true), in: RoundedRectangle(cornerRadius: ListRowTokens.rowCornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: ListRowTokens.rowCornerRadius))
        .onTapGesture(perform: onTap)
```
Interactive rows use `.onTapGesture` instead of a semantic `Button` or custom button style.

---

## 2. Logic Chain

1. **Static Backgrounds & Plain Button Styles**: Standard macOS buttons indicate hover/pressed states using slight changes in background color/opacity. Because `StatusFilterButton`, `ClientFilterButton`, and the multi-select toolbar buttons in `InvoicesView` use `.buttonStyle(.plain)` with static backgrounds, they do not trigger system-provided visual indicators.
2. **Missing State Opacity**: Buttons with `.disabled(true)` are visually distinguished by dimming the background and text. Because the background modifiers in the multi-select toolbar are hard-coded to static system colors, the buttons appear active when disabled, violating macOS HIG.
3. **Empty/Loading Transitions**: Asynchronous fetches (`loadTemplate()`) require explicit view states (like a progress spinner) to avoid blank/glitchy UI rendering while data is loading. Currently, no such state is declared or displayed in `InvoiceTemplateRendererView`.
4. **AppToolbar compactLabels Default**: The helper `.appToolbarLinkStyle()` applies `.labelStyle(.iconOnly)` on macOS. Because `InvoicesContentToolbar` applies this helper without overriding the default, the dynamic sorting info and the active filter count are hidden.
5. **Interactive Rows & Accessibility**: Using `.onTapGesture` on list items bypasses native focus rings and is not recognized as a button by screen readers (VoiceOver). Replacing or augmenting this with `.accessibilityAddTraits(.isButton)` or native buttons resolves this.

---

## 3. Caveats
* This is a read-only investigation. No live changes have been written to the app code.
* The interaction feedback behavior was analyzed based on SwiftUI code structure and standard macOS styling. Actual rendering depends on platform version and environment.

---

## 4. Conclusion
The views within `Feature.Invoices` require targeted interactive enhancements:
1. **Filter popover toggle buttons** need hover states via `@State` and `.onHover`, and explicit accessibility traits/hints.
2. **Multi-select toolbar buttons** need visual disabled styling (opacity reduction and default pointer instead of link) and hover feedback.
3. **AppToolbar items** need `compactLabels: false` to avoid hiding active filter counts and sort status text.
4. **InvoiceTemplateRendererView** needs a `@State private var isLoading` overlay with a `ProgressView`.
5. **Layout Token Hygiene**: `clientListMaxHeight` should use `listMinHeight` instead of `sortPickerWidth`.

---

## 5. Verification Method

To independently verify these conclusions and proposals:
1. Inspect the referenced files at the quoted lines using `view_file` to confirm the code structure.
2. Run the feature's test suite to ensure the baseline is stable:
   ```bash
   swift test --package-path Packages/Feature.Invoices
   ```
3. Once proposed changes are implemented, run the same test command.
4. Open the application (or run UI tests if available) and open the Invoice filter popover. Verify that hovering and selecting the Status and Client filters visually highlight, and verify with VoiceOver that they announce as selected/unselected buttons.
