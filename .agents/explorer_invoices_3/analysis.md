# Analysis: Feature.Invoices UI Refinement

## Summary of Findings
An investigation of the views in `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/` identified several key areas for visual feedback, state polish, and accessibility refinement:
1. **Visual Feedback & Interactive Affordances**: Custom toggle buttons in the filter popover and bulk actions in the multi-select toolbar lack hover/pressed feedback and disabled states.
2. **State Polish**: Date range fields have no visual indicators when cleared/inactive, and the template preview renderer lacks loading/error states during asynchronous fetches.
3. **Accessibility**: Key action buttons (pencil/trash icons, bulk toolbar) lack VoiceOver labels, and popover filter buttons do not expose selection traits or hints.
4. **Style Guide Violations**: Token mismatch (using a width token for scroll height) and gesture-based interaction instead of semantic button behaviors in lists.

---

## 1. Detailed Observations & Findings

### 1.1 Visual Feedback & Interactive Affordances
* **Filter Toggle Buttons**: `StatusFilterButton` and `ClientFilterButton` in `InvoiceFilterPopoverContent.swift` use `.buttonStyle(.plain)` and a static background. Pressing or hovering over them yields zero visual response, making them feel unresponsive.
* **Bulk Operation Toolbar**: The action buttons (Delete, Export, Email) in `InvoicesView.swift` use hard-coded background colors. When no items are selected, the buttons are disabled, but their backgrounds remain fully saturated, falsely indicating they are active.
* **Add Line Item Button**: The dashed-border "Add Line Item" button has a static background color and doesn't respond to hover or tap gestures.

### 1.2 Empty, Error, and Loading State Polish
* **Template Renderer View**: In `InvoiceTemplateRendererView.swift`, `loadTemplate()` resolves and loads templates asynchronously. While loading, the view simply displays a blank canvas without a progress spinner or skeleton. If the load fails, it fails silently, showing a stale canvas.
* **Date Filter Clear State**: When the Date filter is inactive, the date fields still display dates and appear enabled. There is no visual cue (like dimming or checkbox states) showing that they are currently excluded from filtering.
* **Popover Client Height**: `clientListMaxHeight` is bound to `DetailSectionTokens.sortPickerWidth` (`120`). Using a width token for list height is a style guide violation; moreover, `120` points of height is too small for a client list scrollable area.

### 1.3 Accessibility & Contrast
* **Toolbar Label Hiding**: In `InvoicesContentToolbar.swift`, both the Organize menu and the Filter button use `.appToolbarLinkStyle()`, which hides text labels on macOS. This completely hides the dynamic sort state (e.g. "Date") and the active filter count (e.g. "Filter (2)") in the toolbar.
* **VoiceOver Omissions**: Icon-only buttons (pencil/trash in `InvoiceLineItemsSection.swift`) do not have `.accessibilityLabel` modifiers, leading VoiceOver to read standard system symbols. Toggle buttons in the filter popover do not publish selection traits.

### 1.4 Style Guide Violations
* **Tap Gestures on List Rows**: In `NavigationListRow.swift`, tap actions are handled via `.onTapGesture(perform: onTap)` instead of a semantic `Button` or custom button style. This breaks standard keyboard focus and accessibility hierarchy.

---

## 2. Proposed Action Plan

### Proposal 1: Add Hover/Selection Polish and Accessibility to Popover Filters
* **File**: `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterPopoverContent.swift`
* **Changes**:
  1. Add `@State private var isHovered = false` to filter buttons.
  2. Apply dynamic opacity on hover: `isHovered ? 0.20 : 0.10` when selected, and `isHovered ? 0.12 : 0.05` when unselected.
  3. Add `.accessibilityElement(children: .combine)`, `.accessibilityAddTraits(.isButton)`, and `.accessibilityAddTraits(isSelected ? [.isSelected] : [])`.
  4. Fix token usage: Change `clientListMaxHeight` target to `DetailSectionTokens.listMinHeight` (`200`).
  5. Add `.opacity(viewModel.isDateFilterActive ? 1.0 : 0.6)` to the date picker range fields to visually dim them when inactive.

### Proposal 2: Add Loading State to Template Preview
* **File**: `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceTemplateRendererView.swift`
* **Changes**:
  1. Add `@State private var isLoading = false`.
  2. Set `isLoading = true` during data updates/template loading, and `isLoading = false` on completion.
  3. Wrap the body in a `ZStack` and overlay a `ProgressView` when `isLoading` is true.

### Proposal 3: Polish Multi-Select Toolbar & Disabled States
* **File**: `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesView.swift`
* **Changes**:
  1. Add `@State` hover properties for each action button.
  2. Set background opacity to `0.4` and pointer style to `.default` when disabled.
  3. Add `.onHover` support to alter background opacity during interaction.
  4. Add explicit `.accessibilityLabel` to all action buttons in the multi-select bar.

### Proposal 4: Expose Labels for Menus and Action Icons
* **Files**: 
  * `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesContentToolbar.swift`
  * `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceLineItemsSection.swift`
* **Changes**:
  1. Set `compactLabels: false` for the toolbar menus so they display sorting state and active filter counts next to icons on macOS.
  2. Add `.accessibilityLabel("Edit line item")` and `.accessibilityLabel("Delete line item")` to line item grid actions.

---

## 3. Proposed Diffs (Reference implementation)

### Popover Filter Button Polish (Status & Client)
```swift
// Example in StatusFilterButton
struct StatusFilterButton: View {
    ...
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            let shape = RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact, style: .continuous)
            HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                Image(systemName: statusIcon)
                    .foregroundStyle(isSelected ? statusColor : StyleGuide.Colors.textSecondary)
                Text(...)
            }
            .padding(...)
            .background(isSelected ? statusColor.opacity(isHovered ? 0.2 : 0.1) : StyleGuide.Colors.secondary.opacity(isHovered ? 0.12 : 0.05))
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(isSelected ? statusColor.opacity(StyleGuide.Opacity.strong) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityHint("Toggles filter for \(AppConstants.invoiceStatusDisplayName(for: status))")
    }
}
```

### Template Renderer Progress View
```swift
struct InvoiceTemplateRendererView: View {
    ...
    @State private var isLoading = false

    var body: some View {
        ZStack {
            InvoiceCanvasView(document: document)
                .environment(document)
                .environment(templateDataService)
                .opacity(isLoading ? 0.5 : 1.0)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                    .transition(.opacity)
            }
        }
        .onAppear {
            loadTemplate()
        }
        ...
    }

    private func loadTemplate() {
        isLoading = true
        Task {
            defer { isLoading = false }
            ...
        }
    }
}
```
