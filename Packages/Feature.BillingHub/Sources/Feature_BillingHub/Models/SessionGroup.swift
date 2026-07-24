import Foundation
import SwiftUI
import SharedUI

public struct SessionGroup: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let sessions: [KanbanCardData]
    public let groupID: UUID?

    public init(groupID: UUID?, sessions: [KanbanCardData]) {
        if let groupID {
            self.id = groupID
        } else if sessions.count == 1 {
            self.id = sessions[0].id
        } else {
            self.id = UUID()
        }

        self.groupID = groupID
        self.sessions = sessions
    }

    public var accentColor: Color {
        sessions.first?.accentColor ?? ColorSystem.Session.defaultAccent
    }
}
