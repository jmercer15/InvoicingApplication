//
//  EditingPanel.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import SwiftUI
import SharedUI

struct EditingPanel: View {
    let card: KanbanCardData
    @Binding var isVisible: Bool

    @State private var editedService: String = ""
    @State private var editedClient: String = ""
    @State private var editedAmount: String = ""
    @State private var editedDuration: String = ""
    @State private var selectedPriority: Priority = .low
    // Removed legacy notes states

    var body: some View {
        VStack(spacing: 0) {
            editingPanelHeader
            // Subcolumn-specific full panel content
            panelContent
                .padding(StyleGuide.Dimensions.paddingLarge)
            
        }
        .background(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BillingHubTheme.Palette.surfacePrimary.opacity(0.96),
                            BillingHubTheme.Palette.surfaceSecondary.opacity(0.82)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous)
                        .stroke(BillingHubTheme.Palette.accentHighlight.opacity(0.45), lineWidth: 1.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous)
                        .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                        .blendMode(.plusLighter)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous))
        .shadow(color: BillingHubTheme.Palette.accentHighlight.opacity(0.35), radius: 36, x: 0, y: 22)
        .shadow(color: BillingHubTheme.Shadows.soft.opacity(0.35), radius: 48, x: 0, y: 30)
        .padding(StyleGuide.Dimensions.paddingXLarge)
    }

    // MARK: - Header
    private var editingPanelHeader: some View {
        HStack {
            Text(editingPanelTitle)
                .font(StyleGuide.Header.titleFont)
                .foregroundColor(BillingHubTheme.Palette.textPrimary)
            
            Spacer()
            
            // Small action buttons
            HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                Button(action: {
                    withAnimation(BillingHubTheme.Animations.spring) {
                        isVisible = false
                    }
                }) {
                    Text("Cancel")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(BillingHubTheme.Palette.textSecondary)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            Capsule()
                                .fill(BillingHubTheme.Palette.surfacePrimary.opacity(0.75))
                                .overlay(
                                    Capsule()
                                        .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                                )
                        )
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    // Save changes logic would go here
                    withAnimation(BillingHubTheme.Animations.spring) {
                        isVisible = false
                    }
                }) {
                    Text("Save")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(BillingHubTheme.Palette.textPrimary)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            LinearGradient(
                                colors: [
                                    BillingHubTheme.Columns.processing,
                                    BillingHubTheme.Palette.accentHighlight
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingXLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingMediumLarge)
        .background(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BillingHubTheme.Palette.accentHighlight.opacity(0.38),
                            BillingHubTheme.Palette.surfacePrimary.opacity(0.85)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous)
                        .stroke(BillingHubTheme.Palette.accentHighlight.opacity(0.55), lineWidth: 1.25)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous)
                        .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                        .blendMode(.plusLighter)
                )
                .shadow(color: BillingHubTheme.Palette.accentHighlight.opacity(0.28), radius: 18, x: 0, y: 12)
        )
    }
    
    private var editingPanelTitle: String {
        switch card {
        case .session(_): return "Edit Session"
        case .invoice(_): return "Edit Invoice"
        }
    }
    
    // MARK: - Session Details Column
    private var sessionDetailsColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with icon
            HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                Image(systemName: "doc.text.fill")
                    .font(.title3)
                    .foregroundColor(BillingHubTheme.Palette.textSecondary)
                Text("Session Details")
                    .font(StyleGuide.Header.titleFont)
                    .foregroundColor(BillingHubTheme.Palette.textPrimary)
            }
            .padding(.bottom, StyleGuide.Dimensions.paddingLarge)
            
            // Form fields with professional styling
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingLarge) {
                serviceTypeField
                durationAmountRow
                clientField
            }
            .padding(StyleGuide.Dimensions.paddingLarge)
            .glassEffect(in: .rect(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium)) // Apply glass effect

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Priority Status Column
    private var priorityStatusColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with icon
            HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundColor(BillingHubTheme.Palette.textSecondary)
                Text("Priority & Status")
                    .font(StyleGuide.Header.titleFont)
                    .foregroundColor(BillingHubTheme.Palette.textPrimary)
            }
            .padding(.bottom, StyleGuide.Dimensions.paddingLarge)
            
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingLarge) {
                priorityLevelSection
                currentStatusSection
                sessionInfoCard
            }
            .padding(StyleGuide.Dimensions.paddingLarge)
            .glassEffect(in: .rect(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium)) // Apply glass effect

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Notes Column (legacy, no longer used)
    private var notesColumn: some View { EmptyView() }

    // MARK: - Subcolumn-specific full panel content
    @ViewBuilder
    private var panelContent: some View {
        let column = card.columnType
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
            // Dynamic header for the selected subcolumn
            HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                Image(systemName: subcolumnHeader.icon)
                    .font(.title3)
                    .foregroundColor(BillingHubTheme.Palette.textSecondary)
                Text(subcolumnHeader.title)
                    .font(StyleGuide.Header.titleFont)
                    .foregroundColor(BillingHubTheme.Palette.textPrimary)
            }

            // Entire panel body varies by subcolumn
            Group {
                switch (card, column) {
                // Session subcolumns
                case (.session, .assignServices):
                    AssignServicesPanel(card: card)
                case (.session, .addTravel):
                    AddTravelPanel(card: card)
                case (.session, .completed):
                    CompletedPanel(card: card)
                case (.session, .grouped):
                    GroupedPanel(card: card)

                // Invoice subcolumns
                case (.invoice, .reviewDrafts):
                    ReviewDraftsPanel(card: card)
                case (.invoice, .readyToSend):
                    ReadyToSendPanel(card: card)
                case (.invoice, .pending):
                    PendingPaymentPanel(card: card)
                case (.invoice, .received):
                    PaymentReceivedPanel(card: card)

                default:
                    EmptyView()
                }
            }
            .padding(StyleGuide.Dimensions.paddingMediumLarge)
            .background(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                    .fill(BillingHubTheme.Palette.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                            .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                    )
            )
        }
    }

    // Helper for subcolumn headers used in individual panels

    private var subcolumnHeader: (icon: String, title: String) {
        switch card.columnType {
        case .assignServices: return ("wrench.and.screwdriver", "Assign Services")
        case .addTravel: return ("car", "Travel Charges")
        case .completed: return ("checkmark.circle", "Completed Options")
        case .grouped: return ("rectangle.stack", "Group")
        case .reviewDrafts: return ("doc.text.magnifyingglass", "Review Draft")
        case .readyToSend: return ("paperplane", "Send Invoice")
        case .pending: return ("clock", "Record Payment")
        case .received: return ("checkmark.seal", "Payment Received")
        }
    }

    // (infoTip replaced by InfoTipRow component)

    // MARK: Session and Invoice subcolumn panels
    private struct AssignServicesPanel: View {
        let card: KanbanCardData
        @State private var searchText: String = ""
        @State private var selectedService: String = ""
        @State private var unit: String = "hour"
        @State private var rate: String = ""
        // Removed notes state

        var body: some View {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingLarge) {
                HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                    EditingPanel.LabeledField(label: "Search Services", text: $searchText, placeholder: "Type to filter…")
                    Button("View Client Services") {}
                        .buttonStyle(.plain)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(BillingHubTheme.Palette.surfaceStroke.opacity(StyleGuide.Opacity.light))
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                }

                VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
                    Text("Suggested Services")
                        .font(.subheadline.bold())
                        .foregroundColor(BillingHubTheme.Palette.textPrimary)
                    ScrollView(.horizontal) {
                        HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                            ForEach(exampleServices, id: \.self) { svc in
                                Button(action: { selectedService = svc }) {
                                    Text(svc)
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(selectedService == svc ? BillingHubTheme.Palette.textPrimary : BillingHubTheme.Palette.textPrimary.opacity(0.8))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(BillingHubTheme.Palette.surfacePrimary)
                                                .overlay(
                                                    Capsule()
                                                        .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                    EditingPanel.LabeledField(label: "Selected Service", text: $selectedService, placeholder: "None selected")
                    EditingPanel.LabeledField(label: "Unit", text: $unit, placeholder: "hour")
                    EditingPanel.LabeledField(label: "Rate", text: $rate, placeholder: "$88.00")
                }

                // Notes input removed per request

                HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                    Button("Assign Service") {}
                        .buttonStyle(.plain)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            LinearGradient(
                                colors: [
                                    BillingHubTheme.Columns.preparing,
                                    BillingHubTheme.Columns.processing
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                    Button("Clear") { selectedService = ""; rate = ""; unit = "hour" }
                        .buttonStyle(.plain)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            Capsule()
                                .fill(BillingHubTheme.Palette.surfacePrimary.opacity(0.7))
                                .overlay(
                                    Capsule()
                                        .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                                )
                        )
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                }
            }
        }

        private var exampleServices: [String] {
            ["Personal Care", "Community Access", "Transport Support", "Domestic Assistance", "Plan Management"]
        }
    }

    private struct AddTravelPanel: View {
        private enum CalculationMethod: String, CaseIterable, Identifiable {
            case distance
            case time

            var id: String { rawValue }

            var label: String {
                switch self {
                case .distance: return "Distance"
                case .time: return "Time"
                }
            }
        }

        let card: KanbanCardData
        private let sessionData: SessionKanbanCardData?
        @State private var distanceKM: String
        @State private var timeMinutes: String
        @State private var method: CalculationMethod
        @State private var rate: String
        @State private var tolls: String

        init(card: KanbanCardData) {
            self.card = card
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

        var body: some View {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingLarge) {
                if let sessionData {
                    suggestedMetricsView(for: sessionData)
                }

                HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                    EditingPanel.LabeledField(label: "Distance (km)", text: $distanceKM, placeholder: "12.4")
                    EditingPanel.LabeledField(label: "Time (min)", text: $timeMinutes, placeholder: "25")
                    EditingPanel.LabeledField(label: rateFieldLabel, text: $rate, placeholder: ratePlaceholder)
                }

                HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                    EditingPanel.LabeledField(label: "Tolls ($)", text: $tolls, placeholder: "0.00")
                    Picker("Calculation Method", selection: $method) {
                        ForEach(CalculationMethod.allCases) { method in
                            Text(method.label).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }

                HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                    Text("Estimated total: \(estimatedTotal)")
                        .font(.subheadline.bold())
                        .foregroundColor(BillingHubTheme.Palette.textPrimary)
                    Spacer()
                    Button("Add Travel Charge") {}
                        .buttonStyle(.plain)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            LinearGradient(
                                colors: [
                                    BillingHubTheme.Columns.processing,
                                    BillingHubTheme.Columns.payment
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                }
            }
        }

        private func suggestedMetricsView(for session: SessionKanbanCardData) -> some View {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
                if let rate = session.travelRate {
                    Text("Rate: \(NumberFormatter.currency.string(from: NSNumber(value: rate)) ?? "$0.00") per \(session.travelRateUnit?.lowercased() ?? "unit")")
                        .font(.caption)
                        .foregroundColor(BillingHubTheme.Palette.textSecondary)
                }
                if let distance = session.suggestedTravelDistanceKM {
                    Text(String(format: "Suggested distance: %.1f km", distance))
                        .font(.caption)
                        .foregroundColor(BillingHubTheme.Palette.textSecondary)
                }
                if let minutes = session.suggestedTravelTimeMinutes {
                    Text(String(format: "Suggested travel time: %.0f min", minutes))
                        .font(.caption)
                        .foregroundColor(BillingHubTheme.Palette.textSecondary)
                }
            }
        }

        private var estimatedTotal: String {
            guard let effectiveRate = resolvedRate else { return currencyString(resolvedTolls ?? 0) }

            var total: Double = 0
            switch method {
            case .distance:
                guard let distance = resolvedDistance, distance > 0 else { return currencyString(resolvedTolls ?? 0) }
                total = distance * effectiveRate
            case .time:
                guard let minutes = resolvedMinutes, minutes > 0 else { return currencyString(resolvedTolls ?? 0) }
                total = timeBasedAmount(rate: effectiveRate, minutes: minutes)
            }

            total += resolvedTolls ?? 0
            return currencyString(total)
        }

        private var rateFieldLabel: String {
            switch method {
            case .distance:
                return "Rate ($/km)"
            case .time:
                if normalizedUnit.contains("min") {
                    return "Rate ($/min)"
                }
                return "Rate ($/hr)"
            }
        }

        private var ratePlaceholder: String {
            switch method {
            case .distance:
                return "0.85"
            case .time:
                return normalizedUnit.contains("min") ? "2.70" : "90.00"
            }
        }

        private var normalizedUnit: String {
            sessionData?.travelRateUnit?.lowercased() ?? ""
        }

        private var resolvedRate: Double? {
            parseNumeric(rate) ?? sessionData?.travelRate
        }

        private var resolvedDistance: Double? {
            parseNumeric(distanceKM) ?? sessionData?.suggestedTravelDistanceKM
        }

        private var resolvedMinutes: Double? {
            parseNumeric(timeMinutes) ?? sessionData?.suggestedTravelTimeMinutes
        }

        private var resolvedTolls: Double? {
            guard !tolls.isEmpty else { return nil }
            return parseNumeric(tolls)
        }

        private func timeBasedAmount(rate: Double, minutes: Double) -> Double {
            if normalizedUnit.contains("min") {
                return rate * minutes
            }
            return rate * (minutes / 60.0)
        }

        private func parseNumeric(_ text: String) -> Double? {
            let sanitized = text.replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
            guard !sanitized.isEmpty else { return nil }
            let normalized = sanitized.replacingOccurrences(of: ",", with: "")
            return Double(normalized)
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

    private struct CompletedPanel: View {
        let card: KanbanCardData
        @State private var flagged: Bool = false
        @State private var tags: String = ""
        // Removed notes state

        var body: some View {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingLarge) {
                EditingPanel.InfoTipRow(text: "This session is marked Completed. You can optionally tag or flag it before grouping.")
                Toggle("Flag for follow-up", isOn: $flagged)
                    .toggleStyle(.switch)
                EditingPanel.LabeledField(label: "Tags (comma-separated)", text: $tags, placeholder: "urgent, home-visit")
                // Notes input removed per request
                HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                    Button("Move to Grouped") {}
                        .buttonStyle(.plain)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            LinearGradient(
                                colors: [
                                    BillingHubTheme.Columns.preparing,
                                    BillingHubTheme.Columns.processing
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                    Button("Clear Flags") { flagged = false; tags = "" }
                        .buttonStyle(.plain)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            Capsule()
                                .fill(BillingHubTheme.Palette.surfacePrimary.opacity(0.7))
                                .overlay(
                                    Capsule()
                                        .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                                )
                        )
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                }
            }
        }
    }

    private struct GroupedPanel: View {
        let card: KanbanCardData
        @State private var groupName: String = ""
        // Removed notes state

        var body: some View {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingLarge) {
                EditingPanel.LabeledField(label: "Group Name", text: $groupName, placeholder: "e.g., Morning Sessions")
                // Group notes input removed per request
                HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                    Button("Ungroup") {}
                        .buttonStyle(.plain)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            Capsule()
                                .fill(BillingHubTheme.Palette.surfacePrimary.opacity(0.7))
                                .overlay(
                                    Capsule()
                                        .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                                )
                        )
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                    Button("Create Draft Invoice") {}
                        .buttonStyle(.plain)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            LinearGradient(
                                colors: [
                                    BillingHubTheme.Columns.processing,
                                    BillingHubTheme.Columns.payment
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                }
            }
        }
    }

    private struct ReviewDraftsPanel: View {
        let card: KanbanCardData
        @State private var dueDate: Date = Date().addingTimeInterval(7*24*3600)
        // Removed reviewer notes state

        var body: some View {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingLarge) {
                HStack(spacing: StyleGuide.Dimensions.paddingMediumLarge) {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    Spacer()
                    Button("Approve Draft") {}
                        .buttonStyle(.plain)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            LinearGradient(
                                colors: [
                                    BillingHubTheme.Columns.processing,
                                    BillingHubTheme.Columns.payment
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                    Button("Request Changes") {}
                        .buttonStyle(.plain)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            Capsule()
                                .fill(BillingHubTheme.Palette.surfacePrimary.opacity(0.7))
                                .overlay(
                                    Capsule()
                                        .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                                )
                        )
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                }
                // Reviewer notes input removed per request
            }
        }
    }

    private struct ReadyToSendPanel: View {
        let card: KanbanCardData
        @State private var recipients: String = ""
        @State private var cc: String = ""
        @State private var subject: String = "Invoice"
        @State private var message: String = "Please find attached your invoice."
        @State private var attachPDF: Bool = true
        @State private var sendCopy: Bool = true
        @State private var scheduleSend: Bool = false
        @State private var scheduleDate: Date = Date().addingTimeInterval(3600)

        var body: some View {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingLarge) {
                HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                    EditingPanel.LabeledField(label: "To", text: $recipients, placeholder: "recipient@domain.com")
                    EditingPanel.LabeledField(label: "Cc", text: $cc, placeholder: "optional")
                }
                EditingPanel.LabeledField(label: "Subject", text: $subject, placeholder: "Invoice")
                VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingSmall) {
                    Text("Message")
                        .font(.subheadline)
                    TextEditor(text: $message)
                        .frame(minHeight: 140)
                        .scrollContentBackground(.hidden)
                        .padding(StyleGuide.Dimensions.paddingMedium)
                        .background(
                            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                                .fill(BillingHubTheme.Palette.surfacePrimary.opacity(0.65))
                                .overlay(
                                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                                        .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                                )
                        )
                }
                HStack(spacing: StyleGuide.Dimensions.paddingLarge) {
                    Toggle("Attach PDF", isOn: $attachPDF)
                    Toggle("Send copy to myself", isOn: $sendCopy)
                    Toggle("Schedule send", isOn: $scheduleSend)
                    if scheduleSend {
                        DatePicker("", selection: $scheduleDate)
                            .labelsHidden()
                    }
                    Spacer()
                    Button("Send Test") {}
                        .buttonStyle(.plain)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            Capsule()
                                .fill(BillingHubTheme.Palette.surfacePrimary.opacity(0.7))
                                .overlay(
                                    Capsule()
                                        .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                                )
                        )
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                    Button("Send") {}
                        .buttonStyle(.plain)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            LinearGradient(
                                colors: [
                                    BillingHubTheme.Columns.processing,
                                    BillingHubTheme.Columns.payment
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                }
            }
        }
    }

    private struct PendingPaymentPanel: View {
        let card: KanbanCardData
        @State private var amount: String = ""
        @State private var date: Date = Date()
        @State private var method: String = "Bank Transfer"
        @State private var reference: String = ""
        // Removed notes state

        var body: some View {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingLarge) {
                HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                    EditingPanel.LabeledField(label: "Amount", text: $amount, placeholder: "$0.00")
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Method", selection: $method) {
                        Text("Bank Transfer").tag("Bank Transfer")
                        Text("Card").tag("Card")
                        Text("Cash").tag("Cash")
                        Text("Cheque").tag("Cheque")
                    }
                    .frame(maxWidth: 200)
                }
                EditingPanel.LabeledField(label: "Reference", text: $reference, placeholder: "Receipt or transaction ID")
                // Notes input removed per request
                HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                    Button("Mark as Received") {}
                        .buttonStyle(.plain)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            LinearGradient(
                                colors: [
                                    BillingHubTheme.Columns.payment,
                                    BillingHubTheme.Palette.accentHighlight
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                    Button("Save Draft") {}
                        .buttonStyle(.plain)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            Capsule()
                                .fill(BillingHubTheme.Palette.surfacePrimary.opacity(0.7))
                                .overlay(
                                    Capsule()
                                        .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                                )
                        )
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                }
            }
        }
    }

    private struct PaymentReceivedPanel: View {
        let card: KanbanCardData
        @State private var receiptEmail: String = ""
        @State private var includePDF: Bool = true

        var body: some View {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingLarge) {
                EditingPanel.InfoTipRow(text: "Payment has been received. You can send a receipt or export documents.")
                HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                    EditingPanel.LabeledField(label: "Send receipt to", text: $receiptEmail, placeholder: "accounts@client.com")
                    Toggle("Attach PDF receipt", isOn: $includePDF)
                        .toggleStyle(.switch)
                }
                HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                    Button("Send Receipt") {}
                        .buttonStyle(.plain)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            LinearGradient(
                                colors: [
                                    BillingHubTheme.Columns.payment,
                                    BillingHubTheme.Palette.accentHighlight
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                    Button("Export PDF") {}
                        .buttonStyle(.plain)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .background(
                            Capsule()
                                .fill(BillingHubTheme.Palette.surfacePrimary.opacity(0.7))
                                .overlay(
                                    Capsule()
                                        .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                                )
                        )
                        .cornerRadius(StyleGuide.Dimensions.cornerRadiusXSmall)
                }
            }
        }
    }

    
    
    // Reusable helpers as components
    private struct LabeledField: View {
        var label: String
        @Binding var text: String
        var placeholder: String
        var body: some View {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.9))
                TextField(placeholder, text: $text)
                    .textFieldStyle(ProfessionalTextFieldStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct InfoTipRow: View {
        var text: String
        var body: some View {
            HStack(alignment: .top, spacing: StyleGuide.Dimensions.paddingMedium) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(BillingHubTheme.Palette.textSecondary)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.9))
            }
        }
    }
    // MARK: - Helper Views
    private var columnBackground: some View {
        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium)
            .fill(BillingHubTheme.Palette.surfacePrimary.opacity(StyleGuide.Opacity.light))
            .overlay(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium)
                    .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1) 
            )
    }
    
    private var serviceTypeField: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingSmall) {
            HStack {
                Text("Service Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.9))
                Spacer()
                Image(systemName: "gearshape.fill")
                    .font(.caption)
                    .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(StyleGuide.Opacity.medium))
            }
            
            TextField("Enter service type", text: $editedService)
                .textFieldStyle(ProfessionalTextFieldStyle()) 
                .onAppear {
                    switch card {
                    case .session(let sessionData):
                        editedService = sessionData.serviceName
                    case .invoice(let invoiceData):
                        editedService = invoiceData.serviceName
                    }
                }
        }
    }
    
    private var durationAmountRow: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMediumLarge) {
            switch card {
            case .session(let sessionData):
                VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingSmall) {
                    HStack {
                        Text("Duration")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.9))
                        Spacer()
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(StyleGuide.Opacity.medium))
                    }
                    
                    TextField("2.0h", text: $editedDuration)
                        .textFieldStyle(ProfessionalTextFieldStyle()) 
                        .onAppear {
                            editedDuration = sessionData.duration
                        }
                }
            case .invoice(let invoiceData):
                VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingSmall) {
                    HStack {
                        Text("Amount")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.9))
                        Spacer()
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.caption)
                            .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(StyleGuide.Opacity.medium))
                    }
                    
                    TextField("$85.00", text: $editedAmount)
                        .textFieldStyle(ProfessionalTextFieldStyle()) 
                        .onAppear {
                            editedAmount = invoiceData.amount
                        }
                }
            }
        }
    }
    
    private var clientField: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingSmall) {
            HStack {
                Text("Client Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.9))
                Spacer()
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(StyleGuide.Opacity.medium))
            }
            
            TextField("Enter client name", text: $editedClient)
                .textFieldStyle(ProfessionalTextFieldStyle()) 
                .onAppear {
                    switch card {
                    case .session(let sessionData):
                        editedClient = sessionData.clientName
                    case .invoice(let invoiceData):
                        editedClient = invoiceData.clientName
                    }
                }
        }
    }
    
    private var priorityLevelSection: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
            HStack {
                Text("Priority Level")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.9))
                Spacer()
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(StyleGuide.Opacity.medium))
            }
            
            HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                ProfessionalPriorityButton(
                    title: "Low",
                    priority: Priority.low,
                    isSelected: selectedPriority == Priority.low,
                    action: { selectedPriority = Priority.low }
                )
                ProfessionalPriorityButton(
                    title: "Medium",
                    priority: Priority.medium,
                    isSelected: selectedPriority == Priority.medium,
                    action: { selectedPriority = Priority.medium }
                )
                ProfessionalPriorityButton(
                    title: "High",
                    priority: Priority.high,
                    isSelected: selectedPriority == Priority.high,
                    action: { selectedPriority = Priority.high }
                )
            }
            .onAppear {
                switch card {
                case .session(let sessionData):
                    selectedPriority = sessionData.priority
                case .invoice(let invoiceData):
                    selectedPriority = invoiceData.priority
                }
            }
        }
    }
    
    private var currentStatusSection: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
            HStack {
                Text("Current Status")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.9))
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(StyleGuide.Opacity.medium))
            }
            
            HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                Circle()
                    .fill(BillingHubTheme.Palette.textPrimary.opacity(StyleGuide.Opacity.medium))
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .fill(BillingHubTheme.Palette.textPrimary.opacity(0.7))
                            .frame(width: 8, height: 8)
                    )
                
                Text(statusText(for: card.currentWorkflowStatus))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.9))
                
                Spacer()
            }
            .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
            .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
            .background(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                    .fill(BillingHubTheme.Palette.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                            .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                    )
            )
        }
    }
    
    private var sessionInfoCard: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
            HStack {
                Text("Details")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.9))
                Spacer()
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(StyleGuide.Opacity.medium))
            }
            
            VStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                switch card {
                case .session(let sessionData):
                    HStack {
                        Text("Date")
                            .font(.caption)
                            .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.6))
                        Spacer()
                        Text(sessionData.date)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.8))
                    }
                    
                    Divider()
                        .background(BillingHubTheme.Palette.surfaceStroke.opacity(StyleGuide.Opacity.light))
                    
                    HStack {
                        Text("Start Time")
                            .font(.caption)
                            .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.6))
                        Spacer()
                        Text(sessionData.startTime?.formatted(date: .omitted, time: .shortened) ?? "-")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.9))
                    }
                    
                    Divider()
                        .background(BillingHubTheme.Palette.surfaceStroke.opacity(StyleGuide.Opacity.light))
                    
                    HStack {
                        Text("End Time")
                            .font(.caption)
                            .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.6))
                        Spacer()
                        Text(sessionData.endTime?.formatted(date: .omitted, time: .shortened) ?? "-")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.8))
                    }
                case .invoice(let invoiceData):
                    HStack {
                        Text("Issue Date")
                            .font(.caption)
                            .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.6))
                        Spacer()
                        Text(invoiceData.date)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.8))
                    }
                    
                    Divider()
                        .background(BillingHubTheme.Palette.surfaceStroke.opacity(StyleGuide.Opacity.light))
                    
                    HStack {
                        Text("Amount")
                            .font(.caption)
                            .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.6))
                        Spacer()
                        Text(invoiceData.amount)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(BillingHubTheme.Palette.textPrimary.opacity(0.9))
                    }
                }
            }
            .padding(StyleGuide.Dimensions.paddingMediumLarge)
            .background(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                    .fill(BillingHubTheme.Palette.surfacePrimary.opacity(StyleGuide.Opacity.light))
                    .overlay(
                        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                            .stroke(BillingHubTheme.Palette.surfaceStroke, lineWidth: 1)
                    )
            )
        }
    }
    
    // Notes-based sections removed per request

    private func statusText(for status: KanbanCardData.WorkflowStatus) -> String {
        switch status {
        case .completed: return "Completed"
        case .grouped: return "Grouped"
        case .readyToInvoice: return "Ready to Invoice"
        case .draftReview: return "Draft Review"
        case .readyToSend: return "Ready to Send"
        case .pendingPayment: return "Pending Payment"
        case .paymentReceived: return "Payment Received"
        }
    }
}

