import SwiftUI
import SwiftData
import Core
import MapKit
import Data
import SharedUI

struct TravelChargeView: View {

    @Environment(\.dismiss) private var dismiss
    
    // Use StateObject for the ViewModel
    @StateObject private var viewModel: TravelChargeViewModel

    // MARK: - Enums for Travel Logic
    
    enum TravelChargeType: String, CaseIterable, Identifiable {
        case standard = "Standard Travel"
        case activityBased = "Activity-Based Transport"
        var id: String { rawValue }
    }

    enum TravelDirection: String, CaseIterable, Identifiable {
        case before = "Before Session"
        case after = "After Session"
        var id: String { rawValue }
    }

    enum MMMZone: String, CaseIterable, Identifiable {
        case mmm1_3 = "Zones 1-3 (Metro)"
        case mmm4_5 = "Zones 4-5 (Regional)"
        case mmm6_7 = "Zones 6-7 (Remote/Very Remote)"
        var id: String { rawValue }
        
        var maxTime: Double {
            switch self {
            case .mmm1_3: return 30
            case .mmm4_5: return 60
            case .mmm6_7: return .infinity
            }
        }
    }

    enum VehicleType: String, CaseIterable, Identifiable {
        case standard = "Standard Car"
        case modified = "Modified/Bus"
        var id: String { rawValue }

        var rate: Double {
            switch self {
            case .standard: return 0.99
            case .modified: return 2.76
            }
        }
    }
    
    // MARK: - Init
    
    init(
        unitOfWork: UnitOfWorkService,
        mainSession: Session,
        daySessions: [DisplayableCalendarItem],
        onSave: @escaping () -> Void
    ) {
         _viewModel = StateObject(wrappedValue: TravelChargeViewModel(
            unitOfWork: unitOfWork,
            mainSession: mainSession,
            daySessions: daySessions
        ))
        self.onSave = onSave
    }

