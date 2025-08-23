import SwiftUI
import SwiftData

// MARK: - Left Column Layout Constants
private enum LeftColumnLayout {
    static let outerHorizontalPadding: CGFloat = 12
    static let outerVerticalPadding: CGFloat = 8
    static let sectionSpacing: CGFloat = 10
    static let rowSpacing: CGFloat = 6
    static let controlHorizontalPadding: CGFloat = 10
    static let controlVerticalPadding: CGFloat = 8
    static let headerHorizontalPadding: CGFloat = 12
    static let headerVerticalPadding: CGFloat = 8
}

struct NDISBillingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedClient: ClientEntity?
    @State private var selectedSessions: [SessionEntity] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var generatedInvoice: InvoiceEntity?
    @State private var showingInvoiceDetails = false
    @State private var selectedSession: SessionEntity?
    @State private var billingContext: NDISBillingContext = NDISBillingContext()
    @State private var sessionContexts: [SessionEntity.ID: NDISBillingContext] = [:]
    @State private var shouldAutoDetermine: Bool = false
    @Namespace private var glassTransition
    @State private var isSidebarVisible: Bool = true
    
    // Expandable section states
    @State private var isClientSectionExpanded = true
    @State private var isSessionSectionExpanded = true
    @State private var isPerSessionBillingExpanded = true
    @State private var expandedSessionIds: Set<SessionEntity.ID> = []
    
    private var billingService: NDISBillingIntegrationService {
        NDISBillingIntegrationService(modelContext: modelContext)
    }
    
    // Helper to get/set a session-specific billing context
    private func contextBinding(for session: SessionEntity) -> Binding<NDISBillingContext> {
        let sessionId = session.id
        return Binding<NDISBillingContext>(
            get: { sessionContexts[sessionId] ?? NDISBillingContext() },
            set: { newValue in
                sessionContexts[sessionId] = newValue
            }
        )
    }
    
    var body: some View {
        CustomHSplitView(fraction: 0.35, isPrimaryVisible: $isSidebarVisible) {
            // Compact Sidebar
            VStack(spacing: 0) {
                // Compact Header
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    Text("NDIS Billing")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Spacer()
                }
                .padding(.horizontal, LeftColumnLayout.headerHorizontalPadding)
                .padding(.vertical, LeftColumnLayout.headerVerticalPadding)
                .glassEffect(in: Rectangle())
                
                // Scrollable Content (flattened, minimal nesting)
                ScrollView {
                    VStack(spacing: LeftColumnLayout.sectionSpacing) {
                        // Client Selection
                        GlassEffectContainer(spacing: 12) {
                        CompactExpandableSection(
                            title: "Client Selection",
                            isExpanded: $isClientSectionExpanded,
                            icon: "person.fill"
                        ) {
                            VStack(alignment: .leading, spacing: LeftColumnLayout.rowSpacing) {
                                // Selected client chip or search field
                            if let client = selectedClient {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(client.fullName)
                                                .font(.system(size: 11, weight: .medium))
                                                .lineLimit(1)
                                            if !client.ndisNumber.isEmpty {
                                                Text("NDIS: \(client.ndisNumber)")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        Button(action: {
                                    selectedClient = nil
                                    selectedSessions = []
                                            selectedSession = nil
                                    billingContext = NDISBillingContext()
                                    sessionContexts = [:]
                                    expandedSessionIds.removeAll()
                                    shouldAutoDetermine = false
                                        }) {
                                            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                        }
                                        .padding(6)
                                        .contentShape(Rectangle())
                                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 6))
                                        .glassEffectID("clear-client", in: glassTransition)
                                        .help("Clear selected client")
                                        .appInteractiveCursor()
                                }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 6))
                            } else {
                                    HStack(spacing: LeftColumnLayout.rowSpacing) {
                                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                                        TextField("Search clients...", text: $searchText)
                                            .textFieldStyle(.plain)
                                            .font(.system(size: 11))
                                    }
                                    .padding(.horizontal, LeftColumnLayout.controlHorizontalPadding)
                                    .padding(.vertical, LeftColumnLayout.controlVerticalPadding)
                                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 6))

                                    // Client list
                                    let clients = allClients
                                    let filtered = clients.filter { searchText.isEmpty || $0.fullName.localizedCaseInsensitiveContains(searchText) || $0.ndisNumber.localizedCaseInsensitiveContains(searchText) }
                                    LazyVStack(spacing: LeftColumnLayout.rowSpacing) {
                                        ForEach(filtered, id: \.id) { client in
                                             Button(action: {
                                                                            selectedClient = client
                                    selectedSessions = []
                                                selectedSession = nil
                                    billingContext = NDISBillingContext()
                                    sessionContexts = [:]
                                    expandedSessionIds.removeAll()
                                    shouldAutoDetermine = false
                                             }) {
                                                HStack(spacing: LeftColumnLayout.rowSpacing) {
                                                    Text(client.fullName).font(.system(size: 11)).lineLimit(1)
                                                    Spacer()
                                                    if !client.ndisNumber.isEmpty {
                                                        Text(client.ndisNumber).font(.system(size: 9)).foregroundColor(.secondary)
                                                    }
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, LeftColumnLayout.controlHorizontalPadding)
                                                .padding(.vertical, LeftColumnLayout.controlVerticalPadding - 2)
                                                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 6))
                                                .contentShape(RoundedRectangle(cornerRadius: 6))
                                              }
                                              .buttonStyle(.plain)
                                              .help("Select client")
                                              .glassEffectID("client-row-\(client.id)", in: glassTransition)
                                              .appInteractiveCursor()
                                        }
                                    }
                                    .frame(maxHeight: 220)
                                }
                            }
                            .padding(.top, 4)
                        }
                        }

                        // Sessions & Per-Session Billing (consolidated)
                        if let client = selectedClient {
                            GlassEffectContainer {
                            CompactExpandableSection(
                                title: "Sessions & Billing",
                                isExpanded: $isSessionSectionExpanded,
                                icon: "slider.vertical.3"
                            ) {
                                let sessions = sessions(for: client)
                                VStack(alignment: .leading, spacing: LeftColumnLayout.rowSpacing) {
                                    HStack(spacing: LeftColumnLayout.rowSpacing) {
                                        Text("\(selectedSessions.count) of \(sessions.count) session(s) selected")
                                            .font(.system(size: 10)).foregroundColor(.secondary)
                                        Spacer()
                                        if !selectedSessions.isEmpty {
                                            Button {
                                                selectedSessions.removeAll()
                                                expandedSessionIds.removeAll()
                                                shouldAutoDetermine = false
                                                didChangeSessions()
                                            } label: {
                                                Label("Clear", systemImage: "xmark.circle")
                                                    .labelStyle(.iconOnly)
                                                    .foregroundColor(.red)
                                            }
                                            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 6))
                                            .glassEffectID("clear-sessions", in: glassTransition)
                                            .help("Clear selected sessions")
                                            .appInteractiveCursor()
                                        }
                                    }
                                    // Selectable rows
                                    LazyVStack(spacing: LeftColumnLayout.rowSpacing - 2) {
                                        ForEach(sessions, id: \.id) { s in
                                            VStack(spacing: 6) {
                                                Button(action: {
                                                    if let idx = selectedSessions.firstIndex(of: s) { selectedSessions.remove(at: idx) } else { selectedSessions.append(s) }
                                                    didChangeSessions()
                                                }) {
                                                    HStack(spacing: LeftColumnLayout.rowSpacing) {
                                                        VStack(alignment: .leading, spacing: 1) {
                                                            if let start = s.startTime { Text(start, style: .date).font(.system(size: 10, weight: .medium)) }
                                                            if let start = s.startTime { Text(start, style: .time).font(.system(size: 9)).foregroundColor(.secondary) }
                                                        }
                                                        Spacer()
                                                        if let code = s.clientService?.ndisCode { Text(code).font(.system(size: 9)).foregroundColor(.blue) }
                                                        Image(systemName: selectedSessions.contains(s) ? "checkmark.circle.fill" : "circle")
                                                            .foregroundColor(selectedSessions.contains(s) ? .blue : .secondary)
                                                            .animation(.easeInOut(duration: 0.2), value: selectedSessions.contains(s))
                                                }
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .padding(.horizontal, LeftColumnLayout.controlHorizontalPadding - 2)
                                                    .padding(.vertical, LeftColumnLayout.controlVerticalPadding - 4)
                                                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 6))
                                                    .glassEffectID("session-row-\(s.id)", in: glassTransition)
                                                    .contentShape(RoundedRectangle(cornerRadius: 6))
                                                }
                                                 .buttonStyle(.plain)
                                                 .help("Select/Deselect session")
                                                 .appInteractiveCursor()

                                                // Per-session editor inline below the row when selected and expanded
                                                if selectedSessions.contains(s) {
                                                    Button(action: {
                                                        if expandedSessionIds.contains(s.id) { expandedSessionIds.remove(s.id) } else { expandedSessionIds.insert(s.id) }
                                                    }) {
                                                        HStack {
                                                            Text(expandedSessionIds.contains(s.id) ? "Hide Billing Context" : "Show Billing Context")
                                                                .font(.system(size: 10, weight: .semibold))
                                                                .foregroundColor(.secondary)
                                                            Spacer()
                                                            Image(systemName: expandedSessionIds.contains(s.id) ? "chevron.down" : "chevron.right")
                                                                .font(.system(size: 10, weight: .semibold))
                                                                .rotationEffect(.degrees(expandedSessionIds.contains(s.id) ? 0 : 0))
                                                                .animation(.easeInOut(duration: 0.2), value: expandedSessionIds.contains(s.id))
                                                    }
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                        .padding(.horizontal, LeftColumnLayout.controlHorizontalPadding - 2)
                                                        .padding(.vertical, LeftColumnLayout.controlVerticalPadding - 6)
                                                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 6))
                                                        .glassEffectID("session-toggle-\(s.id)", in: glassTransition)
                                                        .contentShape(RoundedRectangle(cornerRadius: 6))
                                                    }
                                                     .buttonStyle(.plain)
                                                     .help("Expand/Collapse billing context")
                                                     .appInteractiveCursor()

                                                    if expandedSessionIds.contains(s.id) {
                                                        ScrollView {
                                                            CompactNDISBillingContextView(
                                                                billingContext: contextBinding(for: s),
                                                                session: s,
                                                                shouldAutoDetermine: shouldAutoDetermine
                                                            )
                                                            .padding(.horizontal, LeftColumnLayout.controlHorizontalPadding)
                                                            .padding(.vertical, LeftColumnLayout.controlVerticalPadding)
                                                        }
                                                        .frame(height: 240)
                                                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                            }
                        }

                        // Old standalone Session Selection section removed; consolidated above



                        // Generate Invoice
                        if !selectedSessions.isEmpty {
                            Button(action: generateInvoice) {
                                HStack(spacing: 6) {
                                    if isLoading { ProgressView().scaleEffect(0.7) }
                                    Text(isLoading ? "Generating..." : "Generate Invoice")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                            }
                            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 8))
                            .opacity(isLoading ? 0.8 : 1)
                            .disabled(isLoading)
                            .padding(.top, LeftColumnLayout.sectionSpacing)
                            .appInteractiveCursor()
                        }
                    }
                    .padding(.horizontal, LeftColumnLayout.outerHorizontalPadding)
                    .padding(.vertical, LeftColumnLayout.outerVerticalPadding)
                }
                .scrollEdgeEffectStyle(.hard, for: .top)
            }
        } secondary: {
            // Detail View
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Invoice Preview")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    if let client = selectedClient {
                        Text("Client: \(client.fullName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .glassEffect(.regular, in: Rectangle())
                .contentShape(Rectangle())
                .help("Preview of the invoice for selected sessions")
                
                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        // Generated Invoice
                        if let invoice = generatedInvoice {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Generated Invoice")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                GeneratedInvoiceView(invoice: invoice)
                            }
                        }
                        
                        // Invoice Preview (only after automation finishes)
                        else if !selectedSessions.isEmpty && shouldAutoDetermine {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                Text("Invoice Preview")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    Spacer()
                                    Button(action: { didChangeSessions() }) {
                                        Label("Refresh", systemImage: "arrow.clockwise")
                                            .labelStyle(.titleAndIcon)
                                            .font(.caption)
                                    }
                                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 6))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .contentShape(RoundedRectangle(cornerRadius: 6))
                                     .help("Re-run automation and refresh preview")
                                     .appInteractiveCursor()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 6))
                                .contentShape(RoundedRectangle(cornerRadius: 6))
                                
                                InvoicePreviewView(
                                    sessions: selectedSessions,
                                    billingContext: billingContext,
                                    perSessionBillingContexts: sessionContexts
                                )
                                    .id(billingContext)
                            }
                        } else if !selectedSessions.isEmpty && !shouldAutoDetermine {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    ProgressView().scaleEffect(0.8)
                                    Text("Preparing preview… running automation")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Text("The preview will appear once the automation has determined billing context.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Error Message
                        if let errorMessage = errorMessage {
                            ErrorMessageView(message: errorMessage)
                        }
                        
                        // Empty State
                        else if selectedSession == nil {
                            EmptyStateView(
                                icon: "doc.text",
                                title: "No Session Selected",
                                message: "Select a client and session to preview the invoice"
                            )
                        }
                    }
                    .padding()
                }
                .scrollEdgeEffectStyle(.hard, for: .top)
            }
        } splitter: { _ in
            Splitter()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { withAnimation(.easeInOut(duration: 0.25)) { isSidebarVisible.toggle() } }) {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle Sidebar")
                .appInteractiveCursor()
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: generateInvoice) {
                    Label("Generate Invoice", systemImage: "doc.text")
                }
                .disabled(selectedSessions.isEmpty || isLoading)
                .help("Generate an invoice for the selected sessions")
                .appInteractiveCursor()
            }
        }
    }
    
    private func generateInvoice() {
        guard !selectedSessions.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                guard let client = selectedClient else { 
                    await MainActor.run {
                        errorMessage = "No client selected"
                        isLoading = false
                    }
                    return
                }
                
                let invoice = try billingService.generateNDISInvoice(
                    for: selectedSessions,
                    client: client
                )
                
                await MainActor.run {
                    generatedInvoice = invoice
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Minimal Data Helpers
private extension NDISBillingContainerView {
    var allClients: [ClientEntity] {
        let descriptor = FetchDescriptor<ClientEntity>(sortBy: [SortDescriptor(\.fullName)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func sessions(for client: ClientEntity) -> [SessionEntity] {
        let clientId = client.id
        let descriptor = FetchDescriptor<SessionEntity>(
            predicate: #Predicate<SessionEntity> { $0.client?.id == clientId },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func didChangeSessions() {
        if let session = selectedSessions.first {
            selectedSession = session
            Task {
                let orchestrator = NDISBillingAutomationOrchestrator(modelContext: modelContext)
                // Run automation for each selected session and store its context
                for s in selectedSessions {
                    var ctx = sessionContexts[s.id] ?? billingContext
                    let _ = await orchestrator.executeAutomationFlow(for: s, context: &ctx)
                    sessionContexts[s.id] = ctx
                }
                await MainActor.run {
                    shouldAutoDetermine = true
                }
            }
        } else {
            selectedSession = nil
            billingContext = NDISBillingContext()
            sessionContexts = [:]
            shouldAutoDetermine = false
        }
    }
}

// MARK: - Compact Expandable Section

struct CompactExpandableSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    let icon: String
    let content: Content
    @State private var isHovering = false
    
    init(
        title: String,
        isExpanded: Binding<Bool>,
        icon: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self._isExpanded = isExpanded
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with liquid glass styling
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                ZStack {
                    // Base gray background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                    
                    // Hover glass effect
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                        .opacity(isHovering ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: isHovering)
                    
                    // Border
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isHovering ? Color.blue.opacity(0.8) : Color.white.opacity(0.1), lineWidth: 1)
                        .animation(.easeInOut(duration: 0.2), value: isHovering)
                    
                    HStack(spacing: LeftColumnLayout.rowSpacing) {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(width: 16)
                        
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .rotationEffect(.degrees(isExpanded ? 0 : 0))
                            .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    }
                    .padding(.horizontal, LeftColumnLayout.controlHorizontalPadding)
                    .padding(.vertical, LeftColumnLayout.controlVerticalPadding - 2)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
            
            // Content with liquid glass background
            if isExpanded {
                VStack(spacing: LeftColumnLayout.rowSpacing) {
                    content
                }
                .padding(.horizontal, LeftColumnLayout.controlHorizontalPadding)
                .padding(.vertical, LeftColumnLayout.controlVerticalPadding)
                .glassEffect(in: RoundedRectangle(cornerRadius: 6))
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
        }
    }
}

// MARK: - Compact Billing Context

struct CompactNDISBillingContextView: View {
    @Binding var billingContext: NDISBillingContext
    let session: SessionEntity
    let shouldAutoDetermine: Bool
    @Environment(\.modelContext) private var modelContext
    
    // Expandable section states
    @State private var isServiceTypeExpanded = true
    @State private var isLocationTimeExpanded = true
    @State private var isTravelTransportExpanded = true
    @State private var isSpecialCircumstancesExpanded = false
    
    private var automationOrchestrator: NDISBillingAutomationOrchestrator {
        NDISBillingAutomationOrchestrator(modelContext: modelContext)
    }
    
    private var ndisItem: NDISItemEntity? {
        session.clientService?.ndisItem
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Support Item Display
            if let clientService = session.clientService,
               let ndisItem = clientService.ndisItem {
                CompactContextRow(
                    title: "Support",
                    value: "\(ndisItem.category ?? "Unknown") - \(ndisItem.itemNumber)",
                    isSet: true
                )
                .padding(.bottom, 4)
            }
            
            // Service Type Section (Expandable)
            CompactExpandableSection(
                title: "Service Type",
                isExpanded: $isServiceTypeExpanded,
                icon: "person.2.fill"
            ) {
                VStack(spacing: 4) {
                    CompactBillingToggle(
                        title: "Complex Behavior",
                        isOn: $billingContext.isComplexBehavior,
                        isAutoDetermined: false,
                        isDisabled: !automationOrchestrator.isComplexBehaviorSupported(for: session)
                    )
                    
                    CompactBillingToggle(
                        title: "High Intensity",
                        isOn: $billingContext.isHighIntensity,
                        isAutoDetermined: false,
                        isDisabled: !automationOrchestrator.isHighIntensitySupported(for: session)
                    )
                    
                    CompactBillingToggle(
                        title: "Group Support",
                        isOn: $billingContext.isGroupSupport,
                        isAutoDetermined: billingContext.autoDeterminedValues.contains(.groupSupport),
                        isDisabled: false
                    )
                    
                    CompactBillingToggle(
                        title: "Telehealth",
                        isOn: $billingContext.isTelehealth,
                        isAutoDetermined: false,
                        isDisabled: ndisItem?.nonFaceToFaceProvision != true
                    )
                }
                .padding(.top, 4)
            }
            
            // Location & Time Section (Expandable)
            CompactExpandableSection(
                title: "Location & Time",
                isExpanded: $isLocationTimeExpanded,
                icon: "location.fill"
            ) {
                VStack(spacing: 4) {
                    CompactBillingToggle(
                        title: "Remote Area",
                        isOn: $billingContext.isRemoteArea,
                        isAutoDetermined: billingContext.autoDeterminedValues.contains(.remoteArea),
                        isDisabled: false
                    )
                    
                    CompactBillingToggle(
                        title: "Very Remote Area",
                        isOn: $billingContext.isVeryRemoteArea,
                        isAutoDetermined: billingContext.autoDeterminedValues.contains(.veryRemoteArea),
                        isDisabled: false
                    )
                    
                    CompactBillingToggle(
                        title: "Public Holiday",
                        isOn: $billingContext.isPublicHoliday,
                        isAutoDetermined: billingContext.autoDeterminedValues.contains(.publicHoliday),
                        isDisabled: false
                    )
                    
                    CompactBillingToggle(
                        title: "Evening",
                        isOn: $billingContext.isEvening,
                        isAutoDetermined: billingContext.autoDeterminedValues.contains(.evening),
                        isDisabled: false
                    )
                    
                    CompactBillingToggle(
                        title: "Night",
                        isOn: $billingContext.isNight,
                        isAutoDetermined: billingContext.autoDeterminedValues.contains(.night),
                        isDisabled: false
                    )
                    
                    CompactBillingToggle(
                        title: "Weekend",
                        isOn: $billingContext.isWeekend,
                        isAutoDetermined: billingContext.autoDeterminedValues.contains(.weekend),
                        isDisabled: false
                    )
                }
                .padding(.top, 4)
            }
            
            // Travel & Transport Section (Expandable)
            CompactExpandableSection(
                title: "Travel & Transport",
                isExpanded: $isTravelTransportExpanded,
                icon: "car.fill"
            ) {
                VStack(spacing: 4) {
                    CompactBillingToggle(
                        title: "Provider Travel",
                        isOn: $billingContext.isProviderTravel,
                        isAutoDetermined: billingContext.autoDeterminedValues.contains(.providerTravel),
                        isDisabled: false
                    )
                    
                    CompactBillingToggle(
                        title: "Activity Transport",
                        isOn: $billingContext.isActivityTransport,
                        isAutoDetermined: billingContext.autoDeterminedValues.contains(.activityTransport),
                        isDisabled: false
                    )
                }
                .padding(.top, 4)
            }
            
            // Special Circumstances Section (Expandable)
            CompactExpandableSection(
                title: "Special Circumstances",
                isExpanded: $isSpecialCircumstancesExpanded,
                icon: "exclamationmark.triangle.fill"
            ) {
                VStack(spacing: 4) {
                    CompactBillingToggle(
                        title: "Shadow Shift",
                        isOn: $billingContext.isShadowShift,
                        isAutoDetermined: billingContext.autoDeterminedValues.contains(.shadowShift),
                        isDisabled: false
                    )
                    
                    CompactBillingToggle(
                        title: "SIL Unplanned Exit",
                        isOn: $billingContext.isSilUnplannedExit,
                        isAutoDetermined: billingContext.autoDeterminedValues.contains(.silUnplannedExit),
                        isDisabled: false
                    )
                    
                    CompactBillingToggle(
                        title: "NDIA Report",
                        isOn: $billingContext.isNdiaReport,
                        isAutoDetermined: billingContext.autoDeterminedValues.contains(.ndiaReport),
                        isDisabled: false
                    )
                    
                    CompactBillingToggle(
                        title: "Short Notice Cancellation",
                        isOn: $billingContext.isShortNoticeCancellation,
                        isAutoDetermined: billingContext.autoDeterminedValues.contains(.shortNoticeCancellation),
                        isDisabled: false
                    )
                    
                    CompactBillingToggle(
                        title: "Prepayment",
                        isOn: $billingContext.isPrepayment,
                        isAutoDetermined: billingContext.autoDeterminedValues.contains(.prepayment),
                        isDisabled: false
                    )
                }
                .padding(.top, 4)
            }
        }
    }
}

struct CompactBillingToggle: View {
    let title: String
    @Binding var isOn: Bool
    let isAutoDetermined: Bool
    let isDisabled: Bool
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            // Base liquid glass background
            RoundedRectangle(cornerRadius: 6)
                .glassEffect()
            
            // Hover glass effect
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
                .opacity(isHovering ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isHovering)
            
            // Border
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHovering ? Color.blue.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                .animation(.easeInOut(duration: 0.2), value: isHovering)
            
            HStack {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 10))
                        .foregroundColor(isDisabled ? .white.opacity(0.4) : .white.opacity(0.8))
                    
                    if isAutoDetermined {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 8))
                            .foregroundColor(.blue.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .scaleEffect(0.7)
                    .disabled(isDisabled)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .opacity(isDisabled ? 0.6 : 1.0)
        .onHover { hovering in
            if !isDisabled {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
        }
    }
}

struct CompactContextRow: View {
    let title: String
    let value: String
    let isSet: Bool
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            // Base liquid glass background
            RoundedRectangle(cornerRadius: 6)
                .glassEffect()
            
            // Special background for active/set items
            if isSet {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.green.opacity(0.1))
            }
            
            // Hover glass effect
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
                .opacity(isHovering ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isHovering)
            
            // Border
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSet ? Color.green.opacity(0.6) : (isHovering ? Color.blue.opacity(0.6) : Color.white.opacity(0.1)), lineWidth: 1)
                .animation(.easeInOut(duration: 0.2), value: isHovering)
            
            HStack {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 60, alignment: .leading)
                
                Text(value)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSet ? .white.opacity(0.9) : .white.opacity(0.6))
                    .lineLimit(1)
                
                Spacer()
                
                if isSet {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.green.opacity(0.8))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Generated Invoice View

struct GeneratedInvoiceView: View {
    let invoice: InvoiceEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("NDIS INVOICE")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(invoice.invoiceNumber)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Divider()
            
            // Client Info
            if let client = invoice.client {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Client: \(client.fullName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if !client.ndisNumber.isEmpty {
                        Text("NDIS: \(client.ndisNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Invoice Details
            VStack(alignment: .leading, spacing: 4) {
                Text("Issue Date: \(invoice.issueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                
                if let dueDate = invoice.dueDate {
                    Text("Due Date: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                }
                
                Text("Status: \(invoice.status ?? "Draft")")
                    .font(.subheadline)
                    .foregroundColor(statusColor)
            }
            .foregroundColor(.secondary)
            
            Divider()
            
            // Line Items
            if let items = invoice.items, !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Billable Items")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.itemDescription.isEmpty ? "NDIS Support Item" : item.itemDescription)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if !item.itemDescription.isEmpty {
                                    Text("Item: \(item.itemDescription)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Text(String(format: "$%.2f", item.quantity * item.rate))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        if index < items.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            
            Divider()
            
            // Summary
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Text("Subtotal:")
                    Spacer()
                    Text(String(format: "$%.2f", invoice.totalAmount))
                }
                
                HStack {
                    Text("GST:")
                    Spacer()
                    Text(String(format: "$%.2f", invoice.totalAmount * 0.1))
                }
                
                Divider()
                
                HStack {
                    Text("TOTAL:")
                        .fontWeight(.bold)
                    Spacer()
                    Text(String(format: "$%.2f", invoice.totalAmount * 1.1))
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                }
            }
            .font(.subheadline)
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 8))
    }
    
    private var statusColor: Color {
        switch invoice.status?.lowercased() {
        case "paid":
            return .green
        case "overdue":
            return .red
        case "draft":
            return .orange
        default:
            return .secondary
        }
    }
}



// MARK: - Unified Invoice Preview View (single or multiple sessions)

struct InvoicePreviewView: View {
    @Environment(\.modelContext) private var modelContext
    let sessions: [SessionEntity]
    let billingContext: NDISBillingContext
    let perSessionBillingContexts: [SessionEntity.ID: NDISBillingContext]
    
    private var billingService: NDISBillingIntegrationService {
        NDISBillingIntegrationService(modelContext: modelContext)
    }
    
    private struct PreviewItem: Identifiable {
        let id = UUID()
        let session: SessionEntity
        let items: [InvoiceItemEntity]
        let total: Double
    }
    
    private func fallbackItems(for session: SessionEntity) -> [InvoiceItemEntity] {
        guard let clientService = session.clientService,
              let start = session.startTime,
              let end = session.endTime else { return [] }
        let duration = max(0, end.timeIntervalSince(start) / 3600.0)
        let item = InvoiceItemEntity(id: UUID(), itemDescription: clientService.computedServiceName)
        item.quantity = duration
        item.rate = clientService.computedRate
        item.unit = clientService.computedUnit
        item.serviceDate = start
        item.session = session
        item.date = start
        item.amount = duration * clientService.computedRate
        return [item]
    }

    private var previewData: [PreviewItem] {
        sessions.compactMap { session in
            do {
                // Prefer per-session context when available, otherwise fall back to global
                let ctx = perSessionBillingContexts[session.id] ?? billingContext
                let claimable = try billingService.calculateBillableAmounts(for: session, billingContext: ctx)
                var items = billingService.convertToInvoiceItems(claimable, for: session)
                // Inject travel/parking/tolls preview lines if the engine didn't provide them
                items = appendTravelPreviewItemsIfNeeded(items: items, session: session, context: ctx)
                if items.isEmpty {
                    items = fallbackItems(for: session)
                }
                let total = items.reduce(0) { $0 + $1.amount }
                return items.isEmpty ? nil : PreviewItem(session: session, items: items, total: total)
            } catch {
                var items = fallbackItems(for: session)
                items = appendTravelPreviewItemsIfNeeded(items: items, session: session, context: perSessionBillingContexts[session.id] ?? billingContext)
                let total = items.reduce(0) { $0 + $1.amount }
                return items.isEmpty ? nil : PreviewItem(session: session, items: items, total: total)
            }
        }
    }

    // Injects travel-based preview items derived from the current billingContext when the engine doesn't add them
    private func appendTravelPreviewItemsIfNeeded(items: [InvoiceItemEntity], session: SessionEntity, context: NDISBillingContext) -> [InvoiceItemEntity] {
        var extended = items
        // If provider travel context is active, add KM-based line when missing
        if context.isProviderTravel && context.travelDistance > 0 {
            let alreadyHasTravel = items.contains { ($0.claimType ?? "") == "ProviderTravel" || $0.itemDescription.localizedCaseInsensitiveContains("Travel") }
            if !alreadyHasTravel {
                let perKmRate: Double = 0.85 // preview fallback
                let travel = InvoiceItemEntity(id: UUID(), itemDescription: "Provider Travel")
                travel.quantity = context.travelDistance
                travel.rate = perKmRate
                travel.unit = "km"
                travel.serviceDate = session.startTime ?? Date()
                travel.session = session
                travel.date = session.startTime ?? Date()
                travel.amount = travel.quantity * travel.rate
                extended.append(travel)
            }
        }
        // Add tolls/parking if present and missing
        if context.travelTolls > 0 {
            let hasTolls = items.contains { $0.itemDescription.localizedCaseInsensitiveContains("Toll") }
            if !hasTolls {
                let tolls = InvoiceItemEntity(id: UUID(), itemDescription: "Travel Tolls")
                tolls.quantity = 1
                tolls.rate = context.travelTolls
                tolls.unit = "each"
                tolls.serviceDate = session.startTime ?? Date()
                tolls.session = session
                tolls.date = session.startTime ?? Date()
                tolls.amount = tolls.rate
                extended.append(tolls)
            }
        }
        if context.travelParking > 0 {
            let hasParking = items.contains { $0.itemDescription.localizedCaseInsensitiveContains("Parking") }
            if !hasParking {
                let parking = InvoiceItemEntity(id: UUID(), itemDescription: "Travel Parking")
                parking.quantity = 1
                parking.rate = context.travelParking
                parking.unit = "each"
                parking.serviceDate = session.startTime ?? Date()
                parking.session = session
                parking.date = session.startTime ?? Date()
                parking.amount = parking.rate
                extended.append(parking)
            }
        }
        return extended
    }
    
    private var grandTotal: Double {
        previewData.reduce(0) { $0 + $1.total }
    }
    
    // Flattened list of all items across sessions for single table rendering
    private var allLineItems: [InvoiceItemEntity] {
        previewData.flatMap { $0.items }
    }
    
    // Resolve an item number to display for a given invoice item
    private func displayItemNumber(for item: InvoiceItemEntity) -> String {
        if let n = item.ndisItemNumber, !n.isEmpty { return n }
        if let code = item.session?.clientService?.ndisItem?.itemNumber, !code.isEmpty { return code }
        if let code = item.session?.clientService?.ndisCode, !code.isEmpty { return code }
        return ""
    }
    
    // MARK: - Header helpers
    private var previewBusiness: BusinessEntity? {
        (try? modelContext.fetch(FetchDescriptor<BusinessEntity>()))?.first
    }
    private var previewClient: ClientEntity? {
        sessions.first?.client
    }
    private var nextInvoiceNumber: String {
        generateNextInvoiceNumber(for: previewClient)
    }
    private var issueDate: Date { Date() }
    private var paymentTermsDays: Int {
        let days = UserDefaults.standard.integer(forKey: "defaultPaymentTerms")
        return days > 0 ? days : 14
    }
    private var dueDate: Date {
        Calendar.current.date(byAdding: .day, value: paymentTermsDays, to: Date()) ?? Date()
    }
    private var gstRate: Double {
        let rate = UserDefaults.standard.double(forKey: "taxRate")
        return rate
    }
    private var paymentTermsText: String {
        UserDefaults.standard.string(forKey: "defaultPaymentTermsText") ?? "Payment due within \(paymentTermsDays) days."
    }
    
    // Date formatter: dd/MM/yyyy for headers and table
    private let ddMMyyyyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    // Reuse the existing invoice number generation logic from InvoicesViewModel
    private func generateNextInvoiceNumber(for client: ClientEntity?) -> String {
        guard let cl = client else {
            let genericDescriptor = FetchDescriptor<InvoiceEntity>(predicate: #Predicate<InvoiceEntity> { $0.invoiceNumber.starts(with: "INV-") })
            let existingInvoices = (try? modelContext.fetch(genericDescriptor)) ?? []
            let existingNumbers = existingInvoices.compactMap { inv -> Int? in
                inv.invoiceNumber.split(separator: "-").last.flatMap { Int($0) }
            }
            let highestNumber = existingNumbers.max() ?? 0
            return String(format: "INV-%04d", highestNumber + 1)
        }

        let nameParts = cl.fullName.split(separator: " ").map { String($0) }
        guard let firstName = nameParts.first, !firstName.isEmpty,
              let lastName = nameParts.last, !lastName.isEmpty else {
            return generateNextInvoiceNumber(for: nil)
        }

        let surnamePart = String(lastName.uppercased().prefix(4))
        let firstNameInitial = String(firstName.uppercased().prefix(1))
        let clientPrefix = "\(surnamePart)-\(firstNameInitial)-"

        let fetchDescriptor = FetchDescriptor<InvoiceEntity>()
        let allInvoices = (try? modelContext.fetch(fetchDescriptor)) ?? []
        let existingClientInvoices = allInvoices.filter { inv in
            inv.invoiceNumber.starts(with: clientPrefix) && inv.client?.id == cl.id
        }
        let existingSuffixes = existingClientInvoices.compactMap { inv -> Int? in
            guard inv.invoiceNumber.starts(with: clientPrefix) else { return nil }
            return Int(String(inv.invoiceNumber.dropFirst(clientPrefix.count)))
        }
        let highestSuffix = existingSuffixes.max() ?? 0
        return "\(clientPrefix)\(String(format: "%04d", highestSuffix + 1))"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if previewData.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No billable line items found for the selected sessions")
                        .font(.subheadline).foregroundColor(.secondary)
                    Text("Tip: Ensure sessions have start/end times and a linked client service with a rate.")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding()
                .background(Color.black.opacity(0.06))
                .cornerRadius(8)
            }

            // Tax Invoice Header
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TAX INVOICE")
                            .font(.title3).fontWeight(.bold)
                        if let biz = previewBusiness {
                            Text(biz.name).font(.subheadline).fontWeight(.semibold)
                            if !biz.abn.isEmpty { Text("ABN: \(biz.abn)").font(.caption).foregroundColor(.secondary) }
                            if let addr = biz.address { Text(addr.fullFormattedAddress).font(.caption).foregroundColor(.secondary) }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Invoice No: \(nextInvoiceNumber)").font(.caption)
                        Text("Issue Date: \(ddMMyyyyFormatter.string(from: issueDate))").font(.caption)
                        Text("Due Date: \(ddMMyyyyFormatter.string(from: dueDate))").font(.caption)
                    }
                }
                Divider()
                HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                        Text("BILL TO").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                        if let client = previewClient {
                            Text(client.fullName).font(.subheadline).fontWeight(.medium)
                            if !client.ndisNumber.isEmpty { Text("NDIS: \(client.ndisNumber)").font(.caption).foregroundColor(.secondary) }
                            if let addr = client.address { Text(addr.fullFormattedAddress).font(.caption).foregroundColor(.secondary) }
                        }
                    }
                    Spacer()
                }
            }
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 8))

            // Single consolidated table across all sessions
            VStack(spacing: 0) {
                // Column headers
                HStack {
                    Text("Service Date")
                        .font(.caption).fontWeight(.semibold)
                        .frame(width: 120, alignment: .leading)
                    Text("Description")
                        .font(.caption).fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Qty")
                        .font(.caption).fontWeight(.semibold)
                        .frame(width: 60, alignment: .trailing)
                    Text("Rate")
                        .font(.caption).fontWeight(.semibold)
                        .frame(width: 90, alignment: .trailing)
                    Text("Amount")
                        .font(.caption).fontWeight(.semibold)
                        .frame(width: 100, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)

                ForEach(Array(allLineItems.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top) {
                        Text(ddMMyyyyFormatter.string(from: item.serviceDate))
                            .font(.caption.monospacedDigit())
                            .frame(width: 120, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.itemDescription.isEmpty ? "NDIS Support Item" : item.itemDescription)
                                    .font(.caption)
                                .foregroundColor(.primary)
                            Text("Item: \(displayItemNumber(for: item))")
                                .font(.caption2)
                                    .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(String(format: "%.2f", item.quantity))
                            .font(.caption.monospacedDigit())
                            .frame(width: 60, alignment: .trailing)
                        
                        Text(String(format: "$%.2f", item.rate))
                            .font(.caption.monospacedDigit())
                            .frame(width: 90, alignment: .trailing)

                        Text(String(format: "$%.2f", item.lineTotal))
                            .font(.caption.monospacedDigit()).fontWeight(.medium)
                            .frame(width: 100, alignment: .trailing)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(idx % 2 == 0 ? Color.white.opacity(0.03) : Color.clear)
                    if idx < allLineItems.count - 1 {
                        Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1)
                    }
                }

                // Summary rows inside the table
                Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                HStack {
                    Text("").frame(width: 120)
                    Text("").frame(maxWidth: .infinity, alignment: .leading)
                    Text("").frame(width: 60, alignment: .trailing)
                    Text("Subtotal:").font(.caption).frame(width: 90, alignment: .trailing)
                    Text(String(format: "$%.2f", grandTotal)).font(.caption).fontWeight(.semibold).frame(width: 100, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    
                        HStack {
                    Text("").frame(width: 120)
                    Text("").frame(maxWidth: .infinity, alignment: .leading)
                    Text("").frame(width: 60, alignment: .trailing)
                    Text("GST (\(Int(gstRate))%):").font(.caption).frame(width: 90, alignment: .trailing)
                    Text(String(format: "$%.2f", grandTotal * (gstRate / 100.0))).font(.caption).fontWeight(.semibold).frame(width: 100, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    
                Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                        HStack {
                    Text("").frame(width: 120)
                    Text("").frame(maxWidth: .infinity, alignment: .leading)
                    Text("").frame(width: 60, alignment: .trailing)
                    Text("TOTAL:").font(.caption).fontWeight(.bold).frame(width: 90, alignment: .trailing)
                    Text(String(format: "$%.2f", grandTotal * (1.0 + gstRate / 100.0))).font(.caption).fontWeight(.bold).foregroundColor(.accentColor).frame(width: 100, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
            .glassEffect(.regular, in: .rect(cornerRadius: 6))
            .overlay(
                GeometryReader { geo in
                    let padding: CGFloat = 8
                    let dateWidth: CGFloat = 120
                    let qtyWidth: CGFloat = 60
                    let rateWidth: CGFloat = 90
                    let amountWidth: CGFloat = 100
                    let right = geo.size.width - padding
                    let left = padding
                    let sep3X = right - amountWidth
                    let sep2X = sep3X - rateWidth
                    let sep1X = sep2X - qtyWidth
                    let sep0X = left + dateWidth
                    Path { p in
                        p.addRect(CGRect(origin: .zero, size: geo.size))
                        p.move(to: CGPoint(x: sep0X, y: 0))
                        p.addLine(to: CGPoint(x: sep0X, y: geo.size.height))
                        p.move(to: CGPoint(x: sep1X, y: 0))
                        p.addLine(to: CGPoint(x: sep1X, y: geo.size.height))
                        p.move(to: CGPoint(x: sep2X, y: 0))
                        p.addLine(to: CGPoint(x: sep2X, y: geo.size.height))
                        p.move(to: CGPoint(x: sep3X, y: 0))
                        p.addLine(to: CGPoint(x: sep3X, y: geo.size.height))
                    }
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            )
                
                Divider()
                    HStack {
                        Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    HStack { Text("Subtotal:"); Text(String(format: "$%.2f", grandTotal)) }
                    HStack { Text("GST (\(Int(gstRate))%):"); Text(String(format: "$%.2f", grandTotal * (gstRate / 100.0))) }
                    Divider()
                    HStack {
                        Text("TOTAL:").fontWeight(.bold)
                        Text(String(format: "$%.2f", grandTotal * (1.0 + gstRate / 100.0))).fontWeight(.bold).foregroundColor(.accentColor)
                    }
                }
            }
            
            // Payment details
            VStack(alignment: .leading, spacing: 6) {
                Text("Payment Details").font(.subheadline).fontWeight(.semibold)
                Text(paymentTermsText)
                    .font(.caption).foregroundColor(.secondary)
                if let biz = previewBusiness {
                    if let bsb = biz.bankBSB, let acct = biz.bankAccountNumber, let accName = biz.bankAccountName {
                        Text("BSB: \(bsb)   Account: \(acct)   Name: \(accName)").font(.caption)
                    }
                    if !biz.email.isEmpty {
                        Text("Email remittance: \(biz.email)").font(.caption)
                    }
                }
                Text("NDIS Compliant").font(.caption).foregroundColor(.green)
            }
                .padding()
                .glassEffect(.regular, in: .rect(cornerRadius: 8))
        }
    }
}

// MARK: - Error Message View

struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Error")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
} 