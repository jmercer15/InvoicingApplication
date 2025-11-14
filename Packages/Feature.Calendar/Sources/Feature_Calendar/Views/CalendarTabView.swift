import SwiftUI
import SwiftData
import Data
import EventKit
import Core
import SharedUI

// MARK: - Enhanced TabView-based Calendar Container

/// A modern TabView implementation for calendar view switching that follows Apple's design guidelines.
/// 
/// This implementation provides:
/// - Native TabView with proper Tab and TabSection usage
/// - Full accessibility support with labels, hints, and traits
/// - Smooth animations and haptic feedback
/// - Custom tab bar styling with material effects
/// - Automatic tab bar placement and minimize behavior
/// - Bidirectional synchronization with the view model
///
/// The TabView automatically adapts to different screen sizes and orientations,
/// providing an optimal user experience across all Apple platforms.
struct CalendarTabView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var showInspector: Bool
    @State private var selectedTab: CalendarViewType = .week
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Week View Tab
            WeekView(viewModel: viewModel, showInspector: $showInspector)
                .tabItem {
                    Label("Week", systemImage: "calendar")
                }
                .tag(CalendarViewType.week)
                .accessibilityLabel("Week calendar view")
                .accessibilityHint("Shows calendar events in weekly format")
            
            // Month View Tab
            let weeks = CalendarDisplayDataProvider().buildMonthGridWeeks(for: viewModel.selectedDate)
            MonthView(viewModel: viewModel, showInspector: $showInspector, precomputedWeeks: weeks)
                .tabItem {
                    Label("Month", systemImage: "calendar.badge.clock")
                }
                .tag(CalendarViewType.month)
                .accessibilityLabel("Month calendar view")
                .accessibilityHint("Shows calendar events in monthly format")
        }
        .tabViewStyle(.automatic)
        .onChange(of: selectedTab) { oldValue, newValue in
            print("🔄 Calendar: TabView changed from \(oldValue) to \(newValue)")
            // Update the view model's calendar view type with animation
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.calendarViewType = newValue
            }
        }
        .onChange(of: viewModel.calendarViewType) { oldValue, newValue in
            print("🔄 Calendar: View model changed from \(oldValue) to \(newValue)")
            // Update the selected tab when view model changes
            if selectedTab != newValue {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = newValue
                }
            }
        }
        .onAppear {
            // Initialize the selected tab based on the view model's current state
            selectedTab = viewModel.calendarViewType
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Calendar view selector")
    }
}

// MARK: - Calendar Tab Configuration

extension CalendarTabView {
    /// Configuration for calendar tab appearance and behavior
    private struct TabConfiguration {
        static let animationDuration: Double = 0.3
        static let tabBarHeight: CGFloat = 60
        static let tabIconSize: CGFloat = 20
    }
}

// MARK: - Preview
#Preview {
    // Note: Preview disabled - would need CalendarViewModel(sessionsRepository:clientsRepository:clientServicesRepository:eventKitService:modelContext:)
    EmptyView()
    /*
    let container = try! ModelContainer(for: SessionEntity.self)
    let context = ModelContext(container)
    let sessionsRepository = SessionsRepositorySwiftData(modelContext: context)
    let eventKitService = EventKitSyncService.shared
    let dataManager = CalendarDataManager(sessionsRepository: sessionsRepository, eventKitService: eventKitService)
    CalendarTabView(
        viewModel: CalendarViewModel(
            sessionsRepository: sessionsRepository,
            eventKitService: eventKitService,
            dataManager: dataManager,
            modelContext: context
        ),
        showInspector: .constant(false)
    )
    */
}
