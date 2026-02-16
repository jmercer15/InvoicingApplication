import SwiftData

public enum ModelContainerFactory {
    public static func makePersistentContainer(
        models: [any PersistentModel.Type] = PersistenceSchema.appModels,
        migrationPlan: (any SchemaMigrationPlan.Type)? = nil
    ) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        if let migrationPlan {
            return try ModelContainer(for: schema, migrationPlan: migrationPlan, configurations: [configuration])
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    public static func makeInMemoryContainer(
        models: [any PersistentModel.Type] = PersistenceSchema.appModels,
        migrationPlan: (any SchemaMigrationPlan.Type)? = nil
    ) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        if let migrationPlan {
            return try ModelContainer(for: schema, migrationPlan: migrationPlan, configurations: [configuration])
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    public static func makeInMemoryContext(
        models: [any PersistentModel.Type] = PersistenceSchema.appModels,
        migrationPlan: (any SchemaMigrationPlan.Type)? = nil
    ) throws -> (ModelContainer, ModelContext) {
        let container = try makeInMemoryContainer(models: models, migrationPlan: migrationPlan)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return (container, context)
    }
}
