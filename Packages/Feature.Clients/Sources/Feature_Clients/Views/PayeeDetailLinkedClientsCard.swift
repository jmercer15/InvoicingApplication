import SwiftUI
import Core
import SharedUI
import WorkspaceUI

struct PayeeDetailLinkedClientsCard: View {
    let clients: [Client]
    @Binding var clientsSortOrder: ClientsSortOrder
    let onOpenClient: (UUID) -> Void

    var body: some View {
        GroupBox {
            VStack(spacing: DetailSectionTokens.sectionListSpacing) {
                DetailListBody(
                    isEmpty: clients.isEmpty,
                    emptyMessage: "No clients are linked to this payee"
                ) {
                    ForEach(clients, id: \.id) { client in
                        Button {
                            onOpenClient(client.id)
                        } label: {
                            CompactClientRowView(client: client)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        .accessibilityLabel("Open client \(client.fullName)")
                    }
                }
            }
        } label: {
            DetailSectionHeader(icon: "person.3", title: "Linked Clients") {
                DetailSectionSortPicker(selection: $clientsSortOrder)
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
    }
}
