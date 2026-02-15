import Foundation
import SwiftData

// Protocol for dependency injection container
// This allows feature packages to reference the app assembly without creating a circular dependency

@MainActor
public protocol AppAssemblyProviding: AnyObject, ObservableObject {
    // MARK: - Core Dependencies
    var unitOfWork: UnitOfWorkService { get }
    
    // MARK: - Domain Services
    var sessionDomainService: SessionDomainServiceProtocol { get }
    var invoiceDomainService: InvoiceDomainServiceProtocol { get }
    var ndisDomainService: NDISBillingDomainServiceProtocol { get }
    
    // MARK: - Model Container
    var modelContainer: ModelContainer { get }
}

