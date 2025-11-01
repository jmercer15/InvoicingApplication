# Property Usage Audit Report

## Overview

This report audits the usage of potentially unused entity properties across the codebase to identify properties that can be safely removed or need to be kept.

## ClientServiceEntity.ndisCode Property Audit

### Property Definition

```swift
public var ndisCode: String?
```

### Usage Analysis

**Status: ACTIVELY USED** ✅

The `ndisCode` property is extensively used throughout the codebase in 45 locations across multiple features:

#### 1. Data Services (2 usages)

- **NDISBillingIntegrationService.swift**: Used for billing integration
  - Line 65: `supportItemNumber: clientService.ndisCode ?? ""`
  - Line 144: `supportItemNumber: clientService.ndisCode ?? ""`

#### 2. Import/Export Services (3 usages)

- **AllDataImportService.swift**: Used for data import
  - Line 1207: `let ndisCode = dict["ndisCode"] as? String`
  - Line 1213: `clientService.ndisCode = ndisCode`
- **ServiceImport.swift**: Used for service import
  - Line 122: `clientService.ndisCode = item.code != "N/A" ? item.code : nil`

#### 3. UI Components (25+ usages)

- **ClientServiceEditorView.swift**: Used in service editing UI
  - Multiple references for NDIS code input and validation
- **ClientServicesListView.swift**: Used for display and computed properties
  - Line 196: Display logic
  - Line 363: `computedNdisCode` property that returns `ndisCode`
- **NDISBillingContextView.swift**: Used for billing context display
  - Line 105: `Text("Default: \(clientService.ndisCode ?? "None")")`
- **InvoicesView.swift**: Used in invoice display
  - Line 2075: Invoice item display with NDIS code
- **NDISBillingContainerView.swift**: Used in billing container
  - Line 219: Display logic
  - Line 1167: Billing logic
- **ServiceBulkEditorView.swift**: Used in bulk editing
  - Multiple references for bulk service editing
- **TravelChargeView.swift**: Used in travel charge calculations
  - Line 438: Display logic
  - Line 495: Travel charge logic

#### 4. View Models (8 usages)

- **ClientDetailViewModel.swift**: Used in client service management
  - Line 285: Service editing logic
  - Line 306: NDIS item assignment
  - Line 331: New service creation
  - Line 360: Custom service handling
  - Line 385: Template-based service creation
  - Line 428: Template application

#### 5. Import/Export Views (2 usages)

- **ImportExportView.swift**: Used in data import/export
  - Line 251: Import structure
  - Line 259: Field mapping

### Business Logic Dependencies

The `ndisCode` property is critical for:

1. **NDIS Billing Integration**: Used as the support item number for billing
2. **Service Identification**: Used to identify NDIS services vs custom services
3. **UI Display**: Used throughout the UI to show NDIS codes
4. **Data Import/Export**: Used in data migration and backup/restore
5. **Travel Charge Calculations**: Used in travel charge logic
6. **Invoice Generation**: Used in invoice item display

### Recommendation

**KEEP THE PROPERTY** - The `ndisCode` property is actively used and is essential for NDIS billing functionality. Removing it would break multiple features.

## ClientServiceEntity.endDate Property Audit

### Property Definition

```swift
public var endDate: Date?
```

### Usage Analysis

**Status: LIMITED USAGE** ⚠️

The `endDate` property has very limited usage across the codebase:

#### 1. Data Import (1 usage)

- **AllDataImportService.swift**: Used for data import
  - Line 1221: `clientService.endDate = ISO8601DateFormatter().date(from: endDateString)`

#### 2. UI Components (4 usages)

- **ClientServiceEditorView.swift**: Used in service editing UI
  - Line 104: `_hasEndDate = State(initialValue: currentService?.endDate != nil)`
  - Line 105: `_endDate = State(initialValue: currentService?.endDate)`
  - Line 613: `serviceToSave.endDate = hasEndDate ? endDate : nil`

#### 3. View Models (1 usage)

- **ClientDetailViewModel.swift**: Used in service creation
  - Line 433: `newService.endDate = nil`

### Business Logic Dependencies

The `endDate` property appears to be:

1. **Optional Service End Date**: Used to set when a client service ends
2. **UI Feature**: Available in the service editor but not heavily used
3. **Data Import**: Supported in data import/export

### Recommendation

**KEEP THE PROPERTY** - While usage is limited, the property is:

- Used in the UI for service editing
- Part of the data import/export functionality
- Represents a valid business concept (service end date)
- May be used more extensively in the future

## Next Properties to Audit

## ClientServiceEntity.startDate Property Audit

### Property Definition

```swift
public var startDate: Date?
```

### Usage Analysis

**Status: MODERATE USAGE** ✅

The `startDate` property has moderate usage across the codebase:

