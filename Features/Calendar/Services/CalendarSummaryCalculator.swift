//
//  CalendarSummaryCalculator.swift
//  InvoicingApplication
//
//  Created by AI Assistant for Refactoring Initiative
//
import Foundation


/// Responsible for all financial calculations and summary generation
/// Extracted from CalendarViewModel for better separation of concerns and testability
class CalendarSummaryCalculator {
    
    // MARK: - Financial Calculations
    
    /// Calculates total billable hours from a collection of sessions
    func calculateTotalBillableHours(from sessions: [SessionEntity]) -> Double {
        print("[SummaryCalculator] Calculating totalBillableHours for \(sessions.count) sessions...")
        
        let totalDurationInSeconds = sessions.reduce(into: 0.0) { total, session in
            // Calculate duration only if both start and end times exist
            if let startTime = session.startTime, let endTime = session.endTime {
                let sessionDuration = endTime.timeIntervalSince(startTime)
                
                // Add duration only if it's positive
                if sessionDuration > 0 {
                    print("  -> Session \(session.title): Adding \(sessionDuration / 3600.0) hours")
                    total += sessionDuration
                } else {
                    print("  -> Session \(session.title): Skipping due to non-positive duration (\(sessionDuration)s)")
                }
            } else {
                print("  -> Session \(session.title): Skipping due to missing start/end time")
            }
        }
        
        let hours = totalDurationInSeconds / 3600.0
        print("[SummaryCalculator] Calculated totalBillableHours: \(hours)")
        
        return hours
    }
    
    /// Calculates total gross income from a collection of sessions
    func calculateTotalGrossIncome(from sessions: [SessionEntity]) -> Double {
        print("[SummaryCalculator] Calculating totalGrossIncome for \(sessions.count) sessions...")
        
        return sessions.reduce(0.0) { total, session in
            // Ensure the session has a client service and a valid rate
            guard let service = session.clientService, service.rate > 0 else {
                print("  -> Session \(session.title): Skipping income (no service or rate <= 0)")
                return total
            }
            
            let sessionTitle = session.title
            let serviceUnit = service.unit.lowercased()
            let serviceRate = service.rate
            
            // Calculate session duration in hours for hourly rates
            if serviceUnit == "hour" {
                if let startTime = session.startTime, let endTime = session.endTime, endTime > startTime { 
                    let durationInSeconds = endTime.timeIntervalSince(startTime)
                    let durationInHours = durationInSeconds / 3600.0
                    let income = serviceRate * durationInHours
                    print("  -> Session \(sessionTitle) (Hourly: \(durationInHours)h @ \(serviceRate)): Adding \(income)")
                    return total + income
                } else {
                    print("  -> Session \(sessionTitle) (Hourly): Skipping income (invalid duration)")
                    return total
                }
            } else if serviceUnit != "hour" && !serviceUnit.isEmpty {
                // For non-hourly units (e.g., 'session', 'item'), add the rate directly
                print("  -> Session \(sessionTitle) (Unit: \(serviceUnit)): Adding fixed rate \(serviceRate)")
                return total + serviceRate
            } else {
                print("  -> Session \(sessionTitle): Skipping income (no valid unit)")
                return total
            }
        }
    }
    
    // MARK: - Advanced Calculations
    
    /// Calculates financial summary for multiple time periods
    func calculateFinancialSummary(
        sessions: [SessionEntity],
        groupingBy period: SummaryPeriod = .day
    ) -> FinancialSummary {
        
        let groupedSessions = groupSessions(sessions, by: period)
        var periodSummaries: [PeriodSummary] = []
        
        for (periodKey, periodSessions) in groupedSessions.sorted(by: { $0.key < $1.key }) {
            let billableHours = calculateTotalBillableHours(from: periodSessions)
            let grossIncome = calculateTotalGrossIncome(from: periodSessions)
            let sessionCount = periodSessions.count
            
            let summary = PeriodSummary(
                period: periodKey,
                sessionCount: sessionCount,
                billableHours: billableHours,
                grossIncome: grossIncome,
                averageSessionValue: sessionCount > 0 ? grossIncome / Double(sessionCount) : 0
            )
            
            periodSummaries.append(summary)
        }
        
        // Calculate overall totals
        let totalBillableHours = periodSummaries.reduce(0) { $0 + $1.billableHours }
        let totalGrossIncome = periodSummaries.reduce(0) { $0 + $1.grossIncome }
        let totalSessions = periodSummaries.reduce(0) { $0 + $1.sessionCount }
        
        return FinancialSummary(
            totalBillableHours: totalBillableHours,
            totalGrossIncome: totalGrossIncome,
            totalSessions: totalSessions,
            averageHourlyRate: totalBillableHours > 0 ? totalGrossIncome / totalBillableHours : 0,
            periodSummaries: periodSummaries,
            period: period
        )
    }
    
