# Data Migration Strategy

## Overview

This document outlines the comprehensive data migration strategy for the Invoicing Application's Swift Data persistence layer. The strategy covers property renames, unused property removals, and architectural compliance fixes.

## Migration Categories

### 1. Property Renames (High Priority)

#### 1.1 AddressEntity.suburb → city

- **Scope**: Single property rename
- **Impact**: Low - only affects mapping layer
- **Migration Type**: Column rename
- **Rollback**: Simple column rename back

#### 1.2 PlanManagerEntity.businessName → name

- **Scope**: Single property rename
- **Impact**: Low - only affects mapping layer
- **Migration Type**: Column rename
- **Rollback**: Simple column rename back

#### 1.3 NDISItemEntity.itemDescription → description

- **Scope**: Single property rename
- **Impact**: Low - only affects mapping layer
- **Migration Type**: Column rename
- **Rollback**: Simple column rename back

### 2. Unused Property Removals (High Priority)

#### 2.1 SessionEntity Unused Properties

- **Properties**: hasSecondReminder, secondReminderTime, useRichText, isSystemEvent, attachmentsData, firstReminderTime
- **Scope**: 6 properties
- **Impact**: Medium - affects entity, domain model, and mapping
- **Migration Type**: Column removal
- **Rollback**: Column recreation with default values

#### 2.2 TravelChargeEntity Unused Properties

- **Properties**: auditLogs
- **Scope**: 1 property
- **Impact**: Low - affects entity and mapping
- **Migration Type**: Column removal
- **Rollback**: Column recreation with default values

### 3. Architectural Compliance Fixes (Critical Priority)

#### 3.1 ColorHex Property Removals

- **Properties**: PayeeEntity.colorHex, ClientEntity.colorHex
- **Scope**: 2 properties across 2 entities
- **Impact**: High - affects 56+ files across UI, import/export, and mapping layers
- **Migration Type**: Column removal + UI refactoring
- **Rollback**: Complex - requires UI refactoring

#### 3.2 PayeeEntity.notes Removal

- **Properties**: PayeeEntity.notes
- **Scope**: 1 property
- **Impact**: Medium - affects 5 files
- **Migration Type**: Column removal + UI refactoring
- **Rollback**: Column recreation + UI refactoring

#### 3.3 Missing Domain Properties

- **Properties**: Payee.status, PlanManager.abn
- **Scope**: 2 properties across 2 domain models
- **Impact**: Medium - affects domain models and mapping
- **Migration Type**: Domain model updates
- **Rollback**: Domain model property removal

## Migration Execution Strategy

### Phase 1: Property Renames (Low Risk)

1. **AddressEntity.suburb → city**

   - Update entity definition
   - Update mapping layer
   - Create database migration script
   - Test with sample data

2. **PlanManagerEntity.businessName → name**

   - Update entity definition
   - Update mapping layer
   - Create database migration script
   - Test with sample data

3. **NDISItemEntity.itemDescription → description**
   - Update entity definition
   - Update mapping layer
   - Create database migration script
   - Test with sample data

### Phase 2: Unused Property Removals (Medium Risk)

1. **SessionEntity Unused Properties**

   - Remove from entity definition
   - Remove from domain model
   - Update mapping layer
   - Create database migration script
   - Test with sample data

2. **TravelChargeEntity Unused Properties**
   - Remove from entity definition
   - Update mapping layer
   - Create database migration script
   - Test with sample data

### Phase 3: Architectural Compliance Fixes (High Risk)

1. **Missing Domain Properties**

   - Add Payee.status to domain model
   - Add PlanManager.abn to domain model
   - Update mapping layers
   - Test with sample data

2. **ColorHex Property Removals**

   - Remove from entity definitions
   - Remove from domain models
   - Update mapping layers
   - Refactor UI components (56+ files)
   - Update import/export services
   - Create database migration script
   - Test with sample data

3. **PayeeEntity.notes Removal**
   - Remove from entity definition
   - Remove from domain model
   - Update mapping layer
   - Refactor UI components
   - Update import/export services
   - Create database migration script
   - Test with sample data

## Database Migration Scripts

### Swift Data Migration Approach

Swift Data uses a different migration approach than Core Data. For Swift Data:

