//
//  NDISBillingConfigService.swift
//  InvoicingApplication
//
//  Created by AI Assistant for NDIS Billing Integration
//

import Foundation
import CoreLocation
import os

/// Service for managing NDIS billing configuration and regulatory values
public class NDISBillingConfigService {
    private let logger = Logger(subsystem: "com.invoicing.ndis", category: "BillingConfig")
    
    // MARK: - Configuration Storage
    
    private var configValues: [String: Any] = [:]
    
    public init() {
        loadDefaultConfiguration()
        logger.debug("Initialized NDISBillingConfigService with default configuration")
    }
    
    // MARK: - Configuration Management
    
    /// Gets a configuration value with type safety
    func getConfigValue<T>(_ key: String, defaultValue: T) -> T {
        return configValues[key] as? T ?? defaultValue
    }
    
    /// Gets a configuration value as Double
    func getConfigValue(_ key: String) -> Double {
        return getConfigValue(key, defaultValue: 0.0)
    }
    
    /// Gets a configuration value as String
    func getConfigValueString(_ key: String) -> String {
        return getConfigValue(key, defaultValue: "")
    }
    
    /// Gets a configuration value as Bool
    func getConfigValueBool(_ key: String) -> Bool {
        return getConfigValue(key, defaultValue: false)
    }
    
    /// Gets a configuration value as Int
    func getConfigValueInt(_ key: String) -> Int {
        return getConfigValue(key, defaultValue: 0)
    }
    
    /// Sets a configuration value
    func setConfigValue(_ key: String, value: Any) {
        configValues[key] = value
    }
    
    // MARK: - Default Configuration
    
    private func loadDefaultConfiguration() {
        // Geographic Loading
        configValues["GeoLoading.Remote"] = 1.40
        configValues["GeoLoading.VeryRemote"] = 1.50
        
        // Time Modifiers
        configValues["TimeModifier.PublicHoliday"] = 2.0
        configValues["TimeModifier.Sunday"] = 1.5
        configValues["TimeModifier.Saturday"] = 1.25
        configValues["TimeModifier.DSW.Evening"] = 1.25
        configValues["TimeModifier.DSW.Night"] = 1.5
        configValues["TimeModifier.Nurse.Night"] = 1.5
        configValues["TimeModifier.Nurse.Evening"] = 1.25
        
        // Travel Rates
        configValues["TravelRate.TherapyModifier"] = 0.5
        configValues["TravelRate.NonLabourPerKm"] = 0.85
        
        // Sleepover Configuration
        configValues["Sleepover.IncludedActiveHours"] = 8.0
        
        // Shadow Shift Configuration
        configValues["ShadowShift.AnnualCapHours"] = 200.0
        
        // SIL Configuration
        configValues["SIL.UnplannedExit.MaxWeeks"] = 4
        
        // Prepayment Configuration
        configValues["Prepayment.FinalHoldbackPercent"] = 0.10 // 10%
        
        // Subscription Caps
        configValues["Subscription.Cap.Consumables"] = 5000.0
        configValues["Subscription.Cap.AssistiveTechnology"] = 10000.0
        
        // Program of Support
        configValues["ProgramOfSupport.MaxMissedWeeks"] = 4
        
        // MMM Zone Configuration
        configValues["MMM.TimeCap.MMM1-3"] = 30.0 // minutes
        configValues["MMM.TimeCap.MMM4-5"] = 60.0 // minutes
        configValues["MMM.TimeCap.MMM6-7"] = 120.0 // minutes
        
        // Centre Capital Cost Rates
        configValues["CentreCapital.Rate.MMM1"] = 0.50
        configValues["CentreCapital.Rate.MMM2"] = 0.75
        configValues["CentreCapital.Rate.MMM3"] = 1.00
        configValues["CentreCapital.Rate.MMM4"] = 1.25
        configValues["CentreCapital.Rate.MMM5"] = 1.50
        configValues["CentreCapital.Rate.MMM6"] = 1.75
        configValues["CentreCapital.Rate.MMM7"] = 2.00
        
        // Establishment Fee Rates
        configValues["EstablishmentFee.Rate.MMM1"] = 100.0
        configValues["EstablishmentFee.Rate.MMM2"] = 150.0
        configValues["EstablishmentFee.Rate.MMM3"] = 200.0
        configValues["EstablishmentFee.Rate.MMM4"] = 250.0
        configValues["EstablishmentFee.Rate.MMM5"] = 300.0
        configValues["EstablishmentFee.Rate.MMM6"] = 350.0
        configValues["EstablishmentFee.Rate.MMM7"] = 400.0
        
        // Transport Rates
        configValues["TransportRate.StandardVehicle"] = 0.85
        configValues["TransportRate.ModifiedVehicle"] = 1.20
    }
    
