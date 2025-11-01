# InvoicingApplication

A comprehensive iOS invoicing application built with SwiftUI and SwiftData, designed for NDIS service providers and small businesses.

## Features

### 📅 Calendar & Session Management

- Multi-view calendar (Month, Week, Timeline, Agenda)
- Session creation and management
- Travel charge automation
- Recurring session support
- External calendar integration

### 💰 Invoicing & Billing

- NDIS billing automation
- Custom invoice templates
- Invoice generation and management
- Tax reporting (BAS)
- Expense tracking

### 👥 Client & Relationship Management

- Client database with detailed profiles
- Service assignments
- Payee management
- Plan manager tracking
- Bulk operations

### 🗺️ Location Services

- Travel charge calculation
- MMM zone integration
- Geocoding services
- Map integration

### ⚙️ Settings & Configuration

- Company profile management
- NDIS billing settings
- Data import/export
- Travel charge automation settings

## Technology Stack

- **Frontend**: SwiftUI
- **Data Persistence**: SwiftData
- **Architecture**: MVVM with modular feature-based structure
- **Dependencies**: Core Location, EventKit, MapKit
- **Build System**: Xcode

## Data Architecture

### Overview

The application uses a clean architecture approach with clear separation between domain models and persistence entities. This ensures maintainability, testability, and data integrity.

### Architecture Layers

#### 1. Domain Layer (`Core` Package)

- **Purpose**: Contains business logic and domain models
- **Models**: Pure Swift structs representing business concepts
- **Use Cases**: Business logic operations
- **Ports**: Repository interfaces for data access

#### 2. Data Layer (`Data` Package)

- **Purpose**: Handles data persistence and external integrations
- **Entities**: SwiftData `@Model` classes for persistence
- **Repositories**: SwiftData implementations of repository interfaces
- **Mapping**: Conversion between domain models and entities
- **Services**: External service integrations (NDIS, geocoding, etc.)

#### 3. Feature Layer (`Feature.*` Packages)

- **Purpose**: UI and feature-specific logic
- **Views**: SwiftUI views and view models
- **Models**: Feature-specific data models
- **Services**: Feature-specific business logic

### Key Architectural Patterns

#### Repository Pattern

```swift
// Domain layer defines the interface
protocol InvoicesRepository {
    func fetch(by id: UUID) async throws -> Invoice?
    func create(_ invoice: Invoice) async throws -> Invoice
    func update(_ invoice: Invoice) async throws -> Invoice
}

// Data layer provides the implementation
class InvoicesRepositorySwiftData: InvoicesRepository {
    // SwiftData implementation
}
```

#### Domain-Entity Mapping

```swift
// Entity to Domain conversion
extension Invoice {
    init(fromEntity entity: InvoiceEntity) {
        self.id = entity.id
        self.invoiceNumber = entity.invoiceNumber
        // ... other properties
    }
}

// Domain to Entity update
extension InvoiceEntity {
    func update(from invoice: Invoice) {
        self.invoiceNumber = invoice.invoiceNumber
        // ... other properties
    }
}
```

#### Data Transfer Objects (DTOs)

- Domain models use flattened relationships (IDs instead of full objects)
- Prevents accidental loading of deep object graphs
- Ensures lightweight data transfer between layers

### Data Integrity Features

#### Relationship Management

- **Cascade Deletes**: For strong ownership relationships
- **Nullify Deletes**: For shared resources and optional relationships
- **Audit Trail**: Comprehensive logging of data changes

#### Validation and Constraints

- **Unique Constraints**: On business identifiers (NDIS numbers, ABNs)
- **Data Validation**: At both entity and domain levels
- **Business Rule Enforcement**: Through domain models and use cases

#### Error Handling

- **Graceful Degradation**: Sensible defaults for missing data
- **Comprehensive Logging**: For debugging and monitoring
- **Data Recovery**: Strategies for handling data inconsistencies

### Performance Optimizations

#### Query Optimization

- **Indexed Properties**: For frequently queried fields
- **Predicate Optimization**: Efficient SwiftData queries
- **Lazy Loading**: For expensive operations