    /// Calculates client-specific financial breakdown
    func calculateClientBreakdown(from sessions: [SessionEntity]) -> [ClientFinancialBreakdown] {
        let sessionsByClient = Dictionary(grouping: sessions) { session in
            session.client?.id ?? UUID() // Group sessions without clients under a single UUID
        }
        
        return sessionsByClient.compactMap { (clientID, clientSessions) in
            guard let firstSession = clientSessions.first,
                  let client = firstSession.client else {
                return nil // Skip sessions without clients
            }
            
            let billableHours = calculateTotalBillableHours(from: clientSessions)
            let grossIncome = calculateTotalGrossIncome(from: clientSessions)
            
            return ClientFinancialBreakdown(
                clientID: clientID,
                clientName: client.fullName,
                sessionCount: clientSessions.count,
                billableHours: billableHours,
                grossIncome: grossIncome,
                averageSessionValue: clientSessions.isEmpty ? 0 : grossIncome / Double(clientSessions.count)
            )
        }.sorted { $0.grossIncome > $1.grossIncome } // Sort by income descending
    }
    
    /// Calculates service-specific financial breakdown
    func calculateServiceBreakdown(from sessions: [SessionEntity]) -> [ServiceFinancialBreakdown] {
        let sessionsByService = Dictionary(grouping: sessions) { session in
            session.clientService?.id ?? UUID()
        }
        
        return sessionsByService.compactMap { (serviceID, serviceSessions) in
            guard let firstSession = serviceSessions.first,
                  let service = firstSession.clientService else {
                return nil
            }
            
            let billableHours = calculateTotalBillableHours(from: serviceSessions)
            let grossIncome = calculateTotalGrossIncome(from: serviceSessions)
            
            return ServiceFinancialBreakdown(
                serviceID: serviceID,
                serviceName: service.serviceName,
                serviceRate: service.rate,
                serviceUnit: service.unit,
                sessionCount: serviceSessions.count,
                billableHours: billableHours,
                grossIncome: grossIncome,
                efficiency: billableHours > 0 ? grossIncome / billableHours : 0
            )
        }.sorted { $0.grossIncome > $1.grossIncome }
    }
    
    // MARK: - Session Grouping
    
    private func groupSessions(_ sessions: [SessionEntity], by period: SummaryPeriod) -> [Date: [SessionEntity]] {
        let calendar = Calendar.current
        
        return Dictionary(grouping: sessions) { session in
            guard let startDate = session.startTime else {
                return Date.distantPast // Group sessions without dates
            }
            
            switch period {
            case .day:
                return calendar.startOfDay(for: startDate)
            case .week:
                return startDate.startOfWeek
            case .month:
                return startDate.startOfMonth
            case .year:
                let components = calendar.dateComponents([.year], from: startDate)
                return calendar.date(from: components) ?? startDate
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Formats financial amounts for display
    func formatCurrency(_ amount: Double, currencyCode: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    /// Formats hours for display
    func formatHours(_ hours: Double) -> String {
        let wholeHours = Int(hours)
        let minutes = Int((hours - Double(wholeHours)) * 60)
        
        if minutes == 0 {
            return "\(wholeHours)h"
        } else {
            return "\(wholeHours)h \(minutes)m"
        }
    }
    
    /// Calculates percentage change between two values
    func calculatePercentageChange(from oldValue: Double, to newValue: Double) -> Double {
        guard oldValue != 0 else { return newValue > 0 ? 100 : 0 }
        return ((newValue - oldValue) / oldValue) * 100
    }
    
    // MARK: - Data Structures
    
    enum SummaryPeriod {
        case day, week, month, year
    }
    
    struct FinancialSummary {
        let totalBillableHours: Double
        let totalGrossIncome: Double
        let totalSessions: Int
        let averageHourlyRate: Double
        let periodSummaries: [PeriodSummary]
        let period: SummaryPeriod
        
        var averageSessionValue: Double {
            return totalSessions > 0 ? totalGrossIncome / Double(totalSessions) : 0
        }
    }
    
    struct PeriodSummary {
        let period: Date
        let sessionCount: Int
        let billableHours: Double
        let grossIncome: Double
        let averageSessionValue: Double
    }
    
    struct ClientFinancialBreakdown {
        let clientID: UUID
        let clientName: String
        let sessionCount: Int
        let billableHours: Double
        let grossIncome: Double
        let averageSessionValue: Double
    }
    
    struct ServiceFinancialBreakdown {
        let serviceID: UUID
        let serviceName: String
        let serviceRate: Double
        let serviceUnit: String
        let sessionCount: Int
        let billableHours: Double
        let grossIncome: Double
        let efficiency: Double // Income per hour
    }
} 