    private var accentColor: Color { .blue }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Form {
                Section {
                    Picker("", selection: $viewModel.chargeType) {
                        ForEach(TravelChargeType.allCases, id: \.self) { type in
                            Text(String(describing: type)).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)

                switch viewModel.chargeType {
                case .standard:
                    standardTravelForm
                case .activityBased:
                    activityBasedForm
                }

                multiParticipantSection
                travelServiceSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color("Surface", bundle: .sharedUI))
        }
        .frame(minWidth: 550, idealWidth: 600, minHeight: 600)
        .onAppear(perform: {
            setupViewModel()
        })
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading Services...")
                    .padding()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    func setupViewModel() {
        // Setup Save Callback
        viewModel.onSave = {
            onSave() // Call the View's closure
        }
        
        viewModel.loadServices()
        viewModel.checkForExistingTravel()
        viewModel.setupAndCalculateDistance()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Travel Charges")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("For: \(viewModel.mainSession.title)")
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            Spacer()
            Button("Cancel", role: .cancel, action: { dismiss() })
            Button("Save", action: viewModel.saveTravelCharges)
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSave)
        }
        .padding()
        .background(Color("Background", bundle: .sharedUI))
    }

    // MARK: - Form Sections (Updated to use viewModel Bindings)
    @ViewBuilder
    private var standardTravelForm: some View {
        Section("Labour Cost (Time-Based)") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Include Labour Costs")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                Toggle("Include Labour Costs", isOn: $viewModel.includeLabour.animation())
            }

            if viewModel.includeLabour {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MMM Zone")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    Picker("MMM Zone", selection: $viewModel.mmmZone) {
                        ForEach(MMMZone.allCases, id: \.self) { zone in
                            Text(String(describing: zone)).tag(zone)
                        }
                    }
                    .pickerStyle(.menu)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Provider Type")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    Picker("Provider Type", selection: $viewModel.providerType) {
                        ForEach(TravelChargeProviderType.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Travel occurs")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    Picker("Travel occurs", selection: $viewModel.travelDirection) {
                        ForEach(TravelDirection.allCases, id: \.self) { direction in
                            Text(String(describing: direction)).tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .onChange(of: viewModel.travelDirection) {
                    viewModel.setupAndCalculateDistance()
                }

                if viewModel.travelDirection == .before {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Time Before (minutes)")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        TextField("30", text: $viewModel.travelTimeBeforeString)
                            .textFieldStyle(.roundedBorder)
                    }
                    .disabled(viewModel.hasExistingTravelBefore)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Time After (minutes)")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        TextField("30", text: $viewModel.travelTimeAfterString)
                            .textFieldStyle(.roundedBorder)
                    }
                    .disabled(viewModel.hasExistingTravelAfter)
                }
            }
        }
        
        Section("Non-Labour Cost (Distance-Based)") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Include Kilometre Allowance")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                Toggle("Include Kilometre Allowance", isOn: $viewModel.includeNonLabour.animation())
            }

            if viewModel.includeNonLabour {
                VStack(alignment: .leading, spacing: 12) {
                    addressDisplay()
                    distanceField()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Parking Fees")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        TextField("e.g., 5.50", text: $viewModel.parkingString)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Road Tolls")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        TextField("e.g., 4.75", text: $viewModel.tollsString)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private func addressDisplay() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("From: \(viewModel.fromAddressString)")
            Text("To:   \(viewModel.toAddressString)")
        }
        .font(.caption)
        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
    }

    @ViewBuilder
    private func distanceField() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Distance (km)")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                TextField("e.g., 15", text: $viewModel.distanceString)
                    .textFieldStyle(.roundedBorder)
            }
            
            if viewModel.isCalculatingDistance {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 44, height: 44)
            } else {
                Button(action: { viewModel.setupAndCalculateDistance() }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderless)
                .help("Recalculate distance")
            }
        }
        if let error = viewModel.distanceCalculationError {
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
        }
    }

    @ViewBuilder
    private var activityBasedForm: some View {
        Section("Activity-Based Transport Costs") {
            // Vehicle & Distance Costs
            VStack(alignment: .leading, spacing: 4) {
                Text("Vehicle Type")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                Picker("Vehicle Type", selection: $viewModel.vehicleType) {
                    ForEach(VehicleType.allCases, id: \.self) { type in
                        Text(String(describing: type)).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Distance (Round Trip, km)")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                TextField("e.g., 25", text: $viewModel.distanceString)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Other Costs
            VStack(alignment: .leading, spacing: 4) {
                Text("Parking Fees")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                HStack {
                    Text("$")
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    TextField("e.g., 5.50", text: $viewModel.parkingString)
                }
                .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Road Tolls")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                HStack {
                    Text("$")
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    TextField("e.g., 4.75", text: $viewModel.tollsString)
                }
                .textFieldStyle(.roundedBorder)
            }
            
            Divider()
            
            // Time Costs
            Text("Travel Time").font(.caption).foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            VStack(alignment: .leading, spacing: 4) {
                Text("Travel occurs")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                Picker("Travel occurs", selection: $viewModel.travelDirection) {
                    ForEach(TravelDirection.allCases, id: \.self) { direction in
                        Text(String(describing: direction)).tag(direction)
                    }
                }
                .pickerStyle(.segmented)
            }
            .onChange(of: viewModel.travelDirection) {
                viewModel.setupAndCalculateDistance()
            }

            if viewModel.travelDirection == .before {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time Before (minutes)")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    TextField("30", text: $viewModel.travelTimeBeforeString)
                        .textFieldStyle(.roundedBorder)
                }
                .disabled(viewModel.hasExistingTravelBefore)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time After (minutes)")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    TextField("30", text: $viewModel.travelTimeAfterString)
                        .textFieldStyle(.roundedBorder)
                }
                .disabled(viewModel.hasExistingTravelAfter)
            }
        }
    }
    
    private var multiParticipantSection: some View {
        Section("Multi-Participant") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Split Costs Between Multiple Participants")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                Toggle("Split Costs Between Multiple Participants", isOn: $viewModel.splitCosts.animation())
            }

            if viewModel.splitCosts {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Number of Participants")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    TextField("2", text: $viewModel.participantCountString)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var travelServiceSection: some View {
        Section("NDIS Service Items") {
            if viewModel.chargeType == .standard && viewModel.includeLabour {
                serviceRow(title: "Labour Service", service: viewModel.labourService)
            }
            if viewModel.chargeType == .standard && viewModel.includeNonLabour {
                serviceRow(title: "Non-Labour Service", service: viewModel.nonLabourService)
            }
            if viewModel.chargeType == .activityBased {
                serviceRow(title: "Activity Transport Service", service: viewModel.labourService)
            }
            
            if (viewModel.chargeType == .standard && viewModel.includeLabour && viewModel.labourService == nil) ||
               (viewModel.chargeType == .standard && viewModel.includeNonLabour && viewModel.nonLabourService == nil) ||
               (viewModel.chargeType == .activityBased && viewModel.labourService == nil) {
                Text("Could not find a matching NDIS travel item for this service's registration group.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private func serviceRow(title: String, service: ClientService?) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            if let service = service {
                Text(service.serviceName)
                Text(service.ndisCode ?? "No NDIS Code")
                    .font(.caption2)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            } else {
                Text("N/A").italic()
            }
        }
    }
    
    private let onSave: () -> Void 
}
