# Travel Charge Architectural Analysis

## Critical Conceptual Differences Between Entity and Domain Models

### TravelChargeEntity vs TravelCharge

#### Entity Model (TravelChargeEntity)

- **Complex NDIS-focused structure** with 20+ properties
- **EventRepresentable protocol** - inherits calendar integration properties
- **Cost breakdown approach**: Separate fields for `parkingCost`, `tollCost`, `travelDistance`, `travelDuration`
- **NDIS-specific fields**: `mmmZoneName`, `chargeType`, `participantCount`, `splitCosts`
- **Relationship-based**: Links to `SessionEntity`, `ClientEntity`, `ClientServiceEntity`
- **No status field**: Status information is not explicitly stored
- **No amount field**: Amount must be calculated from component costs
- **No created date**: Uses `ekCreationDate` from EventKit integration

#### Domain Model (TravelCharge)

- **Simple, focused structure** with 12 properties
- **Business-focused**: Designed for invoice generation and billing
- **Single amount field**: `amount: Double` for total cost
- **Status-driven**: Explicit `TravelChargeStatus` enum
- **Address-based**: Separate `fromAddress` and `toAddress` fields
- **Time-based**: `travelTime: TimeInterval` instead of duration
- **Audit trail**: `createdDate` and `lastModifiedDate` for tracking

### TravelChargeAuditLogEntity vs TravelChargeAuditLog

#### Entity Model (TravelChargeAuditLogEntity)

- **Relationship-based**: Links to `TravelChargeEntity` via relationship
- **Optional timestamp**: `timestamp: Date?`
- **Summary field**: `summary: String?` (used for performedBy in mapping)
- **Action field**: `action: String?`

#### Domain Model (TravelChargeAuditLog)

- **ID-based**: Uses `travelChargeId: UUID` instead of relationship
- **Required timestamp**: `timestamp: Date`
- **PerformedBy field**: `performedBy: String?` (mapped from summary)
- **Action field**: `action: String` (required)

### TravelChargeReviewItemEntity vs TravelChargeReviewItem

#### Entity Model (TravelChargeReviewItemEntity)

- **Complex violation tracking**: JSON-encoded arrays for violations, details, actions
- **Session relationship**: Links to `SessionEntity` instead of travel charge
- **Status enum**: String-based status with multiple states
- **Override system**: Complex override tracking with types and reasons
- **Computed properties**: Helper methods for violation checking

#### Domain Model (TravelChargeReviewItem)

- **Simple violation tracking**: Single `hasViolations: Bool` and `violationDescription: String?`
- **Travel charge relationship**: Links to `travelChargeId: UUID`
- **Simple review**: Basic review date and reviewer information
- **No override system**: Simplified model without complex override logic

## Architectural Implications

### 1. Data Loss Risk

The mapping between these models involves significant data transformation and potential loss:

- Entity's complex cost breakdown → Domain's single amount
- Entity's JSON-encoded violation arrays → Domain's simple boolean + description
- Entity's override system → Domain's simple review model

### 2. Business Logic Complexity

The entity model appears designed for complex NDIS compliance and billing scenarios, while the domain model is simplified for basic invoice generation. This suggests:

- The feature may be over-engineered for current requirements
- Business logic for cost calculation and violation handling is missing
- The domain model may not support all required business scenarios

### 3. Integration Challenges

- EventRepresentable protocol adds calendar integration complexity
- Relationship-based vs ID-based approaches create mapping overhead
- Optional vs required fields create validation challenges

## Recommendations

### Immediate Actions Required

1. **Decide on single source of truth**: Either simplify the entity model to match domain requirements or enhance the domain model to support entity complexity
2. **Implement proper business logic**: Add cost calculation and violation handling logic
3. **Create comprehensive mapping tests**: Ensure no data loss during transformations
4. **Document business rules**: Clearly define how costs are calculated and violations are handled

### Long-term Architectural Decisions

1. **Feature scope**: Determine if the complex NDIS compliance features are actually needed
2. **Model alignment**: Choose either entity-first or domain-first approach and align both models
3. **Integration strategy**: Decide how calendar integration should work with the domain model
4. **Data migration**: Plan for migrating existing data to the chosen model structure