#### 1. Data Import (2 usages)

- **AllDataImportService.swift**: Used for data import
  - Line 1218: `clientService.startDate = ISO8601DateFormatter().date(from: startDateString)`
- **ServiceImport.swift**: Used for service import
  - Line 126: `clientService.startDate = Date() // Default start date to now`

#### 2. UI Components (3 usages)

- **ClientServiceEditorView.swift**: Used in service editing UI
  - Line 103: `_startDate = State(initialValue: currentService?.startDate ?? Date())`
  - Line 612: `serviceToSave.startDate = startDate`

#### 3. View Models (5 usages)

- **ClientDetailViewModel.swift**: Used in client service management
  - Line 140: Sorting logic `($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast)`
  - Line 339: `newService.startDate = Date()`
  - Line 356: `newService.startDate = Date()`
  - Line 392: `newService.startDate = Date()`
  - Line 432: `newService.startDate = Date()`

### Business Logic Dependencies

The `startDate` property is used for:

1. **Service Start Date**: Records when a client service begins
2. **Sorting Logic**: Used to sort client services by start date
3. **UI Features**: Available in the service editor
4. **Data Import**: Supported in data import/export
5. **Default Values**: Set to current date when creating new services

### Recommendation

**KEEP THE PROPERTY** - The `startDate` property is actively used for:

- Service sorting and organization
- UI functionality in service editing
- Data import/export functionality
- Business logic for service lifecycle management

## Next Properties to Audit

### PayeeEntity.colorHex

**Property Definition:**

var colorHex: String = ""

**Usage Analysis:**

- **Entity Definition**: PayeeEntity.swift:17
- **Initializer**: PayeeEntity.swift:29-32
- **Mapping**: Client+Mapping.swift:12, 77
- **Import/Export**: AllDataImportService.swift:235, 339, 400
- **UI Components**:
  - PayeeDetailView.swift:150
  - ClientDetailView.swift:82
  - CompactRowViews.swift:64
  - PayeeDetailViewModel.swift:76, 158, 180
  - ClientDetailViewModel.swift:108, 185
  - ClientsViewModel.swift:130, 165
- **Calendar Integration**: CalendarPreferences.swift:108, CalendarSettingsViewModel.swift:259, 263, 274, 283
- **Billing Hub**: BillingHubViewModel.swift:125, 135, 142, BillingHubView.swift:169, 187, 315, 316
- **Repository**: ClientsRepositorySwiftData.swift:57
- **Domain Model**: Client.swift:9, 32
- **Export Service**: SwiftDataExportService.swift:32, 52
- **Client Picker**: ClientPickerView.swift:95
- **Calendar Views**: MonthDayCellView.swift:202, 319, WeekView/CalendarItemBlockView.swift:24, 37, 54, 64
- **Import Services**: ClientImport.swift:184, 277, 293, PayeeImport.swift:143

**Business Logic Dependencies:**

- Color theming and visual identification of clients and payees
- UI consistency across calendar, billing, and client management views
- Import/export functionality for client and payee data
- Calendar integration for visual representation

**CRITICAL ARCHITECTURAL ISSUE:**
According to architectural guidance, colorHex is not supposed to be used at all, and hex colors aren't supposed to be used in general. This represents a major architectural violation where the codebase is using a deprecated/forbidden approach.

**Recommendation:**
REMOVE THE PROPERTY - This property violates architectural guidelines and should be removed. All usage of colorHex throughout the codebase needs to be refactored to use the approved color system. This is a high-priority architectural cleanup task.

### PayeeEntity.notes

**Property Definition:**

```swift
var notes: String?
```

**Usage Analysis:**

- **Entity Definition**: PayeeEntity.swift:19
- **ViewModels**:
  - PayeeDetailViewModel.swift:77, 159, 181
- **Import/Export**:
  - AllDataImportService.swift:347
  - PayeeImport.swift:169, 172
- **Export Service**: SwiftDataExportService.swift:55

**Business Logic Dependencies:**

- Payee detail editing functionality
- Import/export operations for payee data
- Data persistence for payee notes

**CRITICAL ARCHITECTURAL ISSUE:**
According to architectural guidance, payee is not supposed to have notes at all. This represents an architectural violation where the codebase is using a forbidden approach.

**Recommendation:**
REMOVE THE PROPERTY - This property violates architectural guidelines and should be removed. All usage of PayeeEntity.notes throughout the codebase needs to be refactored to remove this functionality. This is a high-priority architectural cleanup task.

### PayeeEntity.status

**Property Definition:**

var status: String?

**Usage Analysis:**

- **Entity Definition**: PayeeEntity.swift:23
- **ViewModels**:
  - PayeeDetailViewModel.swift:75, 157, 179, 307
