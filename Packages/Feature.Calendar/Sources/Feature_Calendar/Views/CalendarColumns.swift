import SwiftUI
import SwiftData
import SharedUI
import Observation

public struct CalendarContentColumn: View {
    /// Strong reference to the workspace-owned view model. Avoid stored `@Bindable` on an
    /// externally owned `@Observable` class — split-view / toolbar menu hosting can evaluate
    /// nested closures outside the column's observation scope and crash reading filter state.
    private let viewModel: CalendarViewModel
    @State private var showViewOptions = false

    public init(viewModel: CalendarViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        let activeFilterCount = Self.activeFilterCount(for: viewModel)

        VStack(spacing: 12) {
            if viewModel.isBulkSelectionMode {
                CalendarBulkOperationsToolbar(viewModel: viewModel)
            }

            CalendarView(
                viewModel: viewModel,
                queryRange: viewModel.currentViewDateRange
            )
            .id(CalendarQueryRangeIdentity(viewModel.currentViewDateRange))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            CalendarContentToolbar(
                viewModel: viewModel,
                activeFilterCount: activeFilterCount,
                showViewOptions: $showViewOptions
            )
        }
    }

    static func activeFilterCount(for viewModel: CalendarViewModel) -> Int {
        let calendarHidden = viewModel.availableCalendars.count
            - viewModel.visibleCalendarIdentifiers.count
        let statusCount = viewModel.selectedStatusFilters.count
        let clientCount = viewModel.selectedClientFilters.count
        return (calendarHidden > 0 ? 1 : 0) + (statusCount > 0 ? 1 : 0) + (clientCount > 0 ? 1 : 0)
    }
}

// MARK: - Toolbar

private struct CalendarContentToolbar: ToolbarContent {
    let viewModel: CalendarViewModel
    let activeFilterCount: Int
    @Binding var showViewOptions: Bool

    var body: some ToolbarContent {
        AppToolbarPeriodNavigation(
            onPrevious: { viewModel.goToPrevious() },
            onToday: { viewModel.goToToday() },
            onNext: { viewModel.goToNext() }
        )

        ToolbarItem(placement: .principal) {
            CalendarViewModePicker(viewModel: viewModel)
        }

        AppToolbarUtilityGroup {
            CalendarJumpToDateButton(viewModel: viewModel)
            CalendarFiltersMenu(viewModel: viewModel, activeFilterCount: activeFilterCount)
            CalendarViewOptionsButton(viewModel: viewModel, showViewOptions: $showViewOptions)
        }

        ToolbarItem(placement: .primaryAction) {
            AppToolbarPrimaryCreateButton(
                "New Session",
                systemImage: "plus.circle.fill",
                help: "Create a new session",
                action: { viewModel.createNewSession() }
            )
        }
    }
}

private struct CalendarViewModePicker: View {
    let viewModel: CalendarViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        Picker("View Mode", selection: $viewModel.calendarViewType) {
            ForEach(CalendarViewType.allCases) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: StyleGuide.Dimensions.calendarSidebarWidth)
    }
}

private struct CalendarJumpToDateButton: View {
    let viewModel: CalendarViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        Button {
            viewModel.showDatePicker.toggle()
        } label: {
            Label("Go to Date", systemImage: "calendar.badge.clock")
        }
        .popover(isPresented: $viewModel.showDatePicker, arrowEdge: .bottom) {
            VStack(alignment: .leading) {
                Text("Jump to date").font(StyleGuide.Typography.sectionTitle)
                DatePicker("", selection: $viewModel.selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .onChange(of: viewModel.selectedDate) { _, newDate in
                        viewModel.goToDate(newDate)
                    }
            }
            .padding()
            .frame(width: StyleGuide.Dimensions.calendarPopoverWidth, height: StyleGuide.Dimensions.calendarPopoverHeight)
        }
        .appToolbarLinkStyle(help: "Jump to a specific date")
    }
}

/// Menu label uses a precomputed count so toolbar hosting never reads `@Observable` state in a deferred closure.
private struct CalendarFiltersMenu: View {
    let viewModel: CalendarViewModel
    let activeFilterCount: Int

