import XCTest
@testable import Feature_InvoiceTemplateEditor

final class TableEngineTests: XCTestCase {
    
    func testSparseMatrixInitialization() {
        let doc = TableDocument(rowCount: 3, colCount: 3)
        XCTAssertEqual(doc.cells.count, 9)
        XCTAssertEqual(doc.spanIndex.count, 9)
        
        let cell = doc.cell(at: GridCoordinate(row: 1, column: 1))
        XCTAssertNotNil(cell)
        XCTAssertEqual(cell?.coordinate, GridCoordinate(row: 1, column: 1))
    }
    
    func testMerge() {
        let doc = TableDocument(rowCount: 3, colCount: 3)
        let selection: Set<GridCoordinate> = [
            GridCoordinate(row: 0, column: 0),
            GridCoordinate(row: 0, column: 1),
            GridCoordinate(row: 1, column: 0),
            GridCoordinate(row: 1, column: 1)
        ]
        
        doc.merge(selection: selection)
        
        // Check anchor
        let anchor = doc.cell(at: GridCoordinate(row: 0, column: 0))
        XCTAssertNotNil(anchor)
        XCTAssertEqual(anchor?.span.rowSpan, 2)
        XCTAssertEqual(anchor?.span.colSpan, 2)
        
        // Check merged cells
        let mergedCell = doc.cell(at: GridCoordinate(row: 1, column: 1))
        XCTAssertEqual(mergedCell?.id, anchor?.id)
        
        // Check sparse storage
        XCTAssertNil(doc.cells[GridCoordinate(row: 1, column: 1)])
        XCTAssertNotNil(doc.cells[GridCoordinate(row: 0, column: 0)])
    }
    
    func testSplit() {
        let doc = TableDocument(rowCount: 3, colCount: 3)
        let selection: Set<GridCoordinate> = [
            GridCoordinate(row: 0, column: 0),
            GridCoordinate(row: 0, column: 1)
        ]
        doc.merge(selection: selection)
        
        guard let anchor = doc.cell(at: GridCoordinate(row: 0, column: 0)) else {
            XCTFail("Anchor not found")
            return
        }
        
        doc.split(cell: anchor)
        
        let cell1 = doc.cell(at: GridCoordinate(row: 0, column: 0))
        let cell2 = doc.cell(at: GridCoordinate(row: 0, column: 1))
        
        XCTAssertEqual(cell1?.span.colSpan, 1)
        XCTAssertEqual(cell2?.span.colSpan, 1)
        XCTAssertNotEqual(cell1?.id, cell2?.id)
    }
    
    func testInsertRow() {
        let doc = TableDocument(rowCount: 2, colCount: 2)
        doc.updateContent(for: GridCoordinate(row: 1, column: 0), content: RichTextContent(string: "Bottom"))
        
        doc.insertRow(at: 1)
        
        XCTAssertEqual(doc.rowCount, 3)
        
        // Check shifted content
        let shiftedCell = doc.cell(at: GridCoordinate(row: 2, column: 0))
        XCTAssertEqual(shiftedCell?.content.storage.string, "Bottom")
        
        // Check new row
        let newCell = doc.cell(at: GridCoordinate(row: 1, column: 0))
        XCTAssertEqual(newCell?.content.storage.string, "")
    }
    
    func testRichTextContent() {
        let content = RichTextContent(string: "Hello")
        XCTAssertEqual(content.storage.string, "Hello")
        
        // Test Codable (basic check)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(content)
            let decoded = try decoder.decode(RichTextContent.self, from: data)
            XCTAssertEqual(decoded.storage.string, "Hello")
        } catch {
            XCTFail("Codable failed: \(error)")
        }
    }
    
    func testMergeConsolidatesContent() {
        let doc = TableDocument(rowCount: 2, colCount: 2)
        doc.updateContent(for: GridCoordinate(row: 0, column: 0), content: RichTextContent(string: "A"))
        doc.updateContent(for: GridCoordinate(row: 0, column: 1), content: RichTextContent(string: "B"))
        
        doc.merge(selection: [
            GridCoordinate(row: 0, column: 0),
            GridCoordinate(row: 0, column: 1)
        ])
        
        let anchor = doc.cell(at: GridCoordinate(row: 0, column: 0))
        XCTAssertEqual(anchor?.content.storage.string, "A\nB")
    }
}
