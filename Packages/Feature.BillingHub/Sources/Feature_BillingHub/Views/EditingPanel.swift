import SwiftUI
import SharedUI
import Core
import Data

struct EditingPanel: View {
    let card: KanbanCardData
    @State private var editedService: String = ""
    @State private var editedClient: String = ""
    @State private var editedAmount: String = ""
    @State private var editedDuration: String = ""
    @State private var selectedPriority: Priority = .low
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openInvoice) private var openInvoice
    @Environment(\.openSession) private var openSession
    @EnvironmentObject var viewModel: BillingHubViewModel
    @FocusState private var focusedField: Field?
    @State private var supportLogDraft: SupportLogDraft = SupportLogDraft()
    @State private var supportLogError: String?
    @State private var complianceWarnings: [ComplianceIssue] = []
    @State private var complianceBlockers: [ComplianceIssue] = []
    @State private var complianceLoadError: String?
    
    enum Field {
        case serviceType, client, amount, duration
    }

    var body: some View {
        NavigationStack {
            Form {
                // Top Section: Details and Statistics/Priority
                switch card {
                case .session:
                    Section("Session Details") {
                        sessionDetailsContent
                    }
                    Section("Support Log") {
                        supportLogContent
                    }
                    Section("Priority & Status") {
                        priorityStatusContent
                    }
                case .invoice:
                    Section("Invoice Details") {
                        invoiceDetailsContent
                    }
                    Section("Compliance Checklist") {
                        complianceChecklistContent
                    }
                    Section("Status") {
                        invoiceStatusContent
                    }
                }

                Section("Open In Workspace") {
                    crossFeatureNavigationContent
                }
                
                // Subcolumn-specific full panel content
                Section {
                    panelContent
                } header: {
                    Label(subcolumnHeader.title, systemImage: subcolumnHeader.icon)
                        .font(.headline)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .formStyle(.grouped) // Use grouped style for standard look
            .navigationTitle(editingPanelTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    .help("Discard changes and close the panel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .help("Preserve all edits and close the panel")
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .defaultFocus($focusedField, .serviceType)
        .task(id: card.id) {
            await loadComplianceData()
        }
    }

    @ViewBuilder
    private var crossFeatureNavigationContent: some View {
        switch card {
        case .session(let sessionData):
            Button("Open Session in Calendar") {
                openSession?(sessionData.sessionId)
                dismiss()
            }
        case .invoice(let invoiceData):
            Button("Open Invoice in Invoices") {
                openInvoice?(invoiceData.invoiceId)
                dismiss()
            }
        }
    }
    
    private func saveChanges() {
        Task {
            switch card {
            case .session(let data):
                await viewModel.updateSessionDetails(id: data.sessionId, durationString: editedDuration)
            case .invoice(let data):
                await viewModel.updateInvoiceDetails(id: data.invoiceId, amountString: editedAmount, clientName: editedClient)
            }
        }
    }
    
    private var editingPanelTitle: String {
        switch card {
        case .session(_): return "Edit Session"
        case .invoice(_): return "Edit Invoice"
        }
    }
    
    // MARK: - Session Details Content
    private var sessionDetailsContent: some View {
        Group {
            serviceTypeField
            durationAmountRow
            clientField
        }
    }
    
    // MARK: - Priority Status Content
    private var priorityStatusContent: some View {
        Group {
            priorityLevelSection
            currentStatusSection
            sessionInfoCard
        }
    }

    // MARK: - Invoice Details Content
    private var invoiceDetailsContent: some View {
        Group {
            serviceTypeField
            durationAmountRow
            clientField
        }
    }

    // MARK: - Invoice Status Content
    private var invoiceStatusContent: some View {
        Group {
            if case .invoice(let data) = card {
                HStack {
                    Text("Current Status")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Spacer()
                    StatusIndicator(
                        color: data.accentColor,
                        label: "", // Label managed by HStack
                        count: data.workflowStatus.rawValue.capitalized
                    )
                    .lineLimit(1)
                    .truncationMode(.tail)
                }
                
                LabeledContent {
                    Text(data.date)
                } label: {
                    Text("Date")
                        .fontWeight(.medium)
                }
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help("The issuance date of this invoice")
                
                if let days = data.daysOverdue, days > 0 {
                    LabeledContent {
                         Text("\(days) days")
                             .lineLimit(1)
                             .foregroundStyle(.red)
                             .fontWeight(.bold)
                             .monospacedDigit()
                    } label: {
                        Text("Overdue")
                            .fontWeight(.medium)
                    }
                }
            } else {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var supportLogContent: some View {
        if case .session(let sessionData) = card {
            TextField("Participant name", text: $supportLogDraft.participantName)
            TextField("Participant NDIS number", text: $supportLogDraft.participantNdisNumber)
            TextField("Support item number", text: $supportLogDraft.supportItemNumber)
            TextField("Service description", text: $supportLogDraft.serviceDescription)
            TextField("Location", text: $supportLogDraft.location)
            DatePicker("Delivered from", selection: $supportLogDraft.deliveredFrom, displayedComponents: [.date, .hourAndMinute])
            DatePicker("Delivered to", selection: $supportLogDraft.deliveredTo, displayedComponents: [.date, .hourAndMinute])
            TextField("Delivered by", text: $supportLogDraft.deliveredBy)
            TextField("Attested by", text: $supportLogDraft.attestedBy)
            DatePicker("Attested at", selection: $supportLogDraft.attestedAt, displayedComponents: [.date, .hourAndMinute])
            TextField("Signed by (optional)", text: Binding(
                get: { supportLogDraft.signedBy ?? "" },
                set: { supportLogDraft.signedBy = $0.isEmpty ? nil : $0 }
            ))
            Picker(
                "Signature Method",
                selection: Binding(
                    get: { supportLogDraft.signatureMethod ?? SignatureMethod.attestation.rawValue },
                    set: { supportLogDraft.signatureMethod = $0 }
                )
            ) {
                ForEach(SignatureMethod.allCases, id: \.rawValue) { method in
                    Text(method.rawValue.capitalized).tag(method.rawValue)
                }
            }
            TextField("Cancellation reason (optional)", text: Binding(
                get: { supportLogDraft.cancellationReasonCode ?? "" },
                set: { supportLogDraft.cancellationReasonCode = $0.isEmpty ? nil : $0 }
            ))
            TextField("Notes (optional)", text: Binding(
                get: { supportLogDraft.notes ?? "" },
                set: { supportLogDraft.notes = $0.isEmpty ? nil : $0 }
            ))

            if let supportLogError,
               !supportLogError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(supportLogError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Save Support Log") {
                Task {
                    await saveSupportLog(for: sessionData.sessionId)
                }
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var complianceChecklistContent: some View {
        if let complianceLoadError,
           !complianceLoadError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(complianceLoadError)
                .font(.caption)
                .foregroundStyle(.red)
        }

        if complianceBlockers.isEmpty && complianceWarnings.isEmpty {
            Text("No compliance issues detected.")
                .foregroundStyle(.secondary)
        } else {
            if !complianceBlockers.isEmpty {
                Text("Blockers")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
                ForEach(complianceBlockers, id: \.self) { issue in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "xmark.octagon.fill")
                            .foregroundStyle(.red)
                        Text("[\(issue.id)] \(issue.message)")
                            .font(.caption)
                    }
                }
            }

            if !complianceWarnings.isEmpty {
                Text("Warnings")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
                ForEach(complianceWarnings, id: \.self) { issue in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("[\(issue.id)] \(issue.message)")
                            .font(.caption)
                    }
                }
            }
        }
    }

    private func loadComplianceData() async {
        supportLogError = nil
        complianceLoadError = nil
        complianceWarnings = []
        complianceBlockers = []

        switch card {
        case .session(let sessionData):
            if let supportLog = await viewModel.fetchSupportLog(for: sessionData.sessionId) {
                supportLogDraft = supportLogDraft(from: supportLog)
            }
        case .invoice(let invoiceData):
            if let result = await viewModel.fetchComplianceChecklist(for: invoiceData.invoiceId) {
                complianceWarnings = result.warnings
                complianceBlockers = result.blockers
            }
        }
    }

    private func saveSupportLog(for sessionId: UUID) async {
        do {
            _ = try await viewModel.upsertSupportLog(sessionId: sessionId, draft: supportLogDraft)
            supportLogError = nil
        } catch {
            supportLogError = error.localizedDescription
        }
    }

    private func supportLogDraft(from log: SupportLog) -> SupportLogDraft {
        SupportLogDraft(
            participantName: log.participantName,
            participantNdisNumber: log.participantNdisNumber,
            supportItemNumber: log.supportItemNumber,
            serviceDescription: log.serviceDescription,
            location: log.location,
            deliveredFrom: log.deliveredFrom,
            deliveredTo: log.deliveredTo,
            quantityHours: log.quantityHours,
            deliveredBy: log.deliveredBy,
            attestedBy: log.attestedBy,
            attestedAt: log.attestedAt,
            signatureMethod: log.signatureMethod,
            signedBy: log.signedBy,
            signedAt: log.signedAt,
            cancellationReasonCode: log.cancellationReasonCode,
            notes: log.notes
        )
    }

    // MARK: - Subcolumn-specific full panel content
    @ViewBuilder
    private var panelContent: some View {
        Group {
            switch (card, card.columnType) {
            // Session subcolumns
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
    }

    private var subcolumnHeader: (icon: String, title: String) {
        switch card.columnType {
        case .addTravel: return ("car", "Travel Charges")
        case .completed: return ("checkmark.circle", "Completed Options")
        case .grouped: return ("rectangle.stack", "Group")
        case .reviewDrafts: return ("doc.text.magnifyingglass", "Review Draft")
        case .readyToSend: return ("paperplane", "Send Invoice")
        case .pending: return ("clock", "Awaiting Payment")
        case .received: return ("checkmark.seal", "Completed")
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
            
            var icon: String {
                switch self {
                case .distance: return "map"
                case .time: return "clock"
                }
            }
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
        
        @EnvironmentObject var viewModel: BillingHubViewModel
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            Group {
                if let sessionData {
                    Section("Suggestions") {
                        suggestedMetricsView(for: sessionData)
                    }
                }
                
                // Provider Type Info (read-only)
                Section("Provider Info") {
                    providerTypeChip
                }

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

                Section("Travel Details") {
                    TextField("Distance (km)", text: $distanceKM, prompt: Text("12.4"))
                        .monospacedDigit()
                        .help("Total distance traveled in kilometers")
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .submitLabel(.next)

                    TextField("Time (min)", text: $timeMinutes, prompt: Text("25"))
                        .monospacedDigit()
                        .help("Total travel time in minutes")
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .submitLabel(.next)

                    TextField("Tolls ($)", text: $tolls, prompt: Text("0.00"))
                        .monospacedDigit()
                        .help("Toll expenses")
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                    
                    TextField("Parking ($)", text: $parking, prompt: Text("0.00"))
                        .monospacedDigit()
                        .help("Parking expenses")
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                }
                
                Section("Participants") {
                    Stepper("Participants: \(participantCount)", value: $participantCount, in: 1...10)
                    
                    Toggle("Split costs among participants", isOn: $splitCosts)
                        .disabled(participantCount <= 1)
                }
                
                // NDIS Breakdown Display
                Section("NDIS Calculation") {
                    ndisBreakdownView
                }

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
        }
        
        @ViewBuilder
        private var providerTypeChip: some View {
            if let session = viewModel.fetchSession(byID: card.id) {
                let providerType = viewModel.inferProviderType(for: session)
                InfoChip(
                    icon: providerType == .therapist ? "stethoscope" : "person.fill",
                    label: "Provider",
                    value: providerType == .therapist ? "Therapist" : "DSW",
                    color: providerType == .therapist ? .purple : .blue
                )
            } else {
                Text("Session not found").foregroundStyle(.secondary)
            }
        }
        
        @ViewBuilder
        private var ndisBreakdownView: some View {
            let distance = Double(distanceKM) ?? 0
            let time = Double(timeMinutes) ?? 0
            let tollsValue = Double(tolls) ?? 0
            let parkingValue = Double(parking) ?? 0
            
            if let breakdown = viewModel.calculateTravelBreakdown(
                sessionId: card.id,
                distance: distance,
                time: time,
                tolls: tollsValue,
                parking: parkingValue,
                chargeType: chargeType.rawValue,
                vehicleType: vehicleType.rawValue,
                participantCount: participantCount,
                splitCosts: splitCosts
            ), let session = viewModel.fetchSession(byID: card.id) {
                VStack(alignment: .leading, spacing: 8) {
                    // Session rate info
                    if let rate = session.assignedRate {
                        HStack {
                            Text("Hourly Rate")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(currencyString(rate) + "/hr")
                                .monospacedDigit()
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                        }
                    }
                    
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
                    
                    // Show per-participant if splitting
                    if splitCosts && participantCount > 1 {
                        HStack {
                            Text("Per Participant (\(participantCount))")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(currencyString(breakdown.totalPerParticipant))
                                .monospacedDigit()
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    HStack {
                        Text("Total")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(currencyString(breakdown.grossTotal))
                            .font(.title3)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundStyle(.green)
                    }
                    
                    // Billable time info
                    if breakdown.billableMinutes < breakdown.requestedMinutes {
                        Text("⚠️ Capped: \(Int(breakdown.billableMinutes)) of \(Int(breakdown.requestedMinutes)) min billable")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 4)
            } else {
                Text("Enter travel details to see calculation")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }

        private func suggestedMetricsView(for session: SessionKanbanCardData) -> some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if let rate = session.travelRate {
                        InfoChip(
                            icon: "tag.fill",
                            label: "Rate",
                            value: "\(NumberFormatter.currency.string(from: NSNumber(value: rate)) ?? "$0.00")/\(session.travelRateUnit?.lowercased() ?? "unit")",
                            color: .blue
                        )
                    }
                    if let distance = session.suggestedTravelDistanceKM {
                        InfoChip(
                            icon: "map.fill",
                            label: "Distance",
                            value: String(format: "%.1f km", distance),
                            color: .purple
                        )
                    }
                    if let minutes = session.suggestedTravelTimeMinutes {
                        InfoChip(
                            icon: "clock.fill",
                            label: "Time",
                            value: String(format: "%.0f min", minutes),
                            color: .orange
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }

        private struct InfoChip: View {
            let icon: String
            let label: String
            let value: String
            let color: Color
            
            var body: some View {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 12))
                        .frame(width: 24, height: 24)
                        .background(color.opacity(0.1))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Text(value)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.trailing, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                )
            }
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
        @EnvironmentObject var viewModel: BillingHubViewModel
        @Environment(\.dismiss) private var dismiss
        // Removed notes state

        var body: some View {
            Group {
                Section {
                    Text("This session is marked Completed. You can optionally tag or flag it before grouping.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Toggle("Flag for follow-up", isOn: $flagged)
                        .toggleStyle(.switch)
                        .help("Mark this session as needing special attention or further review")
                    TextField("Tags (comma-separated)", text: $tags, prompt: Text("urgent, home-visit"))
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                }
                
                Button("Move to Grouped") {
                    Task {
                        viewModel.moveSessionToGrouped(sessionID: card.id)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .help("Move this completed session to the grouping stage")
                .accessibilityLabel("Move to grouped")
                .accessibilityHint("Prepares the session for inclusion in a draft invoice.")
                
                Button("Clear Flags") { flagged = false; tags = "" }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Reset tags and follow-up flags")
                    .accessibilityLabel("Clear flags and tags")
            }
        }
    }

    private struct GroupedPanel: View {
        let card: KanbanCardData
        @State private var groupName: String = ""
        @EnvironmentObject var viewModel: BillingHubViewModel
        @Environment(\.dismiss) private var dismiss
        // Removed notes state

        var body: some View {
            Group {
                Section("Group Details") {
                    TextField("Group Name", text: $groupName, prompt: Text("e.g., Morning Sessions"))
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                }
                
                Button("Create Draft Invoice") {
                    if case .session(let data) = card {
                        Task {
                            if let groupID = data.groupID {
                                await viewModel.createDraftInvoice(fromGroupID: groupID)
                            } else {
                                await viewModel.createInvoiceFromSessions([data.sessionId])
                            }
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .help("Generate a new draft invoice from this group of sessions")
                .accessibilityLabel("Create draft invoice")
                .accessibilityHint("Creates an editable draft invoice containing all sessions in this group.")
                
                Button("Ungroup") {
                    viewModel.dropIntoGroupedColumn(sessionID: card.id)
                    dismiss()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .help("Remove this session from the group while keeping it in Grouped")
                .accessibilityLabel("Ungroup session in grouped column")
            }
        }
    }

    private struct ReviewDraftsPanel: View {
        let card: KanbanCardData
        @State private var dueDate: Date = Date().addingTimeInterval(7*24*3600)
        @EnvironmentObject var viewModel: BillingHubViewModel
        @Environment(\.dismiss) private var dismiss
        // Removed reviewer notes state

        var body: some View {
            Group {
                Section {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .help("Expected date the payment should be received")
                }
                
                Button("Approve Draft") {
                    Task {
                        await viewModel.approveDraftInvoice(id: card.id, dueDate: dueDate)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .help("Approve this draft and move it to Ready to Send")
                .accessibilityLabel("Approve draft invoice")
                .accessibilityHint("Changes the invoice status to ready to send.")
                
                Button("Request Changes") {
                    Task {
                        await viewModel.requestChanges(for: card.id)
                        dismiss()
                    }
                }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Flag this draft for changes before approval")
                    .accessibilityLabel("Request changes")
                    .accessibilityHint("Flags the draft as needing revisions.")
            }
            .onAppear {
                if let invoice = viewModel.invoice(byId: card.id), let existingDueDate = invoice.dueDate {
                    dueDate = existingDueDate
                }
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
        @EnvironmentObject var viewModel: BillingHubViewModel
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            Group {
                Section("Recipients") {
                    TextField("To", text: $recipients, prompt: Text("recipient@domain.com"))
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .help("Primary email recipient for the invoice")
                        .textFieldStyle(.roundedBorder)

                    TextField("Cc", text: $cc, prompt: Text("optional"))
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .help("Additional email recipients to copy on the message")
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("Message Content") {
                    TextField("Subject", text: $subject, prompt: Text("Invoice"))
                        .submitLabel(.next)
                        .help("The subject line of the email")
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    
                    VStack(alignment: .leading) {
                        Text("Message").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $message)
                            .frame(minHeight: 120)
                            .help("Custom message to include in the email body")
                    }
                }
                
                Section {
                    Toggle("Attach PDF", isOn: $attachPDF)
                        .toggleStyle(.switch)
                        .help("Include the invoice as a PDF attachment")
                    Toggle("Send copy to myself", isOn: $sendCopy)
                        .toggleStyle(.switch)
                        .help("Send a BCC of this message to your account email")
                    Toggle("Schedule send", isOn: $scheduleSend)
                        .toggleStyle(.switch)
                        .help("Delay sending this message to a specific time")
                    if scheduleSend {
                        DatePicker("Send Date", selection: $scheduleDate)
                            .datePickerStyle(.compact)
                            .help("Select the date and time to send this invoice")
                    }
                }
                
                Button("Send") {
                    Task {
                        await viewModel.sendInvoice(id: card.id, recipients: recipients, subject: subject, message: message)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(recipients.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send invoice to recipients")
                .accessibilityHint("Finalizes the invoice and sends it via email.")

                Button("Mark as Sent (Manual)") {
                    Task {
                        await viewModel.updateInvoiceStatus(card.id, to: .pending)
                        dismiss()
                    }
                }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Move invoice to Sent when delivery happens outside this app")
                    .accessibilityLabel("Mark invoice as sent manually")
                
                Button("Send Test") {
                    Task {
                        await viewModel.sendTestInvoice(id: card.id, recipients: recipients, subject: subject, message: message)
                    }
                }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Send a copy to yourself to preview the layout")
                    .accessibilityLabel("Send test email")
                    .accessibilityHint("Sends a preview of the invoice to your own email address.")

                Button("Move Back to Draft Review") {
                    Task {
                        await viewModel.moveInvoiceBackToDraftReview(id: card.id)
                        dismiss()
                    }
                }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .controlSize(.regular)
                    .help("Return this invoice to Review Drafts for further edits")
                    .accessibilityLabel("Move invoice back to draft review")
            }
            .onAppear {
                guard let invoice = viewModel.invoice(byId: card.id) else { return }
                if recipients.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    recipients = invoice.clientEmail ?? ""
                }
                if subject == "Invoice" {
                    subject = "Invoice \(invoice.invoiceNumber)"
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
        @EnvironmentObject var viewModel: BillingHubViewModel
        @Environment(\.dismiss) private var dismiss
        // Removed notes state

        var body: some View {
            Group {
                Section("Payment Details") {
                    TextField("Amount", text: $amount, prompt: Text("$0.00"))
                        .monospacedDigit()
                        .submitLabel(.next)
                        .help("Total amount received")
                        .textFieldStyle(.roundedBorder)

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .help("The date the payment was received")
                    Picker("Method", selection: $method) {
                        Text("Bank Transfer").tag("Bank Transfer")
                        Text("Card").tag("Card")
                        Text("Cash").tag("Cash")
                        Text("Cheque").tag("Cheque")
                    }
                    .pickerStyle(.menu)
                    .help("The payment method used by the client")
                    TextField("Reference", text: $reference, prompt: Text("Receipt or transaction ID"))
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .help("Transaction reference number or notes")
                        .textFieldStyle(.roundedBorder)
                }
                
                Button("Mark as Completed") {
                    Task {
                        await viewModel.finalizePayment(
                            id: card.id,
                            amount: amount,
                            date: date,
                            method: method,
                            reference: reference
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .help("Record that payment has been received")
                .accessibilityLabel("Mark invoice as completed")
                .accessibilityHint("Updates the invoice status to completed and clears pending flags.")
                
                Button("Save Draft") {
                    Task {
                        await viewModel.savePaymentDraft(id: card.id, amount: amount, date: date, method: method, reference: reference)
                        dismiss()
                    }
                }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Save payment details as a draft without finalizing")
                    .accessibilityLabel("Save payment draft")

                Button("Mark as Overdue") {
                    Task {
                        await viewModel.markInvoiceOverdue(id: card.id)
                        dismiss()
                    }
                }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .help("Flag this invoice as overdue while keeping it in Payment")
                    .accessibilityLabel("Mark invoice as overdue")

                Button("Move Back to Ready to Send") {
                    Task {
                        await viewModel.moveInvoiceBackToReadyToSend(id: card.id)
                        dismiss()
                    }
                }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Return invoice to Ready to Send for delivery corrections")
                    .accessibilityLabel("Move invoice back to ready to send")
            }
            .onAppear {
                guard let invoice = viewModel.invoice(byId: card.id) else { return }
                if amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    amount = String(format: "%.2f", invoice.totalAmount)
                }
                if invoice.paidDate != nil {
                    date = invoice.paidDate ?? date
                }
                if let terms = invoice.paymentTerms, !terms.isEmpty {
                    method = terms
                }
            }
        }
    }

    private struct PaymentReceivedPanel: View {
        let card: KanbanCardData
        @State private var receiptEmail: String = ""
        @State private var includePDF: Bool = true
        @EnvironmentObject var viewModel: BillingHubViewModel
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            Group {
                Section {
                    Text("Payment has been received. You can send a receipt or export documents.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section("Receipt") {
                    TextField("Send receipt to", text: $receiptEmail, prompt: Text("accounts@client.com"))
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)

                    Toggle("Attach PDF receipt", isOn: $includePDF)
                        .toggleStyle(.switch)
                        .help("Include a PDF version of the payment receipt")
                }
                
                Button("Send Receipt") {
                    Task {
                        await viewModel.sendReceipt(id: card.id, recipientEmail: receiptEmail, includePDF: includePDF)
                        dismiss()
                    }
                }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .disabled(receiptEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("Send the payment receipt to the client")
                    .accessibilityLabel("Send receipt")
                    .accessibilityHint("Sends an email receipt with optional PDF attachment.")
                
                Button("Export PDF") {
                    Task {
                        _ = await viewModel.exportReceiptPDF(id: card.id)
                    }
                }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Download the receipt as a PDF file")
                    .accessibilityLabel("Export receipt PDF")

                Button("Reopen as Sent") {
                    Task {
                        await viewModel.reopenInvoiceAsPending(id: card.id)
                        dismiss()
                    }
                }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .controlSize(.regular)
                    .help("Move this invoice back to Sent/Pending when payment needs re-confirmation")
                    .accessibilityLabel("Reopen invoice as sent")
            }
            .onAppear {
                if receiptEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    receiptEmail = viewModel.invoice(byId: card.id)?.clientEmail ?? ""
                }
            }
        }
    }    
    private var serviceTypeField: some View {
        TextField("Service Type", text: $editedService)
            .submitLabel(.next)
            .focused($focusedField, equals: .serviceType)
            .textContentType(.name)
            .textFieldStyle(.roundedBorder)
            .help("The type of service provided during this session")
            .onAppear {
                switch card {
                case .session(let sessionData):
                    editedService = sessionData.serviceName
                case .invoice(let invoiceData):
                    editedService = invoiceData.serviceName
                }
            }
    }
    
    private var durationAmountRow: some View {
        Group {
            switch card {
            case .session(let sessionData):
                TextField("Duration", text: $editedDuration)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .duration)
                    .textFieldStyle(.roundedBorder)
                    .help("The total duration of the session (e.g., 1h 30m)")
                    .onAppear {
                        editedDuration = sessionData.duration
                    }
            case .invoice(let invoiceData):
                TextField("Amount", text: $editedAmount)
                    .monospacedDigit()
                    .submitLabel(.next)
                    .focused($focusedField, equals: .amount)
                    .textFieldStyle(.roundedBorder)
                    .help("The total monetary amount for this invoice")
                    .onAppear {
                        editedAmount = invoiceData.amount
                    }
            }
        }
    }
    
    private var clientField: some View {
        TextField("Client Name", text: $editedClient)
            .submitLabel(.done)
            .focused($focusedField, equals: .client)
            .textContentType(.name)
            .textFieldStyle(.roundedBorder)
            .help("The name of the client associated with this record")
            .onAppear {
                switch card {
                case .session(let sessionData):
                    editedClient = sessionData.clientName
                case .invoice(let invoiceData):
                    editedClient = invoiceData.clientName
                }
            }
    }
    
    private var priorityLevelSection: some View {
        Picker("Priority Level", selection: $selectedPriority) {
            Text("Low").tag(Priority.low)
            Text("Medium").tag(Priority.medium)
            Text("High").tag(Priority.high)
        }
        .pickerStyle(.segmented)
        .help("Set the urgency level for this session or invoice")
        .onAppear {
            switch card {
            case .session(let sessionData):
                selectedPriority = sessionData.priority
            case .invoice(let invoiceData):
                selectedPriority = invoiceData.priority
            }
        }
    }
    
    private var currentStatusSection: some View {
        LabeledContent {
            Text(statusText(for: card.currentWorkflowStatus))
                .lineLimit(1)
                .truncationMode(.tail)
        } label: {
            Text("Current Status")
                .fontWeight(.medium)
        }
        .help("View the current position of this record in the billing workflow")
    }
    
    private var sessionInfoCard: some View {
        Group {
            switch card {
            case .session(let sessionData):
                LabeledContent {
                    Text(sessionData.date)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } label: {
                    Text("Date")
                        .fontWeight(.medium)
                }
                
                LabeledContent {
                    Text(sessionData.startTime?.formatted(date: .omitted, time: .shortened) ?? "-")
                        .monospacedDigit()
                        .lineLimit(1)
                } label: {
                    Text("Start Time")
                        .fontWeight(.medium)
                }
                
                LabeledContent {
                    Text(sessionData.endTime?.formatted(date: .omitted, time: .shortened) ?? "-")
                        .monospacedDigit()
                        .lineLimit(1)
                } label: {
                    Text("End Time")
                        .fontWeight(.medium)
                }
            case .invoice(_):
                EmptyView()
            }
        }
    }
    

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
