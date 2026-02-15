import Foundation

/// Represents a selected element within a DocumentGrid/Table component
enum TableElementSelection: Equatable, Hashable {
    /// A specific cell at the given row and column indices
    case cell(row: Int, column: Int)
    
    /// A rectangular range of cells
    case cellRange(rows: ClosedRange<Int>, columns: ClosedRange<Int>)
    
    /// An entire row at the given index
    case row(Int)
    
    /// An entire column at the given index
    case column(Int)
    
    /// The section title of the table
    case sectionTitle
    
    // MARK: - Convenience Properties
    
    /// Returns the row index if this is a cell or row selection
    var rowIndex: Int? {
        switch self {
        case .cell(let row, _): return row
        case .cellRange(let rows, _): return rows.lowerBound // Return first row for context
        case .row(let row): return row
        case .column, .sectionTitle: return nil
        }
    }
    
    /// Returns the column index if this is a cell or column selection
    var columnIndex: Int? {
        switch self {
        case .cell(_, let column): return column
        case .cellRange(_, let columns): return columns.lowerBound // Return first column for context
        case .column(let column): return column
        case .row, .sectionTitle: return nil
        }
    }
    
    /// Whether this selection affects a specific cell
    func affectsCell(row: Int, column: Int) -> Bool {
        switch self {
        case .cell(let r, let c): return r == row && c == column
        case .cellRange(let rows, let cols): return rows.contains(row) && cols.contains(column)
        case .row(let r): return r == row
        case .column(let c): return c == column
        case .sectionTitle: return false
        }
    }
    
    /// Display name for the selection type
    var displayName: String {
        switch self {
        case .cell(let row, let column): return "Cell (\(row + 1), \(column + 1))"
        case .cellRange(let rows, let cols): return "Cells R\(rows.lowerBound+1)-R\(rows.upperBound+1) : C\(cols.lowerBound+1)-C\(cols.upperBound+1)"
        case .row(let row): return "Row \(row + 1)"
        case .column(let column): return "Column \(column + 1)"
        case .sectionTitle: return "Section Title"
        }
    }
}
