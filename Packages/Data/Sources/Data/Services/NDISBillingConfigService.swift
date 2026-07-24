//
//  NDISBillingConfigService.swift
//  InvoicingApplication
//
//  Created by AI Assistant for NDIS Billing Integration
//

import Foundation
import CoreLocation
import os
import Core

/// Service for managing NDIS billing configuration and regulatory values
public class NDISBillingConfigService {
    private let logger = Logger(subsystem: "com.invoicing.ndis", category: "BillingConfig")
    private let mmmZoneLookup: Core.MMMZoneLookup
    
    // MARK: - Configuration Storage
    
    private var configValues: [String: Any] = [:]
    
    public init(mmmZoneLookup: Core.MMMZoneLookup) {
        self.mmmZoneLookup = mmmZoneLookup
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
    
    /// Gets a configuration value as Int
    func getConfigValueInt(_ key: String) -> Int {
        return getConfigValue(key, defaultValue: 0)
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
    
    /// Gets the MMM rating for a location using coordinates only.
    func getMmmRating(for location: NDISLocation) -> Int? {
        guard let lat = location.latitude, let lon = location.longitude else {
            logger.warning("MMM lookup skipped because no coordinates were provided")
            return nil
        }

        return mmmZoneLookup.mmm(for: CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }
    
    /// Gets the geographic multiplier for a location
    func getGeoMultiplier(for location: NDISLocation) -> Double? {
        guard let mmmRating = getMmmRating(for: location) else {
            logger.warning("Geographic multiplier requires a resolved MMM zone")
            return nil
        }
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
    
    // MARK: - Rate Calculations
    
    /// Gets the centre capital cost rate for a location
    func getCentreCapitalRate(for location: NDISLocation) -> Double? {
        guard let mmmRating = getMmmRating(for: location) else {
            logger.warning("Centre capital cost requires a resolved MMM zone")
            return nil
        }
        let key = "CentreCapital.Rate.MMM\(mmmRating)"
        return getConfigValue(key)
    }
    
    /// Gets the establishment fee rate for a location
    func getEstablishmentFeeRate(for location: NDISLocation) -> Double? {
        guard let mmmRating = getMmmRating(for: location) else {
            logger.warning("Establishment fee requires a resolved MMM zone")
            return nil
        }
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
    
    // MARK: - Validation Rules

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
    
} 
