import Foundation

extension TravelChargeAutomationService {
    func resolvedLocationText(for session: SessionAutomationContext) -> String? {
        if let location = nonEmptyLocation(session.location) {
            return location
        }
        return nonEmptyLocation(session.address?.fullFormattedAddress)
    }

    func nonEmptyLocation(_ location: String?) -> String? {
        guard let location,
              !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return location
    }

    /// Saves a travel charge entity to Core Data and tracks it for audit logging.
    func saveTravelCharge(_ travelCharge: TravelChargeSnapshot, context: SessionAutomationContext) async {
        if testingMode {
            let clientName = context.client?.fullName ?? "Unknown Client"
            let sessionTitle = travelCharge.location ?? "Unknown Location"
            let type = travelCharge.travelType?.rawValue ?? "unknown"
            let dir = travelCharge.travelDirection?.rawValue ?? "unknown"
            let distString = String(format: "%.1f", travelCharge.distanceKM ?? 0.0)
            let notes = travelCharge.notes ?? ""

            var details: [String] = []
            details.append("Client: \(clientName)")
            details.append("Linked Session: \(sessionTitle)")
            details.append("Charge Type: \(type)")
            details.append("Travel Direction: \(dir)")
            details.append("Distance: \(distString) km")

            if let duration = travelCharge.durationMinutes {
                details.append("Duration: \(String(format: "%.1f", duration)) min")
            }

            let amount = travelCharge.chargeAmount ?? 0.0
            details.append("Amount/Participant: \(amount.formatted(.currency(code: "AUD")))")

            if let mmmZone = lookupMMMZone(for: context) {
                details.append("MMM Zone: \(mmmZone.name)")
            }

            if let vehicleType = travelCharge.vehicleType?.rawValue {
                details.append("Vehicle Type: \(vehicleType)")
            }
            if (travelCharge.parkingCost ?? 0) > 0 {
                let parkingCost = travelCharge.parkingCost ?? 0
                details.append("Parking Cost: $\(String(format: "%.2f", parkingCost))")
            }
            if (travelCharge.tollCost ?? 0) > 0 {
                let tollCost = travelCharge.tollCost ?? 0
                details.append("Toll Cost: $\(String(format: "%.2f", tollCost))")
            }
            if (travelCharge.participantCount ?? 1) > 1 {
                details.append("Participant Count: \(travelCharge.participantCount ?? 1)")
            }
            if travelCharge.splitCosts ?? false {
                details.append("Split Costs: Yes")
            }

            if !notes.isEmpty {
                details.append("Notes: \(notes)")
            }

            let summary = details.joined(separator: "\n")
            appendTestTravelChargeSummary(summary)
            return
        }

        try? persistence.persistTravelCharge(travelCharge)
    }
}

