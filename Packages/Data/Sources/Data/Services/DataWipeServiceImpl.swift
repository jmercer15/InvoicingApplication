//
//  DataWipeServiceImpl.swift
//  Data
//
//  Implements DataWipeService using SwiftData ModelContext.
//

import Foundation
import SwiftData
import Core

/// SwiftData implementation of DataWipeService.
public final class DataWipeServiceImpl: DataWipeService {
    private let modelContainer: ModelContainer

    public init(modelContext: ModelContext) {
        self.modelContainer = modelContext.container
    }

    public func wipeAllData() async throws -> (totalDeleted: Int, deletedByEntity: [String: Int]) {
        let wipeActor = WipeDataModelActor(modelContainer: modelContainer)
        return try await wipeActor.wipeAll()
    }
}
