import Core
import Foundation

extension Array where Element == Client {
    public func sorted(using order: ClientsSortOrder) -> [Client] {
        switch order {
        case .nameAsc:
            sorted { $0.fullName < $1.fullName }
        case .nameDesc:
            sorted { $0.fullName > $1.fullName }
        case .ndisAsc:
            sorted { $0.ndisNumber < $1.ndisNumber }
        case .ndisDesc:
            sorted { $0.ndisNumber > $1.ndisNumber }
        case .statusAsc:
            sorted { ($0.status?.rawValue ?? "") < ($1.status?.rawValue ?? "") }
        case .statusDesc:
            sorted { ($0.status?.rawValue ?? "") > ($1.status?.rawValue ?? "") }
        }
    }
}

extension Array where Element == ClientService {
    public func sorted(using order: ServicesSortOrder) -> [ClientService] {
        switch order {
        case .nameAsc:
            sorted { $0.serviceName < $1.serviceName }
        case .nameDesc:
            sorted { $0.serviceName > $1.serviceName }
        case .rateAsc:
            sorted { $0.rate < $1.rate }
        case .rateDesc:
            sorted { $0.rate > $1.rate }
        case .dateAddedAsc, .dateCreatedAsc:
            sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
        case .dateAddedDesc, .dateCreatedDesc:
            sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
        }
    }
}

extension Array where Element == Invoice {
    public func sorted(using order: InvoicesSortOrder) -> [Invoice] {
        switch order {
        case .dateAsc:
            sorted { $0.issueDate < $1.issueDate }
        case .dateDesc:
            sorted { $0.issueDate > $1.issueDate }
        case .dueDateAsc:
            sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }
        case .dueDateDesc:
            sorted { ($0.dueDate ?? .distantPast) > ($1.dueDate ?? .distantPast) }
        case .invoiceNumber, .numberAsc:
            sorted { $0.invoiceNumber < $1.invoiceNumber }
        case .amountAsc:
            sorted { $0.totalAmount < $1.totalAmount }
        case .amountDesc:
            sorted { $0.totalAmount > $1.totalAmount }
        case .clientName, .statusAsc:
            sorted { ($0.status?.rawValue ?? "") < ($1.status?.rawValue ?? "") }
        case .numberDesc:
            sorted { $0.invoiceNumber > $1.invoiceNumber }
        case .statusDesc:
            sorted { ($0.status?.rawValue ?? "") > ($1.status?.rawValue ?? "") }
        }
    }
}
