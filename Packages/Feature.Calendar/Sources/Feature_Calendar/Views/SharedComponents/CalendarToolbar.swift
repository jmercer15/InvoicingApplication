import SwiftUI
import SharedUI

/// Centralized toolbar for the Calendar feature (ToolbarContent Builder)
struct CalendarToolbar: ToolbarContent {
    @ObservedObject var containerViewModel: CalendarContainerViewModel
    @Binding var showInspector: Bool

    var body: some ToolbarContent {
        // Navigation controls
        ToolbarItem {
            HStack(spacing: 0) {
                Button("Previous", systemImage: "chevron.left", action: { containerViewModel.goToPrevious() })
                Divider()
                Button("Today", action: { containerViewModel.goToToday() })
                Divider()
                Button("Next", systemImage: "chevron.right", action: { containerViewModel.goToNext() })
            }
        }

        // Date picker
        ToolbarItemGroup {
            Button("Date Picker", systemImage: "calendar.badge.clock", action: { containerViewModel.showDatePicker = true })
        }

        // View selector is now handled by TabView - no toolbar picker needed

        // Filters and actions
        ToolbarItemGroup {
            if containerViewModel.calendarViewModel.calendarViewType == .week {
                Slider(value: $containerViewModel.hourHeight, in: 30...200, step: 10) {
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
                                Image(systemName: "eye.slash").foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            }
                        }
                    }
                }
            }

            Menu {
                Button("All") {
                    containerViewModel.selectedStatusFilterString = "All"
                }
                ForEach(containerViewModel.calendarViewModel.availableFilterStatuses, id: \.label) { status in
                    if let value = status.value {
                        Button(status.label) {
                            containerViewModel.selectedStatusFilterString = value
                        }
                    }
                }
            } label: {
                Label("Status", systemImage: "line.3.horizontal.decrease.circle")
            }

            Menu {
                Button("All Clients") {
                    containerViewModel.selectedClientFilterString = "All Clients"
                }
                ForEach(containerViewModel.calendarViewModel.availableFilterClients, id: \.label) { client in
                    if let _ = client.value {
                        Button(client.label) {
                            containerViewModel.selectedClientFilterString = client.label
                        }
                    }
                }
            } label: {
                Label("Client", systemImage: "person.2")
            }

            Button("New Session", systemImage: "plus") {
                containerViewModel.createNewSession()
            }
        }
    }
}
