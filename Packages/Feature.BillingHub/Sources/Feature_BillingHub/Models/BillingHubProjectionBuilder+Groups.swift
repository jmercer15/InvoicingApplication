import PersistenceModels
import Foundation

extension BillingHubProjectionBuilder {
    
    internal struct GroupedCluster: Hashable, Sendable {
        let id: UUID
        let groupID: UUID?
        let sessionIDs: [UUID]
        let sortPosition: Int32
    }

    internal static func makeSessionGroups(
        from sessions: [Session],
        clients: [Client],
        clientServicesCache: [UUID: [ClientService]],
        allSessions: [Session]
    ) -> [SessionGroup] {
        var clusters = groupedClusters(from: sessions)
        sortGroupedClusters(&clusters)

        let sessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })

        return clusters.compactMap { cluster in
            let clusterSessions = cluster.sessionIDs.compactMap { sessionsByID[$0] }
            let cards = clusterSessions.compactMap {
                mapSessionToKanbanCard($0, clients: clients, clientServicesCache: clientServicesCache, allSessions: allSessions)
            }
            guard !cards.isEmpty else { return nil }
            return SessionGroup(groupID: cluster.groupID, sessions: cards)
        }
    }

    internal static func groupedClusters(from sessions: [Session]) -> [GroupedCluster] {
        let grouped = sessions.filter { canonicalSessionStatusToken($0.statusToken) == "grouped" }
        let groupedByID = Dictionary(grouping: grouped, by: { $0.groupID })
        var clusters: [GroupedCluster] = []
        for (groupID, members) in groupedByID {
            let orderedMembers = orderGroupedMembers(members)
            if let groupID {
                let minPosition = orderedMembers.map { $0.groupedPosition }.min() ?? 0
                clusters.append(GroupedCluster(id: groupID, groupID: groupID, sessionIDs: orderedMembers.map { $0.id }, sortPosition: minPosition))
            } else {
                for session in orderedMembers {
                    clusters.append(GroupedCluster(id: session.id, groupID: nil, sessionIDs: [session.id], sortPosition: session.groupedPosition))
                }
            }
        }
        return clusters
    }

    internal static func sortGroupedClusters(_ clusters: inout [GroupedCluster]) {
        clusters.sort { lhs, rhs in
            if lhs.sortPosition != rhs.sortPosition { return lhs.sortPosition < rhs.sortPosition }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    internal static func orderGroupedMembers(_ sessions: [Session]) -> [Session] {
        sessions.sorted { lhs, rhs in
            if lhs.groupedPosition != rhs.groupedPosition { return lhs.groupedPosition < rhs.groupedPosition }
            let leftStart = lhs.startTime ?? .distantFuture
            let rightStart = rhs.startTime ?? .distantFuture
            if leftStart != rightStart { return leftStart < rightStart }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
