# UI Refinement Plan: BillingHub and Calendar

This plan outlines the required UI and accessibility enhancements for the views under `Packages/Feature.BillingHub` and `Packages/Feature.Calendar`. The adjustments target layout hierarchy, loading/empty/error states, keyboard navigation, interactive pointer styles, and WCAG AA compliance.

---

## 1. Layout Depth & Hierarchy
- **Visual Contrast & Hierarchy**: Some elements, especially borders and background opacities, have low contrast. We need to define clearer spacing rules and distinct border indicators.
- **Scroll Separation**: Keep headers separate from scrollable areas by implementing clean dividers with subtle drop shadows to make sure content doesn't visually bleed under headers during scroll events.

---

## 2. Empty, Loading, and Error States
- **Billing Hub Board**:
  - Introduce a loading indicator when `viewModel.isLoading` is active.
  - Implement an empty state (`ContentUnavailableView` style) when the Kanban board projection yields zero results.
  - Handle fetching errors gracefully in the UI.
- **Billable Drafts Home View**:
  - Add a loading indicator while drafts are being refreshed.
  - Add an empty state placeholder if no drafts are available.
  - Expose fetching error messages on the main list.
- **Calendar View**:
  - Ensure fetch errors set an error state on `CalendarViewModel` and render a banner rather than failing silently.

---

## 3. Interactive States
- **Keyboard Navigation**:
  - Convert `KanbanCardView` from an `.onTapGesture` implementation to a native `Button` using `.buttonStyle(.plain)`. This makes the cards focusable by keyboard, displays a focus ring on macOS, and allows activation via Space/Enter keys.
  - Ensure all customized controls support hover transitions, pressed states, and appropriate macOS pointer styles.

---

## 4. Accessibility & WCAG AA Compliance
- **Nested Button Violation**:
  - In `MonthView` / `MonthDayCellView`, the entire cell is wrapped in a `Button` to select the date, while the cell contents (session/event indicators) are also wrapped in `Button`s. This results in nested buttons which violate SwiftUI hit-testing and accessibility guidelines.
  - **Refactoring Solution**: Use a `ZStack` in `MonthDayCellView` with a background button for selecting the date, and a foreground overlay containing the day number and the session/event buttons as siblings rather than children of the parent button.
- **Accessibility Attributes**:
  - Add `.accessibilityElement(children: .combine)` and set descriptive labels, hints, and roles on composite components such as `KanbanCardView`, `StatusIndicator`, and `CalendarItemBlockView`.
  - Expose context menu actions as accessibility actions.

---

## Detailed File-by-File Refactoring Guide

### 1. Packages/Feature.BillingHub/Sources/Feature_BillingHub/ViewModels/BillingHubViewModel.swift
- **Existing Implementation**: Defines `isLoading: Bool` but never sets it during fetching.
- **What is Lacking**: Dynamic loading state update.
- **Modification Details**: Update `refreshProjection()` to toggle `isLoading`.
- **Code Change**:
```swift
// Replace lines 74-85 with:
public func refreshProjection() async {
    isLoading = true
    defer { isLoading = false }
    do {
        let newProjection = try await workflow.fetchProjection(
            searchText: searchText,
            selectedClientID: selectedClientID,
            sortOptions: columnSortOptions
        )
        self.boardProjection = newProjection
    } catch {
        print("Failed to fetch projection: \(error)")
    }
}
```

---

### 2. Packages/Feature.BillingHub/Sources/Feature_BillingHub/Views/BillingHubView.swift
- **Existing Implementation**: Renders the Kanban board directly.
- **What is Lacking**: No UI for loading, empty projection, or error states.
- **Modification Details**: Add overlay/conditional views for loading and empty states.
- **Code Change**:
```swift
// Modify body in BillingHubView.swift (around lines 49-68):
public var body: some View {
    ZStack {
        boardContent(projection: viewModel.boardProjection)
            .opacity(viewModel.isLoading ? 0.6 : 1.0)
        
        if viewModel.isLoading {
            ProgressView("Refreshing Board...")
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(8)
        } else if viewModel.boardProjection.isEmpty {
            ContentUnavailableView(
                "No Billing Data Available",
                systemImage: "tray.fill",
                description: Text("Try adjusting client filters or check your date ranges.")
            )
        }
    }
    .task(id: projectionTaskID) {
        try? await Task.sleep(for: .milliseconds(150))
        await viewModel.refreshProjection()
    }
    .toolbar {
        toolbarContent
    }
    .navigationTitle("Billing Hub")
    .sheet(item: presentedCardBinding) { card in
        EditingPanel(
            card: card,
            viewModel: viewModel,
            openInvoice: openInvoice,
            openSession: openSession
        )
    }
}
```

