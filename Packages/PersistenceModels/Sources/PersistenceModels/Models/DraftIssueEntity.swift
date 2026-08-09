import Foundation
import Core
import SwiftData

@Model public class DraftIssue {
    public var id: UUID = UUID()
    public var draftId: UUID = UUID()
    @Relationship(deleteRule: .nullify) public var draft: BillableDraft?
    public var severity: DraftIssueSeverity = DraftIssueSeverity.blocking
    public var code: String = ""
    public var message: String = ""
    public var resolutionKind: DraftIssueResolutionKind = DraftIssueResolutionKind.userInput
    public var resolutionData: Data?
    public var createdAt: Date = Date()

    public init(
        id: UUID,
        draftId: UUID,
        severity: DraftIssueSeverity,
        code: String,
        message: String,
        resolutionKind: DraftIssueResolutionKind,
        resolutionData: Data? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.draftId = draftId
        self.severity = severity
        self.code = code
        self.message = message
        self.resolutionKind = resolutionKind
        self.resolutionData = resolutionData
        self.createdAt = createdAt
    }
    
    /// Returns a thread-safe snapshot of the DraftIssue.
    public func snapshot() -> DraftIssueSnapshot {
        DraftIssueSnapshot(self)
    }
}
