import SwiftUI
import Core
import SharedUI

extension TravelChargeView {
    // MARK: - Form Sections (Updated to use viewModel Bindings)
    @ViewBuilder
    var standardTravelForm: some View {
        Section("Labour Cost (Time-Based)") {
            VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                Toggle("Include provider travel time", isOn: $viewModel.form.includeLabour.animation())
                Text("Bills provider time immediately before or after this session.")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }

            if viewModel.form.includeLabour {
                VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                    Text("MMM Zone")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                    Picker("MMM Zone", selection: $viewModel.form.mmmZone) {
                        ForEach(TravelChargeSheetMMMZone.allCases, id: \.self) { zone in
                            Text(zone.rawValue).tag(zone)
                        }
                    }
                    .pickerStyle(.menu)
                }
                VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                    Text("Provider Type")
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                    Picker("Provider Type", selection: $viewModel.form.providerType) {
                        ForEach(Core.TravelChargeProviderType.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                    Text("Travel occurs")
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                    Picker("Travel occurs", selection: $viewModel.form.travelDirection) {
                        ForEach(TravelChargeSheetDirection.allCases, id: \.self) { direction in
                            Text(direction.rawValue).tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .onChange(of: viewModel.form.travelDirection) {
                    viewModel.form.setupAndCalculateDistance()
                }

                if viewModel.form.travelDirection == .before {
                    VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                        Text("Time Before (minutes)")
                            .font(StyleGuide.Typography.itemSubtitle)
                            .foregroundStyle(StyleGuide.Colors.textSecondary)
                    TextField("30", text: $viewModel.form.travelTimeBeforeString)
                        .textFieldStyle(.roundedBorder)
                    }
                } else {
                    VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                        Text("Time After (minutes)")
                            .font(StyleGuide.Typography.itemSubtitle)
                            .foregroundStyle(StyleGuide.Colors.textSecondary)
                    TextField("30", text: $viewModel.form.travelTimeAfterString)
                        .textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
        
        Section("Non-Labour Cost (Distance-Based)") {
            VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                Toggle("Include kilometre allowance", isOn: $viewModel.form.includeNonLabour.animation())
                Text("Bills distance plus optional parking and toll costs.")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }

            if viewModel.form.includeNonLabour {
                VStack(alignment: .leading, spacing: FormSectionTokens.sectionStackSpacing) {
                    addressDisplay()
                    distanceField()
                    VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                        Text("Parking Fees")
                            .font(StyleGuide.Typography.itemSubtitle)
                            .foregroundStyle(StyleGuide.Colors.textSecondary)
                        TextField("e.g., 5.50", text: $viewModel.form.parkingString)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                        Text("Road Tolls")
                            .font(StyleGuide.Typography.itemSubtitle)
                            .foregroundStyle(StyleGuide.Colors.textSecondary)
                        TextField("e.g., 4.75", text: $viewModel.form.tollsString)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
            }
        }
    }

    @ViewBuilder
    func addressDisplay() -> some View {
        VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
            Text("From: \(viewModel.form.fromAddressString)")
            Text("To:   \(viewModel.form.toAddressString)")
        }
        .font(StyleGuide.Typography.itemSubtitle)
        .foregroundStyle(StyleGuide.Colors.textSecondary)
    }

    @ViewBuilder
    func distanceField() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                Text("Distance (km)")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                TextField("e.g., 15", text: $viewModel.form.distanceString)
                    .textFieldStyle(.roundedBorder)
            }
            
            if viewModel.form.isCalculatingDistance {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: StyleGuide.Dimensions.travelProviderIconSize, height: StyleGuide.Dimensions.travelProviderIconSize)
            } else {
                Button(action: { viewModel.form.setupAndCalculateDistance() }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderless)
                .help("Recalculate distance")
            }
        }
        if let error = viewModel.form.distanceCalculationError {
            Text(error)
                .font(.caption)
                .foregroundStyle(ColorSystem.Status.error)
        }
    }
}
