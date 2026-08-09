import Foundation
import SwiftData
import Core
import PersistenceModels
import SharedUI

@ModelActor
public actor RelationshipsProjectionActor {
    
    func build(
        searchText: String,
        selectedFilter: EntityFilter,
        selectedStatus: StatusFilter
    ) throws -> RelationshipsProjection {
        let currentSearch = searchText
        let currentFilter = selectedFilter
        let currentStatus = selectedStatus
        var items: [TreeItem] = []

        if currentFilter == .all || currentFilter == .clients {
            let clientDescriptor = FetchDescriptor<Client>(
                sortBy: [
                    SortDescriptor(\.fullName),
                    SortDescriptor(\.id)
                ]
            )
            let clients = try modelContext.fetch(clientDescriptor)
            let filtered = clients.filter { client in
                let matchesSearch = currentSearch.isEmpty || client.fullName.localizedCaseInsensitiveContains(currentSearch)
                let matchesStatus = currentStatus == .all || (client.status?.rawValue ?? "") == currentStatus.rawValue
                return matchesSearch && matchesStatus
            }
            if !filtered.isEmpty {
                items.append(
                    TreeItem(
                        id: "section_clients",
                        title: "Clients",
                        subtitle: "\(filtered.count) items",
                        children: filtered.map {
                            TreeItem(
                                id: "client_\($0.id)",
                                title: $0.fullName,
                                subtitle: $0.status?.rawValue,
                                children: nil,
                                entityID: $0.id.uuidString,
                                entityType: "client"
                            )
                        }
                    )
                )
            }
        }

        if currentFilter == .all || currentFilter == .payees {
            let payees = try modelContext.fetch(payeeDescriptor(searchText: currentSearch, selectedStatus: currentStatus))
            let filtered = payees.filter { payee in
                let matchesSearch = currentSearch.isEmpty || payee.fullName.localizedCaseInsensitiveContains(currentSearch)
                let matchesStatus = currentStatus == .all || payee.status == currentStatus.rawValue
                return matchesSearch && matchesStatus
            }
            if !filtered.isEmpty {
                items.append(
                    TreeItem(
                        id: "section_payees",
                        title: "Payees",
                        subtitle: "\(filtered.count) items",
                        children: filtered.map {
                            TreeItem(
                                id: "payee_\($0.id)",
                                title: $0.fullName,
                                subtitle: $0.status ?? "Unknown",
                                children: nil,
                                entityID: $0.id.uuidString,
                                entityType: "payee"
                            )
                        }
                    )
                )
            }
        }

        if currentFilter == .all || currentFilter == .planManagers {
            let planManagers = try modelContext.fetch(planManagerDescriptor())
            let filtered = planManagers.filter { manager in
                currentSearch.isEmpty || (manager.name ?? "").localizedCaseInsensitiveContains(currentSearch)
            }
            if !filtered.isEmpty {
                items.append(
                    TreeItem(
                        id: "section_planmanagers",
                        title: "Plan Managers",
                        subtitle: "\(filtered.count) items",
                        children: filtered.map {
                            TreeItem(
                                id: "planmanager_\($0.id)",
                                title: $0.name ?? "",
                                subtitle: "Plan Manager",
                                children: nil,
                                entityID: $0.id.uuidString,
                                entityType: "planManager"
                            )
                        }
                    )
                )
            }
        }

        var counts: [String: Int] = [:]
        func count(for node: TreeItem) -> Int {
            if let children = node.children, !children.isEmpty {
                let total = children.reduce(0) { $0 + count(for: $1) }
                counts[node.id] = total
                return total
            }
            let value = node.entityID != nil ? 1 : 0
            counts[node.id] = value
            return value
        }
        for item in items {
            _ = count(for: item)
        }

        return RelationshipsProjection(tree: items, counts: counts)
    }

    private func payeeDescriptor(
        searchText: String,
        selectedStatus: StatusFilter
    ) -> FetchDescriptor<Payee> {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let status = selectedStatus.rawValue
        let sortBy = [
            SortDescriptor(\Payee.fullName),
            SortDescriptor(\Payee.id)
        ]

        if !trimmedSearch.isEmpty, selectedStatus != .all {
            return FetchDescriptor<Payee>(
                predicate: #Predicate { $0.fullName.localizedStandardContains(trimmedSearch) && $0.status == status },
                sortBy: sortBy
            )
        } else if !trimmedSearch.isEmpty {
            return FetchDescriptor<Payee>(
                predicate: #Predicate { $0.fullName.localizedStandardContains(trimmedSearch) },
                sortBy: sortBy
            )
        } else if selectedStatus != .all {
            return FetchDescriptor<Payee>(
                predicate: #Predicate { $0.status == status },
                sortBy: sortBy
            )
        } else {
            return FetchDescriptor<Payee>(sortBy: sortBy)
        }
    }

    private func planManagerDescriptor() -> FetchDescriptor<PlanManager> {
        let sortBy = [
            SortDescriptor(\PlanManager.name),
            SortDescriptor(\PlanManager.id)
        ]
        // SwiftData's SQLite translator cannot lower optional-name coalescing plus
        // localized containment. Search remains bounded to actor-owned results above.
        return FetchDescriptor<PlanManager>(sortBy: sortBy)
    }
}