    // MARK: - MMM Zone Lookup
    
    /// Gets the MMM rating for a location
    func getMmmRating(for location: NDISLocation) -> Int {
        // Attempt high-accuracy lookup via coordinates first
        if let lat = location.latitude, let lon = location.longitude {
            if let mmmValue = MMMZoneLookup.shared.mmm(for: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                return mmmValue
            }
        }
        
        let postcode = location.postcode
        let cleaned = postcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let code = Int(cleaned), cleaned.count == 4 else { return 1 }

        switch code {
        case 6799, 2898...2899:
            return 7
        case 800...999, 6000...6998:
            return 6
        case 4700...4999, 7200...7999:
            return 5
        case 5200...5999, 6200...6798:
            return 4
        default:
            return 1
        }
    }
    
    /// Gets the geographic multiplier for a location
    func getGeoMultiplier(for location: NDISLocation) -> Double {
        let mmmRating = getMmmRating(for: location)
        logger.debug("Applying geographic multiplier for MMM\(mmmRating)")
        switch mmmRating {
        case 6:
            return getConfigValue("GeoLoading.Remote")
        case 7:
            return getConfigValue("GeoLoading.VeryRemote")
        default:
            return 1.0
        }
    }
    
    /// Gets the time cap for a location based on MMM rating
    func getTimeCap(for location: NDISLocation) -> Double {
        let mmmRating = getMmmRating(for: location)
        
        switch mmmRating {
        case 1...3:
            return getConfigValue("MMM.TimeCap.MMM1-3")
        case 4...5:
            return getConfigValue("MMM.TimeCap.MMM4-5")
        case 6...7:
            return getConfigValue("MMM.TimeCap.MMM6-7")
        default:
            return getConfigValue("MMM.TimeCap.MMM1-3")
        }
    }
    
    // MARK: - Rate Calculations
    
    /// Gets the centre capital cost rate for a location
    func getCentreCapitalRate(for location: NDISLocation) -> Double {
        let mmmRating = getMmmRating(for: location)
        let key = "CentreCapital.Rate.MMM\(mmmRating)"
        return getConfigValue(key)
    }
    
    /// Gets the establishment fee rate for a location
    func getEstablishmentFeeRate(for location: NDISLocation) -> Double {
        let mmmRating = getMmmRating(for: location)
        let key = "EstablishmentFee.Rate.MMM\(mmmRating)"
        return getConfigValue(key)
    }
    
    /// Gets the time modifier for a date and provider type
    func getTimeModifier(for date: Date, providerType: String = "DSW") -> Double {
        if isPublicHoliday(date) {
            return getConfigValue("TimeModifier.PublicHoliday")
        }
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        if weekday == 1 { // Sunday
            return getConfigValue("TimeModifier.Sunday")
        } else if weekday == 7 { // Saturday
            return getConfigValue("TimeModifier.Saturday")
        }
        
        let hour = calendar.component(.hour, from: date)
        if providerType == "Nurse" {
            if hour >= 20 || hour < 6 {
                return getConfigValue("TimeModifier.Nurse.Night")
            } else if hour >= 16 {
                return getConfigValue("TimeModifier.Nurse.Evening")
            }
        } else {
            if hour >= 20 || hour < 6 {
                return getConfigValue("TimeModifier.DSW.Night")
            } else if hour >= 16 {
                return getConfigValue("TimeModifier.DSW.Evening")
            }
        }
        
        return 1.0
    }
    
