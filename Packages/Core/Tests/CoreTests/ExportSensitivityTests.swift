import Core
import Testing

@Suite(.tags(.unit))
struct ExportSensitivityTests {
    @Test(arguments: [
        ImportSource.clients,
        .payees,
        .services,
        .invoices,
        .sessions,
        .allData,
    ])
    func piiHeavySourcesRequireConsent(_ source: ImportSource) {
        #expect(ExportSensitivity.requiresConsent(for: source))
        #expect(ExportSensitivity.level(for: source) == .piiHeavy)
    }

    @Test func ndisCatalogueExportSkipsConsent() {
        #expect(!ExportSensitivity.requiresConsent(for: .ndisItems))
        #expect(ExportSensitivity.level(for: .ndisItems) == .reference)
    }

    @Test func consentCopyMentionsRedactionPreset() {
        let message = ExportSensitivity.consentMessage(
            for: .allData, preset: .omitBankAndNDISIdentifiers)
        #expect(message.contains("Omit bank & NDIS IDs"))
        #expect(message.contains("bank account fields"))
    }
}

struct ExportRedactionPresetTests {
    @Test func presetSummariesAreNonEmpty() {
        for preset in ExportRedactionPreset.allCases {
            #expect(!preset.displayName.isEmpty)
            #expect(!preset.summary.isEmpty)
        }
    }
}
