import SwiftUI
import SwiftData
import EventKit
import Data
import SharedUI

public struct CalendarContentColumn: View {
    @ObservedObject private var containerViewModel: CalendarContainerViewModel
    @Binding private var showInspector: Bool
    @State private var showCalendarSettings = false
    @State private var showViewOptions = false
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var eventKitService: EventKitSyncService

    public init(viewModel: CalendarContainerViewModel, showInspector: Binding<Bool>) {
        self._containerViewModel = ObservedObject(wrappedValue: viewModel)
        self._showInspector = showInspector
    }

    public var body: some View {
        VStack(spacing: 16) {
            if containerViewModel.calendarViewModel.isBulkSelectionMode {
                CalendarBulkOperationsToolbar(viewModel: containerViewModel.calendarViewModel)
                    .fluidListTransition()
            }

            CalendarView(viewModel: containerViewModel.calendarViewModel, showInspector: $showInspector)
                .environmentObject(eventKitService)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color("Background", bundle: .sharedUI))
        .toolbar(content: toolbarContent)
        .environment(\.modelContext, modelContext)
        .onAppear {
            containerViewModel.updateContextIfNeeded(modelContext)
        }
        .preference(
            key: InspectorContentPreferenceKey.self,
            value: InspectorContent(id: "CalendarInspector", view: AnyView(currentSidebarContent))
        )
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(id: "nav", placement: .automatic) {
            ControlGroup {
                Button(role: .none) {
                    print("🔘 Calendar: Previous button tapped")
                    containerViewModel.goToPrevious()
                } label: { Image(systemName: "chevron.left") }
                .help("Previous")
                .appInteractiveCursor()

                Button("Today") { 
                    print("🔘 Calendar: Today button tapped")
                    containerViewModel.goToToday() 
                }
                    .help("Jump to today")
                    .appInteractiveCursor()

                Button(role: .none) {
                    print("🔘 Calendar: Next button tapped")
                    containerViewModel.goToNext()
                } label: { Image(systemName: "chevron.right") }
                .help("Next")
                .appInteractiveCursor()
            }
            .controlGroupStyle(.navigation)
        }

        ToolbarItem(id: "jumpToDate", placement: .automatic) {
            Button {
                containerViewModel.showDatePicker.toggle()
            } label: { Label("Jump to Date", systemImage: "calendar.badge.clock") }
            .popover(isPresented: $containerViewModel.showDatePicker, arrowEdge: .bottom) {
                VStack(alignment: .leading) {
                    Text("Jump to date").font(.headline)
                    DatePicker("", selection: $containerViewModel.selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .onChange(of: containerViewModel.selectedDate) { _, newDate in
                            containerViewModel.goToDate(newDate)
                        }
                }
                .padding()
                .frame(width: 320, height: 380)
            }
            .help("Jump to a specific date")
            .appInteractiveCursor()
        }

        // View type switching is now handled by TabView - no toolbar picker needed

        ToolbarItemGroup(placement: .automatic) {
            calendarsMenu
            statusMenu
            clientMenu
        }

        ToolbarItem(id: "viewOptions", placement: .automatic) {
            Button {
                showViewOptions.toggle()
            } label: { Label("View Options", systemImage: "slider.horizontal.3") }
            .popover(isPresented: $showViewOptions, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    if containerViewModel.calendarViewModel.calendarViewType == .week {
                        Text("Hour height").font(.headline)
                        Slider(value: $containerViewModel.hourHeight, in: 30...200, step: 10)
                        HStack {
                            Text("30"); Spacer(); Text("200")
                        }
                        .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                    }
                }
                .padding()
                .frame(width: 300)
            }
            .help("Layout & density")
            .appInteractiveCursor()
        }

        ToolbarItem(id: "newSession", placement: .automatic) {
            Button("New Session", systemImage: "plus", action: { 
                print("🔘 Calendar: New Session button tapped")
                containerViewModel.createNewSession() 
            })
                .keyboardShortcut("n")
                .glassEffect(.regular.tint(.blue).interactive(), in: .buttonBorder)
                .appInteractiveCursor()
        }

        ToolbarItem(placement: .automatic) {
            Button {
                showInspector.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.trailing")
            }
            .help("Show or hide inspector")
            .appInteractiveCursor()
        }
    }

