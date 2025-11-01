//
//  ModelEnums.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 1/10/2025.
//
//

import Foundation

// MARK: - Client Status
public enum ClientStatus: String, CaseIterable, Codable {
    case active = "Active"
    case inactive = "Inactive"
    case suspended = "Suspended"
    case archived = "Archived"
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var color: String {
        switch self {
        case .active: return "green"
        case .inactive: return "orange"
        case .suspended: return "red"
        case .archived: return "gray"
        }
    }
}

// MARK: - Invoice Status
public enum InvoiceStatus: String, CaseIterable, Codable {
    case draft = "Draft"
    case sent = "Sent"
    case paid = "Paid"
    case overdue = "Overdue"
    case cancelled = "Cancelled"
    case voided = "Voided"
    case ready = "Ready"
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var color: String {
        switch self {
        case .draft: return "gray"
        case .sent: return "blue"
        case .paid: return "green"
        case .overdue: return "red"
        case .cancelled: return "orange"
        case .voided: return "purple"
        case .ready: return "yellow"
        }
    }
}

// MARK: - Session Status
public enum SessionStatus: String, CaseIterable, Codable {
    case scheduled = "Scheduled"
    case completed = "Completed"
    case cancelled = "Cancelled"
    case noShow = "No Show"
    case rescheduled = "Rescheduled"
    case grouped = "Grouped"
    case needsServices = "Needs Services"
    case needsTravel = "Needs Travel"
    case reviewDraft = "Review Draft"
    case readyToSend = "Ready To Send"
    case pending = "Pending"
    case received = "Received"
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var color: String {
        switch self {
        case .scheduled: return "blue"
        case .completed: return "green"
        case .cancelled: return "red"
        case .noShow: return "orange"
        case .rescheduled: return "yellow"
        case .grouped: return "indigo"
        case .needsServices: return "yellow"
        case .needsTravel: return "cyan"
        case .reviewDraft: return "orange"
        case .readyToSend: return "blue"
        case .pending: return "gray"
        case .received: return "green"
        }
    }
}

// MARK: - NDIS Claim Type
public enum NDISClaimType: String, CaseIterable, Codable {
    case direct = "Direct"
    case providerTravel = "ProviderTravel"
    case cancellation = "Cancellation"
    case prepayment = "Prepayment"
    case telehealth = "Telehealth"
    case nonFaceToFace = "NonFaceToFace"
    case ndiaReport = "NDIAReport"
    case irregularSILSupport = "IrregularSILSupport"
    case bereavement = "Bereavement"
    
    public var displayName: String {
        switch self {
        case .direct: return "Direct Support"
        case .providerTravel: return "Provider Travel"
        case .cancellation: return "Cancellation Fee"
        case .prepayment: return "Prepayment"
        case .telehealth: return "Telehealth"
        case .nonFaceToFace: return "Non-Face-to-Face"
        case .ndiaReport: return "NDIA Report"
        case .irregularSILSupport: return "Irregular SIL Support"
        case .bereavement: return "Bereavement Support"
        }
    }
}

// MARK: - Travel Charge Type
public enum TravelChargeType: String, CaseIterable, Codable {
    case standard = "Standard"
    case tolls = "Tolls"
    case parking = "Parking"
    case fuel = "Fuel"
    case maintenance = "Maintenance"
    case insurance = "Insurance"
    
    public var displayName: String {
        return self.rawValue
    }
}

// MARK: - Vehicle Type
public enum VehicleType: String, CaseIterable, Codable {
    case car = "Car"
    case motorcycle = "Motorcycle"
    case bicycle = "Bicycle"
    case publicTransport = "Public Transport"
    case taxi = "Taxi"
    case rideshare = "Rideshare"
    case walking = "Walking"
    
    public var displayName: String {
        return self.rawValue
    }
}

// MARK: - Travel Direction
public enum TravelChargeDirection: String, CaseIterable, Codable {
    case toClient = "To Client"
    case fromClient = "From Client"
    case roundTrip = "Round Trip"
    case betweenClients = "Between Clients"
    
    public var displayName: String {
        return self.rawValue
    }
}

// MARK: - Billing Authority
public enum BillingAuthority: String, CaseIterable, Codable {
    case client = "Client"
    case parentGuardian = "Parent/Guardian"
    case planManager = "Plan Manager"
    case ndia = "NDIA"
    
    public var displayName: String {
        return self.rawValue
    }
}

// MARK: - Credit History Type
public enum CreditHistoryType: String, CaseIterable, Codable {
    case credit = "Credit"
    case refund = "Refund"
    case adjustment = "Adjustment"
    case writeOff = "Write Off"
    case payment = "Payment"
    case creditNote = "Credit Note"
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var color: String {
        switch self {
        case .credit: return "green"
        case .refund: return "blue"
        case .adjustment: return "orange"
        case .writeOff: return "red"
        case .payment: return "purple"
        case .creditNote: return "cyan"
        }
    }
}

// MARK: - Address Validation Status
public enum AddressValidationStatus: String, CaseIterable, Codable {
    case unvalidated = "unvalidated"
    case pending = "pending"
    case valid = "valid"
    case failed = "failed"
    
    public var displayName: String {
        switch self {
        case .unvalidated: return "Not Validated"
        case .pending: return "Validating..."
        case .valid: return "Valid"
        case .failed: return "Validation Failed"
        }
    }
    
    public var icon: String {
        switch self {
        case .unvalidated: return "questionmark.circle"
        case .pending: return "clock"
        case .valid: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
    
    public var color: String {
        switch self {
        case .unvalidated: return "gray"
        case .pending: return "blue"
        case .valid: return "green"
        case .failed: return "red"
        }
    }
}