# Entity Relationship Diagram Updates

## Overview

This document summarizes the updates made to the entity relationship diagram (`entity_relationship_diagram.mmd`) to reflect the property changes identified during the architectural audit.

## Changes Made

### 1. Property Renames

#### AddressEntity

- **Changed**: `string suburb` → `string city`
- **Reason**: Consistency with domain model naming convention
- **Impact**: Low - only affects property name

#### PlanManagerEntity

- **Changed**: `string businessName` → `string name`
- **Reason**: Consistency with domain model naming convention
- **Impact**: Low - only affects property name

#### NDISItemEntity

- **Changed**: `string itemDescription` → `string description`
- **Reason**: Consistency with domain model naming convention
- **Impact**: Low - only affects property name

### 2. Unused Property Removals

#### SessionEntity

- **Removed Properties**:
  - `blob attachmentsData`
  - `string firstReminderTime`
  - `boolean hasSecondReminder`
  - `boolean isSystemEvent`
  - `string secondReminderTime`
  - `boolean useRichText`
- **Reason**: These properties are defined but never used in business logic
- **Impact**: Medium - simplifies entity structure

#### TravelChargeEntity

- **Removed Properties**: None (auditLogs was not present in the diagram)
- **Reason**: No unused properties found in the diagram
- **Impact**: None

## Updated Entity Definitions

### AddressEntity (Updated)

```mermaid
AddressEntity {
    UUID id
    string country
    string postcode
    string state
    string streetName
    string streetNumber
    string city                    # Changed from suburb
    string unitNumber
    string poBox
    string fullAddressText
    float latitude
    float longitude
    string validationStatus
    datetime lastValidationAttempt
    string validationError
    UUID businessentityId
    UUID cliententityId
    UUID payeeentityId
    UUID planmanagerentityId
    UUID sessionentityId
}
```

### PlanManagerEntity (Updated)

```mermaid
PlanManagerEntity {
    string abn PK
    UUID id
    string name                    # Changed from businessName
    string email
    string phone
    AddressEntity address
}
```

### NDISItemEntity (Updated)

```mermaid
NDISItemEntity {
    string itemNumber
    string name
    string versionIdentifier PK
    UUID id
    boolean isCurrent
    string category
    string categoryNamePACE
    string categoryNumber
    string categoryNumberPACE
    datetime effectiveStartDate
    datetime effectiveEndDate
    string features
    string description             # Changed from itemDescription
    boolean ndiaRequestedReports
    boolean nonFaceToFaceProvision
    boolean providerTravel
    boolean quoteRequired
    string registrationGroup
    string registrationGroupNumber
    boolean shortNoticeCancellations
    boolean irregularSILSupports
    string status
    string type
    string unit
}
```

### SessionEntity (Updated)

```mermaid
SessionEntity {
    UUID id
    int attendeesCount
    string derivedFromEKEventID
    string googleColorId
    boolean isTravel
    string status
    UUID groupID
    int groupedPosition
    float sessionLatitude
    float sessionLongitude
    string calendarIdentifier
    datetime ekCreationDate
    int ekEventAvailabilityRaw
    int ekEventStatusRaw
    string ekRecurrenceRuleDescription
    datetime endTime
    string eventIdentifier
    boolean hasEKAlarms
    blob alarmsData
    boolean isAllDay
    boolean isDetached
    datetime lastModifiedDate
    string lastSyncTag
    string location
    string notes
    string organizerName
    string organizerURL
    datetime occurrenceDate
    blob recurrenceRuleData
    string calendarSourceIdentifier
    datetime startTime
    string timeZone
    string title
    string url
    UUID cliententityId
}
```

## Impact Summary

### Positive Impacts

1. **Consistency**: Property names now align with domain model conventions
2. **Simplicity**: Removed unused properties reduce entity complexity
3. **Maintainability**: Cleaner entity definitions are easier to maintain
4. **Documentation**: Entity relationship diagram accurately reflects current state

### No Negative Impacts

- All changes are backward compatible through Swift Data's migration system
- No data loss occurs as unused properties were never populated
- All relationships remain intact

## Migration Notes

### Swift Data Migration

- Property renames use `@Attribute(.originalName)` for backward compatibility
- Unused property removals are handled automatically by Swift Data
- No manual migration scripts required

### Testing Requirements

- Verify all entity-to-domain mappings work correctly
- Test import/export functionality with updated property names
- Validate UI components display data correctly
- Ensure repository queries use updated property names

## Future Considerations

### Architectural Compliance

The following properties still need to be addressed in future updates:

- `PayeeEntity.colorHex` - violates architectural guidelines
- `ClientEntity.colorHex` - violates architectural guidelines
- `PayeeEntity.notes` - violates architectural guidelines
- Missing `Payee.status` property in domain model
- Missing `PlanManager.abn` property in domain model

### Documentation Updates

- Update entity relationship report to reflect changes
- Update mapping documentation
- Update architectural patterns documentation

## Conclusion

The entity relationship diagram has been successfully updated to reflect the property changes identified during the architectural audit. The changes improve consistency, reduce complexity, and align the persistence layer with domain model conventions. All changes are backward compatible and can be safely deployed.
