import SwiftUI
import SwiftData
import EventKit
import Data
import SharedUI

public struct CalendarContentColumn: View {
    @ObservedObject private var containerViewModel: CalendarContainerViewModel
    @State private var showViewOptions = false

    @EnvironmentObject private var eventKitService: EventKitSyncService

    public init(viewModel: CalendarContainerViewModel) {
        self._containerViewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 12) {
            if containerViewModel.calendarViewModel.isBulkSelectionMode {
                CalendarBulkOperationsToolbar(viewModel: containerViewModel.calendarViewModel)
            }

            CalendarView(viewModel: containerViewModel.calendarViewModel)
                .environmentObject(eventKitService)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(content: toolbarContent)
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            ControlGroup {
                Button(role: .none) {
                    containerViewModel.goToPrevious()
                } label: { Image(systemName: "chevron.left") }
                .help("Previous")


                Button("Today") { 
                    containerViewModel.goToToday() 
                }
                    .help("Jump to today")


                Button(role: .none) {
                    containerViewModel.goToNext()
                } label: { Image(systemName: "chevron.right") }
                .help("Next")

            }
            .controlGroupStyle(.navigation)
            .pointerStyle(.link)
        }

        ToolbarItem(placement: .automatic) {
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
            .pointerStyle(.link)

        }

        // View type switching is now handled by TabView - no toolbar picker needed

        ToolbarItemGroup(placement: .automatic) {
            calendarsMenu
            statusMenu
            clientMenu
        }

        ToolbarItem(placement: .automatic) {
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
            .pointerStyle(.link)

        }

        ToolbarItem(placement: .automatic) {
            Button("New Session", systemImage: "plus", action: { 
                containerViewModel.createNewSession() 
            })
                .keyboardShortcut("n")
                .glassEffect(.regular.tint(.blue).interactive(), in: .buttonBorder)
                .help("Create a new session")
                .pointerStyle(.link)

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
                        .toggleCalendarVisibility(id: calendar.calendarIdentifier)
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(calendar.cgColor ?? CGColor(gray: 0.5, alpha: 1.0)))
                            .frame(width: 8, height: 8)
                        Text(calendar.title)
                        Spacer()
                        Image(systemName:
                              containerViewModel.calendarViewModel
                                .isCalendarVisible(id: calendar.calendarIdentifier)
                              ? "eye.fill" : "eye.slash"
                        ).foregroundStyle(.secondary)
                    }
                }
            }
        } label: {
            Label {
                let hiddenCount = containerViewModel.calendarViewModel.availableCalendars.count - containerViewModel.calendarViewModel.visibleCalendarIdentifiers.count
                Text(hiddenCount == 0 ? "Calendars" : "Calendars (-\(hiddenCount))")
            } icon: {
                let allVisible = containerViewModel.calendarViewModel.visibleCalendarIdentifiers.count == containerViewModel.calendarViewModel.availableCalendars.count
                Image(systemName: allVisible ? "calendar" : "calendar.badge.minus")
            }
        }
        .help("Choose which calendars are visible")
        .pointerStyle(.link)

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
            Label {
                Text(containerViewModel.selectedStatusFilters.isEmpty ? "Status" : "Status (\(containerViewModel.selectedStatusFilters.count))")
            } icon: {
                Image(systemName: containerViewModel.selectedStatusFilters.isEmpty ? "circle.grid.2x2" : "circle.grid.2x2.fill")
            }
        }
        .help("Filter by status")
        .pointerStyle(.link)

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
            Label {
                Text(containerViewModel.selectedClientFilters.isEmpty ? "Client" : "Client (\(containerViewModel.selectedClientFilters.count))")
            } icon: {
                Image(systemName: containerViewModel.selectedClientFilters.isEmpty ? "person.2" : "person.2.fill")
            }
        }
        .help("Filter by client")
        .pointerStyle(.link)

    }

}