1. **Property Renames**: Use `@Attribute(.originalName)` to maintain backward compatibility
2. **Property Removals**: Properties can be removed directly from the model
3. **Property Additions**: New properties can be added with default values

### Migration Script Template

```swift
import SwiftData

// Example migration script for property renames
extension ModelContainer {
    static func createMigratedContainer() throws -> ModelContainer {
        let schema = Schema([
            // Updated entity definitions with new property names
            AddressEntity.self,
            PlanManagerEntity.self,
            NDISItemEntity.self,
            // ... other entities
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    }
}
```

### Property Rename Migration

```swift
// For AddressEntity.suburb → city
@Model public class AddressEntity {
    @Attribute(.originalName("suburb")) public var city: String = ""
    // ... other properties
}

// For PlanManagerEntity.businessName → name
@Model public class PlanManagerEntity {
    @Attribute(.originalName("businessName")) public var name: String?
    // ... other properties
}

// For NDISItemEntity.itemDescription → description
@Model public class NDISItemEntity {
    @Attribute(.originalName("itemDescription")) public var description: String?
    // ... other properties
}
```

## Testing Strategy

### 1. Unit Tests

- Test all mapping operations with sample data
- Test entity-to-domain conversions
- Test domain-to-entity updates
- Test edge cases with nil values

### 2. Integration Tests

- Test database operations with migrated data
- Test import/export functionality
- Test UI components with migrated data
- Test repository operations

### 3. Migration Tests

- Test migration with existing data
- Test rollback scenarios
- Test data integrity after migration
- Test performance with large datasets

## Risk Assessment

### Low Risk (Property Renames)

- **Risk Level**: Low
- **Impact**: Minimal
- **Rollback**: Easy
- **Testing**: Standard unit tests

### Medium Risk (Unused Property Removals)

- **Risk Level**: Medium
- **Impact**: Moderate
- **Rollback**: Moderate
- **Testing**: Comprehensive unit and integration tests

### High Risk (Architectural Compliance Fixes)

- **Risk Level**: High
- **Impact**: High
- **Rollback**: Complex
- **Testing**: Extensive testing across all layers

## Rollback Strategy

### 1. Property Renames

- Simple column rename back to original name
- Update entity definitions
- Update mapping layers

### 2. Unused Property Removals

- Recreate columns with default values
- Restore entity definitions
- Restore domain models
- Update mapping layers

### 3. Architectural Compliance Fixes

- Recreate removed columns
- Restore entity definitions
- Restore domain models
- Restore UI components
- Restore import/export functionality

## Monitoring and Validation

### 1. Data Integrity Checks

- Verify all data is preserved after migration
- Check for data loss or corruption
- Validate mapping operations
- Test import/export functionality

### 2. Performance Monitoring

- Monitor database performance after migration
- Check for performance regressions
- Optimize queries if needed
- Monitor memory usage

### 3. User Experience Validation

- Test all UI components
- Verify functionality works as expected
- Check for visual regressions
- Validate user workflows

## Implementation Timeline

### Week 1: Property Renames

- Day 1-2: AddressEntity.suburb → city
- Day 3-4: PlanManagerEntity.businessName → name
- Day 5: NDISItemEntity.itemDescription → description

### Week 2: Unused Property Removals

- Day 1-3: SessionEntity unused properties
- Day 4-5: TravelChargeEntity unused properties

### Week 3-4: Architectural Compliance Fixes

- Day 1-2: Missing domain properties
- Day 3-7: ColorHex property removals
- Day 8-10: PayeeEntity.notes removal

### Week 5: Testing and Validation

- Day 1-3: Unit and integration testing
- Day 4-5: Performance testing and optimization

## Success Criteria

1. **Data Integrity**: All existing data is preserved and accessible
2. **Functionality**: All features work as expected after migration
3. **Performance**: No performance regressions
4. **Architecture**: All architectural violations are resolved
5. **Code Quality**: Reduced complexity and improved maintainability
6. **Documentation**: All changes are properly documented

## Conclusion

This migration strategy provides a comprehensive approach to updating the Invoicing Application's data persistence layer. The phased approach minimizes risk while ensuring all architectural issues are resolved. The strategy includes detailed rollback plans and extensive testing to ensure data integrity and system stability.
