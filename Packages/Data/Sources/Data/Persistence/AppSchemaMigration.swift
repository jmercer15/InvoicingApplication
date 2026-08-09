import SwiftData

/// Current schema only. Historical schemas must be reconstructed from the matching shipped
/// source revisions; aliases to live models are not valid SwiftData compatibility schemas.
enum AppSchemaCurrent: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }

    static var models: [any PersistentModel.Type] {
        PersistenceSchema.appModels
    }
}

/// Current-store migration plan.
///
/// Release support for stores from prior shipped versions is intentionally blocked until
/// redacted stores and matching source/build revisions permit immutable historical schemas
/// and fixture-qualified stages. Never add a historical schema by reusing live model types.
public enum AppMigrationPlan: SchemaMigrationPlan {
    public static let legacyStoreMigrationIsQualified = false

    public static var schemas: [any VersionedSchema.Type] {
        [AppSchemaCurrent.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}
