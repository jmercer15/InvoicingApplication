//
//  DraftIssueSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation

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
}

