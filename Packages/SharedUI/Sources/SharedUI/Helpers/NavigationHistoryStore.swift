import Core
import Foundation

struct NavigationHistoryStore {
    private var navigationHistory: [NavigationHistoryEntry] = []
    private var currentHistoryIndex: Int = -1
    private let maxHistorySize: Int

    init(maxHistorySize: Int = 50) {
        self.maxHistorySize = maxHistorySize
    }

    var currentHistoryEntry: NavigationHistoryEntry? {
        guard currentHistoryIndex >= 0 && currentHistoryIndex < navigationHistory.count else { return nil }
        return navigationHistory[currentHistoryIndex]
    }

    var canNavigateBack: Bool {
        currentHistoryIndex > 0
    }

    var canNavigateForward: Bool {
        currentHistoryIndex < navigationHistory.count - 1
    }

    var recentHistory: [NavigationHistoryEntry] {
        Array(navigationHistory.reversed().prefix(10))
    }

    var backNavigationEntry: NavigationHistoryEntry? {
        guard canNavigateBack else { return nil }
        return navigationHistory[currentHistoryIndex - 1]
    }

    var forwardNavigationEntry: NavigationHistoryEntry? {
        guard canNavigateForward else { return nil }
        return navigationHistory[currentHistoryIndex + 1]
    }

    var latestEntry: NavigationHistoryEntry? {
        navigationHistory.last
    }

    mutating func addToHistory(tab: AppTab, context: NavigationContext?, title: String? = nil) {
        let entry = NavigationHistoryEntry(tab: tab, context: context, title: title)

        guard currentHistoryEntry != entry else { return }

        if currentHistoryIndex < navigationHistory.count - 1 {
            navigationHistory.removeSubrange((currentHistoryIndex + 1)...)
        }

        navigationHistory.append(entry)
        currentHistoryIndex = navigationHistory.count - 1

        if navigationHistory.count > maxHistorySize {
            navigationHistory.removeFirst()
            currentHistoryIndex -= 1
        }
    }

    /// Rewrites entry at cursor (sidebar / ⌘1–6). Drops forward branch. Does not grow stack depth.
    mutating func replaceCurrentEntry(tab: AppTab, context: NavigationContext?, title: String? = nil) {
        let entry = NavigationHistoryEntry(tab: tab, context: context, title: title)
        if currentHistoryIndex < navigationHistory.count - 1 {
            navigationHistory.removeSubrange((currentHistoryIndex + 1)...)
        }
        if currentHistoryIndex >= 0, currentHistoryIndex < navigationHistory.count {
            if navigationHistory[currentHistoryIndex] == entry { return }
            navigationHistory[currentHistoryIndex] = entry
        } else {
            navigationHistory.append(entry)
            currentHistoryIndex = navigationHistory.count - 1
        }

        if navigationHistory.count > maxHistorySize {
            navigationHistory.removeFirst()
            currentHistoryIndex -= 1
        }
    }

    mutating func navigateBack() -> NavigationHistoryEntry? {
        guard canNavigateBack else { return nil }
        currentHistoryIndex -= 1
        return navigationHistory[currentHistoryIndex]
    }

    mutating func navigateForward() -> NavigationHistoryEntry? {
        guard canNavigateForward else { return nil }
        currentHistoryIndex += 1
        return navigationHistory[currentHistoryIndex]
    }
}
