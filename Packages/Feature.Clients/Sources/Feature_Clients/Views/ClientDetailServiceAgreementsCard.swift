import SwiftUI
import PersistenceModels
import SharedUI

struct ClientDetailServiceAgreementsCard: View {
    @Bindable var viewModel: ClientDetailViewModel

    var body: some View {
        GroupBox {
            VStack(spacing: DetailSectionTokens.sectionListSpacing) {
                DetailListBody(
                    isEmpty: viewModel.serviceAgreements.isEmpty,
                    emptyMessage: "No service agreements"
                ) {
                    VStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                        ForEach(viewModel.serviceAgreements) { agreement in
                            ServiceAgreementRowCard(
                                agreement: agreement,
                                onEdit: { viewModel.prepareToEditServiceAgreement(agreement) },
                                onArchive: { viewModel.archiveServiceAgreement(agreement) },
                                dateRange: serviceAgreementDateRange(agreement)
                            )
                        }
                    }
                }

                DetailListTrailingActionFooter("Add Agreement") {
                    viewModel.prepareToAddServiceAgreement()
                }
            }
        } label: {
            DetailSectionHeader(icon: "doc.text", title: "Service Agreements")
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
    }

    private func serviceAgreementDateRange(_ agreement: ServiceAgreement) -> String {
        let from = DateFormatting.mediumDate(agreement.effectiveFrom)
        if let to = agreement.effectiveTo {
            return "\(from) - \(DateFormatting.mediumDate(to))"
        }
        return "\(from) onwards"
    }
}

private struct ServiceAgreementRowCard: View {
    let agreement: ServiceAgreement
    let onEdit: () -> Void
    let onArchive: () -> Void
    let dateRange: String

    
    var body: some View {
        HStack(alignment: .top, spacing: StyleGuide.Dimensions.paddingLarge) {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingSmall) {
                Text(dateRange)
                    .font(StyleGuide.Typography.itemTitle)
                    .fontWeight(.bold)
                    .foregroundColor(StyleGuide.Colors.text)
                
                Text("Cancellation: \(agreement.cancellationPolicyType)")
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                
                HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                    if agreement.allowsProviderTravel {
                        Label("Travel", systemImage: "car.fill")
                            .font(StyleGuide.Typography.micro)
                    }
                    if agreement.allowsTelehealth {
                        Label("Telehealth", systemImage: "video.fill")
                            .font(StyleGuide.Typography.micro)
                    }
                    if agreement.allowsNonFaceToFace {
                        Label("NF2F", systemImage: "person.2.fill")
                            .font(StyleGuide.Typography.micro)
                    }
                }
                .foregroundStyle(StyleGuide.Colors.textSecondary)
                
                if agreement.isArchived {
                    Text("Archived")
                        .font(StyleGuide.Typography.micro)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
                        .padding(.vertical, 2)
                        .background(ColorSystem.Status.warning.opacity(0.2))
                        .foregroundColor(ColorSystem.Status.warning)
                        .clipShape(Capsule())
                }
            }
            
            Spacer(minLength: 8)
            
            Menu {
                Button("Edit", action: onEdit)
                if !agreement.isArchived {
                    Button("Archive", role: .destructive, action: onArchive)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(StyleGuide.Colors.textSecondary)
                    .contentShape(Circle())
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("Agreement actions")
            .accessibilityHint("Shows menu with options to edit or archive this agreement")
        }
        .padding(StyleGuide.Dimensions.paddingLarge)
        .background(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                .fill(StyleGuide.Colors.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                .stroke(StyleGuide.Colors.border, lineWidth: 0.6)
        )
    }
}
