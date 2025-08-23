import SwiftUI


// ─────────────────────────────────────────────────────────────
// MARK: - Week View Sidebar
// ─────────────────────────────────────────────────────────────

struct WeekSidebarView: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                summarySection()
            }
            .padding(12)
        }
        .background(Color.clear)
    }

    // --- Section View Builders ---
    @ViewBuilder private func summarySection() -> some View {
        VStack(spacing: 10) {
            // Visible Sessions (all instances)
                VStack(spacing: 4) {
                    Text("VISIBLE SESSIONS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                        .tracking(1)
                let visibleSessionCount = viewModel.visibleSessionInstances.count
                Text("\(visibleSessionCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
                // Total Billable Hours
                VStack(spacing: 4) {
                    Text("BILLABLE HOURS")
            .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                        .tracking(1)
                Text(String(format: "%.1f h", viewModel.visibleBillableHours))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
                // Total Gross Income
                VStack(spacing: 4) {
                    Text("GROSS INCOME")
            .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                        .tracking(1)
                Text(viewModel.formatCurrency(viewModel.visibleGrossIncome))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
            }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Mini Month Calendar View (Used in Sidebar)
// ─────────────────────────────────────────────────────────────

struct MiniMonthView: View {
    @ObservedObject var viewModel: CalendarViewModel

    // Access weeks from ViewModel
    private var weeks: [[Date?]] { viewModel.miniCalendarWeeks }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            monthHeader()
            weekdayHeaders()
            dayGrid()
                .aspectRatio(7.0 / CGFloat(max(1, weeks.count)), contentMode: .fit)
            monthNavigationArrows()
        }
        .padding(8)
    }

    @ViewBuilder
    private func monthHeader() -> some View {
        HStack {
            Spacer()
            monthMenu()
            yearMenu()
            Spacer()
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func monthMenu() -> some View {
        Menu {
            monthSelectionGrid()
        } label: {
            Text(viewModel.miniCalendarFormattedMonth)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private func yearMenu() -> some View {
        Menu {
            yearSelectionList()
        } label: {
            Text(viewModel.miniCalendarFormattedYear)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private func monthSelectionGrid() -> some View {
        let monthSymbols = Calendar.current.shortMonthSymbols
        ForEach(0..<12) { monthIndex in
            Button {
                viewModel.selectMiniCalendarMonth(monthIndex + 1)
            } label: {
                Text(monthSymbols[monthIndex])
                    .frame(maxWidth: .infinity)
            }
            .background(
                Calendar.current.component(.month, from: viewModel.miniCalendarDisplayMonth) == monthIndex + 1
                ? Color.accentColor.opacity(0.2)
                : Color.clear
            )
            .cornerRadius(4)
        }
    }

    @ViewBuilder
    private func yearSelectionList() -> some View {
        ForEach(viewModel.miniCalendarSelectableYears, id: \.self) { year in
            Button {
                viewModel.selectMiniCalendarYear(year)
            } label: {
                Text(String(year))
                    .frame(maxWidth: .infinity)
            }
            .background(
                Calendar.current.component(.year, from: viewModel.miniCalendarDisplayMonth) == year
                ? Color.accentColor.opacity(0.2)
                : Color.clear
            )
            .cornerRadius(4)
        }
    }

    @ViewBuilder
    private func weekdayHeaders() -> some View {
        HStack(spacing: 0) {
            let calendar = Calendar.current
            let symbols = calendar.shortWeekdaySymbols
            let orderedSymbols = Array(symbols[calendar.firstWeekday - 1 ..< symbols.count]) + Array(symbols[0 ..< calendar.firstWeekday - 1])
            ForEach(orderedSymbols, id: \.self) { symbol in
                Text(symbol.prefix(1))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dayGrid() -> some View {
        VStack(spacing: 0) {
            ForEach(weeks.indices, id: \.self) { weekIndex in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        if let date = weeks[weekIndex][dayIndex] {
                            dayCell(date)
                        } else {
                            emptyDayCell()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        let isDisplayMonth = Calendar.current.isDate(date, equalTo: viewModel.miniCalendarDisplayMonth, toGranularity: .month)

        Text(dayNumber(date))
            .font(.system(size: 11))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundColor(
                isSelected ? .white : isToday ? .accentColor : (isDisplayMonth ? .primary : .secondary.opacity(0.5))
            )
            .background(
                ZStack {
                    if isSelected {
                        Circle().fill(Color.accentColor).padding(2)
                    } else if isToday {
                        Circle().stroke(Color.accentColor, lineWidth: 1).padding(2)
                    }
                }
            )
            .contentShape(Rectangle())
            .overlay(Rectangle().stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
            .onTapGesture {
                withAnimation {
                    viewModel.selectedDate = date
                }
            }
            .opacity(isDisplayMonth ? 1.0 : 0.4)
    }

    @ViewBuilder
    private func emptyDayCell() -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(Rectangle().stroke(Color.secondary.opacity(0.1), lineWidth: 0.5))
    }

    @ViewBuilder
    private func monthNavigationArrows() -> some View {
        HStack {
            Button { viewModel.changeMiniCalendarMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            Spacer()
            Button { viewModel.changeMiniCalendarMonth(by: 1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
        }
        .padding(.horizontal, 8)
    }

    // Helper Methods
    private func dayNumber(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "d"; return formatter.string(from: date)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - Helper Views (Section Container & Background)
// ─────────────────────────────────────────────────────────────

struct SectionContainer<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .background(ContainerBackground())
            .padding(.horizontal, 12)
    }
}

struct ContainerBackground: View {
    var body: some View {
         RoundedRectangle(cornerRadius: 8)
            .fill(Color(.controlBackgroundColor).opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
            )
    }
}
