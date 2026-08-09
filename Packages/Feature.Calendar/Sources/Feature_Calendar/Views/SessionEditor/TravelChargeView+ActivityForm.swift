import SwiftUI
import SharedUI

extension TravelChargeView {
    @ViewBuilder
    var activityBasedForm: some View {
        Section("Activity-Based Transport Costs") {
            // Vehicle & Distance Costs
            VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                Text("Vehicle Type")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                Picker("Vehicle Type", selection: $viewModel.form.vehicleType) {
                    ForEach(TravelChargeSheetVehicleType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
            VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                Text("Distance (Round Trip, km)")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                TextField("e.g., 25", text: $viewModel.form.distanceString)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Other Costs
            VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                Text("Parking Fees")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                HStack {
                    Text("$")
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                    TextField("e.g., 5.50", text: $viewModel.form.parkingString)
                }
                .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                Text("Road Tolls")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                HStack {
                    Text("$")
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                    TextField("e.g., 4.75", text: $viewModel.form.tollsString)
                }
                .textFieldStyle(.roundedBorder)
            }
            
            Divider()
            
            // Time Costs
            Text("Travel Time").font(StyleGuide.Typography.itemSubtitle).foregroundStyle(StyleGuide.Colors.textSecondary)
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
}
