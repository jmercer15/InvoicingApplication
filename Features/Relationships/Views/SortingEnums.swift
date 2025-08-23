import Foundation

// MARK: - Services Sort Order
enum ServicesSortOrder: String, CaseIterable {
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
    case rateAsc = "Rate (Low-High)"
    case rateDesc = "Rate (High-Low)"
    case dateAddedAsc = "Date Added (Old-New)"
    case dateAddedDesc = "Date Added (New-Old)"
    case dateCreatedAsc = "Date Created (Old-New)"
    case dateCreatedDesc = "Date Created (New-Old)"
    
    var displayName: String { rawValue }
}

// MARK: - Clients Sort Order
enum ClientsSortOrder: String, CaseIterable {
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
    case ndisAsc = "NDIS Number (A-Z)"
    case ndisDesc = "NDIS Number (Z-A)"
    case statusAsc = "Status (A-Z)"
    case statusDesc = "Status (Z-A)"
    
    var displayName: String { rawValue }
}

// MARK: - Invoices Sort Order
enum InvoicesSortOrder: String, CaseIterable {
    case dateDesc = "Date (New-Old)"
    case dateAsc = "Date (Old-New)"
    case numberDesc = "Number (High-Low)"
    case numberAsc = "Number (Low-High)"
    case amountDesc = "Amount (High-Low)"
    case amountAsc = "Amount (Low-High)"
    case statusAsc = "Status (A-Z)"
    case statusDesc = "Status (Z-A)"
    
    var displayName: String { rawValue }
}
