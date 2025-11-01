import Foundation
import SwiftUI
import Data
import Core

// MARK: - Navigation History Entry
struct NavigationHistoryEntry: Identifiable, Equatable {
    let id = UUID()
    let tab: AppTab
    let context: NavigationContext?
    let timestamp: Date
    let title: String // Human-readable description of the navigation
    
    init(tab: AppTab, context: NavigationContext? = nil, title: String? = nil) {
        self.tab = tab
        self.context = context
        self.timestamp = Date()
        
        // Generate a descriptive title based on tab and context
        if let customTitle = title {
            self.title = customTitle
        } else {
            self.title = Self.generateTitle(for: tab, context: context)
        }
    }
    
    static func generateTitle(for tab: AppTab, context: NavigationContext?) -> String {
        if let entityType = context?.targetEntityType {
            switch entityType {
            case .client:
                return "\(tab.title) - Client Details"
            case .session:
                return "\(tab.title) - Session Details"
            case .invoice:
                return "\(tab.title) - Invoice Details"
            case .payee:
                return "\(tab.title) - Payee Details"
            case .planManager:
                return "\(tab.title) - Plan Manager Details"
            case .clientService:
                return "\(tab.title) - Service Details"
            case .ndisItem:
                return "\(tab.title) - NDIS Item Details"
            }
        } else if let targetDate = context?.targetDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "\(tab.title) - \(formatter.string(from: targetDate))"
        } else {
            return tab.title
        }
    }
    
    static func == (lhs: NavigationHistoryEntry, rhs: NavigationHistoryEntry) -> Bool {
        return lhs.tab == rhs.tab &&
               lhs.context?.targetEntity == rhs.context?.targetEntity &&
               lhs.context?.targetEntityType == rhs.context?.targetEntityType &&
               lhs.context?.targetDate == rhs.context?.targetDate
    }
}

// MARK: - Navigation Context Data Models
public struct NavigationContext {
    public var targetEntity: UUID?
    public var targetEntityType: EntityType?
    public var targetDate: Date?
    public var searchQuery: String?
    public var additionalData: [String: Any]?
    
    public enum EntityType {
        case client
        case session
        case invoice
        case payee
        case planManager
        case clientService
        case ndisItem
    }
}

// MARK: - App Navigation Manager
@MainActor
public class AppNavigationManager: ObservableObject {
    @MainActor public static let shared = AppNavigationManager()
    
    @Published var selectedTab: AppTab = .invoices
    @Published var navigationContext: NavigationContext?
    
    // MARK: - Navigation History
    @Published private var navigationHistory: [NavigationHistoryEntry] = []
    @Published private var currentHistoryIndex: Int = -1
    private let maxHistorySize: Int = 50
    private var isNavigatingInternally: Bool = false
    
    public init() {
        // Add initial invoices entry to history
        addToHistory(tab: .invoices, context: nil, title: "Invoices")
    }
    
    // MARK: - History Management
    
    /// Add current navigation to history
    private func addToHistory(tab: AppTab, context: NavigationContext?, title: String? = nil) {
        let entry = NavigationHistoryEntry(tab: tab, context: context, title: title)
        
        // Don't add duplicate entries
        if let currentEntry = currentHistoryEntry,
           currentEntry == entry {
            return
        }
        

        if currentHistoryIndex < navigationHistory.count - 1 {
            navigationHistory.removeSubrange((currentHistoryIndex + 1)...)
        }
        
        // Add new entry
        navigationHistory.append(entry)
        currentHistoryIndex = navigationHistory.count - 1
        
        // Maintain max history size
        if navigationHistory.count > maxHistorySize {
            navigationHistory.removeFirst()
            currentHistoryIndex -= 1
        }
    }
    
    /// Get current history entry
    var currentHistoryEntry: NavigationHistoryEntry? {
        guard currentHistoryIndex >= 0 && currentHistoryIndex < navigationHistory.count else { return nil }
        return navigationHistory[currentHistoryIndex]
    }
    
    /// Check if we can navigate back
    var canNavigateBack: Bool {
        currentHistoryIndex > 0
    }
    
    /// Check if we can navigate forward
    var canNavigateForward: Bool {
        currentHistoryIndex < navigationHistory.count - 1
    }
    
    /// Navigate back in history
    func navigateBack() {
        guard canNavigateBack else { return }
        
        currentHistoryIndex -= 1
        let entry = navigationHistory[currentHistoryIndex]
        
        // Set flag to prevent double-tracking
        isNavigatingInternally = true
        
        DispatchQueue.main.async {
            self.navigationContext = entry.context
            self.selectedTab = entry.tab
            self.isNavigatingInternally = false
        }
    }
    
    /// Navigate forward in history
    func navigateForward() {
        guard canNavigateForward else { return }
        
        currentHistoryIndex += 1
        let entry = navigationHistory[currentHistoryIndex]
        
        // Set flag to prevent double-tracking
        isNavigatingInternally = true
        
        DispatchQueue.main.async {
            self.navigationContext = entry.context
            self.selectedTab = entry.tab
            self.isNavigatingInternally = false
        }
    }
    
    /// Get navigation history for display (most recent first)
    var recentHistory: [NavigationHistoryEntry] {
        Array(navigationHistory.reversed().prefix(10))
    }
    
    /// Get back navigation entry (previous entry)
    var backNavigationEntry: NavigationHistoryEntry? {
        guard canNavigateBack else { return nil }
        return navigationHistory[currentHistoryIndex - 1]
    }
    
    /// Get forward navigation entry (next entry)
    var forwardNavigationEntry: NavigationHistoryEntry? {
        guard canNavigateForward else { return nil }
        return navigationHistory[currentHistoryIndex + 1]
    }
    
