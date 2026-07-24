import SwiftUI
import Core
import Data
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
                        CompactServiceRowView(service: service)
                    }
                }

                HStack {
                    Spacer()
                    Button("Assign Services") {
                        showingServiceAssignment = true
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                }
                .padding(DetailSectionTokens.listRowInsets)
            }
        } label: {
            DetailSectionHeader(icon: "list.bullet", title: "Services") {
                DetailSectionSortPicker(selection: $servicesSortOrder)
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
    }
}
