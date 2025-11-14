# Import/Export Services Architecture Review

## Overview

The import/export services in `Feature.Settings` use `ModelContext` directly for data operations. This is **acceptable** for the following reasons:

## Rationale

### 1. Infrastructure-Level Operations
Import/export are data migration operations, not business logic. They work at the persistence layer and need direct SwiftData access for:
- Bulk entity creation
- Relationship resolution during import
- Transaction management
- Performance optimization for large data sets

### 2. Isolation
The `ModelContext` usage is:
- **Isolated** to `Feature.Settings` package
- **Contained** within import/export service classes
- **Not exposed** to ViewModels or Views

### 3. Abstraction Layer
The higher-level `SettingsViewModel` uses use cases (`ImportAllData`, `ExportAllData`) which:
- Abstract the import/export operations
- Follow clean architecture principles
- Can be tested independently

### 4. Practical Considerations
- Direct entity manipulation is necessary for efficient bulk imports
- Relationship management during import requires entity-level access
- Export needs to serialize entities directly
- Migration operations benefit from direct SwiftData APIs

## Current Architecture

```
SettingsViewModel (Use Cases)
    ↓
ImportAllData / ExportAllData (Use Cases)
    ↓
UnifiedImportService / Export Services (ModelContext usage - ACCEPTABLE)
    ↓
SwiftData Entities
```

## Conclusion

**ModelContext usage in import/export services is acceptable** because:
1. It's infrastructure-level, not business logic
2. It's isolated to the Settings package
3. Higher-level code uses abstraction (use cases)
4. Direct entity access is necessary for bulk operations

## Future Considerations

If import/export operations become more complex or need additional business logic, consider:
- Extracting domain models during import processing
- Using repositories for validation/preprocessing
- Keeping ModelContext only for final persistence

For now, the current pattern is appropriate for data migration operations.