- **UI Components**:
  - RelationshipsView.swift:230, 404, 405, 566
  - EntityRowViews.swift:104, 105
  - PayeeRowView.swift:566
- **Import/Export**:
  - AllDataImportService.swift:344
  - ImportExportView.swift:1328
  - ClientImport.swift:280
- **Export Service**: SwiftDataExportService.swift:55
- **RelationshipsContainerViewModel**: RelationshipsContainerViewModel.swift:213

**Business Logic Dependencies:**

- Payee detail editing functionality
- Status filtering and display in UI components
- Import/export operations for payee data
- Data persistence for payee status

**CRITICAL ARCHITECTURAL ISSUE:**
The Payee struct in Client.swift is supposed to have a status property, but it's currently missing. This represents a domain model incompleteness where the entity has a property that the domain model lacks.

**Recommendation:**
ADD MISSING PROPERTY - The Payee domain model in Client.swift needs to be updated to include the status property. This is a high-priority architectural fix to ensure domain-entity consistency.

### PlanManagerEntity.abn

**Property Definition:**

```swift
@Attribute(.unique) var abn: String
```

**Usage Analysis:**

- **Entity Definition**: PlanManagerEntity.swift:14
- **Initializer**: PlanManagerEntity.swift:21-24
- **ViewModels**:
  - PlanManagerDetailViewModel.swift:66, 144, 170
- **UI Components**:
  - PlanManagerDetailView.swift:142, 218, 247, 385, 495, 498, 499, 501, 508, 509
  - EntityRowViews.swift:141
  - RelationshipsView.swift:415
  - RelationshipsContainerViewModel.swift:221
  - BulkOperationsView.swift:198
- **Import/Export**:
  - AllDataImportService.swift:591, 737
- **NDIS Services**:
  - NDISBillingIntegrationService.swift:53, 134
  - NDISBillingService.swift:168, 220
- **Invoice Generation**:
  - Invoice.swift:142
  - InvoicesView.swift:715, 1202
  - A4InvoiceSheetView.swift:32
  - NDISBillingContainerView.swift:1261
- **Company Settings**:
  - CompanyView.swift:41, 42

**Business Logic Dependencies:**

- Plan manager detail editing functionality
- ABN validation and display in UI components
- Import/export operations for plan manager data
- NDIS billing integration and provider validation
- Invoice generation and business information display
- Company settings and business profile management

**ARCHITECTURAL DISCREPANCY:**
The PlanManager struct in Client.swift doesn't have an abn property, but the PlanManagerEntity does and it's being used extensively throughout the codebase. This represents a domain model incompleteness where the entity has a property that the domain model lacks.

**Recommendation:**
ADD MISSING PROPERTY - The PlanManager domain model in Client.swift needs to be updated to include the abn property. This is a high-priority architectural fix to ensure domain-entity consistency.

## Unused Properties Analysis

### SessionEntity - Truly Unused Properties

The following properties are defined in SessionEntity but are not used in any business logic:

1. **hasSecondReminder** - Only appears in entity definition, domain model, and mapping
2. **secondReminderTime** - Only appears in entity definition, domain model, and mapping
3. **useRichText** - Only appears in entity definition, domain model, and mapping
4. **isSystemEvent** - Only appears in entity definition, domain model, and mapping
5. **attachmentsData** - Only appears in entity definition, domain model, and mapping
6. **firstReminderTime** - Only appears in entity definition, domain model, and mapping

### TravelChargeEntity - Truly Unused Properties

The following properties are defined in TravelChargeEntity but are not used in any business logic:

1. **auditLogs** - Only appears in entity definition and documentation

### Recommendation

These properties should be removed from the entities and domain models as they represent dead code that adds complexity without providing value. This will simplify the data model and reduce maintenance overhead.

## Audit Methodology

### 1. Search Strategy

- Use `grep` to search for property name across entire codebase
- Check for both direct property access and computed properties
- Look for property in mapping files, repositories, and UI components

### 2. Usage Classification

- **Active Usage**: Property is directly accessed or used in business logic
- **Indirect Usage**: Property is used through computed properties or methods
- **Unused**: Property is defined but never accessed

### 3. Impact Assessment

- **Critical**: Property is essential for core functionality
- **Important**: Property is used in multiple features
- **Optional**: Property is used in limited scenarios
- **Unused**: Property can be safely removed

### 4. Removal Strategy

For unused properties:

1. **Backup**: Create data export before removal
2. **Migration**: Create migration script to remove property
3. **Testing**: Comprehensive testing after removal
4. **Documentation**: Update entity diagrams and documentation

## Conclusion

The `ndisCode` property audit shows that it is actively used throughout the codebase and is essential for NDIS billing functionality. The audit methodology established here will be used for the remaining property audits.