---

### 3. Packages/Feature.BillingHub/Sources/Feature_BillingHub/Views/BillingHubDragDropComponents.swift (KanbanCardView)
- **Existing Implementation**: Uses `.onTapGesture` and lacks accessibility combinations.
- **What is Lacking**: Keyboard focusability, focus rings, keyboard selection, and combined accessibility attributes.
- **Modification Details**: Rewrite root container to use `Button` with a plain style, and apply combined accessibility modifiers.
- **Code Change**:
```swift
// Modify body in KanbanCardView (around lines 44-132):
var body: some View {
    Button(action: onTap) {
        HStack(spacing: 0) {
            Rectangle()
                .fill(card.accentColor)
                .frame(width: BillingHubTheme.Dimensions.dragHandleWidth)
                .frame(alignment: .leading)

            VStack(alignment: .leading, spacing: ListRowTokens.titleSubtitleSpacing + 4) {
                highlightedText(card.titleText, searchingFor: searchText)
                    .font(BillingHubTheme.Typography.cardTitle)
                    .foregroundColor(BillingHubTheme.Palette.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)

                highlightedText(card.subtitleText, searchingFor: searchText)
                    .font(BillingHubTheme.Typography.cardSubtitle)
                    .foregroundColor(BillingHubTheme.Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .truncationMode(.tail)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: ListRowTokens.metadataSpacing + 2) {
                        metadataLeading
                        Spacer(minLength: 4)
                        metadataTrailing
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        metadataLeading
                        metadataTrailing
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(BillingHubTheme.Dimensions.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(cardBackground)
    .overlay(
        RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.cardCornerRadius)
            .strokeBorder(
                isSelected
                    ? Color.accentColor
                    : BillingHubTheme.Surfaces.cardStroke.opacity(
                        isHovering
                            ? BillingHubTheme.Surfaces.cardHoverStrokeOpacity
                            : BillingHubTheme.Surfaces.cardDefaultStrokeOpacity
                    ),
                lineWidth: isSelected
                    ? BillingHubTheme.Surfaces.cardSelectedStrokeWidth
                    : BillingHubTheme.Surfaces.cardDefaultStrokeWidth
            )
    )
    .clipShape(RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.cardCornerRadius))
    .contextMenu {
        Button {
            onTap()
            onOpen?()
        } label: {
            Label("Open Details", systemImage: "pencil")
        }

        if let nextColumn = viewModel.nextColumn(for: card) {
            Divider()
            Button {
                Task {
                    _ = await viewModel.advanceCard(card)
                }
            } label: {
                Label("Move to \(nextColumn.menuTitle)", systemImage: "arrow.right.circle")
            }
        }
    }
    .onHover { hovering in
        withAnimation(BillingHubTheme.Animations.hover) {
            isHovering = hovering
        }
    }
    .billingHubPointerStyle(.link)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(card.titleText), \(card.subtitleText), \(card.detailText ?? "No date"), \(card.statusText ?? "")")
    .accessibilityHint("Double click to open details.")
    .accessibilityAddTraits(.isButton)
    .accessibilityAction(named: "Open Details") {
        onTap()
        onOpen?()
    }
}
```

---

### 4. Packages/Feature.BillingHub/Sources/Feature_BillingHub/Views/StatusIndicator.swift
- **Existing Implementation**: Standard rendering with no accessibility support.
- **What is Lacking**: Accessibility elements are unassociated fragments.
- **Modification Details**: Add combined accessibility elements.
- **Code Change**:
```swift
// Modify body in StatusIndicator.swift (around line 16):
var body: some View {
    HStack(spacing: 8) {
        // ... (ZStack of inner/outer circles) ...
        // ... (VStack of text labels) ...
    }
    // Add accessibility:
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label) status indicator")
    .accessibilityValue("\(count) items")
}
```

