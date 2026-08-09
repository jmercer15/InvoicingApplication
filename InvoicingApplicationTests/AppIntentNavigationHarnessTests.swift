import Foundation
import SharedUI
import Core
import Testing

extension Tag {
    @Tag static var integration: Self
}

/// Host-app harness validating workspace routing surfaces used by App Intents.
@MainActor
@Suite(.tags(.integration))
struct AppIntentNavigationHarnessTests {
    @Test func openClientRoutingSelectsRelationshipsTab() {
        let navigationManager = AppNavigationManager()
        let clientID = UUID()

        navigationManager.applyRoutingIntent(.selectTab(.relationships), onCreateInvoice: {}, onCreateSession: {})
        navigationManager.navigationContext = NavigationContext(
            targetEntity: clientID,
            targetEntityType: .client
        )

        #expect(navigationManager.selectedTab == .relationships)
        #expect(navigationManager.navigationContext?.targetEntity == clientID)
    }

    @Test func openTabRoutingSelectsCalendar() {
        let navigationManager = AppNavigationManager()

        navigationManager.applyRoutingIntent(.selectTab(.calendar), onCreateInvoice: {}, onCreateSession: {})

        #expect(navigationManager.selectedTab == .calendar)
    }
}