    // MARK: - Primary Navigation Methods
    
    /// Navigate to a specific tab with optional context
    func navigateTo(tab: AppTab, context: NavigationContext? = nil, title: String? = nil) {
        // Add to history before navigating
        addToHistory(tab: tab, context: context, title: title)
        
        // Set flag to prevent double-tracking from onChange listener
        isNavigatingInternally = true
        
        DispatchQueue.main.async {
            self.navigationContext = context
            self.selectedTab = tab
            // Reset flag after navigation is complete
            self.isNavigatingInternally = false
        }
    }
    
    /// Navigate to view a specific client in the relationships tab
    func navigateToClient(_ clientID: UUID) {
        let context = NavigationContext(
            targetEntity: clientID,
            targetEntityType: .client
        )
        navigateTo(tab: .relationships, context: context, title: "Client Details")
    }
    
    /// Navigate to view a specific session in the calendar tab
    func navigateToSession(_ sessionID: UUID, date: Date? = nil) {
        let context = NavigationContext(
            targetEntity: sessionID,
            targetEntityType: .session,
            targetDate: date
        )
        navigateTo(tab: .calendar, context: context, title: "Session Details")
    }
    
    /// Navigate to view a specific invoice in the invoices tab
    func navigateToInvoice(_ invoiceID: UUID) {
        let context = NavigationContext(
            targetEntity: invoiceID,
            targetEntityType: .invoice
        )
        navigateTo(tab: .invoices, context: context, title: "Invoice Details")
    }
    
    /// Navigate to view a specific payee in the relationships tab
    func navigateToPayee(_ payeeID: UUID) {
        let context = NavigationContext(
            targetEntity: payeeID,
            targetEntityType: .payee
        )
        navigateTo(tab: .relationships, context: context)
    }
    
    /// Navigate to view a specific plan manager in the relationships tab
    func navigateToPlanManager(_ planManagerID: UUID) {
        let context = NavigationContext(
            targetEntity: planManagerID,
            targetEntityType: .planManager
        )
        navigateTo(tab: .relationships, context: context)
    }
    
    /// Navigate to view a specific client service in the relationships tab
    func navigateToClientService(_ clientServiceID: UUID) {
        let context = NavigationContext(
            targetEntity: clientServiceID,
            targetEntityType: .clientService
        )
        navigateTo(tab: .relationships, context: context)
    }
    
    /// Navigate to view a specific NDIS item in the NDIS catalogue
    func navigateToNDISItem(_ ndisItemID: UUID, searchQuery: String? = nil) {
        let context = NavigationContext(
            targetEntity: ndisItemID,
            targetEntityType: .ndisItem,
            searchQuery: searchQuery
        )
        navigateTo(tab: .ndisCatalogue, context: context)
    }
    

    
    // MARK: - Complex Navigation Scenarios
    

    
    /// Navigate from invoice to related client
    func navigateFromInvoiceToClient(clientID: UUID) {
        navigateToClient(clientID)
    }
    
    /// Navigate from client to their sessions on calendar
    func navigateFromClientToSessions(clientID: UUID, date: Date? = nil) {
        let context = NavigationContext(
            targetEntity: clientID,
            targetEntityType: .client,
            targetDate: date,
            additionalData: ["filterByClient": true]
        )
        navigateTo(tab: .calendar, context: context)
    }
    
    /// Navigate from session to client details
    func navigateFromSessionToClient(sessionID: UUID, clientID: UUID) {
        navigateToClient(clientID)
    }
    
    /// Navigate from session to invoice (if exists)
    func navigateFromSessionToInvoice(sessionID: UUID, invoiceID: UUID?) {
        guard let invoiceID = invoiceID else { return }
        navigateToInvoice(invoiceID)
    }
    
    // MARK: - Context Management
    
    /// Clear navigation context after it's been consumed
    func clearNavigationContext() {
        DispatchQueue.main.async {
            self.navigationContext = nil
        }
    }
    
    /// Check if there's pending navigation context
    var hasPendingNavigation: Bool {
        navigationContext != nil
    }
    
    /// Get and clear navigation context (consume it)
    public func consumeNavigationContext() -> NavigationContext? {
        let context = navigationContext
        clearNavigationContext()
        return context
    }
    
    /// Ensure current tab is properly tracked in history (safety net for external changes)
    func ensureCurrentTabInHistory() {
        // Don't add to history if this change was initiated internally
        guard !isNavigatingInternally else { return }
        
        let currentEntry = NavigationHistoryEntry(tab: selectedTab, context: navigationContext)
        
        // Check if current state is already the latest entry
        if let lastEntry = navigationHistory.last,
           lastEntry == currentEntry {
            return // Already tracked
        }
        
        // Add current state to history
        addToHistory(tab: selectedTab, context: navigationContext)
    }
}



// MARK: - SwiftUI Environment Key
struct AppNavigationManagerKey: EnvironmentKey {
    static let defaultValue: AppNavigationManager? = nil
}

extension EnvironmentValues {
    var appNavigationManager: AppNavigationManager? {
        get { self[AppNavigationManagerKey.self] }
        set { self[AppNavigationManagerKey.self] = newValue }
    }
}

// MARK: - View Extension for Easy Navigation
extension View {
    func withAppNavigation() -> some View {
        self.environment(\.appNavigationManager, AppNavigationManager.shared)
    }
}

// MARK: - Helper Extensions
extension AppTab {
    var supportsEntityNavigation: Bool {
        switch self {
        case .relationships, .calendar, .invoices, .billingHub, .ndisCatalogue, .ndisBilling, .invoiceTemplateEditor, .testingArea:
            return true
        case .settings:
            return false
        }
    }
} 
