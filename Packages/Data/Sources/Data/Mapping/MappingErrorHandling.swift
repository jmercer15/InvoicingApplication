//
//  MappingErrorHandling.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//
//  Error handling patterns and utilities for mapping operations
//  This file provides consistent error handling patterns for all mapping operations
//  to ensure data integrity and provide meaningful error messages.
//

import Foundation

/// Errors that can occur during mapping operations
public enum MappingError: Error, LocalizedError {
    case invalidData(String)
    case missingRequiredProperty(String)
    case typeConversionFailed(String)
    case relationshipMappingFailed(String)
    case businessRuleViolation(String)
    case dataIntegrityViolation(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidData(let message):
            return "Invalid data during mapping: \(message)"
        case .missingRequiredProperty(let property):
            return "Missing required property: \(property)"
        case .typeConversionFailed(let message):
            return "Type conversion failed: \(message)"
        case .relationshipMappingFailed(let message):
            return "Relationship mapping failed: \(message)"
        case .businessRuleViolation(let message):
            return "Business rule violation: \(message)"
        case .dataIntegrityViolation(let message):
            return "Data integrity violation: \(message)"
        }
    }
}

/// Mapping validation utilities
public struct MappingValidator {
    
    /// Validate that a required string property is not empty
    /// - Parameters:
    ///   - value: The string value to validate
    ///   - propertyName: The name of the property for error reporting
    /// - Throws: MappingError.missingRequiredProperty if validation fails
    public static func validateRequiredString(_ value: String?, propertyName: String) throws {
        guard let value = value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MappingError.missingRequiredProperty(propertyName)
        }
    }
    
    /// Validate that a required UUID is not nil
    /// - Parameters:
    ///   - value: The UUID value to validate
    ///   - propertyName: The name of the property for error reporting
    /// - Throws: MappingError.missingRequiredProperty if validation fails
    public static func validateRequiredUUID(_ value: UUID?, propertyName: String) throws {
        guard value != nil else {
            throw MappingError.missingRequiredProperty(propertyName)
        }
    }
    
    /// Validate that a numeric value is within acceptable range
    /// - Parameters:
    ///   - value: The numeric value to validate
    ///   - min: Minimum allowed value
    ///   - max: Maximum allowed value
    ///   - propertyName: The name of the property for error reporting
    /// - Throws: MappingError.invalidData if validation fails
    public static func validateNumericRange(_ value: Double, min: Double, max: Double, propertyName: String) throws {
        guard value >= min && value <= max else {
            throw MappingError.invalidData("\(propertyName) value \(value) is outside acceptable range [\(min), \(max)]")
        }
    }
    
    /// Validate that a date is not in the future
    /// - Parameters:
    ///   - date: The date to validate
    ///   - propertyName: The name of the property for error reporting
    /// - Throws: MappingError.invalidData if validation fails
    public static func validateDateNotInFuture(_ date: Date?, propertyName: String) throws {
        guard let date = date else { return }
        guard date <= Date() else {
            throw MappingError.invalidData("\(propertyName) date \(date) is in the future")
        }
    }
    
    /// Validate that a date is not before a certain date
    /// - Parameters:
    ///   - date: The date to validate
    ///   - beforeDate: The date that the validated date should not be before
    ///   - propertyName: The name of the property for error reporting
    /// - Throws: MappingError.invalidData if validation fails
    public static func validateDateNotBefore(_ date: Date?, beforeDate: Date, propertyName: String) throws {
        guard let date = date else { return }
        guard date >= beforeDate else {
            throw MappingError.invalidData("\(propertyName) date \(date) is before \(beforeDate)")
        }
    }
    
    /// Validate that an email address has a valid format
    /// - Parameters:
    ///   - email: The email address to validate
    ///   - propertyName: The name of the property for error reporting
    /// - Throws: MappingError.invalidData if validation fails
    public static func validateEmailFormat(_ email: String?, propertyName: String) throws {
        guard let email = email, !email.isEmpty else { return }
        
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        guard emailPredicate.evaluate(with: email) else {
            throw MappingError.invalidData("\(propertyName) email '\(email)' has invalid format")
        }
    }
    
    /// Validate that a phone number has a valid format
    /// - Parameters:
    ///   - phone: The phone number to validate
    ///   - propertyName: The name of the property for error reporting
    /// - Throws: MappingError.invalidData if validation fails
    public static func validatePhoneFormat(_ phone: String?, propertyName: String) throws {
        guard let phone = phone, !phone.isEmpty else { return }
        
        // Remove all non-digit characters for validation
        let digitsOnly = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // Australian phone numbers should have 10 digits (mobile) or 8 digits (landline)
        guard digitsOnly.count == 10 || digitsOnly.count == 8 else {
            throw MappingError.invalidData("\(propertyName) phone '\(phone)' has invalid format")
        }
    }
    
    /// Validate that a status value is one of the allowed values
    /// - Parameters:
    ///   - status: The status value to validate
    ///   - allowedValues: Array of allowed status values
    ///   - propertyName: The name of the property for error reporting
    /// - Throws: MappingError.invalidData if validation fails
    public static func validateStatus(_ status: String?, allowedValues: [String], propertyName: String) throws {
        guard let status = status, !status.isEmpty else { return }
        
        guard allowedValues.contains(status) else {
            throw MappingError.invalidData("\(propertyName) status '\(status)' is not one of the allowed values: \(allowedValues.joined(separator: ", "))")
        }
    }
}

