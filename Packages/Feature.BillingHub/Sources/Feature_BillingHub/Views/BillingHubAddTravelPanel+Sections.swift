import SwiftUI
import SharedUI
import Core

extension BillingHubAddTravelPanel {
    @ViewBuilder
    var travelDetailsSection: some View {
        Section("Travel Details") {
            Picker("Direction", selection: $travelDirection) {
                ForEach(BillingHubTravelDirection.allCases) { direction in
                    Label(direction.label, systemImage: direction.icon).tag(direction)
                }
            }
            .pickerStyle(.segmented)

            Text("Saving replaces any existing travel charge in this direction; the other direction stays unchanged.")
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

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

            if !hasValidTravelInput {
                Label(
                    travelInputGuidance,
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(ColorSystem.Status.warning)
                .accessibilityLabel(travelInputGuidance)
            }
        }
    }

    @ViewBuilder
    var advancedBillingOptionsSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showsAdvancedBillingOptions) {
                providerTypeChip

                Picker("Charge Type", selection: $chargeType) {
                    ForEach(BillingHubTravelChargeType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                if chargeType.showsVehiclePicker {
                    Picker("Vehicle Type", selection: $vehicleType) {
                        ForEach(BillingHubTravelVehicleType.allCases) { type in
                            Text("\(type.label) (\(CurrencyFormatting.display(type.ratePerKilometre))/km)").tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Stepper("Participants: \(participantCount)", value: $participantCount, in: 1...10)

                Toggle("Split costs among participants", isOn: $splitCosts)
                    .disabled(participantCount <= 1)
            } label: {
                VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingTiny) {
                    Text("Advanced Billing Options")
                        .font(StyleGuide.Typography.bodyMedium)
                    Text(advancedBillingSummary)
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    var ndisCalculationSection: some View {
        Section("NDIS Calculation") {
            ndisBreakdownView
        }
    }

    @ViewBuilder
    var addActionButton: some View {
        Button {
            guard !isAdding else { return }
            isAdding = true
            Task {
                let distance = parsedDistance ?? 0
                let time = parsedTime ?? 0
                let tollsValue = parsedTolls ?? 0
                let parkingValue = parsedParking ?? 0
                let success = await viewModel.addTravelToSession(
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
                isAdding = false
                if success {
                    dismiss()
                }
            }
        } label: {
            BillingHubBusyButtonLabel.progressOrLabel(
                isBusy: isAdding,
                title: "Save Travel Charge",
                systemImage: "car.badge.plus"
            )
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isAdding || !hasValidTravelInput)
        .accessibilityLabel("Save travel charge")
        .accessibilityHint("Calculates and saves travel. An existing charge in this direction is replaced.")
    }

    func refreshBreakdown() async {
        let distance = parsedDistance ?? 0
        let time = parsedTime ?? 0
        let tollsValue = parsedTolls ?? 0
        let parkingValue = parsedParking ?? 0

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

    func nonNegativeValue(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        guard let value = Double(trimmed), value >= 0 else { return nil }
        return value
    }

    var travelInputGuidance: String {
        switch chargeType {
        case .labour:
            return "Enter travel time greater than zero for a labour charge."
        case .nonLabour:
            return "Enter distance, tolls, or parking greater than zero for a non-labour charge."
        case .standard, .activityBased:
            return "Enter at least one valid travel amount greater than zero."
        }
    }

    @ViewBuilder
    var providerTypeChip: some View {
        let providerType = viewModel.inferProviderType(for: card.id)
        InfoChip(
            icon: providerType == .therapist ? "stethoscope" : "person.fill",
            label: "Provider",
            value: providerType == .therapist ? "Therapist" : "DSW",
            color: providerType == .therapist ? ColorSystem.Session.therapist : ColorSystem.Primary.blue
        )
    }

    @ViewBuilder
    var ndisBreakdownView: some View {
        if let breakdown {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
                HStack {
                    Text("Labour")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currencyString(breakdown.labourTotal))
                        .monospacedDigit()
                        .font(StyleGuide.Typography.bodyMedium)
                }
                HStack {
                    Text("Non-Labour")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currencyString(breakdown.nonLabourTotal))
                        .monospacedDigit()
                        .font(StyleGuide.Typography.bodyMedium)
                }
                Divider()

                if splitCosts && participantCount > 1 {
                    HStack {
                        Text("Per Participant (\(participantCount))")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(currencyString(breakdown.chargeAmount))
                            .monospacedDigit()
                            .fontWeight(.semibold)
                            .foregroundStyle(ColorSystem.Status.warning)
                    }
                }

                HStack {
                    Text(chargeAmountLabel)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(currencyString(breakdown.chargeAmount))
                        .font(StyleGuide.Typography.sectionTitle)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(ColorSystem.Status.success)
                }

                if chargeType != .standard && abs(breakdown.chargeAmount - breakdown.totalPerParticipant) > 0.0001 {
                    HStack {
                        Text("Full travel total")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(currencyString(breakdown.grossTotal))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                if breakdown.billableMinutes < breakdown.requestedMinutes {
                    Label(
                        "Capped: \(Int(breakdown.billableMinutes)) of \(Int(breakdown.requestedMinutes)) min billable",
                        systemImage: "exclamationmark.triangle.fill"
                    )
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

    var chargeAmountLabel: String {
        switch chargeType {
        case .labour: return "Labour Charge"
        case .nonLabour: return "Non-Labour Charge"
        case .activityBased: return "Activity Charge"
        case .standard: return "Total"
        }
    }

    var advancedBillingSummary: String {
        let providerType = viewModel.inferProviderType(for: card.id)
        let provider = providerType == .therapist ? "Therapist" : "DSW"
        let participants = participantCount == 1 ? "1 participant" : "\(participantCount) participants"
        return "\(provider) · \(chargeType.label) · \(participants)"
    }

    func suggestedMetricsView(for session: SessionKanbanCardData) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: StyleGuide.Dimensions.paddingMediumLarge) {
                if let rate = session.travelRate {
                    InfoChip(
                        icon: "tag.fill",
                        label: "Rate",
                        value: "\(CurrencyFormatting.display(rate))/\(session.travelRateUnit?.lowercased() ?? "unit")",
                        color: ColorSystem.Primary.blue
                    )
                }
                if let distance = session.suggestedTravelDistanceKM {
                    InfoChip(
                        icon: "map.fill",
                        label: "Distance",
                        value: MeasurementFormatting.kilometers(distance),
                        color: ColorSystem.Session.therapist
                    )
                }
                if let minutes = session.suggestedTravelTimeMinutes {
                    InfoChip(
                        icon: "clock.fill",
                        label: "Time",
                        value: MeasurementFormatting.minutes(minutes),
                        color: ColorSystem.Status.warning
                    )
                }
            }
            .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
        }
    }

    func currencyString(_ value: Double) -> String {
        CurrencyFormatting.display(value)
    }
}
