# Mapping Troubleshooting Guide

## Common Issues and Solutions

### 1. Data Loss During Mapping

#### Problem

Data is lost when converting between entity and domain models.

#### Symptoms

- Properties are `nil` when they should have values
- Financial calculations are incorrect
- UI displays empty or default values

#### Common Causes

- **Hardcoded `nil` values** in mapping logic
- **Missing property mapping** in initializers
- **Incorrect data transformation** logic

#### Solutions

```swift
// ❌ BAD: Hardcoded nil
self.price = nil

// ✅ GOOD: Extract from related data
self.price = Self.extractRepresentativePrice(from: entity.regionalPrices)

// ❌ BAD: Missing property
init(from entity: SomeEntity) {
    self.id = entity.id
    // Missing: self.name = entity.name
}

// ✅ GOOD: All properties mapped
init(from entity: SomeEntity) {
    self.id = entity.id
    self.name = entity.name
    self.email = entity.email
}
```

#### Debugging Steps

1. **Add logging** to mapping methods
2. **Verify entity data** before mapping
3. **Test with known data** sets
4. **Check for type mismatches**

### 2. Type Conversion Errors

#### Problem

Compilation errors or runtime crashes due to type mismatches.

#### Symptoms

- Compiler errors about type incompatibility
- Runtime crashes with type conversion failures
- Unexpected `nil` values

#### Common Causes

- **Int16 vs Int32** mismatches
- **Optional vs non-optional** type differences
- **String vs String?** inconsistencies

#### Solutions

```swift
// ❌ BAD: Type mismatch
self.position = entity.position  // Int16 vs Int32

// ✅ GOOD: Explicit conversion
self.position = Int32(entity.position)

// ❌ BAD: Optional handling
self.timestamp = entity.timestamp  // Date? vs Date

// ✅ GOOD: Safe unwrapping
self.timestamp = entity.timestamp ?? Date()
```

#### Debugging Steps

1. **Check entity property types**
2. **Verify domain model types**
3. **Add type conversion** where needed
4. **Test with edge cases**

### 3. Relationship Mapping Issues

#### Problem

Relationships are not properly mapped between entity and domain models.

#### Symptoms

- Related objects are `nil` when they should exist
- Circular reference issues
- Performance problems with deep object graphs

#### Common Causes

- **Direct relationship assignment** instead of ID flattening
- **Missing relationship loading**
- **Circular reference** problems

#### Solutions

```swift
// ❌ BAD: Direct relationship assignment
self.client = entity.client  // Loads entire object graph

// ✅ GOOD: ID flattening
self.clientId = entity.client?.id

// ❌ BAD: Missing relationship handling
self.sessionIds = []  // Always empty

// ✅ GOOD: Proper relationship mapping
self.sessionIds = entity.sessions?.map { $0.id } ?? []
```

#### Debugging Steps

1. **Verify relationship loading** in repository
2. **Check for circular references**
3. **Use ID flattening** for performance
4. **Test relationship queries**

### 4. Business Logic Mapping Errors

#### Problem

Business rules are not correctly applied during mapping.

#### Symptoms

- Incorrect calculations
- Wrong status values
- Missing business logic

#### Common Causes

- **Missing business logic** in mapping
- **Incorrect calculation** formulas
- **Hardcoded values** instead of computed values

#### Solutions

```swift
// ❌ BAD: Hardcoded business logic
self.status = "pending"  // Always pending

// ✅ GOOD: Business logic applied
self.status = Self.determineStatus(from: entity.statusFlags)

// ❌ BAD: Simple assignment
self.amount = entity.baseAmount

// ✅ GOOD: Business calculation
self.amount = Self.calculateTotalAmount(
    baseAmount: entity.baseAmount,
    modifiers: entity.modifiers,
    discounts: entity.discounts
)
```

#### Debugging Steps

1. **Review business requirements**
2. **Test with various data scenarios**
3. **Verify calculation logic**
4. **Check for edge cases**

### 5. Performance Issues

#### Problem

Mapping operations are slow or cause memory issues.

#### Symptoms

- Slow UI updates
- High memory usage
- App crashes with large datasets

#### Common Causes

- **Loading entire object graphs**
- **Inefficient mapping loops**
- **Memory leaks** in mapping code

#### Solutions

```swift
// ❌ BAD: Loading entire object graph
self.client = entity.client  // Loads client with all relationships

// ✅ GOOD: Lazy loading
lazy var client: Client? = {
    return entity.client.map { Client(from: $0) }
}()

// ❌ BAD: Inefficient mapping
let domainModels = entities.map { entity in
    let domainModel = DomainModel(from: entity)
    // Expensive operations here
    return domainModel
}

// ✅ GOOD: Efficient mapping
let domainModels = entities.map { DomainModel(from: $0) }
```

#### Debugging Steps