    private var calendarsMenu: some View {
        Menu {
            let all = containerViewModel.calendarViewModel.availableCalendars
            let allVisible = containerViewModel.calendarViewModel.visibleCalendarIdentifiers.count == all.count
            Button(allVisible ? "Hide All Calendars" : "Show All Calendars",
                   systemImage: allVisible ? "eye.slash" : "eye") {
                if allVisible {
                    containerViewModel.calendarViewModel.visibleCalendarIdentifiers.removeAll()
                } else {
                    containerViewModel.calendarViewModel.visibleCalendarIdentifiers =
                        Set(all.map { $0.calendarIdentifier })
                }
                containerViewModel.calendarViewModel.updateDisplayableItems()
            }

            Divider()
            ForEach(all, id: \.calendarIdentifier) { calendar in
                Button {
                    containerViewModel.calendarViewModel
                        .toggleCalendarVisibility(calendarIdentifier: calendar.calendarIdentifier)
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(calendar.cgColor ?? CGColor(gray: 0.5, alpha: 1.0)))
                            .frame(width: 8, height: 8)
                        Text(calendar.title)
                        Spacer()
                        Image(systemName:
                              containerViewModel.calendarViewModel
                                .isCalendarVisible(calendarIdentifier: calendar.calendarIdentifier)
                              ? "eye.fill" : "eye.slash"
                        ).foregroundStyle(.secondary)
                    }
                }
            }
        } label: { Label("Calendars", systemImage: "calendar") }
        .help("Choose which calendars are visible")
        .appInteractiveCursor()
    }

    private var statusMenu: some View {
        Menu {
            Button("All Statuses") {
                containerViewModel.selectedStatusFilters.removeAll()
            }

            Divider()

            ForEach(containerViewModel.calendarViewModel.availableFilterStatuses, id: \.label) { status in
                if let value = status.value {
                    Button {
                        if containerViewModel.selectedStatusFilters.contains(value) {
                            containerViewModel.selectedStatusFilters.remove(value)
                        } else {
                            containerViewModel.selectedStatusFilters.insert(value)
                        }
                    } label: {
                        HStack {
                            Text(status.label)
                            Spacer()
                            if containerViewModel.selectedStatusFilters.contains(value) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color("Primary", bundle: .sharedUI))
                            }
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "circle.grid.2x2.topleft.checkmark.filled")
                if !containerViewModel.selectedStatusFilters.isEmpty {
                    Text("(\(containerViewModel.selectedStatusFilters.count))")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }
            }
        }
        .help("Filter by status")
        .appInteractiveCursor()
    }

    private var clientMenu: some View {
        Menu {
            Button("All Clients") {
                containerViewModel.selectedClientFilters.removeAll()
            }

            Divider()

            ForEach(containerViewModel.calendarViewModel.availableFilterClients, id: \.label) { client in
                if let clientId = client.value {
                    Button {
                        if containerViewModel.selectedClientFilters.contains(clientId) {
                            containerViewModel.selectedClientFilters.remove(clientId)
                        } else {
                            containerViewModel.selectedClientFilters.insert(clientId)
                        }
                    } label: {
                        HStack {
                            if let color = client.color {
                                Circle().fill(color).frame(width: 8, height: 8)
                            }
                            Text(client.label)
                            Spacer()
                            if containerViewModel.selectedClientFilters.contains(clientId) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color("Primary", bundle: .sharedUI))
                            }
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "person.2")
                if !containerViewModel.selectedClientFilters.isEmpty {
                    Text("(\(containerViewModel.selectedClientFilters.count))")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }
            }
        }
        .help("Filter by client")
        .appInteractiveCursor()
    }

    private var currentSidebarContent: some View {
        let viewModel = containerViewModel.calendarViewModel
        switch viewModel.calendarViewType {
        case .week:
            return AnyView(WeekSidebarView(viewModel: viewModel))
        case .month:
            return AnyView(MonthSidebarView(viewModel: viewModel))
        }
    }
}

public struct CalendarDetailColumn: View {
    @ObservedObject private var containerViewModel: CalendarContainerViewModel
    @EnvironmentObject private var eventKitService: EventKitSyncService

    public init(viewModel: CalendarContainerViewModel) {
        self._containerViewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        currentSidebarContent
            .environmentObject(eventKitService)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color("Background", bundle: .sharedUI))
    }

    private var currentSidebarContent: some View {
        let viewModel = containerViewModel.calendarViewModel
        switch viewModel.calendarViewType {
        case .week:
            return AnyView(WeekSidebarView(viewModel: viewModel))
        case .month:
            return AnyView(MonthSidebarView(viewModel: viewModel))
        }
    }
}