// Supporting Components for Editing Panel
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        // Removed GeometryReader and simplified padding/cornerRadius
        configuration
            .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
            .padding(.vertical, StyleGuide.Dimensions.paddingMedium)   
            .background(BillingHubTheme.Palette.surfaceStroke.opacity(StyleGuide.Opacity.light)) 
            .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall) 
            .foregroundColor(BillingHubTheme.Palette.textPrimary) 
            .font(.system(size: 13, design: .rounded)) 
            .accentColor(BillingHubTheme.Palette.textPrimary) 
        .frame(minHeight: 32, maxHeight: 32) 
    }
}

struct ProfessionalTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(BillingHubTheme.Palette.textPrimary) 
            .font(.system(size: 13, design: .rounded))
            .accentColor(BillingHubTheme.Palette.textPrimary) 
    }
}

struct PriorityButton: View {
    let title: String
    let priority: Priority
    let isSelected: Bool
    let action: () -> Void

    var priorityColor: Color {
        switch priority {
        case Priority.low: return BillingHubTheme.Columns.payment
        case Priority.medium: return BillingHubTheme.Columns.processing
        case Priority.high: return BillingHubTheme.Palette.accentCritical
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                Circle()
                    .fill(priorityColor.opacity(isSelected ? 1.0 : StyleGuide.Opacity.strong))
                    .frame(width: 10, height: 10) 
                    .overlay(
                        Circle()
                            .fill(priorityColor)
                            .frame(width: 5, height: 5) 
                    )

                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded)) 
                    .foregroundColor(isSelected ? priorityColor : BillingHubTheme.Palette.textPrimary.opacity(0.7)) 
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
            .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
            .background(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                    .fill(isSelected ? priorityColor.opacity(StyleGuide.Opacity.medium) : BillingHubTheme.Palette.surfaceStroke.opacity(StyleGuide.Opacity.light)) 
                    .overlay(
                        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                            .stroke(isSelected ? priorityColor.opacity(0.5) : BillingHubTheme.Palette.surfaceStroke.opacity(StyleGuide.Opacity.light), lineWidth: 1) 
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProfessionalPriorityButton: View {
    let title: String
    let priority: Priority
    let isSelected: Bool
    let action: () -> Void

    var priorityColor: Color {
        switch priority {
        case .low: return BillingHubTheme.Columns.payment
        case .medium: return BillingHubTheme.Columns.processing
        case .high: return BillingHubTheme.Palette.accentCritical
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                Circle()
                    .fill(priorityColor.opacity(isSelected ? 1.0 : StyleGuide.Opacity.medium))
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .fill(priorityColor)
                            .frame(width: 4, height: 4)
                    )

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? priorityColor : BillingHubTheme.Palette.textSecondary)
            }
            .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
            .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
            .background(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                    .fill(isSelected ? priorityColor.opacity(StyleGuide.Opacity.light) : BillingHubTheme.Palette.surfacePrimary) 
                    .overlay(
                        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                            .stroke(isSelected ? priorityColor.opacity(StyleGuide.Opacity.medium) : BillingHubTheme.Palette.surfaceStroke, lineWidth: 1) 
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
