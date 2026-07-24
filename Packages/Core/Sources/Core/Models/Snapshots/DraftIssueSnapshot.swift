//
//  DraftIssueSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation
import SwiftData

// MARK: - DraftIssueSnapshot

public struct DraftIssueSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let draftId: UUID
    public let severity: DraftIssueSeverity
    public let code: String
    public let message: String
    public let resolutionKind: DraftIssueResolutionKind
    public let resolutionData: Data?
    public let createdAt: Date

    public init(_ issue: DraftIssue) {
        self.id = issue.id
        self.draftId = issue.draftId
        self.severity = issue.severity
        self.code = issue.code
        self.message = issue.message
        self.resolutionKind = issue.resolutionKind
        self.resolutionData = issue.resolutionData
        self.createdAt = issue.createdAt
    }
}

