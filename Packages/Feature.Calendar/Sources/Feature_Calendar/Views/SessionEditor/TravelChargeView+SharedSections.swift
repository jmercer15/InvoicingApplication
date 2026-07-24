import SwiftUI
import Core
import SharedUI

extension TravelChargeView {
    var multiParticipantSection: some View {
        Section("Multi-Participant") {
            VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                Text("Split Costs Between Multiple Participants")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundColor(StyleGuide.Colors.textSecondary)
                Toggle("Split Costs Between Multiple Participants", isOn: $viewModel.form.splitCosts.animation())
            }

            if viewModel.form.splitCosts {
                VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                    Text("Number of Participants")
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundColor(StyleGuide.Colors.textSecondary)
                    TextField("2", text: $viewModel.form.participantCountString)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    var travelServiceSection: some View {
        Section("NDIS Service Items") {
            if viewModel.form.chargeType == .standard && viewModel.form.includeLabour {
                serviceRow(title: "Labour Service", service: viewModel.form.labourService)
            }
            if viewModel.form.chargeType == .standard && viewModel.form.includeNonLabour {
                serviceRow(title: "Non-Labour Service", service: viewModel.form.nonLabourService)
            }
            if viewModel.form.chargeType == .activityBased {
                serviceRow(title: "Activity Transport Service", service: viewModel.form.labourService)
            }
            
            if (viewModel.form.chargeType == .standard && viewModel.form.includeLabour && viewModel.form.labourService == nil) ||
               (viewModel.form.chargeType == .standard && viewModel.form.includeNonLabour && viewModel.form.nonLabourService == nil) ||
               (viewModel.form.chargeType == .activityBased && viewModel.form.labourService == nil) {
                Text("Could not find a matching NDIS travel item for this service's registration group.")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundColor(ColorSystem.Status.warning)
            }
        }
    }
    
    func serviceRow(title: String, service: ClientService?) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(StyleGuide.Typography.itemSubtitle).foregroundColor(StyleGuide.Colors.textSecondary)
            if let service = service {
                Text(service.serviceName)
                Text(service.ndisCode ?? "No NDIS Code")
                    .font(StyleGuide.Typography.nano)
                    .foregroundColor(StyleGuide.Colors.textSecondary)
            } else {
                Text("N/A").italic()
            }
        }
    }
}
