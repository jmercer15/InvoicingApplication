import Foundation
import Testing
import CoreTesting
@testable import SharedUI
import Core

@Suite(.tags(.unit))
struct CurrencyFormattingTests {
    @Test func displayFormatsAUDCurrency() {
        let formatted = CurrencyFormatting.display(123.45, code: "AUD", locale: Locale(identifier: "en_AU"))
        #expect(formatted.contains("123"))
        #expect(formatted.contains("45") || formatted.contains("4"))
    }

    @Test func editableAmountUsesFixedFractionDigits() {
        #expect(CurrencyFormatting.editableAmount(10.5) == "10.50")
        #expect(CurrencyFormatting.editableAmount(10.0) == "10.00")
    }

    @Test(arguments: [
        (12.3, "12.3 km"),
        (45.0, "45 min"),
        (1.5, "1.5h"),
    ])
    func measurementFormattingAppendsUnits(input: (Double, String)) {
        let (value, expectedSuffix) = input
        if expectedSuffix.hasSuffix("km") {
            #expect(MeasurementFormatting.kilometers(value) == expectedSuffix)
        } else if expectedSuffix.hasSuffix("min") {
            #expect(MeasurementFormatting.minutes(value) == expectedSuffix)
        } else {
            #expect(MeasurementFormatting.hoursShort(value) == expectedSuffix)
        }
    }

    @Test func dateFormattingUsesLocaleAwareStyles() {
        let date = Date(timeIntervalSince1970: 1_718_121_600) // 2024-06-12 UTC
        let locale = Locale(identifier: "en_AU")
        let short = DateFormatting.shortDate(date, locale: locale)
        let medium = DateFormatting.mediumDate(date, locale: locale)
        let mediumDateTime = DateFormatting.mediumDateTime(date, locale: locale)
        #expect(!short.isEmpty)
        #expect(!medium.isEmpty)
        #expect(!mediumDateTime.isEmpty)
        #expect(mediumDateTime.contains(medium) || mediumDateTime.count >= medium.count)
        #expect(short != medium || short.contains("2024"))
    }

    @Test func machineFormattingUsesFixedPatterns() throws {
        var components = DateComponents()
        components.year = 2024
        components.month = 6
        components.day = 11
        components.hour = 16
        components.minute = 0
        components.second = 0
        let calendar = Calendar(identifier: .gregorian)
        let date = try #require(calendar.date(from: components))
        #expect(MachineFormatting.exportTimestamp(date) == "2024-06-11-160000")
        #expect(MachineFormatting.bprExportTimestamp(date) == "20240611_160000")
        #expect(ExportMachineFormatting.exportDate(date) == "2024-06-11")
        #expect(ExportMachineFormatting.claimHoursToken(fromHourQuantity: 1.5) == "001:30")
    }
}
