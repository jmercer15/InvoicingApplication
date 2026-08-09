import SwiftUI
import PersistenceModels
import SharedUI

extension TravelChargeView {
    @ViewBuilder
    var travelEstimateSection: some View {
        if let estimate = viewModel.form.chargeEstimate {
            Section("Estimated Charge") {
                if let labourAmount = estimate.labourAmount {
                    LabeledContent(
                        "Provider travel",
                        value: labourAmount.formatted(.currency(code: "AUD"))
                    )
                }
                if let nonLabourAmount = estimate.nonLabourAmount {
                    LabeledContent(
                        "Kilometres and extras",
                        value: nonLabourAmount.formatted(.currency(code: "AUD"))
                    )
                }
                if let activityAmount = estimate.activityTransportAmount {
                    LabeledContent(
                        "Activity transport",
                        value: activityAmount.formatted(.currency(code: "AUD"))
                    )
                }
                if let minutes = estimate.billableMinutes {
                    LabeledContent("Billable time", value: "\(minutes.formatted(.number.precision(.fractionLength(0...1)))) min")
                }
                LabeledContent(
                    "Total per participant",
                    value: estimate.total.formatted(.currency(code: "AUD"))
                )
                .font(StyleGuide.Typography.bodyMedium.weight(.semibold))

                Text("Estimate updates with travel inputs. Billing Hub carries this travel row into the invoice.")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }
        }
    }

    var multiParticipantSection: some View {
        Section("Multi-Participant") {
            VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                Toggle("Split costs between participants", isOn: $viewModel.form.splitCosts.animation())
                Text("Divides calculated travel costs evenly across participants.")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }

            if viewModel.form.splitCosts {
                VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                    Text("Number of Participants")
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
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
                    .foregroundStyle(ColorSystem.Status.warning)
            }
        }
    }
    
    func serviceRow(title: String, service: ClientService?) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(StyleGuide.Typography.itemSubtitle).foregroundStyle(StyleGuide.Colors.textSecondary)
            if let service = service {
                Text(service.serviceName)
                Text(service.ndisCode ?? "No NDIS Code")
                    .font(StyleGuide.Typography.nano)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            } else {
                Text("N/A").italic()
            }
        }
    }
}
