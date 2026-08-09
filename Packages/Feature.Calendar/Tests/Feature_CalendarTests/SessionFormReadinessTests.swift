import Testing
import Core
@testable import Feature_Calendar

@Suite(.tags(.integration))
struct SessionFormReadinessTests {
    @Test func readinessMessageExplainsEveryMissingRequiredField() {
        #expect(SessionFormReadiness.message(
            for: [.emptyTitle, .noClientSelected, .noServiceSelected]
        ) == "To save, add a title, select a client, and select a service.")
    }

    @Test func readinessMessageUsesNaturalGrammarAndClearsWhenReady() {
        #expect(SessionFormReadiness.message(for: [.noClientSelected, .noServiceSelected]) == "To save, select a client and select a service.")
        #expect(SessionFormReadiness.message(for: [.invalidTimeRange]) == "To save, set an end time after the start.")
        #expect(SessionFormReadiness.message(for: []) == nil)
    }

    @Test func completedGuidanceConnectsCalendarToBillingHubAndTravel() {
        let message = CalendarSessionStatusGuidance.message(
            for: .completed, isInvoiced: false)
        #expect(message.contains("Billing Hub"))
        #expect(message.contains("travel"))
    }

    @Test func billingManagedStatusesAreReadOnlyInCalendarEditor() {
        #expect(!(CalendarSessionStatusGuidance.isBillingManaged(.scheduled)))
        #expect(!(CalendarSessionStatusGuidance.isBillingManaged(.completed)))
        #expect(CalendarSessionStatusGuidance.isBillingManaged(.grouped))
        #expect(CalendarSessionStatusGuidance.isBillingManaged(.needsTravel))
        #expect(CalendarSessionStatusGuidance.isBillingManaged(.reviewDraft))
        #expect(CalendarSessionStatusGuidance.isBillingManaged(.readyToSend))
        #expect(CalendarSessionStatusGuidance.isBillingManaged(.pending))
        #expect(CalendarSessionStatusGuidance.isBillingManaged(.received))
    }
}