/// Mapping logging utilities
public struct MappingLogger {
    
    /// Log a mapping operation
    /// - Parameters:
    ///   - operation: The mapping operation being performed
    ///   - entityType: The type of entity being mapped
    ///   - domainType: The type of domain model being created
    public static func logMapping(_ operation: String, entityType: String, domainType: String) {
        print("🔄 Mapping: \(operation) from \(entityType) to \(domainType)")
    }
    
    /// Log a mapping error
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - entityType: The type of entity being mapped
    ///   - domainType: The type of domain model being created
    public static func logMappingError(_ error: Error, entityType: String, domainType: String) {
        print("❌ Mapping Error: \(error.localizedDescription) when mapping from \(entityType) to \(domainType)")
    }
    
    /// Log a mapping warning
    /// - Parameters:
    ///   - warning: The warning message
    ///   - entityType: The type of entity being mapped
    ///   - domainType: The type of domain model being created
    public static func logMappingWarning(_ warning: String, entityType: String, domainType: String) {
        print("⚠️ Mapping Warning: \(warning) when mapping from \(entityType) to \(domainType)")
    }
    
    /// Log a mapping success
    /// - Parameters:
    ///   - entityType: The type of entity that was mapped
    ///   - domainType: The type of domain model that was created
    public static func logMappingSuccess(entityType: String, domainType: String) {
        print("✅ Mapping Success: \(entityType) to \(domainType)")
    }
}

/// Safe mapping utilities
public struct SafeMapping {
    
    /// Safely convert a string to a double, returning nil if conversion fails
    /// - Parameter string: The string to convert
    /// - Returns: The converted double value or nil if conversion fails
    public static func stringToDouble(_ string: String?) -> Double? {
        guard let string = string, !string.isEmpty else { return nil }
        return Double(string)
    }
    
    /// Safely convert a string to an integer, returning nil if conversion fails
    /// - Parameter string: The string to convert
    /// - Returns: The converted integer value or nil if conversion fails
    public static func stringToInt(_ string: String?) -> Int? {
        guard let string = string, !string.isEmpty else { return nil }
        return Int(string)
    }
    
    /// Safely convert a string to a boolean, returning nil if conversion fails
    /// - Parameter string: The string to convert
    /// - Returns: The converted boolean value or nil if conversion fails
    public static func stringToBool(_ string: String?) -> Bool? {
        guard let string = string, !string.isEmpty else { return nil }
        return Bool(string)
    }
    
    /// Safely convert a string to a date using the specified format
    /// - Parameters:
    ///   - string: The string to convert
    ///   - format: The date format to use
    /// - Returns: The converted date or nil if conversion fails
    public static func stringToDate(_ string: String?, format: String) -> Date? {
        guard let string = string, !string.isEmpty else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.date(from: string)
    }
    
    /// Safely convert a date to a string using the specified format
    /// - Parameters:
    ///   - date: The date to convert
    ///   - format: The date format to use
    /// - Returns: The converted string or nil if conversion fails
    public static func dateToString(_ date: Date?, format: String) -> String? {
        guard let date = date else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

/// Mapping performance utilities
public struct MappingPerformance {
    
    /// Measure the time taken for a mapping operation
    /// - Parameter operation: The mapping operation to measure
    /// - Returns: The time taken in seconds
    public static func measureMappingTime<T>(_ operation: () throws -> T) rethrows -> (result: T, time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        let time = endTime - startTime
        
        return (result: result, time: time)
    }
    
    /// Log performance metrics for a mapping operation
    /// - Parameters:
    ///   - operation: The mapping operation being performed
    ///   - time: The time taken in seconds
    ///   - entityCount: The number of entities being mapped
    public static func logPerformance(_ operation: String, time: TimeInterval, entityCount: Int) {
        let averageTime = entityCount > 0 ? time / Double(entityCount) : 0
        print("📊 Mapping Performance: \(operation) - \(entityCount) entities in \(String(format: "%.4f", time))s (avg: \(String(format: "%.4f", averageTime))s per entity)")
    }
}
