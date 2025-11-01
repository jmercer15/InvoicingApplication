# Architectural Patterns and Mapping Conventions

## Overview

This document outlines the architectural patterns and conventions used in the Invoicing Application's data persistence layer, specifically focusing on the mapping between Swift Data entities and domain models.

## Core Architectural Principles

### 1. Domain-Driven Design (DDD)

- **Domain models** represent business concepts and rules
- **Entity models** represent persistence concerns and technical details
- **Clear separation** between business logic and data storage

### 2. Repository Pattern

- **Abstraction layer** between domain and data layers
- **Consistent interface** for data operations
- **Technology-agnostic** domain layer

### 3. Data Transfer Object (DTO) Pattern

- **Lightweight domain models** for data transfer
- **Flattened relationships** to prevent deep object graphs
- **Immutable domain objects** for thread safety

## Mapping Conventions

### File Naming

- **Entity+Mapping.swift**: Contains mapping extensions for entity-to-domain conversion
- **Domain+Mapping.swift**: Contains mapping extensions for domain-to-entity conversion
- **Consistent naming**: `{ModelName}+Mapping.swift`

### Method Naming

- **Entity to Domain**: `init(from entity: {EntityName})`
- **Domain to Entity**: `func update(from domainModel: {DomainName})`
- **Consistent parameters**: Always use `entity` and `domainModel` parameter names

### Code Organization

```swift
// MARK: - {ModelName} Mapping

extension {DomainModel} {
    /// Convert from {EntityName} to domain model
    init(from entity: {EntityName}) {
        // Mapping implementation
    }
}

extension {EntityName} {
    /// Update entity from domain model
    func update(from domainModel: {DomainModel}) {
        // Update implementation
    }
}
```

## Data Transformation Patterns

### 1. Direct Property Mapping

```swift
// Simple 1:1 property mapping
self.id = entity.id
self.name = entity.name
self.email = entity.email
```

### 2. Property Name Transformation

```swift
// Handle naming inconsistencies between layers
self.city = entity.suburb  // Entity uses "suburb", domain uses "city"
self.name = entity.businessName ?? ""  // Entity uses "businessName", domain uses "name"
```

### 3. Data Type Conversion

```swift
// Handle type mismatches
self.position = Int32(entity.position)  // Entity uses Int16, domain uses Int32
self.timestamp = entity.timestamp ?? Date()  // Handle optional to non-optional
```

### 4. Relationship Flattening

```swift
// Flatten rich relationships to simple IDs
self.clientId = entity.client?.id
self.businessId = entity.business?.id
self.sessionIds = entity.sessions?.map { $0.id } ?? []
```

### 5. Computed Property Mapping

```swift
// Transform complex entity data into simple domain properties
self.street = "\(entity.streetNumber) \(entity.streetName)".trimmingCharacters(in: .whitespaces)
self.amount = Self.calculateAmount(from: entity.costComponents)
```

### 6. Business Logic Integration

```swift
// Apply business rules during mapping
self.price = Self.extractRepresentativePrice(from: entity.regionalPrices)
self.status = Self.determineStatus(from: entity.statusFlags)
```

## Error Handling Patterns

### 1. Graceful Degradation

```swift
// Provide sensible defaults for missing data
self.email = entity.email ?? ""
self.phone = entity.phone ?? ""
self.address = entity.address.map { Address(from: $0) }
```

### 2. Validation During Mapping

```swift
// Validate data during mapping
guard !entity.name.isEmpty else {
    throw MappingError.invalidData("Name cannot be empty")
}
self.name = entity.name
```

### 3. Logging and Monitoring

```swift
// Log mapping issues for debugging
if entity.regionalPrices.isEmpty {
    logger.warning("No regional prices found for NDIS item: \(entity.id)")
}
self.price = Self.extractRepresentativePrice(from: entity.regionalPrices)
```

## Performance Considerations

### 1. Lazy Loading

```swift
// Use lazy loading for expensive operations
lazy var fullFormattedAddress: String = {
    return self.computeFormattedAddress()
}()
```

### 2. Batch Operations

```swift
// Process multiple entities efficiently
let domainModels = entities.map { DomainModel(from: $0) }
```