#### Memory Management

- **Relationship Flattening**: Prevents memory leaks
- **Batch Operations**: For large data sets
- **Efficient Mapping**: Minimal object creation

### Data Migration Strategy

#### Schema Evolution

- **Backward Compatibility**: Maintains data integrity during updates
- **Migration Scripts**: For structural changes
- **Data Validation**: Ensures migration success

#### Property Renaming

- **Consistent Naming**: Between domain and entity layers
- **Migration Support**: For existing data
- **Documentation**: Clear mapping between old and new names

### Security and Compliance

#### Data Protection

- **Encryption**: For sensitive data at rest
- **Access Control**: Role-based data access
- **Audit Logging**: Comprehensive change tracking

#### NDIS Compliance

- **Data Retention**: Meets NDIS requirements
- **Privacy Protection**: Client data handling
- **Reporting**: Automated compliance reporting

### Monitoring and Observability

#### Data Quality

- **Integrity Checks**: Automated data validation
- **Performance Monitoring**: Query and mapping performance
- **Error Tracking**: Comprehensive error logging

#### Business Metrics

- **Usage Analytics**: Feature usage tracking
- **Performance Metrics**: Response times and throughput
- **Data Quality Metrics**: Validation success rates

### Development Guidelines

#### Adding New Entities

1. Create SwiftData entity in `Data/Persistence/`
2. Create domain model in `Core/Domain/`
3. Implement mapping in `Data/Mapping/`
4. Create repository interface in `Core/Ports/`
5. Implement repository in `Data/Repositories/`
6. Add comprehensive tests

#### Mapping Best Practices

- **Consistent Naming**: Use same property names across layers
- **Type Safety**: Handle type conversions explicitly
- **Error Handling**: Provide sensible defaults for missing data
- **Performance**: Use efficient mapping patterns
- **Documentation**: Document all business logic in mappings

#### Testing Strategy

- **Unit Tests**: For all mapping logic
- **Integration Tests**: For repository operations
- **Round-Trip Tests**: Entity ↔ Domain ↔ Entity
- **Performance Tests**: For large datasets
- **Edge Case Tests**: For boundary conditions

For detailed information about specific architectural patterns and troubleshooting, see:

- [Architectural Patterns and Conventions](Packages/Data/Sources/Data/Mapping/Architectural_Patterns_and_Conventions.md)
- [Troubleshooting Guide](Packages/Data/Sources/Data/Mapping/Troubleshooting_Guide.md)
- [Relationship Delete Rules Audit](Packages/Data/Sources/Data/Mapping/Relationship_Delete_Rules_Audit.md)

## Project Structure

```
InvoicingApplication/
├── Core/                    # App core and configuration
├── Features/               # Feature modules
│   ├── Calendar/          # Calendar and session management
│   ├── Dashboard/         # Analytics and metrics
│   ├── Invoices/          # Invoice generation
│   ├── NDIS/             # NDIS-specific features
│   ├── Relationships/     # Client and entity management
│   ├── Settings/         # App configuration
│   └── Tax/              # Tax and expense management
├── Models/                # Data models and entities
├── Services/              # Business logic and external services
├── Components/            # Reusable UI components
├── Shared/               # Shared assets and utilities
└── Utilities/            # Helper functions and extensions
```

## Getting Started

### Prerequisites

- Xcode 15.0 or later
- iOS 17.0 or later
- macOS 14.0 or later (for development)

### Installation

1. Clone the repository
2. Open `InvoicingApplication.xcodeproj` in Xcode
3. Build and run the project

### Configuration

- Configure your company details in Settings
- Set up NDIS billing settings if applicable
- Import your client and service data

## Development

### Code Style

- Follow SwiftUI best practices
- Use MVVM architecture pattern
- Implement proper error handling
- Add comprehensive documentation

### Testing

- Unit tests for business logic
- UI tests for critical user flows
- Integration tests for data persistence

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is proprietary software. All rights reserved.

## Support

For support and questions, please contact the development team.