1. **Profile mapping performance**
2. **Check memory usage**
3. **Optimize expensive operations**
4. **Use lazy loading** where appropriate

### 6. Data Validation Issues

#### Problem

Invalid data passes through mapping without validation.

#### Symptoms

- Invalid data in domain models
- Business rule violations
- Data integrity issues

#### Common Causes

- **Missing validation** in mapping
- **Incorrect validation logic**
- **Silent failures** in validation

#### Solutions

```swift
// ❌ BAD: No validation
self.email = entity.email

// ✅ GOOD: Validation with error handling
guard let email = entity.email, !email.isEmpty else {
    throw MappingError.invalidData("Email cannot be empty")
}
self.email = email

// ❌ BAD: Silent validation failure
if entity.amount < 0 {
    self.amount = 0  // Silent correction
}

// ✅ GOOD: Explicit validation
guard entity.amount >= 0 else {
    throw MappingError.invalidData("Amount cannot be negative")
}
self.amount = entity.amount
```

#### Debugging Steps

1. **Add validation** to mapping methods
2. **Test with invalid data**
3. **Handle validation errors** appropriately
4. **Log validation failures**

## Debugging Techniques

### 1. Logging and Monitoring

```swift
// Add comprehensive logging
func mapEntityToDomain(_ entity: SomeEntity) -> DomainModel {
    logger.debug("Mapping entity: \(entity.id)")

    let domainModel = DomainModel(from: entity)

    logger.debug("Mapped domain model: \(domainModel.id)")
    return domainModel
}
```

### 2. Unit Testing

```swift
// Test mapping with known data
func testMappingWithKnownData() {
    let entity = createTestEntity()
    let domainModel = DomainModel(from: entity)

    XCTAssertEqual(domainModel.id, entity.id)
    XCTAssertEqual(domainModel.name, entity.name)
    XCTAssertNotNil(domainModel.price)
}
```

### 3. Round-Trip Testing

```swift
// Test entity -> domain -> entity mapping
func testRoundTripMapping() {
    let originalEntity = createTestEntity()
    let domainModel = DomainModel(from: originalEntity)
    let updatedEntity = createEmptyEntity()
    updatedEntity.update(from: domainModel)

    XCTAssertEqual(originalEntity.id, updatedEntity.id)
    XCTAssertEqual(originalEntity.name, updatedEntity.name)
}
```

### 4. Edge Case Testing

```swift
// Test with edge cases
func testMappingWithNilValues() {
    let entity = createEntityWithNilValues()
    let domainModel = DomainModel(from: entity)

    XCTAssertNotNil(domainModel.id)
    XCTAssertEqual(domainModel.name, "")
    XCTAssertNil(domainModel.optionalField)
}
```

## Prevention Strategies

### 1. Code Reviews

- **Review all mapping code** for completeness
- **Check for hardcoded values**
- **Verify business logic** is correctly applied
- **Ensure error handling** is appropriate

### 2. Automated Testing

- **Unit tests** for all mapping methods
- **Integration tests** for repository operations
- **Performance tests** for large datasets
- **Edge case tests** for boundary conditions

### 3. Documentation

- **Document all mapping logic** with clear comments
- **Explain business rules** applied during mapping
- **Note any assumptions** or limitations
- **Keep documentation** up to date

### 4. Monitoring

- **Monitor mapping performance** in production
- **Log mapping errors** for debugging
- **Track data quality** metrics
- **Alert on mapping failures**

## Common Anti-Patterns

### 1. Manual Property Copying

```swift
// ❌ BAD: Manual copying (error-prone)
let updatedInvoice = Invoice(
    id: invoice.id,
    invoiceNumber: invoice.invoiceNumber,
    totalAmount: invoice.totalAmount,
    // ... 50+ more properties
)

// ✅ GOOD: Using update method
entity.update(from: domainModel)
```

### 2. Direct Entity Usage

```swift
// ❌ BAD: Using entity in domain logic
func processInvoice(_ entity: InvoiceEntity) {
    // Domain logic mixed with persistence
}

// ✅ GOOD: Using domain model
func processInvoice(_ invoice: Invoice) {
    // Clean domain logic
}
```

### 3. Missing Error Handling

```swift
// ❌ BAD: No error handling
self.price = entity.regionalPrices.first?.amount

// ✅ GOOD: Proper error handling
self.price = entity.regionalPrices.first?.amount ?? 0.0
```

### 4. Inconsistent Naming

```swift
// ❌ BAD: Inconsistent naming
// Entity: suburb, businessName
// Domain: city, name

// ✅ GOOD: Consistent naming
// Both: city, name
```

## Conclusion

This troubleshooting guide provides a comprehensive approach to identifying and resolving common mapping issues. By following these patterns and prevention strategies, you can avoid most mapping problems and maintain a robust data layer.