    var body: some View {
        Menu {
            CalendarFiltersMenuContent(viewModel: viewModel)
        } label: {
            AppToolbarFilterMenuLabel(
                "Filters",
                systemImage: "line.3.horizontal.decrease.circle",
                selectionCount: activeFilterCount
            )
        }
        .appToolbarLinkStyle(help: "Calendars, status, and client filters")
    }
}

private struct CalendarFiltersMenuContent: View {
    let viewModel: CalendarViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        calendarsSection(viewModel: viewModel)
        Divider()
        statusSection(viewModel: viewModel)
        Divider()
        clientSection(viewModel: viewModel)
    }

    @ViewBuilder
    private func calendarsSection(viewModel: CalendarViewModel) -> some View {
        Section("Calendars") {
            let all = viewModel.availableCalendars
            let allVisible = viewModel.visibleCalendarIdentifiers.count == all.count
            Button(allVisible ? "Hide All Calendars" : "Show All Calendars",
                   systemImage: allVisible ? "eye.slash" : "eye") {
                if allVisible {
                    viewModel.visibleCalendarIdentifiers.removeAll()
                } else {
                    viewModel.visibleCalendarIdentifiers =
                        Set(all.map(\.calendarIdentifier))
                }
                viewModel.updateDisplayableItems()
            }

            ForEach(all, id: \.calendarIdentifier) { calendar in
                Button {
                    viewModel.toggleCalendarVisibility(id: calendar.calendarIdentifier)
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(calendar.cgColor ?? CGColor(gray: 0.5, alpha: 1.0)))
                            .frame(width: StyleGuide.Dimensions.paddingMedium, height: StyleGuide.Dimensions.paddingMedium)
                        Text(calendar.title)
                        Spacer()
                        AppToolbarMenuCheckmark(
                            isSelected: viewModel.isCalendarVisible(id: calendar.calendarIdentifier)
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func statusSection(viewModel: CalendarViewModel) -> some View {
        Section("Status") {
            Button("All Statuses") {
                viewModel.selectedStatusFilters.removeAll()
            }

            ForEach(viewModel.availableFilterStatuses, id: \.label) { status in
                if let value = status.value {
                    Button {
                        if viewModel.selectedStatusFilters.contains(value) {
                            viewModel.selectedStatusFilters.remove(value)
                        } else {
                            viewModel.selectedStatusFilters.insert(value)
                        }
                    } label: {
                        HStack {
                            Text(status.label)
                            Spacer()
                            AppToolbarMenuCheckmark(
                                isSelected: viewModel.selectedStatusFilters.contains(value)
                            )
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func clientSection(viewModel: CalendarViewModel) -> some View {
        Section("Client") {
            Button("All Clients") {
                viewModel.selectedClientFilters.removeAll()
            }

            ForEach(viewModel.availableFilterClients, id: \.label) { client in
                if let clientId = client.value {
                    Button {
                        if viewModel.selectedClientFilters.contains(clientId) {
                            viewModel.selectedClientFilters.remove(clientId)
                        } else {
                            viewModel.selectedClientFilters.insert(clientId)
                        }
                    } label: {
                        HStack {
                            if let color = client.color {
                                Circle().fill(color).frame(width: StyleGuide.Dimensions.paddingMedium, height: StyleGuide.Dimensions.paddingMedium)
                            }
                            Text(client.label)
                            Spacer()
                            AppToolbarMenuCheckmark(
                                isSelected: viewModel.selectedClientFilters.contains(clientId)
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct CalendarViewOptionsButton: View {
    let viewModel: CalendarViewModel
    @Binding var showViewOptions: Bool

    var body: some View {
        @Bindable var viewModel = viewModel
        Button {
            showViewOptions.toggle()
        } label: {
            Label("View", systemImage: "slider.horizontal.3")
        }
        .popover(isPresented: $showViewOptions, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.calendarViewType == .week {
                    Text("Hour height").font(StyleGuide.Typography.sectionTitle)
                    Slider(value: $viewModel.hourHeightBinding, in: 30...200, step: 10)
                    HStack {
                        Text("30")
                        Spacer()
                        Text("200")
                    }
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                }
            }
            .padding()
            .frame(width: StyleGuide.Dimensions.calendarFilterWidth)
        }
        .appToolbarLinkStyle(help: "Layout and density options")
    }
}
