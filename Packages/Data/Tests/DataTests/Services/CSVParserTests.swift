@testable import Data
import XCTest

final class CSVParserTests: XCTestCase {
    func testParsesQuotedValuesWithEmbeddedCommasAndNewlines() throws {
        let parser = CSVParser()
        let csv = """
Support Item Number,Support Item Name,Description,Quote
"12345","Community, participation","Line 1
Line 2","yes"
"""
        
        let rows = try parser.parse(content: csv)
        
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0]["Support Item Number"], "12345")
        XCTAssertEqual(rows[0]["Support Item Name"], "Community, participation")
        XCTAssertEqual(rows[0]["Description"], "Line 1\nLine 2")
        XCTAssertEqual(rows[0]["Quote"], "yes")
    }
    
    func testSupportsTabSeparatedValues() throws {
        let parser = CSVParser()
        let tabContent = "Item\tName\tUnit\n\"01\"\t\"Service\tname\"\t\"Hour\"\n"
        
        let rows = try parser.parse(content: tabContent, fieldSeparator: "\t")
        
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0]["Name"], "Service\tname")
        XCTAssertEqual(rows[0]["Unit"], "Hour")
    }
    
    func testRejectsMalformedRows() throws {
        let parser = CSVParser()
        let csv = "A,B,C\n1,2"
        
        XCTAssertThrowsError(try parser.parse(content: csv)) { error in
            guard case .malformedRow(let expected, let actual) = error as? CSVParser.CSVParseError else {
                return XCTFail("Expected malformed row error")
            }
            XCTAssertEqual(expected, 3)
            XCTAssertEqual(actual, 2)
        }
    }
}
