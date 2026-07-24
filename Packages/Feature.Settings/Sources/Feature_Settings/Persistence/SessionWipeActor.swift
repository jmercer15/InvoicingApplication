import Core
import Foundation
import SwiftData

@ModelActor
public actor SessionWipeActor {
    public func wipeSessions() throws {
        try modelContext.delete(model: Session.self)
        try modelContext.save()
    }
}
