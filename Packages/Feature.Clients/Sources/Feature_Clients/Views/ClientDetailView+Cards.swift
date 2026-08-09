import SwiftUI

extension ClientDetailView {
    var clientInfoCard: some View {
        ClientDetailClientInformationCard(
            viewModel: viewModel,
            maxLabelWidth: maxLabelWidth,
            planManagers: viewModel.planManagerCatalogue,
            hasAddressData: hasAddressData
        ) {
            compactAddressView
        }
    }

    var billingInfoCard: some View {
        ClientDetailBillingInfoCard(
            viewModel: viewModel,
            maxLabelWidth: maxLabelWidth,
            payeeEntities: viewModel.payeeCatalogue
        )
    }

    var serviceAgreementsCard: some View {
        ClientDetailServiceAgreementsCard(viewModel: viewModel)
    }

    var servicesCard: some View {
        ClientDetailServicesCard(
            viewModel: viewModel,
            sortedServices: viewModel.sortedServices,
            servicesSortOrder: $viewModel.servicesSortOrder,
            showingServiceAssignment: $showingServiceAssignment
        )
    }

    var invoicesCard: some View {
        ClientDetailInvoicesCard(
            viewModel: viewModel,
            sortedInvoices: viewModel.sortedInvoices,
            invoicesSortOrder: $viewModel.invoicesSortOrder,
            onOpenInvoice: onOpenInvoice
        )
    }
}
