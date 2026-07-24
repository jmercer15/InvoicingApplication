import Foundation
import CoreLocation
import Core

extension NDISBillingAutomationOrchestrator {

    // MARK: - Step 4: Geographic Context

    func determineGeographicContext(for session: Session, context: inout NDISBillingContext, result: inout AutomationResult) async {
        print("🌍 [NDIS Automation] Step 4: Determining geographic context")
        result.updateStatus(.determiningGeographic)

        guard hasValidCoordinates(session) else {
            print("⚠️ [NDIS Automation] Cannot determine geographic context - no valid coordinates")
            result.addWarning("Cannot determine geographic context - no valid coordinates")
            return
        }

        let coordinate: CLLocationCoordinate2D
        if session.sessionLatitude != 0.0 && session.sessionLongitude != 0.0 {
            coordinate = CLLocationCoordinate2D(latitude: session.sessionLatitude, longitude: session.sessionLongitude)
        } else if let address = session.address, address.latitude != 0.0 && address.longitude != 0.0 {
            coordinate = CLLocationCoordinate2D(latitude: address.latitude, longitude: address.longitude)
            print("🌍 [NDIS Automation] Using session address coordinates for geographic context")
        } else {
            print("⚠️ [NDIS Automation] No coordinates available for geographic context")
            result.addWarning("No coordinates available for geographic context")
            return
        }

        if let mmmCode = mmmZoneLookup.mmm(for: coordinate) {
            print("🌍 [NDIS Automation] MMM zone found: \(mmmCode)")
            switch mmmCode {
            case 4:
                context.isRemoteArea     = true
                context.isVeryRemoteArea = false
                print("✅ [NDIS Automation] Set Remote Area (MMM Zone 4)")
            case 5:
                context.isRemoteArea     = false
                context.isVeryRemoteArea = true
                print("✅ [NDIS Automation] Set Very Remote Area (MMM Zone 5)")
            default:
                context.isRemoteArea     = false
                context.isVeryRemoteArea = false
                print("✅ [NDIS Automation] No geographic modifier applied (MMM Zone \(mmmCode))")
            }
            context.autoDeterminedValues.insert(.remoteArea)
            context.autoDeterminedValues.insert(.veryRemoteArea)
        } else {
            print("⚠️ [NDIS Automation] No MMM zone found for coordinates")
            result.addWarning("No MMM zone found for session coordinates")
            context.isRemoteArea     = false
            context.isVeryRemoteArea = false
            context.autoDeterminedValues.insert(.remoteArea)
            context.autoDeterminedValues.insert(.veryRemoteArea)
        }
    }

    // MARK: - Step 5: Time Context

    func determineTimeContext(for session: Session, context: inout NDISBillingContext, result: inout AutomationResult) async {
        print("⏰ [NDIS Automation] Step 5: Determining time context")
        result.updateStatus(.determiningTime)

        guard let startTime = session.startTime else {
            result.addError("Session has no start time")
            return
        }

        let calendar   = Calendar.current
        let components = calendar.dateComponents([.weekday, .hour], from: startTime)

        if let weekday = components.weekday {
            let isWeekend = weekday == 1 || weekday == 7
            context.isWeekend = isWeekend
            context.autoDeterminedValues.insert(.weekend)
            if isWeekend { print("✅ [NDIS Automation] Set Weekend (Day \(weekday))") }
        }

        if let hour = components.hour {
            let isEvening = hour >= eveningStartHour && hour < eveningEndHour
            let isNight   = hour >= nightStartHour   || hour < nightEndHour
            context.isEvening = isEvening
            context.isNight   = isNight
            context.autoDeterminedValues.insert(.evening)
            context.autoDeterminedValues.insert(.night)
            if isEvening { print("✅ [NDIS Automation] Set Evening (Hour \(hour))") }
            else if isNight { print("✅ [NDIS Automation] Set Night (Hour \(hour))") }
        }

        context.isPublicHoliday = false
        context.autoDeterminedValues.insert(.publicHoliday)
        print("✅ [NDIS Automation] Time context determined")
    }

    // MARK: - Step 6: Travel Context

    func determineTravelContext(for session: Session, context: inout NDISBillingContext, result: inout AutomationResult) async {
        print("🚗 [NDIS Automation] Step 6: Determining travel context")
        result.updateStatus(.determiningTravel)

        let shouldSetProviderTravel = determineProviderTravelEligibility(for: session, context: context)
        context.isProviderTravel = shouldSetProviderTravel
        context.autoDeterminedValues.insert(.providerTravel)
        if shouldSetProviderTravel { print("✅ [NDIS Automation] Set Provider Travel") }

        let isActivityTransport = isActivityBasedEligible(session: session)
        context.isActivityTransport = isActivityTransport
        context.autoDeterminedValues.insert(.activityTransport)
        if isActivityTransport { print("✅ [NDIS Automation] Set Activity Transport") }

        print("✅ [NDIS Automation] Travel context determined")
    }

    // MARK: - Step 7: Service Type Context

    func determineServiceTypeContext(for session: Session, context: inout NDISBillingContext, result: inout AutomationResult) async {
        print("🏥 [NDIS Automation] Step 7: Determining service type context")
        result.updateStatus(.determiningServiceType)

        let attendeesCount = session.attendeesCount
        let isGroupSupport = attendeesCount > 1
        context.isGroupSupport = isGroupSupport
        context.groupSize      = Int(attendeesCount)
        context.autoDeterminedValues.insert(.groupSupport)
        if isGroupSupport { print("✅ [NDIS Automation] Set Group Support (size: \(attendeesCount))") }

        let isCancelled = determineCancellationStatus(session: session)
        context.isShortNoticeCancellation = isCancelled
        context.autoDeterminedValues.insert(.shortNoticeCancellation)
        if isCancelled { print("✅ [NDIS Automation] Set Short Notice Cancellation") }

        print("✅ [NDIS Automation] Service type context determined")
    }
}
