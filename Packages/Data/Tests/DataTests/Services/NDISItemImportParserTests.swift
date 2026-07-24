@testable import Data
import Core
import XCTest

final class NDISItemImportParserTests: XCTestCase {
    func testParsesSimpleItemArray() throws {
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
        let data = try XCTUnwrap(json.data(using: .utf8))
        var messages: [String] = []

        let items = try NDISItemImportParser.parse(data: data, messages: &messages)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(messages, [])
        XCTAssertEqual(items[0].itemNumber, "01_001_0101_1_1")
        XCTAssertEqual(items[0].name, "Assistance with self-care")
        XCTAssertEqual(items[0].unit, "Hour")
        XCTAssertEqual(items[0].category, "Core")
        XCTAssertEqual(items[0].regionalPricesData?["NATIONAL"], 12.50)
        XCTAssertNotNil(items[0].effectiveStartDate)
        XCTAssertNil(items[0].effectiveEndDate)
    }

    func testParsesCatalogueItemsAndSkipsRowsWithoutItemNumber() throws {
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

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(messages, ["Skipped item: Missing or empty Support Item Number."])

        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.itemNumber, "04_104_0125_6_1")
        XCTAssertEqual(item.name, "Community participation")
        XCTAssertEqual(item.description, "Participate in community activities")
        XCTAssertEqual(item.unit, "Day")
        XCTAssertEqual(item.category, "Social and Community Participation")
        XCTAssertEqual(item.registrationGroup, "Innovative Community Participation")
        XCTAssertEqual(Set(item.features), ["Provider Travel", "NDIA Requested Reports"])
        XCTAssertEqual(item.quoteRequired, true)
        XCTAssertEqual(item.regionalPricesData?["ACT"], 15.0)
        XCTAssertEqual(item.regionalPricesData?["QLD"], 20.50)
        XCTAssertEqual(item.effectiveStartDate, date("2025-07-01"))
        XCTAssertEqual(item.effectiveEndDate, date("2026-06-30"))
    }

    func testDateParserSupportsLegacyImportFormats() {
        XCTAssertEqual(NDISItemImportDateParser.parseDate("01/07/2025"), date("2025-07-01"))
        XCTAssertEqual(NDISItemImportDateParser.parseDate("01-07-2025"), date("2025-07-01"))
        XCTAssertEqual(NDISItemImportDateParser.parseDate("2025-07-01"), date("2025-07-01"))
    }

    private func date(_ isoDate: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: isoDate)!
    }
}
