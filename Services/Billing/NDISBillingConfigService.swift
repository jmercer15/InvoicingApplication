//
//  NDISBillingConfigService.swift
//  InvoicingApplication
//
//  Created by AI Assistant for NDIS Billing Integration
//

import Foundation

/// Service for managing NDIS billing configuration and regulatory values
class NDISBillingConfigService {
    
    // MARK: - Configuration Storage
    
    private var configValues: [String: Any] = [:]
    
    init() {
        loadDefaultConfiguration()
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
    
    /// Gets the MMM rating for a postcode
    func getMmmRating(for postcode: String) -> Int {
        // This would implement the actual MMM zone lookup logic
        // For now, return a default value
        return 1
    }
    
    /// Gets the time cap for a postcode based on MMM rating
    func getTimeCap(for postcode: String) -> Double {
        let mmmRating = getMmmRating(for: postcode)
        
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
    
    /// Gets the centre capital cost rate for a postcode
    func getCentreCapitalRate(for postcode: String) -> Double {
        let mmmRating = getMmmRating(for: postcode)
        let key = "CentreCapital.Rate.MMM\(mmmRating)"
        return getConfigValue(key)
    }
    
    /// Gets the establishment fee rate for a postcode
    func getEstablishmentFeeRate(for postcode: String) -> Double {
        let mmmRating = getMmmRating(for: postcode)
        let key = "EstablishmentFee.Rate.MMM\(mmmRating)"
        return getConfigValue(key)
    }
    
    // MARK: - Holiday Calendar
    
    /// Checks if a date is a public holiday
    func isPublicHoliday(_ date: Date) -> Bool {
        // This would implement holiday calendar lookup
        // For now, return false
        return false
    }
    
    // MARK: - Support Item Mapping
    
    /// Maps a support item to its complex behaviour equivalent
    func mapToComplexBehaviourItem(_ itemNumber: String) -> String {
        // This would implement the mapping logic
        // For now, return the original item number
        return itemNumber
    }
    
    /// Maps a support item to its high intensity equivalent
    func mapToHighIntensityItem(_ itemNumber: String) -> String {
        // This would implement the mapping logic
        // For now, return the original item number
        return itemNumber
    }
    
    /// Maps a support item to its travel non-labour equivalent
    func mapToTravelNonLabourItem(_ itemNumber: String) -> String {
        // This would implement the mapping logic
        // For now, return a default travel item
        return "01_799_0106_6_3" // Example travel item
    }
    
    /// Maps a support item to its activity transport equivalent
    func mapToActivityTransportItem(_ itemNumber: String) -> String {
        // This would implement the mapping logic
        // For now, return a default transport item
        return "09_590_0106_6_3" // Example transport item
    }
    
    /// Maps a support item to its centre capital equivalent
    func mapToCentreCapitalItem(_ itemNumber: String) -> String {
        // This would implement the mapping logic
        // For now, return a default capital item
        return "01_799_0106_6_3" // Example capital item
    }
    
    /// Maps a support item to its establishment fee equivalent
    func mapToEstablishmentFeeItem(_ itemNumber: String) -> String {
        // This would implement the mapping logic
        // For now, return a default establishment fee item
        return "01_799_0106_6_3" // Example establishment fee item
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
        // This would implement the mapping logic
        // For now, return the original item number
        return itemNumber
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