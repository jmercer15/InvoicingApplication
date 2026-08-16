import SwiftUI
import Core
import PersistenceModels
import SharedUI

struct ClientDetailServicesCard: View {
    @Bindable var viewModel: ClientDetailViewModel
    let sortedServices: [ClientService]
    @Binding var servicesSortOrder: ServicesSortOrder
    @Binding var showingServiceAssignment: Bool

    var body: some View {
        GroupBox {
            VStack {
                DetailListBody(
                    isEmpty: viewModel.clientServices.isEmpty,
                    emptyMessage: "No services assigned",
                    maxHeight: DetailSectionTokens.listMinHeight
                ) {
                    ForEach(sortedServices) { service in
                        Button {
                            viewModel.prepareToEditClientService(service)
                        } label: {
                            CompactServiceRowView(service: service)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        .accessibilityHint("Opens service editor")
                    }
                }

                DetailListTrailingActionFooter("Assign Services") {
                    showingServiceAssignment = true
                }
            }
        } label: {
            DetailSectionHeader(icon: "list.bullet", title: "Services") {
                DetailSectionSortPicker(selection: $servicesSortOrder)
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
    }
}
