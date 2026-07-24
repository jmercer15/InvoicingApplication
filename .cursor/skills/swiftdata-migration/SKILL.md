# Skill: swiftdata-migration

Use this skill when modifying existing SwiftData models, adding properties, changing relationships, or upgrading the application's local database schema.

## When To Use This Skill

- Task involves changing any `@Model` properties or relationships in production.
- Upgrading the local database schema version.
- Creating a migration plan to prevent application crashes and data loss.

## SwiftData Migration Workflow

You are executing a production-grade SwiftData database migration. Follow these steps sequentially:

### Step 1: Define the New Schema Version
- **Rule**: Never modify the existing `@Model` in place if it has already been deployed to production.
- Create a new `VersionedSchema` struct (e.g., `enum SchemaV2: VersionedSchema`).
- Copy the old models into the new schema namespace and apply the requested changes (e.g., adding a new property).

### Step 2: Create the SchemaMigrationPlan
- Define a `SchemaMigrationPlan` linking the old schema (e.g., `SchemaV1`) to the new schema (`SchemaV2`).
- Determine if the migration is lightweight or custom. If simply adding an optional field or a field with a default value, utilize a lightweight migration stage.
- For custom migrations (e.g., splitting a string into two fields, or resolving duplicate naming collisions), define a custom stage.

### Step 3: Implement willMigrate and didMigrate
- Use `willMigrate` for any logic that must execute before the schema structure is altered at the SQLite level.
- Use `didMigrate` for data backfilling or deduplication.
- **Safety**: When querying existing records in `didMigrate`, ensure you use the context provided by the block, and operate exclusively on the newly migrated types.

### Step 4: Update the ModelContainer
- Update the application's `ModelContainer` initialization to pass the newly created `SchemaMigrationPlan`.
- Update the application-wide typealias to point to the newest schema version (e.g., `typealias Item = SchemaV2.Item`) so the rest of the codebase seamlessly compiles against the new schema.
