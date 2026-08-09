//
//  Business.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import Core
import SwiftData


@Model public class Business {
    #Index<Business>([\.name], [\.email], [\.phone], [\.abn])
    public var abn: String = ""
    public var name: String = ""
    public var email: String = ""
    public var phone: String = ""
    public var id: UUID = UUID()
    public var logo: Data?
    public var bankAccountName: String?
    public var bankAccountNumber: String?
    public var bankBSB: String?
    public var bankName: String?
    public var accountingMethod: String = "Accrual"
    public var ndiaOrganisationID: String?
    public var isRegisteredProvider: Bool = false
    public var defaultGstCode: String = "P2"
    @Relationship(deleteRule: .cascade) public var address: Address?
    @Relationship(deleteRule: .nullify, inverse: \Invoice.business) public var invoices: [Invoice]?
    public init(id: UUID = UUID(), abn: String) {
        self.id = id
        self.abn = abn
    }
    
    /// Returns a thread-safe snapshot of the Business.
    public func snapshot() -> BusinessSnapshot {
        BusinessSnapshot(self)
    }
}
