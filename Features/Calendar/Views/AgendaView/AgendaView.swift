import SwiftUI
import EventKit
import SwiftData

// ─────────────────────────────────────────────────────────────
// MARK: - Main Agenda View Structure
// ─────────────────────────────────────────────────────────────

struct AgendaView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var showInspector: Bool
    
    // Agenda-specific state
    @State private var searchText = ""
    @State private var selectedViewMode: AgendaViewMode = .chronological
    @State private var selectedPriority: AgendaPriority = .all
    @State private var showCompleted = true
    @State private var showCancelled = true
    @State private var selectedDateRange: AgendaDateRange = .week
    @State private var sortBy: AgendaSortBy = .time
    @State private var showProgress = true
    @State private var showSuggestions = true

    // ════════════════════════════════════════════════════════
    // MARK: Body
    // ════════════════════════════════════════════════════════
    
    var body: some View {
        HStack(spacing: 0) {
            // Main agenda content
            agendaContent()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.11, green: 0.11, blue: 0.13))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                        )
                )
                .layoutPriority(1)
        }
        .padding(16)
        .clipped()
    }

    // ════════════════════════════════════════════════════════
    // MARK: Agenda Content
    // ════════════════════════════════════════════════════════

    @ViewBuilder
    private func agendaContent() -> some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Enhanced header with controls
                agendaHeader()
                    .frame(height: 80)
                
                // Agenda content
                agendaGrid()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func agendaHeader() -> some View {
        VStack(spacing: 8) {
            // Main header
            HStack {
                Text(viewModel.calendarTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                
                Spacer()
                
                // Agenda controls
                HStack(spacing: 12) {
                    // View mode control
                    Picker("View", selection: $selectedViewMode) {
                        ForEach(AgendaViewMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    
                    // Sort by control
                    Picker("Sort", selection: $sortBy) {
                        ForEach(AgendaSortBy.allCases, id: \.self) { sort in
                            Text(sort.displayName).tag(sort)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                        
                    // Priority control
                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(AgendaPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
            }
            
            // Search and filter bar
            HStack {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search agenda...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                
                // Quick filters
                HStack(spacing: 8) {
                    Button(action: { showCompleted.toggle() }) {
                        HStack {
                            Image(systemName: showCompleted ? "checkmark.circle.fill" : "circle")
                            Text("Completed")
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(showCompleted ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showCancelled.toggle() }) {
                        HStack {
                            Image(systemName: showCancelled ? "xmark.circle.fill" : "circle")
                            Text("Cancelled")
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(showCancelled ? Color.red.opacity(0.2) : Color.gray.opacity(0.2))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func agendaGrid() -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Progress summary (if enabled)
                if showProgress {
                    AgendaProgressView(items: filteredItems)
                }
                
                // Smart suggestions (if enabled)
                if showSuggestions && !smartSuggestions.isEmpty {
                    AgendaSuggestionsView(suggestions: smartSuggestions)
                }
                
                // Main agenda items
                ForEach(organizedAgendaItems, id: \.id) { section in
                    AgendaSectionView(
                        section: section,
                        viewModel: viewModel,
                        onItemTap: handleItemSelection
                    )
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    // ════════════════════════════════════════════════════════
    // MARK: Helper Methods
    // ════════════════════════════════════════════════════════

    private var filteredItems: [DisplayableCalendarItem] {
        viewModel.displayableItems.filter { item in
            // Search filter
            let matchesSearch = searchText.isEmpty || 
                item.title.localizedCaseInsensitiveContains(searchText) ||
                {
                    if case .session(let session) = item, let client = session.client {
                        return client.fullName.localizedCaseInsensitiveContains(searchText)
                    }
                    return false
                }()
            
            // Status filter
            let matchesStatus = {
                if case .session(let session) = item {
                    return (session.status == "completed" ? showCompleted : true) &&
                           (session.status == "cancelled" ? showCancelled : true)
                }
                return true
            }()
            
            // Priority filter
            let matchesPriority = selectedPriority.matches(item)
            
            return matchesSearch && matchesStatus && matchesPriority
        }
    }
    
    private var organizedAgendaItems: [AgendaSection] {
        let sortedItems = filteredItems.sorted { first, second in
            switch sortBy {
            case .time:
                return (first.startDate ?? Date()) < (second.startDate ?? Date())
            case .priority:
                return first.priority > second.priority
            case .title:
                return first.title < second.title
            case .client:
                let firstClient = {
                    if case .session(let session) = first, let client = session.client {
                        return client.fullName
                    }
                    return ""
                }()
                let secondClient = {
                    if case .session(let session) = second, let client = session.client {
                        return client.fullName
                    }
                    return ""
                }()
                return firstClient < secondClient
            }
        }
        
        switch selectedViewMode {
        case .chronological:
            return organizeChronologically(sortedItems)
        case .priority:
            return organizeByPriority(sortedItems)
        case .client:
            return organizeByClient(sortedItems)
        case .status:
            return organizeByStatus(sortedItems)
        case .smart:
            return organizeSmart(sortedItems)
        }
    }
    
    private var smartSuggestions: [AgendaSuggestion] {
        let today = Date()
        let calendar = Calendar.current
        
        return [
            AgendaSuggestion(
                title: "Today's Focus",
                description: "\(filteredItems.filter { calendar.isDate($0.startDate ?? Date(), inSameDayAs: today) }.count) events today",
                icon: "star.fill",
                color: .orange
            ),
            AgendaSuggestion(
                title: "Upcoming Deadlines",
                description: "3 sessions due this week",
                icon: "clock.fill",
                color: .red
            ),
            AgendaSuggestion(
                title: "Client Follow-ups",
                description: "2 clients need follow-up",
                icon: "person.2.fill",
                color: .blue
            )
        ]
    }
    
    private func organizeChronologically(_ items: [DisplayableCalendarItem]) -> [AgendaSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.startDate ?? Date())
        }
        
        return grouped.map { date, items in
            AgendaSection(
                id: "date-\(date.timeIntervalSince1970)",
                title: date.formatted(date: .complete, time: .omitted),
                subtitle: "\(items.count) events",
                items: items,
                sectionType: .date,
                priority: .normal
            )
        }.sorted { $0.title < $1.title }
    }
    
    private func organizeByPriority(_ items: [DisplayableCalendarItem]) -> [AgendaSection] {
        let grouped = Dictionary(grouping: items) { item in
            item.priority
        }
        
        return grouped.map { priority, items in
            AgendaSection(
                id: "priority-\(priority.rawValue)",
                title: priority.displayName,
                subtitle: "\(items.count) events",
                items: items,
                sectionType: .priority,
                priority: priority
            )
        }.sorted { $0.priority > $1.priority }
    }
    
    private func organizeByClient(_ items: [DisplayableCalendarItem]) -> [AgendaSection] {
        let grouped = Dictionary(grouping: items) { item in
            if case .session(let session) = item, let client = session.client {
                return client.fullName
            }
            return "Other"
        }
        
        return grouped.map { clientName, items in
            AgendaSection(
                id: "client-\(clientName)",
                title: clientName,
                subtitle: "\(items.count) events",
                items: items,
                sectionType: .client,
                priority: .normal
            )
        }.sorted { $0.title < $1.title }
    }
    
    private func organizeByStatus(_ items: [DisplayableCalendarItem]) -> [AgendaSection] {
        let grouped = Dictionary(grouping: items) { item in
            if case .session(let session) = item {
                return session.status ?? "Unknown"
            }
            return "External Event"
        }
        
        return grouped.map { status, items in
            AgendaSection(
                id: "status-\(status)",
                title: status.capitalized,
                subtitle: "\(items.count) events",
                items: items,
                sectionType: .status,
                priority: .normal
            )
        }.sorted { $0.title < $1.title }
    }
    
    private func organizeSmart(_ items: [DisplayableCalendarItem]) -> [AgendaSection] {
        let today = Date()
        let calendar = Calendar.current
        
        var sections: [AgendaSection] = []
        
        // Today's events
        let todaysItems = items.filter { calendar.isDate($0.startDate ?? Date(), inSameDayAs: today) }
        if !todaysItems.isEmpty {
            sections.append(AgendaSection(
                id: "today",
                title: "Today",
                subtitle: "\(todaysItems.count) events",
                items: todaysItems,
                sectionType: .smart,
                priority: .high
            ))
        }
        
        // This week's events
        let thisWeekItems = items.filter { item in
            guard let startDate = item.startDate else { return false }
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? today
            return startDate >= weekStart && startDate < weekEnd && !calendar.isDate(startDate, inSameDayAs: today)
        }
        if !thisWeekItems.isEmpty {
            sections.append(AgendaSection(
                id: "this-week",
                title: "This Week",
                subtitle: "\(thisWeekItems.count) events",
                items: thisWeekItems,
                sectionType: .smart,
                priority: .normal
            ))
        }
        
        // Future events
        let futureItems = items.filter { item in
            guard let startDate = item.startDate else { return false }
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today) ?? today
            return startDate >= weekEnd
        }
        if !futureItems.isEmpty {
            sections.append(AgendaSection(
                id: "future",
                title: "Future",
                subtitle: "\(futureItems.count) events",
                items: futureItems,
                sectionType: .smart,
                priority: .low
            ))
        }
        
        return sections
    }
    
    private func handleItemSelection(_ item: DisplayableCalendarItem) {
        switch item {
        case .session(let session):
            // Reset selection first to ensure onChange triggers even for same session
            viewModel.selectedSessionInfo = nil
            DispatchQueue.main.async {
                viewModel.selectedSessionInfo = (session: session, instanceStart: item.startDate ?? Date(), instanceEnd: item.endDate ?? Date())
            }
        case .event:
            // Handle external event selection if needed
            break
        case .recurringSessionInstance(let template, let instanceStart, let instanceEnd, _):
            // Reset selection first to ensure onChange triggers even for same session
            viewModel.selectedSessionInfo = nil
            DispatchQueue.main.async {
                viewModel.selectedSessionInfo = (session: template, instanceStart: instanceStart, instanceEnd: instanceEnd)
            }
        case .eventSegment:
            // Handle event segment selection if needed
            break
        }
    }
}

// ════════════════════════════════════════════════════════
// MARK: Supporting Types
// ════════════════════════════════════════════════════════

struct AgendaSection {
    let id: String
    let title: String
    let subtitle: String
    let items: [DisplayableCalendarItem]
    let sectionType: AgendaSectionType
    let priority: AgendaPriority
}

enum AgendaSectionType {
    case date, priority, client, status, smart
}

enum AgendaViewMode: CaseIterable {
    case chronological, priority, client, status, smart
    
    var displayName: String {
        switch self {
        case .chronological: return "Chronological"
        case .priority: return "Priority"
        case .client: return "Client"
        case .status: return "Status"
        case .smart: return "Smart"
        }
    }
}

enum AgendaPriority: Int, CaseIterable, Comparable {
    case all = 0, high = 3, normal = 2, low = 1
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .high: return "High"
        case .normal: return "Normal"
        case .low: return "Low"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .gray
        case .high: return .red
        case .normal: return .orange
        case .low: return .blue
        }
    }
    
    func matches(_ item: DisplayableCalendarItem) -> Bool {
        switch self {
        case .all: return true
        default: return item.priority == self
        }
    }
    
    static func < (lhs: AgendaPriority, rhs: AgendaPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum AgendaSortBy: CaseIterable {
    case time, priority, title, client
    
    var displayName: String {
        switch self {
        case .time: return "Time"
        case .priority: return "Priority"
        case .title: return "Title"
        case .client: return "Client"
        }
    }
}

enum AgendaDateRange: CaseIterable {
    case day, week, month, quarter, year
    
    var displayName: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "Quarter"
        case .year: return "Year"
        }
    }
}

struct AgendaSuggestion {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

// Extension to add priority to DisplayableCalendarItem
extension DisplayableCalendarItem {
    var priority: AgendaPriority {
        switch self {
        case .session(let session):
            // Determine priority based on session properties
            if session.status == "cancelled" { return .low }
            if session.status == "completed" { return .low }
            // Add more priority logic based on your business rules
            return .normal
        case .event:
            return .normal
        case .recurringSessionInstance:
            return .high
        case .eventSegment:
            return .normal
        }
    }
}

struct AgendaProgressView: View {
    let items: [DisplayableCalendarItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                ProgressCard(
                    title: "Total",
                    count: items.count,
                    color: .blue
                )
                
                ProgressCard(
                    title: "Completed",
                    count: items.filter { if case .session(let session) = $0 { return session.status == "completed" }; return false }.count,
                    color: .green
                )
                
                ProgressCard(
                    title: "Pending",
                    count: items.filter { if case .session(let session) = $0 { return session.status == "planned" || session.status == "confirmed" }; return false }.count,
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

struct ProgressCard: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct AgendaSuggestionsView: View {
    let suggestions: [AgendaSuggestion]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Smart Suggestions")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(suggestions, id: \.title) { suggestion in
                    HStack {
                        Image(systemName: suggestion.icon)
                            .foregroundColor(suggestion.color)
                            .font(.system(size: 16))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text(suggestion.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

struct AgendaSectionView: View {
    let section: AgendaSection
    let viewModel: CalendarViewModel
    let onItemTap: (DisplayableCalendarItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(section.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Priority indicator
                if section.priority != .normal {
                    Text(section.priority.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(section.priority.color.opacity(0.2))
                        .foregroundColor(section.priority.color)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
            
            // Agenda items
            VStack(spacing: 4) {
                ForEach(section.items) { item in
                    AgendaItemView(
                        item: item,
                        isSelected: viewModel.selectedItemIDs.contains(item.id),
                        isBulkSelectionMode: viewModel.isBulkSelectionMode
                    ) {
                        if viewModel.isBulkSelectionMode {
                            viewModel.toggleItemSelection(item.id)
                        } else {
                            onItemTap(item)
                        }
                    }
                }
            }
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

struct AgendaItemView: View {
    let item: DisplayableCalendarItem
    let isSelected: Bool
    let isBulkSelectionMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox (only in bulk mode)
            if isBulkSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 16))
            }
            
            // Priority indicator
            Rectangle()
                .fill(item.priority.color)
                .frame(width: 4)
                .cornerRadius(2)
            
            // Time indicator
            VStack(alignment: .leading, spacing: 2) {
                if let startDate = item.startDate {
                    Text(startDate, style: .time)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                if let endDate = item.endDate {
                    Text(endDate, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 60, alignment: .leading)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                Text(item.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    
                    Spacer()
                    
                    // Priority badge
                    if item.priority != .normal {
                        Text(item.priority.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(item.priority.color.opacity(0.2))
                            .foregroundColor(item.priority.color)
                            .cornerRadius(3)
                    }
                }
                
                // Additional details
                if case .session(let session) = item, let client = session.client {
                    Text(client.fullName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Status and duration
                HStack {
                if case .session(let session) = item {
                        Text(session.status ?? "Unknown")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                            .background(statusColor(session.status ?? "Unknown").opacity(0.2))
                            .foregroundColor(statusColor(session.status ?? "Unknown"))
                        .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    // Duration
                    if let start = item.startDate, let end = item.endDate {
                        let duration = end.timeIntervalSince(start)
                        let hours = Int(duration / 3600)
                        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
                        Text("\(hours)h \(minutes)m")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.2))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onTap()
        }
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status {
        case "completed": return .green
        case "cancelled": return .red
        case "confirmed": return .blue
        case "planned": return .orange
        default: return .gray
        }
    }
}

struct AgendaSidebarView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var searchText: String
    @Binding var selectedViewMode: AgendaViewMode
    @Binding var selectedPriority: AgendaPriority
    @Binding var showCompleted: Bool
    @Binding var showCancelled: Bool
    @Binding var selectedDateRange: AgendaDateRange
    @Binding var sortBy: AgendaSortBy
    @Binding var showProgress: Bool
    @Binding var showSuggestions: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Agenda View")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Search
            VStack(alignment: .leading, spacing: 4) {
                Text("Search")
                    .font(.caption)
                    .fontWeight(.medium)
                
                TextField("Search agenda...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            
            // View Mode
            VStack(alignment: .leading, spacing: 8) {
                Text("View Mode")
                    .font(.caption)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(AgendaViewMode.allCases, id: \.self) { mode in
                        Button(action: { selectedViewMode = mode }) {
                            HStack {
                                Image(systemName: selectedViewMode == mode ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedViewMode == mode ? .blue : .gray)
                                Text(mode.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Priority Filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Priority")
                    .font(.caption)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(AgendaPriority.allCases, id: \.self) { priority in
                        Button(action: { selectedPriority = priority }) {
                            HStack {
                                Image(systemName: selectedPriority == priority ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedPriority == priority ? .blue : .gray)
                                Text(priority.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Sort Options
            VStack(alignment: .leading, spacing: 8) {
                Text("Sort By")
                    .font(.caption)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(AgendaSortBy.allCases, id: \.self) { sort in
                        Button(action: { sortBy = sort }) {
                            HStack {
                                Image(systemName: sortBy == sort ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(sortBy == sort ? .blue : .gray)
                                Text(sort.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Display Options
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Options")
                    .font(.caption)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Show Progress", isOn: $showProgress)
                    Toggle("Show Suggestions", isOn: $showSuggestions)
                    Toggle("Show Completed", isOn: $showCompleted)
                    Toggle("Show Cancelled", isOn: $showCancelled)
                }
            }
            
            Spacer()
            
            // Statistics
            VStack(alignment: .leading, spacing: 8) {
                Text("Agenda Statistics")
                    .font(.caption)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Total Items")
                        Spacer()
                        Text("\(viewModel.displayableItems.count)")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("High Priority")
                        Spacer()
                        Text("\(viewModel.displayableItems.filter { $0.priority == .high }.count)")
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                    
                    HStack {
                        Text("Today's Events")
                        Spacer()
                        let today = Date()
                        let calendar = Calendar.current
                        let todaysCount = viewModel.displayableItems.filter { 
                            calendar.isDate($0.startDate ?? Date(), inSameDayAs: today) 
                        }.count
                        Text("\(todaysCount)")
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
                .font(.caption)
            }
        }
        .padding()
    }
}

#Preview {
    AgendaView(viewModel: CalendarViewModel(
        context: ModelContext(try! ModelContainer(for: SessionEntity.self)),
        eventKitService: EventKitSyncService.shared,
        dataManager: CalendarDataManager(
            context: ModelContext(try! ModelContainer(for: SessionEntity.self)),
            eventKitService: EventKitSyncService.shared
        )
    ), showInspector: .constant(false))
} 