---

### 5. Packages/Feature.BillingHub/Sources/Feature_BillingHub/ViewModels/BillableDraftsViewModel.swift
- **Existing Implementation**: Lacks an `isLoading` property.
- **What is Lacking**: No way to track loading state in the drafts list UI.
- **Modification Details**: Add `isLoading: Bool` property and update it inside `refreshDrafts()`.
- **Code Change**:
```swift
// Add property around line 18:
public var isLoading: Bool = false

// Modify refreshDrafts() around lines 41-62:
public func refreshDrafts() async {
    isLoading = true
    defer { isLoading = false }
    do {
        let draftIDs = try await workflow.fetchDraftIDs(
            dateRange: dateRange,
            filterClientId: filterClientId,
            filterPlanType: filterPlanType
        )
        let drafts = draftIDs.compactMap {
            modelContext.model(for: $0) as? BillableDraft
        }
        self.displayedDrafts = drafts.filter { draft in
            if let status = selectedStatus, draft.draftStatus != status.rawValue {
                return false
            }
            return true
        }
    } catch {
        self.errorMessage = "Failed to fetch drafts."
    }
}
```

---

### 6. Packages/Feature.BillingHub/Sources/Feature_BillingHub/Views/BillableDrafts/BillableDraftsHomeView.swift
- **Existing Implementation**: Renders the drafts list inside a VStack.
- **What is Lacking**: No loading state, error state, or empty state displays on the main drafts list.
- **Modification Details**: Add support for displaying error banner, loading progress view, and empty list indicators on the drafts list screen.
- **Code Change**:
```swift
// Modify body in BillableDraftsHomeView.swift (around lines 56-68):
public var body: some View {
    NavigationStack {
        VStack(alignment: .leading, spacing: 0) {
            filtersSection
            
            if let errorMsg = viewModel.errorMessage {
                Text(errorMsg)
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundColor(ColorSystem.Status.error)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(ColorSystem.Status.error.opacity(0.1))
            }
            
            ZStack {
                List {
                    ForEach(viewModel.displayedDrafts) { draft in
                        NavigationLink(value: draft.id) {
                            DraftRowView(draft: draft)
                        }
                    }
                }
                .listStyle(.inset)
                .opacity(viewModel.isLoading ? 0.5 : 1.0)
                
                if viewModel.isLoading {
                    ProgressView("Loading drafts...")
                } else if viewModel.displayedDrafts.isEmpty {
                    ContentUnavailableView(
                        "No Drafts Found",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Try changing the status filter or date range, or generate new drafts.")
                    )
                }
            }
        }
        .navigationTitle("Billable Drafts")
        // ... (toolbar and navigation destinations) ...
    }
}
```

---

### 7. Packages/Feature.Calendar/Sources/Feature_Calendar/Views/MonthView/MonthView.swift
- **Existing Implementation**: Cell is wrapped in a `Button` and contains cell subviews which also render buttons, resulting in nested button warnings/violations.
- **What is Lacking**: Compliance with accessibility hit-testing (no nested buttons).
- **Modification Details**: Remove the wrapper button in `MonthView` and let `MonthDayCellView` handle selection.
- **Code Change**:
```swift
// Modify dayCellView in MonthView.swift (around lines 84-99):
@ViewBuilder
private func dayCellView(date: Date, weekIndex: Int, dayIndex: Int) -> some View {
    MonthDayCellView(
        date: date,
        viewModel: viewModel,
        weekIndex: weekIndex,
        dayIndex: dayIndex,
        isLastWeek: weekIndex == weeks.count - 1
    )
}
```

---

