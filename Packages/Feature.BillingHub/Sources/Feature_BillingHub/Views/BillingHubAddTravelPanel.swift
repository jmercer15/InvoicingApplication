import SwiftUI
import SharedUI
import Core

struct BillingHubAddTravelPanel: View {
    let card: KanbanCardData
    let viewModel: BillingHubViewModel
    let sessionData: SessionKanbanCardData?
    @State var distanceKM: String
    @State var timeMinutes: String
    @State var tolls: String
    @State var parking: String = ""
    @State var chargeType: BillingHubTravelChargeType = .standard
    @State var vehicleType: BillingHubTravelVehicleType = .standard
    @State var travelDirection: BillingHubTravelDirection = .before
    @State var participantCount: Int = 1
    @State var splitCosts: Bool = false
    @State var showsAdvancedBillingOptions = false
    @State var breakdown: TravelCalculationBreakdown?
    @State var isAdding = false

    var parsedDistance: Double? { nonNegativeValue(distanceKM) }
    var parsedTime: Double? { nonNegativeValue(timeMinutes) }
    var parsedTolls: Double? { nonNegativeValue(tolls) }
    var parsedParking: Double? { nonNegativeValue(parking) }

    var hasValidTravelInput: Bool {
        guard let parsedDistance, let parsedTime, let parsedTolls, let parsedParking else {
            return false
        }
        let hasDistanceOrExpenses = parsedDistance > 0 || parsedTolls > 0 || parsedParking > 0
        switch chargeType {
        case .labour:
            return parsedTime > 0
        case .nonLabour:
            return hasDistanceOrExpenses
        case .standard, .activityBased:
            return parsedTime > 0 || hasDistanceOrExpenses
        }
    }

    init(card: KanbanCardData, viewModel: BillingHubViewModel) {
        self.card = card
        self.viewModel = viewModel
        if case let .session(data) = card {
            sessionData = data
            _distanceKM = State(initialValue: Self.formatDistance(data.suggestedTravelDistanceKM))
            _timeMinutes = State(initialValue: Self.formatMinutes(data.suggestedTravelTimeMinutes))
        } else {
            sessionData = nil
            _distanceKM = State(initialValue: "")
            _timeMinutes = State(initialValue: "")
        }
        _tolls = State(initialValue: "")
    }

    @Environment(\.dismiss) var dismiss

    struct BreakdownRefreshID: Equatable {
        let distanceKM: String
        let timeMinutes: String
        let tolls: String
        let parking: String
        let chargeType: BillingHubTravelChargeType
        let vehicleType: BillingHubTravelVehicleType
        let participantCount: Int
        let splitCosts: Bool
    }

    var breakdownRefreshID: BreakdownRefreshID {
        BreakdownRefreshID(
            distanceKM: distanceKM,
            timeMinutes: timeMinutes,
            tolls: tolls,
            parking: parking,
            chargeType: chargeType,
            vehicleType: vehicleType,
            participantCount: participantCount,
            splitCosts: splitCosts
        )
    }

    var body: some View {
        Group {
            Section {
                Text("Add a travel charge here if it wasn't already logged from Calendar. Both create the same travel charge used when generating the NDIS invoice.")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(BillingHubTheme.Palette.textSecondary)
            }

            if let sessionData {
                Section("Suggestions") {
                    suggestedMetricsView(for: sessionData)
                }
            }

            travelDetailsSection
            advancedBillingOptionsSection
            ndisCalculationSection
            addActionButton
        }
        .task(id: breakdownRefreshID) {
            guard await Task.waitUnlessCancelled(for: .milliseconds(150)) else { return }
            guard !Task.isCancelled else { return }
            await refreshBreakdown()
        }
    }

    static func formatDistance(_ value: Double?) -> String {
        guard let value else { return "" }
        return MeasurementFormatting.decimal(value, fractionDigits: 1)
    }

    static func formatMinutes(_ value: Double?) -> String {
        guard let value else { return "" }
        return MeasurementFormatting.decimal(value, fractionDigits: 0)
    }
}
