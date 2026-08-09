@testable import Data
import Core
import Foundation
import Testing
import PersistenceModels
@Suite struct NDISItemImportParserTests {
    @Test func ParsesSimpleItemArray() throws {
        let json = """
        [
          {
            "itemNumber": "01_001_0101_1_1",
            "description": "Assistance with self-care",
            "rate": "$12.50",
            "unit": "hr",
            "category": "Core"
          }
        ]
        """
        let data = try try #require(json.data(using: .utf8))
        var messages: [String] = []

        let items = try NDISItemImportParser.parse(data: data, messages: &messages)

        #expect(items.count == 1)
        #expect(messages == [])
        #expect(items[0].itemNumber == "01_001_0101_1_1")
        #expect(items[0].name == "Assistance with self-care")
        #expect(items[0].unit == "Hour")
        #expect(items[0].category == "Core")
        #expect(items[0].regionalPricesData?["NATIONAL"] == 12.50)
        #expect(items[0].effectiveStartDate != nil)
        #expect(items[0].effectiveEndDate == nil)
    }

    @Test func ParsesCatalogueItemsAndSkipsRowsWithoutItemNumber() throws {
        let payload: [String: Any] = [
            "Current Support Items": [
                [
                    "Support Item": [
                        "Number": "04_104_0125_6_1",
                        "Name": "Community participation",
                        "Description": "Participate in community activities",
                        "Unit": "day"
                    ],
                    "Category Info": [
                        "Registration Group": ["Name": "Innovative Community Participation"],
                        "Support Category": ["Name": "Social and Community Participation"]
                    ],
                    "Prices": [
                        "ACT": 15.0,
                        "QLD": "$20.50"
                    ],
                    "Metadata": [
                        "Provider Travel": "Y",
                        "NDIA Requested Reports": "Y",
                        "effectiveStartDate": "01/07/2025",
                        "effectiveEndDate": "30/06/2026"
                    ],
                    "Quote Info": [
                        "Quote Required": true
                    ]
                ],
                [
                    "Support Item": [
                        "Name": "Missing number"
                    ]
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        var messages: [String] = []

        let items = try NDISItemImportParser.parse(data: data, messages: &messages)

        #expect(items.count == 1)
        #expect(messages == ["Skipped item: Missing or empty Support Item Number."])

        let item = try try #require(items.first)
        #expect(item.itemNumber == "04_104_0125_6_1")
        #expect(item.name == "Community participation")
        #expect(item.description == "Participate in community activities")
        #expect(item.unit == "Day")
        #expect(item.category == "Social and Community Participation")
        #expect(item.registrationGroup == "Innovative Community Participation")
        #expect(Set(item.features) == ["Provider Travel", "NDIA Requested Reports"])
        #expect(item.quoteRequired == true)
        #expect(item.regionalPricesData?["ACT"] == 15.0)
        #expect(item.regionalPricesData?["QLD"] == 20.50)
        #expect(item.effectiveStartDate == date("2025-07-01"))
        #expect(item.effectiveEndDate == date("2026-06-30"))
    }

    @Test func DateParserSupportsLegacyImportFormats() {
        #expect(NDISItemImportDateParser.parseDate("01/07/2025") == date("2025-07-01"))
        #expect(NDISItemImportDateParser.parseDate("01-07-2025") == date("2025-07-01"))
        #expect(NDISItemImportDateParser.parseDate("2025-07-01") == date("2025-07-01"))
    }

    private func date(_ isoDate: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: isoDate)!
    }
}
