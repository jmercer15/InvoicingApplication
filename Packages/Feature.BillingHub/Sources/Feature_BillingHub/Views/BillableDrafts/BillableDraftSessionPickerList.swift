import Core
import SwiftData
import SwiftUI

/// Live `@Query` list of billable sessions in a date window, excluding sessions that already have drafts.
struct BillableDraftSessionPickerList: View {
    let rangeFrom: Date
    let rangeTo: Date
    @Binding var selectedSessionIds: Set<UUID>
    let onSessionsUpdated: ([Session]) -> Void

    @Query private var sessions: [Session]
    @Query private var draftsInRange: [BillableDraft]

    init(
        rangeFrom: Date,
        rangeTo: Date,
        selectedSessionIds: Binding<Set<UUID>>,
        onSessionsUpdated: @escaping ([Session]) -> Void
    ) {
        self.rangeFrom = rangeFrom
        self.rangeTo = rangeTo
        self._selectedSessionIds = selectedSessionIds
        self.onSessionsUpdated = onSessionsUpdated

        _sessions = Query(
            filter: #Predicate<Session> { session in
                session.startTime != nil
                    && session.startTime! >= rangeFrom
                    && session.startTime! <= rangeTo
                    && session.client != nil
                    && session.clientService != nil
            },
            sort: \.startTime
        )
        _draftsInRange = Query(
            filter: #Predicate<BillableDraft> { draft in
                draft.computedAt >= rangeFrom && draft.computedAt <= rangeTo
            }
        )
    }

    private var undraftedSessions: [Session] {
        let draftedSessionIds = Set(draftsInRange.map(\.sessionId))
        return sessions.filter { !draftedSessionIds.contains($0.id) }
    }

    var body: some View {
        List(undraftedSessions, selection: $selectedSessionIds) { session in
            HStack {
                Text(session.title.isEmpty ? "Session \(session.id.uuidString.prefix(8))..." : session.title)
                Text(session.startTime.map { shortDate($0) } ?? "-")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tag(session.id)
        }
        .listStyle(.inset)
        .onChange(of: undraftedSessions.map(\.id), initial: true) { _, _ in
            onSessionsUpdated(undraftedSessions)
        }
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

    private func shortDate(_ date: Date) -> String {
        Self.shortDateFormatter.string(from: date)
    }
}
