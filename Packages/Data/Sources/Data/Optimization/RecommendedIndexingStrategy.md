# Recommended SwiftData Indexing Strategy

## Overview

This document outlines the recommended indexing strategy for the InvoicingApplication SwiftData models to optimize query performance. The `@Index` attribute is not yet available in the current SwiftData implementation, but this document serves as a guide for when it becomes available.

## Indexing Principles

Based on the Apple SwiftData documentation referenced at:

- https://developer.apple.com/documentation/swiftdata/index(_:)-74ia2
- https://developer.apple.com/documentation/swiftdata/index(_:)-7d4z0

**Key Principle**: "Index the way you query. Add @Index(...) for fields (or tuples) you sort/filter on regularly—this can dramatically reduce fetch costs on larger data sets."

## Recommended Indexes by Entity

### ClientEntity

```swift
@Index public var fullName: String        // Frequently sorted and searched
@Index public var status: String          // Frequently filtered (active/inactive)
@Index public var email: String?          // Frequently searched
@Index public var phone: String?         // Occasionally searched
@Index public var isMinor: Bool          // Occasionally filtered
@Index public var hasNdisPlan: Bool       // Frequently filtered
```

### InvoiceEntity

```swift
@Index public var status: String?        // Frequently filtered (draft/sent/paid)
@Index public var issueDate: Date        // Frequently sorted and filtered
@Index public var dueDate: Date?         // Frequently filtered for overdue invoices
@Index public var totalAmount: Double    // Occasionally sorted
@Index public var paidDate: Date?        // Occasionally filtered
@Index public var sentDate: Date?        // Occasionally filtered
```

### SessionEntity

```swift
@Index public var startTime: Date?        // Frequently sorted and filtered
@Index public var endTime: Date?          // Frequently filtered
@Index public var status: String?         // Frequently filtered
@Index public var isTravel: Bool         // Frequently filtered
@Index public var location: String?       // Occasionally searched
```

### NDISItemEntity

```swift
@Index public var itemNumber: String     // Frequently searched
@Index public var name: String         // Frequently searched and sorted
@Index public var isCurrent: Bool         // Frequently filtered
@Index public var category: String?       // Frequently filtered and grouped
@Index public var registrationGroup: String? // Frequently filtered and grouped
@Index public var effectiveStartDate: Date?   // Frequently sorted
@Index public var effectiveEndDate: Date?     // Frequently filtered
@Index public var itemDescription: String?    // Frequently searched
@Index public var quoteRequired: Bool?         // Frequently filtered
@Index public var status: String?             // Frequently filtered
@Index public var type: String?               // Frequently filtered
```

## Composite Indexes

For complex queries that filter on multiple fields, consider composite indexes:

### InvoiceEntity Composite Indexes

```swift
// For status filtering with date sorting
@Index(public var status: String?, public var issueDate: Date)

// For client invoices by status
@Index(public var clientId: String, public var status: String?)

// For overdue invoice queries
@Index(public var dueDate: Date?, public var status: String?)
```

### SessionEntity Composite Indexes

```swift
// For client sessions by date
@Index(public var clientId: String, public var startTime: Date?)

// For time range queries
@Index(public var startTime: Date?, public var endTime: Date?)

// For status filtering with date sorting
@Index(public var status: String?, public var startTime: Date?)

// For travel sessions by date
@Index(public var isTravel: Bool, public var startTime: Date?)
```

### ClientEntity Composite Indexes

```swift
// For active clients sorted by name
@Index(public var status: String, public var fullName: String)

// For NDIS clients by status
@Index(public var hasNdisPlan: Bool, public var status: String)

// For minor clients by status
@Index(public var isMinor: Bool, public var status: String)
```

## Implementation Notes

1. **Primary Keys**: `id` fields are automatically indexed and don't need explicit `@Index` attributes.

2. **Unique Constraints**: Fields with `@Attribute(.unique)` are automatically indexed.

3. **Foreign Keys**: Relationship fields that are frequently used in joins should be indexed.

4. **Search Fields**: Text fields used in search operations should be indexed.

5. **Sort Fields**: Fields used in `sortBy` descriptors should be indexed.

6. **Filter Fields**: Fields used in `#Predicate` filters should be indexed.

## Performance Impact

Based on the Apple documentation, proper indexing can:

- Dramatically reduce fetch costs on larger datasets
- Improve query performance for filtered and sorted operations
- Reduce memory usage during complex queries
- Speed up relationship traversals

## Migration Strategy

When `@Index` becomes available in SwiftData:

1. **Phase 1**: Add indexes to the most frequently queried fields
2. **Phase 2**: Add composite indexes for complex query patterns
3. **Phase 3**: Monitor performance and add additional indexes as needed
4. **Phase 4**: Remove unused indexes to optimize storage

## Monitoring and Optimization

- Use SwiftData's performance monitoring tools to identify slow queries
- Add indexes based on actual query patterns, not theoretical ones
- Regularly review and optimize index usage
- Consider the trade-off between query performance and storage overhead

## Current Workarounds

Until `@Index` is available, consider:

- Using `FetchDescriptor` with optimized `sortBy` and `predicate` parameters
- Implementing efficient in-memory filtering for small datasets
- Using relationship-based queries instead of complex joins where possible
- Caching frequently accessed data in memory