    // MARK: - Generic Accessors
    
    func getSleepoverIncludedHours() -> Double {
        return getConfigValue("Sleepover.IncludedActiveHours")
    }
    
    func getSilMaxWeeks() -> Double {
        return Double(getConfigValueInt("SIL.UnplannedExit.MaxWeeks"))
    }
    
    func getTravelRatePerKm() -> Double {
        return getConfigValue("TravelRate.NonLabourPerKm")
    }
    
    func getTransportRate(isModified: Bool) -> Double {
        return isModified ? getConfigValue("TransportRate.ModifiedVehicle") : getConfigValue("TransportRate.StandardVehicle")
    }
    
    // MARK: - Holiday Calendar
    
    /// Checks if a date is a public holiday
    func isPublicHoliday(_ date: Date) -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        let dayStart = calendar.startOfDay(for: date)

        let fixedDates = [
            DateComponents(year: year, month: 1, day: 1),
            DateComponents(year: year, month: 1, day: 26),
            DateComponents(year: year, month: 4, day: 25),
            DateComponents(year: year, month: 12, day: 25),
            DateComponents(year: year, month: 12, day: 26)
        ]

        for components in fixedDates {
            guard let holiday = calendar.date(from: components) else { continue }
            let holidayStart = calendar.startOfDay(for: holiday)
            if dayStart == holidayStart {
                return true
            }
            if let observed = observedHolidayDate(for: holiday, calendar: calendar),
               dayStart == calendar.startOfDay(for: observed) {
                return true
            }
        }

