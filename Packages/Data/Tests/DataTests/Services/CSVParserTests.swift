@testable import Data
import Testing
import PersistenceModels
@Suite struct CSVParserTests {
    @Test func ParsesQuotedValuesWithEmbeddedCommasAndNewlines() throws {
        let parser = CSVParser()
        let csv = """
Support Item Number,Support Item Name,Description,Quote
"12345","Community, participation","Line 1
Line 2","yes"
"""
        
        let rows = try parser.parse(content: csv)
        
        #expect(rows.count == 1)
        #expect(rows[0]["Support Item Number"] == "12345")
        #expect(rows[0]["Support Item Name"] == "Community, participation")
        #expect(rows[0]["Description"] == "Line 1\nLine 2")
        #expect(rows[0]["Quote"] == "yes")
    }
    
    @Test func SupportsTabSeparatedValues() throws {
        let parser = CSVParser()
        let tabContent = "Item\tName\tUnit\n\"01\"\t\"Service\tname\"\t\"Hour\"\n"
        
        let rows = try parser.parse(content: tabContent, fieldSeparator: "\t")
        
        #expect(rows.count == 1)
        #expect(rows[0]["Name"] == "Service\tname")
        #expect(rows[0]["Unit"] == "Hour")
    }
    
    @Test func RejectsMalformedRows() throws {
        let parser = CSVParser()
        let csv = "A,B,C\n1,2"

        do {
            _ = try parser.parse(content: csv)
            Issue.record("Expected malformed row error")
        } catch let error as CSVParser.CSVParseError {
            guard case .malformedRow(let expected, let actual) = error else {
                Issue.record("Expected malformed row error")
                return
            }
            #expect(expected == 3)
            #expect(actual == 2)
        }
    }
}