### 8. Packages/Feature.Calendar/Sources/Feature_Calendar/Views/MonthView/MonthDayCellView.swift
- **Existing Implementation**: Contains nested subview buttons directly inside a vertical stack.
- **What is Lacking**: Clean isolation of background/foreground interactions to prevent nested button hierarchy.
- **Modification Details**: Use a `ZStack` where a background selector button handles selecting the day, and the foreground details (headers/items) are overlaid on top. Add proper accessibility date descriptions.
- **Code Change**:
```swift
// In MonthDayCellView.swift, add static date formatter:
private static let accessibilityDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    return formatter
}()

// Modify body (around lines 68-127):
var body: some View {
    GeometryReader { geometry in
        ZStack {
            // Background selector button
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.selectedDate = date
                }
            } label: {
                Rectangle()
                    .fill(cellTint ?? .clear)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select \(date, formatter: Self.accessibilityDateFormatter)")
            
            // Foreground Content
            VStack(alignment: .center, spacing: 2) {
                dayNumberHeader()
                itemIndicatorsView(geometry: geometry)
                Spacer()
            }
            .allowsHitTesting(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if let tint = cellTint {
                Rectangle()
                    .fill(tint)
            }
        }
        .overlay(
            weekIndex == 0 ? Rectangle()
                .frame(width: nil, height: StyleGuide.Dimensions.hairlineWidth)
                .foregroundColor(gridBorderColor) : nil,
            alignment: .top
        )
        .overlay(
            dayIndex == 0 ? Rectangle()
                .frame(width: StyleGuide.Dimensions.hairlineWidth, height: nil)
                .foregroundColor(gridBorderColor) : nil,
            alignment: .leading
        )
        .overlay(
            Rectangle()
                .frame(width: StyleGuide.Dimensions.hairlineWidth, height: nil)
                .foregroundColor(gridBorderColor),
            alignment: .trailing
        )
        .overlay(
            Rectangle()
                .frame(width: nil, height: StyleGuide.Dimensions.hairlineWidth)
                .foregroundColor(gridBorderColor),
            alignment: .bottom
        )
        .task(id: dayItemsTaskID) {
            dayItems = viewModel.combinedItems(for: date)
            lastIndicatorHeight = -1
        }
        .contextMenu {
            ForEach(dayItems.filter { $0.underlyingSession != nil }) { item in
                if let session = item.underlyingSession {
                    Button {
                        viewModel.selectedSessionInfo = (session: session, instanceStart: item.startDate, instanceEnd: item.endDate)
                    } label: {
                        Label(session.title, systemImage: "pencil")
                    }
                }
            }
        }
    }
}
```

---

### 9. Packages/Feature.Calendar/Sources/Feature_Calendar/Views/WeekView/CalendarItemBlockView.swift
- **Existing Implementation**: Uses plain buttons with no custom accessibility labels or actions.
- **What is Lacking**: Disjointed accessibility output for screen readers; lack of direct accessibility actions representing context menu shortcuts.
- **Modification Details**: Apply `.accessibilityElement(children: .combine)` and define clear, descriptive labels and actions.
- **Code Change**:
```swift
// Modify body (around lines 188-292):
var body: some View {
    let calculatedWidth = max(0, slotWidth - Self.leadingColumnPadding - Self.trailingColumnPadding)
    let cornerRadii = segmentCornerRadii

    Button(action: handleTap) {
        ZStack(alignment: .top) {
            // ... (VStack with UnevenRoundedRectangle, overlays, etc.) ...
        }
        .frame(width: calculatedWidth, height: cardHeight)
        .padding(.leading, Self.leadingColumnPadding)
        .padding(.trailing, Self.trailingColumnPadding)
    }
    .buttonStyle(.plain)
    .frame(width: slotWidth, height: cardHeight, alignment: .topLeading)
    .contextMenu { makeContextMenu() }
    .onDrag {
        // ... (drag provider config) ...
    }
    .opacity(isCancelled ? 0.7 : 1.0)
    .zIndex(isBeingResized ? 10 : (isEvent ? 2 : 1))
    .contentShape(Rectangle())
    .pointerStyle(.link)
    // Accessibility Enhancements:
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
        "\(item.title), \(timeRangeText), \(item.underlyingSession?.client?.fullName ?? ""), \(item.underlyingSession?.status?.rawValue ?? "")"
    )
    .accessibilityHint("Double click to edit session.")
    .accessibilityAddTraits(.isButton)
    .accessibilityAction(named: "View Details") {
        handleTap()
    }
}
```
