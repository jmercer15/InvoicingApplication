import SwiftUI
import SharedUI

struct BillingHubAddTravelPanel: View {
    private enum CalculationMethod: String, CaseIterable, Identifiable {
        case distance
        case time

        var id: String { rawValue }
    }

    private enum ChargeType: String, CaseIterable, Identifiable {
        case standard
        case labour
        case nonLabour = "non-labour"
        case activityBased = "activity-based"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .standard: return "Standard"
            case .labour: return "Labour"
            case .nonLabour: return "Non-Labour"
            case .activityBased: return "Activity-Based"
            }
        }
    }

    private enum VehicleType: String, CaseIterable, Identifiable {
        case standard
        case modified

        var id: String { rawValue }

        var label: String {
            switch self {
            case .standard: return "Standard"
            case .modified: return "Modified"
            }
        }

        var rate: Double {
            switch self {
            case .standard: return 0.85
            case .modified: return 1.14
            }
        }
    }

    private enum TravelDirection: String, CaseIterable, Identifiable {
        case before
        case after

        var id: String { rawValue }

        var label: String {
            switch self {
            case .before: return "Before Session"
            case .after: return "After Session"
            }
        }

        var icon: String {
            switch self {
            case .before: return "arrow.right.circle"
            case .after: return "arrow.left.circle"
            }
        }
    }

    let card: KanbanCardData
    let viewModel: BillingHubViewModel
    private let sessionData: SessionKanbanCardData?
    @State private var distanceKM: String
    @State private var timeMinutes: String
    @State private var method: CalculationMethod
    @State private var rate: String
    @State private var tolls: String
    @State private var parking: String = ""
    @State private var chargeType: ChargeType = .standard
    @State private var vehicleType: VehicleType = .standard
    @State private var travelDirection: TravelDirection = .before
    @State private var participantCount: Int = 1
    @State private var splitCosts: Bool = false
    @State private var breakdown: TravelCalculationBreakdown?

    init(card: KanbanCardData, viewModel: BillingHubViewModel) {
        self.card = card
        self.viewModel = viewModel
        if case let .session(data) = card {
            sessionData = data
            _distanceKM = State(initialValue: Self.formatDistance(data.suggestedTravelDistanceKM))
            _timeMinutes = State(initialValue: Self.formatMinutes(data.suggestedTravelTimeMinutes))
            _rate = State(initialValue: Self.formatRate(data.travelRate))
            _method = State(initialValue: Self.defaultMethod(for: data))
        } else {
            sessionData = nil
            _distanceKM = State(initialValue: "")
            _timeMinutes = State(initialValue: "")
            _rate = State(initialValue: "")
            _method = State(initialValue: .distance)
        }
        _tolls = State(initialValue: "")
    }

    @Environment(\.dismiss) var dismiss

    var body: some View {
        List {
            if let sessionData {
                Section("Suggestions") {
                    suggestedMetricsView(for: sessionData)
                }
            }

            providerInfoSection
            chargeConfigurationSection
            travelDetailsSection
            participantsSection
            ndisCalculationSection
            addActionButton
        }
        .task {
            await refreshBreakdown()
        }
        .onChange(of: distanceKM) { _, _ in Task { await refreshBreakdown() } }
        .onChange(of: timeMinutes) { _, _ in Task { await refreshBreakdown() } }
        .onChange(of: tolls) { _, _ in Task { await refreshBreakdown() } }
        .onChange(of: parking) { _, _ in Task { await refreshBreakdown() } }
        .onChange(of: chargeType) { _, _ in Task { await refreshBreakdown() } }
        .onChange(of: vehicleType) { _, _ in Task { await refreshBreakdown() } }
        .onChange(of: participantCount) { _, _ in Task { await refreshBreakdown() } }
        .onChange(of: splitCosts) { _, _ in Task { await refreshBreakdown() } }
    }

    @ViewBuilder
    private var providerInfoSection: some View {
        Section("Provider Info") {
            providerTypeChip
        }
    }

    @ViewBuilder
    private var chargeConfigurationSection: some View {
        Section("Charge Configuration") {
            Picker("Charge Type", selection: $chargeType) {
                ForEach(ChargeType.allCases) { type in
                    Text(type.label).tag(type)
                }
            }
            .pickerStyle(.segmented)

            if chargeType == .activityBased {
                Picker("Vehicle Type", selection: $vehicleType) {
                    ForEach(VehicleType.allCases) { type in
                        Text("\(type.label) ($\(String(format: "%.2f", type.rate))/km)").tag(type)
                    }
                }
                .pickerStyle(.menu)
            }

            Picker("Direction", selection: $travelDirection) {
                ForEach(TravelDirection.allCases) { direction in
                    Label(direction.label, systemImage: direction.icon).tag(direction)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var travelDetailsSection: some View {
        Section("Travel Details") {
            TextField(text: $distanceKM) { Text("Distance (km)") }
                .monospacedDigit()
                .help("Total distance traveled in kilometers")
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .submitLabel(.next)

            TextField(text: $timeMinutes) { Text("Time (min)") }
                .monospacedDigit()
                .help("Total travel time in minutes")
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .submitLabel(.next)

            TextField(text: $tolls) { Text("Tolls ($)") }
                .monospacedDigit()
                .help("Toll expenses")
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .submitLabel(.next)

            TextField(text: $parking) { Text("Parking ($)") }
                .monospacedDigit()
                .help("Parking expenses")
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .submitLabel(.done)
        }
    }

    @ViewBuilder
    private var participantsSection: some View {
        Section("Participants") {
            Stepper("Participants: \(participantCount)", value: $participantCount, in: 1...10)

            Toggle("Split costs among participants", isOn: $splitCosts)
                .disabled(participantCount <= 1)
        }
    }

    @ViewBuilder
    private var ndisCalculationSection: some View {
        Section("NDIS Calculation") {
            ndisBreakdownView
        }
    }

    @ViewBuilder
    private var addActionButton: some View {
        Button("Add Travel Charge") {
            Task {
                let distance = Double(distanceKM) ?? 0
                let time = Double(timeMinutes) ?? 0
                let tollsValue = Double(tolls) ?? 0
                let parkingValue = Double(parking) ?? 0
                await viewModel.addTravelToSession(
                    id: card.id,
                    distance: distance,
                    time: time,
                    tolls: tollsValue,
                    parking: parkingValue,
                    chargeType: chargeType.rawValue,
                    vehicleType: vehicleType.rawValue,
                    travelDirection: travelDirection.rawValue,
                    participantCount: participantCount,
                    splitCosts: splitCosts
                )
                dismiss()
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
        .accessibilityLabel("Add travel charge to session")
        .accessibilityHint("Calculates and adds a travel expense item based on the entered metrics.")
    }

    private func refreshBreakdown() async {
        let distance = Double(distanceKM) ?? 0
        let time = Double(timeMinutes) ?? 0
        let tollsValue = Double(tolls) ?? 0
        let parkingValue = Double(parking) ?? 0

        breakdown = await viewModel.calculateTravelBreakdown(
            sessionId: card.id,
            distance: distance,
            time: time,
            tolls: tollsValue,
            parking: parkingValue,
            chargeType: chargeType.rawValue,
            vehicleType: vehicleType.rawValue,
            participantCount: participantCount,
            splitCosts: splitCosts
        )
    }

    @ViewBuilder
    private var providerTypeChip: some View {
        let providerType = viewModel.inferProviderType()
        InfoChip(
            icon: providerType == .therapist ? "stethoscope" : "person.fill",
            label: "Provider",
            value: providerType == .therapist ? "Therapist" : "DSW",
            color: providerType == .therapist ? ColorSystem.Session.therapist : ColorSystem.Primary.blue
        )
    }

    @ViewBuilder
    private var ndisBreakdownView: some View {
        if let breakdown {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
                HStack {
                    Text("Labour")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currencyString(breakdown.labourTotal))
                        .monospacedDigit()
                        .fontWeight(.medium)
                }
                HStack {
                    Text("Non-Labour")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currencyString(breakdown.nonLabourTotal))
                        .monospacedDigit()
                        .fontWeight(.medium)
                }
                Divider()

                if splitCosts && participantCount > 1 {
                    HStack {
                        Text("Per Participant (\(participantCount))")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(currencyString(breakdown.totalPerParticipant))
                            .monospacedDigit()
                            .fontWeight(.semibold)
                            .foregroundStyle(ColorSystem.Status.warning)
                    }
                }

                HStack {
                    Text("Total")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(currencyString(breakdown.grossTotal))
                        .font(StyleGuide.Typography.sectionTitle)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(ColorSystem.Status.success)
                }

                if breakdown.billableMinutes < breakdown.requestedMinutes {
                    Text("⚠️ Capped: \(Int(breakdown.billableMinutes)) of \(Int(breakdown.requestedMinutes)) min billable")
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundStyle(ColorSystem.Status.warning)
                }
            }
            .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
        } else {
            Text("Enter travel details to see calculation")
                .foregroundStyle(.secondary)
                .font(StyleGuide.Typography.itemSubtitle)
        }
    }

    private func suggestedMetricsView(for session: SessionKanbanCardData) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: StyleGuide.Dimensions.paddingMediumLarge) {
                if let rate = session.travelRate {
                    InfoChip(
                        icon: "tag.fill",
                        label: "Rate",
                        value: "\(NumberFormatter.currency.string(from: NSNumber(value: rate)) ?? "$0.00")/\(session.travelRateUnit?.lowercased() ?? "unit")",
                        color: ColorSystem.Primary.blue
                    )
                }
                if let distance = session.suggestedTravelDistanceKM {
                    InfoChip(
                        icon: "map.fill",
                        label: "Distance",
                        value: String(format: "%.1f km", distance),
                        color: ColorSystem.Session.therapist
                    )
                }
                if let minutes = session.suggestedTravelTimeMinutes {
                    InfoChip(
                        icon: "clock.fill",
                        label: "Time",
                        value: String(format: "%.0f min", minutes),
                        color: ColorSystem.Status.warning
                    )
                }
            }
            .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
        }
    }

    private func currencyString(_ value: Double) -> String {
        NumberFormatter.currency.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    private static func formatDistance(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.1f", value)
    }

    private static func formatMinutes(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.0f", value)
    }

    private static func formatRate(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.2f", value)
    }

    private static func defaultMethod(for session: SessionKanbanCardData) -> CalculationMethod {
        if let distance = session.suggestedTravelDistanceKM, distance > 0 {
            return .distance
        }
        if let unit = session.travelRateUnit?.lowercased(), unit.contains("km") {
            return .distance
        }
        return .time
    }
}