### 3. Memory Management

```swift
// Avoid retaining large object graphs
self.sessionIds = entity.sessions?.map { $0.id } ?? []  // Only store IDs, not full objects
```

## Testing Patterns

### 1. Round-Trip Testing

```swift
func testRoundTripMapping() {
    let entity = createTestEntity()
    let domainModel = DomainModel(from: entity)
    let updatedEntity = createEmptyEntity()
    updatedEntity.update(from: domainModel)

    XCTAssertEqual(entity.id, updatedEntity.id)
    XCTAssertEqual(entity.name, updatedEntity.name)
}
```

### 2. Edge Case Testing

```swift
func testMappingWithNilValues() {
    let entity = createEntityWithNilValues()
    let domainModel = DomainModel(from: entity)

    XCTAssertNotNil(domainModel.id)
    XCTAssertEqual(domainModel.name, "")
    XCTAssertNil(domainModel.optionalField)
}
```

### 3. Performance Testing

```swift
func testMappingPerformance() {
    let entities = createLargeEntityArray()

    measure {
        let domainModels = entities.map { DomainModel(from: $0) }
        XCTAssertEqual(domainModels.count, entities.count)
    }
}
```

## Common Anti-Patterns to Avoid

### 1. Direct Entity Usage in Domain Layer

```swift
// ❌ BAD: Using entity directly in domain logic
func processInvoice(_ entity: InvoiceEntity) {
    // Domain logic mixed with persistence concerns
}

// ✅ GOOD: Using domain model in domain logic
func processInvoice(_ invoice: Invoice) {
    // Clean domain logic
}
```

### 2. Manual Property Copying

```swift
// ❌ BAD: Manual property copying (error-prone)
let updatedInvoice = Invoice(
    id: invoice.id,
    invoiceNumber: invoice.invoiceNumber,
    totalAmount: invoice.totalAmount,
    // ... 50+ more properties
)

// ✅ GOOD: Using update method
entity.update(from: domainModel)
```

### 3. Deep Object Graph Loading

```swift
// ❌ BAD: Loading entire object graph
self.client = entity.client  // Loads client with all relationships

// ✅ GOOD: Flattening relationships
self.clientId = entity.client?.id  // Only store ID
```

### 4. Inconsistent Naming

```swift
// ❌ BAD: Inconsistent naming between layers
// Entity: suburb, businessName, itemDescription
// Domain: city, name, description

// ✅ GOOD: Consistent naming
// Both layers use: city, name, description
```

## Migration Strategies

### 1. Property Renaming

```swift
// Step 1: Update entity property
public var city: String = ""  // Renamed from suburb

// Step 2: Update mapping
self.city = entity.city  // Updated from entity.suburb

// Step 3: Create migration script
// Step 4: Update all references
```

### 2. Type Changes

```swift
// Step 1: Update entity type
public var position: Int32 = 0  // Changed from Int16

// Step 2: Update all usages
itemEntity.position = item.position  // Remove type conversion

// Step 3: Update mapping
self.position = entity.position  // Remove Int32() conversion
```

### 3. Relationship Changes

```swift
// Step 1: Update delete rules
@Relationship(deleteRule: .nullify)  // Changed from .cascade

// Step 2: Update business logic
// Step 3: Test deletion scenarios
// Step 4: Update documentation
```

## Best Practices

### 1. Documentation

- **Document all mapping logic** with clear comments
- **Explain business rules** applied during mapping
- **Note any data transformations** or assumptions

### 2. Consistency

- **Use consistent naming** across all layers
- **Follow established patterns** for similar mappings
- **Maintain consistent error handling**

### 3. Testing

- **Test all mapping scenarios** including edge cases
- **Verify round-trip mapping** preserves data integrity
- **Performance test** with realistic data volumes

### 4. Maintenance

- **Review mappings regularly** for optimization opportunities
- **Update documentation** when patterns change
- **Monitor mapping performance** in production

## Conclusion

These patterns and conventions ensure consistent, maintainable, and performant data mapping between the persistence and domain layers. Following these guidelines helps prevent common issues and makes the codebase easier to understand and maintain.
