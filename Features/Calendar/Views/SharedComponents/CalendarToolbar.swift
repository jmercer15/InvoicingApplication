import SwiftUI

/// Centralized toolbar for the Calendar feature (ToolbarContent Builder)
struct CalendarToolbar: ToolbarContent {
    @ObservedObject var containerViewModel: CalendarContainerViewModel
    @Binding var showInspector: Bool

    var body: some ToolbarContent {
        // Navigation controls
        ToolbarItem {
            HStack(spacing: 0) {
                Button("Previous", systemImage: "chevron.left", action: { containerViewModel.moveToPreviousPeriod() })
                    .labelStyle(.iconOnly)
                Divider()
                Button("Today", action: { containerViewModel.moveToToday() })
                Divider()
                Button("Next", systemImage: "chevron.right", action: { containerViewModel.moveToNextPeriod() })
                    .labelStyle(.iconOnly)
            }
        }

        // Date picker
        ToolbarItemGroup {
            Button("Date Picker", systemImage: "calendar.badge.clock", action: { containerViewModel.showDatePicker = true })
                .labelStyle(.iconOnly)
        }

        // View selector
        ToolbarItem {
            Picker("View", selection: containerViewModel.calendarViewTypeBinding) {
                ForEach(CalendarViewType.allCases, id: \.self) { viewType in
                    Text(viewType.rawValue)
                        .tag(viewType)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
        }

        // Filters and actions
        ToolbarItemGroup {
            if containerViewModel.calendarViewModel.calendarViewType == .week {
                Slider(value: containerViewModel.hourHeightBinding, in: 30...200, step: 10) {
                    Text("Hour Height")
                } minimumValueLabel: {
                    Text("30").padding(.leading, 10)
                } maximumValueLabel: {
                    Text("200").padding(.trailing, 10)
                }
                .frame(width: 200)
            }

            Menu("Calendars", systemImage: "calendar") {
                let all = containerViewModel.calendarViewModel.availableCalendars
                let allVisible = containerViewModel.calendarViewModel.visibleCalendarIdentifiers.count == all.count
                Button(allVisible ? "Hide All Calendars" : "Show All Calendars", systemImage: allVisible ? "eye.slash" : "eye") {
                    let all = containerViewModel.calendarViewModel.availableCalendars
                    if containerViewModel.calendarViewModel.visibleCalendarIdentifiers.count == all.count {
                        containerViewModel.calendarViewModel.visibleCalendarIdentifiers.removeAll()
                    } else {
                        containerViewModel.calendarViewModel.visibleCalendarIdentifiers = Set(all.map { $0.calendarIdentifier })
                    }
                    containerViewModel.calendarViewModel.updateDisplayableItems()
                }

                Divider()
                ForEach(containerViewModel.calendarViewModel.availableCalendars, id: \.calendarIdentifier) { calendar in
                    Button(action: {
                        containerViewModel.calendarViewModel.toggleCalendarVisibility(calendarIdentifier: calendar.calendarIdentifier)
                    }) {
                        HStack {
                            Circle()
                                .fill(Color(calendar.cgColor ?? CGColor(gray: 0.5, alpha: 1.0)))
                                .frame(width: 8, height: 8)
                            Text(calendar.title)
                            Spacer()
                            if containerViewModel.calendarViewModel.isCalendarVisible(calendarIdentifier: calendar.calendarIdentifier) {
                                Image(systemName: "eye.fill").foregroundColor(.green)
                            } else {
                                Image(systemName: "eye.slash").foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            Menu("Status", systemImage: "line.3.horizontal.decrease.circle") {
                Picker("Status", selection: $containerViewModel.selectedStatusFilterString) {
                    Text("All").tag("All")
                    ForEach(containerViewModel.calendarViewModel.availableFilterStatuses, id: \.label) { status in
                        if let value = status.value { Text(status.label).tag(value) }
                    }
                }
            }

            Menu("Client", systemImage: "person.2") {
                Picker("Client", selection: $containerViewModel.selectedClientFilterString) {
                    Text("All Clients").tag("All Clients")
                    ForEach(containerViewModel.calendarViewModel.availableFilterClients, id: \.label) { client in
                        if let _ = client.value { Text(client.label).tag(client.label) }
                    }
                }
            }

            Button("New Session", systemImage: "plus") {
                containerViewModel.createNewSession()
            }
        }
    }
}
