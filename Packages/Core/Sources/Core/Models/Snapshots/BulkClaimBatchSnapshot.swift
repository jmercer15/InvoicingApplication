//
//  BulkClaimBatchSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation
import SwiftData

// MARK: - BulkClaimBatchSnapshot

public struct BulkClaimBatchSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let createdAt: Date
    public let fromDate: Date
    public let toDate: Date
    public let status: String
    public let includeTravel: Bool
    public let includeCancellations: Bool
    public let claimReferenceStrategy: String
    public let exportFileName: String?
    public let exportedAt: Date?
    public let submittedAt: Date?
    public let rowCount: Int32
    public let errorCount: Int32
    public let checksumSHA256: String?
    public let notes: String?

    public init(
        id: UUID,
        createdAt: Date,
        fromDate: Date,
        toDate: Date,
        status: String,
        includeTravel: Bool,
        includeCancellations: Bool,
        claimReferenceStrategy: String,
        exportFileName: String? = nil,
        exportedAt: Date? = nil,
        submittedAt: Date? = nil,
        rowCount: Int32 = 0,
        errorCount: Int32 = 0,
        checksumSHA256: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.fromDate = fromDate
        self.toDate = toDate
        self.status = status
        self.includeTravel = includeTravel
        self.includeCancellations = includeCancellations
        self.claimReferenceStrategy = claimReferenceStrategy
        self.exportFileName = exportFileName
        self.exportedAt = exportedAt
        self.submittedAt = submittedAt
        self.rowCount = rowCount
        self.errorCount = errorCount
        self.checksumSHA256 = checksumSHA256
        self.notes = notes
    }

    public init(_ batch: BulkClaimBatch) {
        self.id = batch.id
        self.createdAt = batch.createdAt
        self.fromDate = batch.fromDate
        self.toDate = batch.toDate
        self.status = batch.status
        self.includeTravel = batch.includeTravel
        self.includeCancellations = batch.includeCancellations
        self.claimReferenceStrategy = batch.claimReferenceStrategy
        self.exportFileName = batch.exportFileName
        self.exportedAt = batch.exportedAt
        self.submittedAt = batch.submittedAt
        self.rowCount = batch.rowCount
        self.errorCount = batch.errorCount
        self.checksumSHA256 = batch.checksumSHA256
        self.notes = batch.notes
    }
}

