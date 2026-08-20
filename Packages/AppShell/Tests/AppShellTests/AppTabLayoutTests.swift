import Core
import CoreTesting
import Testing
@testable import AppShell

@Suite(.tags(.unit))
struct AppTabLayoutTests {
    @Test func invoicesPrioritizeEditorWhileKeepingListMetadataReadable() {
        let profile = AppTab.invoices.widthProfile

        #expect(profile.content?.min == 300)
        #expect(profile.content?.ideal == 380)
        #expect(profile.content?.max == 460)
        #expect(profile.detail.min == 520)
        #expect(profile.detail.ideal == 900)
        #expect(profile.detail.max == nil)
    }

    @Test func invoiceWidthsRemainIndependentFromRelationships() {
        let invoices = AppTab.invoices.widthProfile
        let relationships = AppTab.relationships.widthProfile

        #expect(invoices.content?.ideal != relationships.content?.ideal)
        #expect(invoices.detail.ideal != relationships.detail.ideal)
    }
}
