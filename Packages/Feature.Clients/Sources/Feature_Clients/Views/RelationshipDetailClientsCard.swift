import SwiftUI
import Core
import PersistenceModels
import SharedUI
import WorkspaceUI

/// Shared linked/managed clients list card for relationship entity detail screens.
struct RelationshipDetailClientsCard: View {
    let title: String
    let emptyMessage: String
    let clients: [Client]
    @Binding var clientsSortOrder: ClientsSortOrder
    let onOpenClient: (UUID) -> Void

    var body: some View {
        GroupBox {
            VStack(spacing: DetailSectionTokens.sectionListSpacing) {
                DetailListBody(
                    isEmpty: clients.isEmpty,
                    emptyMessage: emptyMessage
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
            DetailSectionHeader(icon: "person.3", title: title) {
                DetailSectionSortPicker(selection: $clientsSortOrder)
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
    }
}

enum RelationshipDetailActiveSheet: Identifiable {
    case map
    case addressEditing

    var id: Self { self }
}

enum RelationshipDetailSheetBindings {
    static func isPresented(
        _ activeSheet: Binding<RelationshipDetailActiveSheet?>,
        equals target: RelationshipDetailActiveSheet
    ) -> Binding<Bool> {
        Binding(
            get: { activeSheet.wrappedValue == target },
            set: { activeSheet.wrappedValue = $0 ? target : nil }
        )
    }
}
