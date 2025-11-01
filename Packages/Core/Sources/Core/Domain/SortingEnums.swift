import Foundation

// MARK: - Sort Field and Direction Enums
public enum SortField: String, CaseIterable, Identifiable {
    case date = "Date"
    case dueDate = "Due Date"
    case amount = "Amount"
    case clientName = "Client Name"
    case invoiceNumber = "Invoice Number"
    public var id: String { self.rawValue }
}

public enum SortDirection: String, CaseIterable, Identifiable {
    case ascending = "Ascending"
    case descending = "Descending"
    public var id: String { self.rawValue }
    
    public var displayName: String {
        switch self {
        case .ascending: return "arrow.up"
        case .descending: return "arrow.down"
        }
    }
}

// MARK: - Services Sort Order
public enum ServicesSortOrder: String, CaseIterable {
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
    case rateAsc = "Rate (Low-High)"
    case rateDesc = "Rate (High-Low)"
    case dateAddedAsc = "Date Added (Old-New)"
    case dateAddedDesc = "Date Added (New-Old)"
    case dateCreatedAsc = "Date Created (Old-New)"
    case dateCreatedDesc = "Date Created (New-Old)"
    
    public var displayName: String { rawValue }
}

// MARK: - Clients Sort Order
public enum ClientsSortOrder: String, CaseIterable {
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
    case ndisAsc = "NDIS Number (A-Z)"
    case ndisDesc = "NDIS Number (Z-A)"
    case statusAsc = "Status (A-Z)"
    case statusDesc = "Status (Z-A)"
    
    public var displayName: String { rawValue }
}

// MARK: - Invoices Sort Order
public enum InvoicesSortOrder: String, CaseIterable, Identifiable {
    
    case dateAsc = "Date (Oldest First)"
    case dateDesc = "Date (Newest First)"
    case dueDateAsc = "Due Date (Ascending)"
    case dueDateDesc = "Due Date (Descending)"
    case amountDesc = "Amount (Highest First)"
    case amountAsc = "Amount (Lowest First)"
    case clientName = "Client Name"
    case invoiceNumber = "Invoice Number"
    
    // Legacy cases for backward compatibility
    case numberDesc = "Number (High-Low)"
    case numberAsc = "Number (Low-High)"
    case statusAsc = "Status (A-Z)"
    case statusDesc = "Status (Z-A)"
    
    public var id: String { self.rawValue }
    public var displayName: String { rawValue }
    
    public var sortField: SortField {
        switch self {
        case .dateDesc, .dateAsc: return .date
        case .dueDateAsc, .dueDateDesc: return .dueDate
        case .amountDesc, .amountAsc: return .amount
        case .clientName: return .clientName
        case .invoiceNumber, .numberDesc, .numberAsc: return .invoiceNumber
        case .statusAsc, .statusDesc: return .clientName // Map to clientName for status sorting
        }
    }
    
    public var sortDirection: SortDirection {
        switch self {
        case .dateDesc, .dueDateDesc, .amountDesc, .numberDesc, .statusDesc: return .descending
        case .dateAsc, .dueDateAsc, .amountAsc, .numberAsc, .statusAsc, .clientName, .invoiceNumber: return .ascending
        }
    }

    public var iconName: String {
        switch self {
        case .dateDesc, .dueDateDesc, .amountDesc, .numberDesc, .statusDesc: return "arrow.down"
        case .dateAsc, .dueDateAsc, .amountAsc, .numberAsc, .statusAsc: return "arrow.up"
        case .clientName, .invoiceNumber: return "arrow.up.arrow.down"
        }
    }
    
    public static func from(field: SortField, direction: SortDirection) -> InvoicesSortOrder {
        switch (field, direction) {
        case (.date, .ascending): return .dateAsc
        case (.date, .descending): return .dateDesc
        case (.dueDate, .ascending): return .dueDateAsc
        case (.dueDate, .descending): return .dueDateDesc
        case (.amount, .ascending): return .amountAsc
        case (.amount, .descending): return .amountDesc
        case (.clientName, .ascending): return .clientName
        case (.clientName, .descending): return .statusDesc // Map to legacy statusDesc
        case (.invoiceNumber, .ascending): return .invoiceNumber
        case (.invoiceNumber, .descending): return .numberDesc // Map to legacy numberDesc
        }
    }
}
