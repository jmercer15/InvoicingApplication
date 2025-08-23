// /Users/user/Developer/InvoicingApplication/InvoicingApplication/InvoicingApplication/Views/Calendar/CalendarContainerView.swift
import SwiftUI
import SwiftData
import EventKit

struct CalendarContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var eventKitService: EventKitSyncService // Use new service from environment
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var showInspector: Bool
    // Use StateObject for the container ViewModel lifecycle tied to this container
    @StateObject private var containerViewModel: CalendarContainerViewModel
    @State private var showCalendarSettings = false
    @State private var showViewOptions = false
    
    // Global inspector content provider
    @StateObject private var inspectorContentProvider = GlobalInspectorContentProvider.shared

    // Initialize the container ViewModel
    init(columnVisibility: Binding<NavigationSplitViewVisibility>, showInspector: Binding<Bool>, modelContext: ModelContext) {
        self._columnVisibility = columnVisibility
        self._showInspector = showInspector
        self._containerViewModel = StateObject(wrappedValue: CalendarContainerViewModel(modelContext: modelContext))
    }

    var body: some View {
        VStack(spacing: 16) {
            // Bulk operations toolbar
            if containerViewModel.calendarViewModel.isBulkSelectionMode {
                CalendarBulkOperationsToolbar(viewModel: containerViewModel.calendarViewModel)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Calendar view with consistent spacing
            CalendarView(viewModel: containerViewModel.calendarViewModel, showInspector: $showInspector)
                .environmentObject(eventKitService)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black)
        .environment(\.modelContext, modelContext)
        .toolbar {
            // LEADING: navigation controls
            ToolbarItem(id: "nav", placement: .navigation) {
                ControlGroup {
                    Button(role: .none) {
                        containerViewModel.moveToPreviousPeriod()
                    } label: { Image(systemName: "chevron.left") }
                    .help("Previous")
                    .appInteractiveCursor()

                    Button("Today") { containerViewModel.moveToToday() }
                        .help("Jump to today")
                        .appInteractiveCursor()

                    Button(role: .none) {
                        containerViewModel.moveToNextPeriod()
                    } label: { Image(systemName: "chevron.right") }
                    .help("Next")
                    .appInteractiveCursor()
                }
                .controlGroupStyle(.navigation)
            }

            // Jump-to-date popover (instead of an always-on picker)
            ToolbarItem(id: "jumpToDate", placement: .navigation) {
                Button {
                    containerViewModel.showDatePicker.toggle()
                } label: { Label("Jump to Date", systemImage: "calendar.badge.clock") }
                .popover(isPresented: $containerViewModel.showDatePicker, arrowEdge: .bottom) {
                    VStack(alignment: .leading) {
                        Text("Jump to date").font(.headline)
                         DatePicker(
                             "",
                             selection: $containerViewModel.selectedDate,
                             displayedComponents: .date
                         )
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



            // CENTER: segmented view selector (no "View" label per HIG)
            ToolbarItem(id: "viewType", placement: .principal) {
                Picker("", selection: containerViewModel.calendarViewTypeBinding) {
                    ForEach(CalendarViewType.allCases, id: \.self) { viewType in
                        Text(viewType.rawValue).tag(viewType)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }
            
            // Filters in main toolbar area (secondary actions), no HStack/spacers
            ToolbarItemGroup(placement: .secondaryAction) {
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

                Menu {
                    Picker("Status", selection: $containerViewModel.selectedStatusFilterString) {
                        Text("All").tag("All")
                        ForEach(containerViewModel.calendarViewModel.availableFilterStatuses, id: \.label) { status in
                            if let v = status.value { Text(status.label).tag(v) }
                        }
                    }
                } label: { Label("Status", systemImage: "line.3.horizontal.decrease.circle") }
                .help("Filter by status")
                .appInteractiveCursor()

                Menu {
                    Picker("Client", selection: $containerViewModel.selectedClientFilterString) {
                        Text("All Clients").tag("All Clients")
                        ForEach(containerViewModel.calendarViewModel.availableFilterClients, id: \.label) { client in
                            if client.value != nil { Text(client.label).tag(client.label) }
                        }
                    }
                } label: { Label("Client", systemImage: "person.2") }
                .help("Filter by client")
                .appInteractiveCursor()
            }

            // View options popover (put the hour-height slider here)
            ToolbarItem(id: "viewOptions", placement: .secondaryAction) {
                Button {
                    showViewOptions.toggle()
                } label: { Label("View Options", systemImage: "slider.horizontal.3") }
                .popover(isPresented: $showViewOptions, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 12) {
                        if containerViewModel.calendarViewModel.calendarViewType == .week {
                            Text("Hour height").font(.headline)
                            Slider(value: containerViewModel.hourHeightBinding, in: 30...200, step: 10)
                            HStack {
                                Text("30"); Spacer(); Text("200")
                            }
                            .foregroundStyle(.secondary)
                        }
                        // add any other per-view toggles here
                    }
                    .padding()
                    .frame(width: 300)
                }
                .help("Layout & density")
                .appInteractiveCursor()
            }

            // TRAILING PRIMARY: main actions
            ToolbarItem(id: "newSession", placement: .primaryAction) {
                Button("New Session", systemImage: "plus", action: {containerViewModel.createNewSession()})
                .keyboardShortcut("n")
                .glassEffect(.regular.tint(.blue).interactive(), in: .buttonBorder)
                .appInteractiveCursor()
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
                .help("Show or hide inspector")
                .appInteractiveCursor()
            }
        }
        
        // Gives editing-centric layout behavior on macOS/iPadOS
        .toolbarRole(.editor)
        
        // Date picker popover
        .sheet(isPresented: $showCalendarSettings) {
            CalendarSettingsView()
        }
        .popover(isPresented: $containerViewModel.showDatePicker) {
            DatePickerView(
                selectedDate: $containerViewModel.selectedDate,
                onDateSelected: {
                    containerViewModel.goToDate(containerViewModel.selectedDate)
                    containerViewModel.showDatePicker = false
                }
            )
            .frame(width: 300, height: 200)
        }
        .onAppear {
            // Provide calendar inspector content to global inspector based on current view type
            updateCalendarInspectorContent()
        }
        .onChange(of: containerViewModel.calendarViewModel.calendarViewType) { _, _ in
            updateCalendarInspectorContent()
        }
        .onDisappear {
            // Clear inspector content when leaving calendar
            inspectorContentProvider.clearInspectorContent()
        }
    }

    // Legacy LiquidToolbar header removed; using system toolbar with .glass buttons

    private func updateCalendarInspectorContent() {
        let viewModel = containerViewModel.calendarViewModel
        let calendarViewType = viewModel.calendarViewType

        switch calendarViewType {
        case .week:
            inspectorContentProvider.setInspectorContent(
                WeekSidebarView(viewModel: viewModel),
                for: .calendar
            )
        case .month:
            inspectorContentProvider.setInspectorContent(
                MonthSidebarView(viewModel: viewModel),
                for: .calendar
            )
        case .agenda:
            // For agenda, we need to create a simple sidebar since AgendaSidebarView has many bindings
            inspectorContentProvider.setInspectorContent(
                AgendaInspectorContent(viewModel: viewModel),
                for: .calendar
            )
        case .timeline:
            // For timeline, create a simple sidebar since there's no TimelineSidebarView
            inspectorContentProvider.setInspectorContent(
                TimelineInspectorContent(viewModel: viewModel),
                for: .calendar
            )
        }
    }
}

// MARK: - Agenda Inspector Content
struct AgendaInspectorContent: View {
    @ObservedObject var viewModel: CalendarViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Agenda Inspector")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Summary statistics
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("TOTAL ITEMS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .tracking(1)
                    Text("\(viewModel.visibleSessionInstances.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                VStack(spacing: 4) {
                    Text("BILLABLE HOURS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .tracking(1)
                    Text(String(format: "%.1f h", viewModel.visibleBillableHours))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                VStack(spacing: 4) {
                    Text("GROSS INCOME")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .tracking(1)
                    Text(viewModel.formatCurrency(viewModel.visibleGrossIncome))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding(16)
    }
}

// MARK: - Timeline Inspector Content
struct TimelineInspectorContent: View {
    @ObservedObject var viewModel: CalendarViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Timeline Inspector")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Summary statistics
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("TIMELINE ITEMS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .tracking(1)
                    Text("\(viewModel.visibleSessionInstances.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                VStack(spacing: 4) {
                    Text("BILLABLE HOURS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .tracking(1)
                    Text(String(format: "%.1f h", viewModel.visibleBillableHours))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                VStack(spacing: 4) {
                    Text("GROSS INCOME")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .tracking(1)
                    Text(viewModel.formatCurrency(viewModel.visibleGrossIncome))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding(16)
    }
}

// Helper function to get icon names for calendar view types
private func iconName(for viewType: CalendarViewType) -> String {
    switch viewType {
    case .week:
        return "calendar.circle.fill"
    case .month:
        return "calendar"
    case .agenda:
        return "list.bullet"
    case .timeline:
        return "chart.bar.xaxis"
    }
}

// UnevenRoundedRectangle implementation if not already available
struct UnevenRoundedRectangle: Shape {
    var topLeadingRadius: CGFloat = 0
    var topTrailingRadius: CGFloat = 0
    var bottomLeadingRadius: CGFloat = 0
    var bottomTrailingRadius: CGFloat = 0
    
    init(topLeadingRadius: CGFloat = 0, topTrailingRadius: CGFloat = 0, 
         bottomLeadingRadius: CGFloat = 0, bottomTrailingRadius: CGFloat = 0) {
        self.topLeadingRadius = topLeadingRadius
        self.topTrailingRadius = topTrailingRadius
        self.bottomLeadingRadius = bottomLeadingRadius
        self.bottomTrailingRadius = bottomTrailingRadius
    }
    
    init(bottomLeadingRadius: CGFloat = 0, bottomTrailingRadius: CGFloat = 0) {
        self.bottomLeadingRadius = bottomLeadingRadius
        self.bottomTrailingRadius = bottomTrailingRadius
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.size.width
        let height = rect.size.height
        
        // Top left corner
        path.move(to: CGPoint(x: topLeadingRadius, y: 0))
        
        // Top edge
        path.addLine(to: CGPoint(x: width - topTrailingRadius, y: 0))
        
        // Top right corner
        path.addArc(center: CGPoint(x: width - topTrailingRadius, y: topTrailingRadius),
                    radius: topTrailingRadius,
                    startAngle: Angle(degrees: -90),
                    endAngle: Angle(degrees: 0),
                    clockwise: false)
        
        // Right edge
        path.addLine(to: CGPoint(x: width, y: height - bottomTrailingRadius))
        
        // Bottom right corner
        path.addArc(center: CGPoint(x: width - bottomTrailingRadius, y: height - bottomTrailingRadius),
                    radius: bottomTrailingRadius,
                    startAngle: Angle(degrees: 0),
                    endAngle: Angle(degrees: 90),
                    clockwise: false)
        
        // Bottom edge
        path.addLine(to: CGPoint(x: bottomLeadingRadius, y: height))
        
        // Bottom left corner
        path.addArc(center: CGPoint(x: bottomLeadingRadius, y: height - bottomLeadingRadius),
                    radius: bottomLeadingRadius,
                    startAngle: Angle(degrees: 90),
                    endAngle: Angle(degrees: 180),
                    clockwise: false)
        
        // Left edge
        path.addLine(to: CGPoint(x: 0, y: topLeadingRadius))
        
        // Top left corner
        path.addArc(center: CGPoint(x: topLeadingRadius, y: topLeadingRadius),
                    radius: topLeadingRadius,
                    startAngle: Angle(degrees: 180),
                    endAngle: Angle(degrees: 270),
                    clockwise: false)
        
        return path
    }
}