        return false
    }
    
    // MARK: - Support Item Mapping
    
    /// Maps a support item to its complex behaviour equivalent
    func mapToComplexBehaviourItem(_ itemNumber: String) -> String {
        if itemNumber.contains("_0106_") { return itemNumber }
        let mapped = itemNumber.replacingOccurrences(of: "_0104_", with: "_0106_")
        return mapped == itemNumber ? itemNumber : mapped
    }
    
    /// Maps a support item to its high intensity equivalent
    func mapToHighIntensityItem(_ itemNumber: String) -> String {
        if itemNumber.contains("_0110_") { return itemNumber }
        let mapped = itemNumber.replacingOccurrences(of: "_0104_", with: "_0110_")
        return mapped == itemNumber ? itemNumber : mapped
    }
    
    /// Maps a support item to its travel non-labour equivalent
    func mapToTravelNonLabourItem(_ itemNumber: String) -> String {
        if itemNumber.contains("_799_") { return itemNumber }
        let components = itemNumber.split(separator: "_")
        guard components.count >= 5 else { return "01_799_0106_6_3" }
        return "\(components[0])_799_\(components[2])_\(components[3])_\(components[4])"
    }
    
    /// Maps a support item to its activity transport equivalent
    func mapToActivityTransportItem(_ itemNumber: String) -> String {
        if itemNumber.contains("_590_") { return itemNumber }
        let components = itemNumber.split(separator: "_")
        guard components.count >= 5 else { return "09_590_0106_6_3" }
        return "09_590_\(components[2])_\(components[3])_\(components[4])"
    }
    
    /// Maps a support item to its centre capital equivalent
    func mapToCentreCapitalItem(_ itemNumber: String) -> String {
        if itemNumber.contains("_799_") { return itemNumber }
        let components = itemNumber.split(separator: "_")
        guard components.count >= 5 else { return "01_799_0106_6_3" }
        return "\(components[0])_799_\(components[2])_\(components[3])_\(components[4])"
    }
    
    /// Maps a support item to its establishment fee equivalent
    func mapToEstablishmentFeeItem(_ itemNumber: String) -> String {
        mapToCentreCapitalItem(itemNumber)
    }
    
    /// Maps a provider type to its bereavement item
    func mapToBereavementItem(_ providerType: String) -> String {
        switch providerType {
        case "SupportCoordinator":
            return "07_501_0106_6_3"
        case "PlanManager":
            return "07_502_0106_6_3"
        case "SILProvider":
            return "07_503_0106_6_3"
        default:
            return "07_501_0106_6_3"
        }
    }
    
    /// Maps a support item to its hourly equivalent for sleepover calculations
    func mapToHourlyEquivalent(_ itemNumber: String) -> String {
        let transformed = itemNumber.replacingOccurrences(of: "_0136_", with: "_0104_")
        return transformed
    }

    private func observedHolidayDate(for holiday: Date, calendar: Calendar) -> Date? {
        let weekday = calendar.component(.weekday, from: holiday)
        switch weekday {
        case 7: // Saturday
            return calendar.date(byAdding: .day, value: 2, to: holiday)
        case 1: // Sunday
            return calendar.date(byAdding: .day, value: 1, to: holiday)
        default:
            return nil
        }
    }
    
    // MARK: - Eligibility Checks
    
    /// Gets the list of eligible capacity building items for activity transport
    func getEligibleCapacityBuildingItems() -> [String] {
        return [
            "09_011_0125_6_3",
            "09_012_0125_6_3",
            "09_013_0125_6_3"
        ]
    }
    
    /// Gets the list of allowed registration groups for centre capital costs
    func getAllowedCentreCapitalRegGroups() -> [String] {
        return ["0104", "0133", "0136"]
    }
    
    /// Gets the list of allowed registration groups for personal care establishment fees
    func getAllowedPersonalCareRegGroups() -> [String] {
        return ["0107", "0104"]
    }
    
    /// Gets the list of allowed registration groups for participation establishment fees
    func getAllowedParticipationRegGroups() -> [String] {
        return ["0125", "0136", "0104", "0133"]
    }
    
    /// Gets the list of allowed provider types for bereavement claims
    func getAllowedBereavementProviderTypes() -> [String] {
        return ["PlanManager", "SupportCoordinator", "SILProvider"]
    }
    
    // MARK: - Validation Rules
    
    /// Checks if an activity description is an excluded administrative task
    func isExcludedAdminTask(_ activityDescription: String) -> Bool {
        let excludedKeywords = [
            "billing", "payment", "claim", "roster", 
            "service agreement", "invoice", "administration",
            "paperwork", "documentation", "reporting"
        ]
        
        let lowercasedDescription = activityDescription.lowercased()
        return excludedKeywords.contains { keyword in
            lowercasedDescription.contains(keyword)
        }
    }
    
    /// Validates notice period for cancellations
    func checkNoticePeriod(noticeTime: Date, serviceTime: Date, amount: Int, unit: String) -> Bool {
        switch unit {
        case "days":
            let duration = serviceTime.timeIntervalSince(noticeTime)
            let days = duration / (24 * 60 * 60)
            return days >= Double(amount)
            
        case "clear_business_days":
            return checkClearBusinessDays(noticeTime: noticeTime, serviceTime: serviceTime, requiredDays: amount)
            
        default:
            return false
        }
    }
    
    private func checkClearBusinessDays(noticeTime: Date, serviceTime: Date, requiredDays: Int) -> Bool {
        var businessDaysCount = 0
        var currentDate = serviceTime
        
        while businessDaysCount < requiredDays && currentDate > noticeTime {
            if isWeekday(currentDate) && !isPublicHoliday(currentDate) {
                businessDaysCount += 1
            }
            currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        return businessDaysCount >= requiredDays
    }
    
    private func isWeekday(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday >= 2 && weekday <= 6 // Monday to Friday
    }
    
    // MARK: - Configuration Persistence
    
    /// Saves configuration to UserDefaults
    func saveConfiguration() {
        if let data = try? JSONSerialization.data(withJSONObject: configValues) {
            UserDefaults.standard.set(data, forKey: "NDISBillingConfig")
        }
    }
    
    /// Loads configuration from UserDefaults
    func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "NDISBillingConfig"),
           let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            configValues = config
        } else {
            loadDefaultConfiguration()
        }
    }
    
    /// Resets configuration to defaults
    func resetConfiguration() {
        loadDefaultConfiguration()
        saveConfiguration()
    }
} 
