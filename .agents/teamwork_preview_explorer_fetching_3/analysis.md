# SwiftData Fetching Remediation Plan — Milestone 2 Investigation

## 1. Executive Summary
This analysis report presents a detailed remediation plan to fix data-fetching inefficiencies and concurrency violations in the `InvoicingApplication` codebase. We focus on ten key files, providing target observations, a complete logic chain for proposed fixes, and concrete code replacement snippets.

---

## 2. Concurrency Remediation Details (Thread Safety)

Accessing `ModelContext` on background cooperative task threads violates SwiftData thread-isolation guidelines. We resolve this by:
1. Fetching identifiers asynchronously using background actors (e.g., `ReferenceDataWorkflowActor`).
2. Batch-resolving the model objects on the `MainActor` using a single database query with `FetchDescriptor`.
3. Performing state updates and callback invocations entirely on the `MainActor`.

### 2.1 File: `Packages/Feature.Clients/Sources/Feature_Clients/Views/ServiceAssignmentSheetView.swift`
* **Observation**: In lines 61-76, `modelContext.model(for:)` is called inside an asynchronous `.task` closure without isolating the model context lookup to the main thread.
* **Remediation**: Wrap the fetch in a `MainActor.run` closure, and optimize the loop using a batch `FetchDescriptor`.

#### Proposed Code Replacement (Lines 65-71)
**Before:**
```swift
                let ids = try await actor.fetchAllNDISItemIDs()
                let items = ids.compactMap { modelContext.model(for: $0) as? NDISItem }
                await MainActor.run {
                    self.availableNDISItems = items
                    self.updateFilteredItems()
                    self.isLoadingItems = false
                }
```
**After:**
```swift
                let ids = try await actor.fetchAllNDISItemIDs()
                let items = await MainActor.run {
                    let descriptor = FetchDescriptor<NDISItem>(
                        predicate: #Predicate { ids.contains($0.persistentModelID) }
                    )
                    return (try? modelContext.fetch(descriptor)) ?? []
                }
                await MainActor.run {
                    self.availableNDISItems = items
                    self.updateFilteredItems()
                    self.isLoadingItems = false
                }
```

---

### 2.2 File: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Editor/ModernTemplateEditorView.swift`
* **Observation**: In lines 58-71, the refresh `.task` resolves all invoices and businesses on a background thread by directly calling `modelContext.model(for:)`.
* **Remediation**: Wrap both queries inside `MainActor.run` using batched `FetchDescriptor`s.

#### Proposed Code Replacement (Lines 61-68)
**Before:**
```swift
                let invoiceIDs = try await actor.fetchAllInvoiceIDs()
                let businessIDs = try await actor.fetchAllBusinessIDs()
                let invoices = invoiceIDs.compactMap { modelContext.model(for: $0) as? Invoice }
                let businesses = businessIDs.compactMap { modelContext.model(for: $0) as? Business }
                
                await templateDataService.refreshSelectedInvoice(from: invoices)
                templateDataService.updateFallbackBusiness(businesses.first)
```
**After:**
```swift
                let invoiceIDs = try await actor.fetchAllInvoiceIDs()
                let businessIDs = try await actor.fetchAllBusinessIDs()
                
                let (invoices, businesses) = await MainActor.run {
                    let invoiceDesc = FetchDescriptor<Invoice>(
                        predicate: #Predicate { invoiceIDs.contains($0.persistentModelID) }
                    )
                    let businessDesc = FetchDescriptor<Business>(
                        predicate: #Predicate { businessIDs.contains($0.persistentModelID) }
                    )
                    return (
                        (try? modelContext.fetch(invoiceDesc)) ?? [],
                        (try? modelContext.fetch(businessDesc)) ?? []
                    )
                }
                
                await templateDataService.refreshSelectedInvoice(from: invoices)
                await MainActor.run {
                    templateDataService.updateFallbackBusiness(businesses.first)
                }
```

---

### 2.3 File: `Packages/Feature.Settings/Sources/Feature_Settings/Views/TravelCharge/TravelChargeAutomationTestView.swift`
* **Observation**: In lines 121-137, the task reloads all sessions and businesses using the main context directly on cooperative thread tasks.
* **Remediation**: Isolate the fetches to the `MainActor` using a batch `FetchDescriptor`.

#### Proposed Code Replacement (Lines 124-133)
**Before:**
```swift
                let sessionIDs = try await actor.fetchAllSessionIDs()
                let businessIDs = try await actor.fetchAllBusinessIDs()
                
                let sessions = sessionIDs.compactMap { modelContext.model(for: $0) as? Session }
                let businesses = businessIDs.compactMap { modelContext.model(for: $0) as? Business }
                
                await MainActor.run {
                    viewModel.updateSessions(sessions)
                    viewModel.updateBusiness(businesses.first)
                }
```
**After:**
```swift
                let sessionIDs = try await actor.fetchAllSessionIDs()
                let businessIDs = try await actor.fetchAllBusinessIDs()
                
                let (sessions, businesses) = await MainActor.run {
                    let sessionDesc = FetchDescriptor<Session>(
                        predicate: #Predicate { sessionIDs.contains($0.persistentModelID) }
                    )
                    let businessDesc = FetchDescriptor<Business>(
                        predicate: #Predicate { businessIDs.contains($0.persistentModelID) }
                    )
                    return (
                        (try? modelContext.fetch(sessionDesc)) ?? [],
                        (try? modelContext.fetch(businessDesc)) ?? []
                    )
                }
                
                await MainActor.run {
                    viewModel.updateSessions(sessions)
                    viewModel.updateBusiness(businesses.first)
                }
```

---

## 3. Data Fetching Optimization (Batching & Relationship Queries)

Running loop queries to resolve arrays of `PersistentIdentifier`s on the main thread generates $N$ database calls. Instead of loops, we query directly using relationship path matching or single-query `FetchDescriptor`s.

### 3.1 File: `Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/ClientDetailViewModel+Loading.swift`
* **Observation**: In lines 23-25, client services, invoices, and agreements are fetched by looping over IDs. In lines 43-44, payees and plan managers are loaded in a loop.
* **Remediation**: Use relationship-based `FetchDescriptor` predicates or fetch all catalog values in a single query since the catalogues are relatively small.

#### Proposed Code Replacement 1 (Lines 23-31)
**Before:**
```swift
            let services = serviceIDs.compactMap { self.modelContext.model(for: $0) as? ClientService }
            let invoices = invoiceIDs.compactMap { self.modelContext.model(for: $0) as? Invoice }
            let agreements = agreementIDs.compactMap { self.modelContext.model(for: $0) as? ServiceAgreement }
            
            await refreshProjectedData(
                clientServices: services,
                relatedInvoices: invoices,
                serviceAgreements: agreements
            )
```
**After:**
```swift
            let clientID = client.id
            let services = (try? modelContext.fetch(FetchDescriptor<ClientService>(
                predicate: #Predicate { $0.client?.id == clientID }
            ))) ?? []
            let invoices = (try? modelContext.fetch(FetchDescriptor<Invoice>(
                predicate: #Predicate { $0.client?.id == clientID }
            ))) ?? []
            let agreements = (try? modelContext.fetch(FetchDescriptor<ServiceAgreement>(
                predicate: #Predicate { $0.client?.id == clientID }
            ))) ?? []
            
            await refreshProjectedData(
                clientServices: services,
                relatedInvoices: invoices,
                serviceAgreements: agreements
            )
```

#### Proposed Code Replacement 2 (Lines 43-47)
**Before:**
```swift
            let payees = payeeIDs.compactMap { self.modelContext.model(for: $0) as? Payee }
            let planManagers = planManagerIDs.compactMap { self.modelContext.model(for: $0) as? PlanManager }
            
            self.payeeCatalogue = payees
            self.planManagerCatalogue = planManagers
```
**After:**
```swift
            let payees = (try? modelContext.fetch(FetchDescriptor<Payee>())) ?? []
            let planManagers = (try? modelContext.fetch(FetchDescriptor<PlanManager>())) ?? []
            
            self.payeeCatalogue = payees
            self.planManagerCatalogue = planManagers
```

---

### 3.2 File: `Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/PayeeDetailViewModel.swift`
* **Observation**: In lines 98-99, client and invoice objects are resolved in a loop.
* **Remediation**: Query the model context using the payee ID as a filter predicate.

#### Proposed Code Replacement (Lines 98-100)
**Before:**
```swift
            let linkedClients = clientIDs.compactMap { self.modelContext.model(for: $0) as? Client }
            let fetchedInvoices = invoiceIDs.compactMap { self.modelContext.model(for: $0) as? Invoice }
```
**After:**
```swift
            let payeeID = payee.id
            let linkedClients = (try? modelContext.fetch(FetchDescriptor<Client>(
                predicate: #Predicate { $0.payee?.id == payeeID }
            ))) ?? []
            let fetchedInvoices = (try? modelContext.fetch(FetchDescriptor<Invoice>(
                predicate: #Predicate { $0.payee?.id == payeeID }
            ))) ?? []
```

---

### 3.3 File: `Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/PlanManagerDetailViewModel.swift`
* **Observation**: In lines 90-91, linked clients and fetched invoices are resolved using loop-based model calls.
* **Remediation**: Fetch matching clients and invoices through relationship paths in single database queries.

#### Proposed Code Replacement (Lines 90-92)
**Before:**
```swift
            let linkedClients = clientIDs.compactMap { self.modelContext.model(for: $0) as? Client }
            let fetchedInvoices = invoiceIDs.compactMap { self.modelContext.model(for: $0) as? Invoice }
```
**After:**
```swift
            let managerID = planManager.id
            let linkedClients = (try? modelContext.fetch(FetchDescriptor<Client>(
                predicate: #Predicate { $0.planManager?.id == managerID }
            ))) ?? []
            let fetchedInvoices = (try? modelContext.fetch(FetchDescriptor<Invoice>(
                predicate: #Predicate { $0.client?.planManager?.id == managerID }
            ))) ?? []
```

---

### 3.4 File: `Packages/Feature.Invoices/Sources/Feature_Invoices/ViewModels/InvoicesContainerViewModel+List.swift`
* **Observation**: In lines 32-35, the list queries all invoice IDs in the background, but loops over them synchronously to load model properties on the Main Actor.
* **Remediation**: Execute the `FetchDescriptor<Invoice>` directly on the Main Actor context in a single batched query, bypassing background ID lookup.

#### Proposed Code Replacement (Lines 32-37)
**Before:**
```swift
            let modelIDs = try await listFetcher.invoiceModelIDs(matching: descriptor)
            try Task.checkCancellation()

            let invoices = modelIDs.compactMap { modelContext.model(for: $0) as? Invoice }
            invoiceEntities = invoices
            updateVisibleInvoices(invoices)
```
**After:**
```swift
            let invoices = try modelContext.fetch(descriptor)
            try Task.checkCancellation()

            invoiceEntities = invoices
            updateVisibleInvoices(invoices)
```

---

### 3.5 File: `Packages/Feature.Settings/Sources/Feature_Settings/ViewModels/ClaimBatchesViewModel.swift`
* **Observation**: In line 49, all claim batches are loaded in a loop. In line 59, claim lines are resolved using a loop.
* **Remediation**: Use `FetchDescriptor` with sorting or relationship predicates.

#### Proposed Code Replacement 1 (Lines 48-50)
**Before:**
```swift
            let ids = try await workflow.fetchAllBulkClaimBatchIDs()
            let batches = ids.compactMap { self.modelContext.model(for: $0) as? BulkClaimBatch }
            self.displayedBatches = batches
```
**After:**
```swift
            let descriptor = FetchDescriptor<BulkClaimBatch>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let batches = try modelContext.fetch(descriptor)
            self.displayedBatches = batches
```

#### Proposed Code Replacement 2 (Lines 58-59)
**Before:**
```swift
            let ids = try await workflow.fetchBulkClaimLineIDs(forBatch: batchId)
            return ids.compactMap { self.modelContext.model(for: $0) as? BulkClaimLine }
```
**After:**
```swift
            let descriptor = FetchDescriptor<BulkClaimLine>(
                predicate: #Predicate { $0.batch?.id == batchId }
            )
            return try modelContext.fetch(descriptor)
```

---

### 3.6 File: `Packages/Feature.Settings/Sources/Feature_Settings/Views/TravelCharge/TravelChargeReviewViewModel.swift`
* **Observation**: In line 51, all review items are fetched via ID loops.
* **Remediation**: Retrieve reviews directly using a batch `FetchDescriptor`.

#### Proposed Code Replacement (Lines 50-52)
**Before:**
```swift
            let ids = try await workflow.fetchAllTravelChargeReviewItemIDs()
            let reviews = ids.compactMap { modelContext.model(for: $0) as? TravelChargeReviewItem }
            self.reviewItemEntities = reviews
```
**After:**
```swift
            let descriptor = FetchDescriptor<TravelChargeReviewItem>()
            let reviews = try modelContext.fetch(descriptor)
            self.reviewItemEntities = reviews
```

---

### 3.7 File: `Packages/Feature.Calendar/Sources/Feature_Calendar/ViewModels/CalendarViewModel+Fetching.swift`
* **Observation**: In lines 173-175, all calendar sessions in the range are resolved one-by-one.
* **Remediation**: Batch resolve sessions by passing the list of `PersistentIdentifier`s to a single `FetchDescriptor`.

#### Proposed Code Replacement (Lines 173-175)
**Before:**
```swift
                fetchedSessions = sessionIDs.compactMap {
                    self.modelContext.model(for: $0) as? Session
                }
```
**After:**
```swift
                let descriptor = FetchDescriptor<Session>(
                    predicate: #Predicate { sessionIDs.contains($0.persistentModelID) }
                )
                fetchedSessions = (try? modelContext.fetch(descriptor)) ?? []
```

---

## 4. Verification Methodology
To verify that these changes are correct and maintain database integrity:
1. Build the packages using `swift build`.
2. Execute the existing unit test suites:
   * `swift test --package-path Packages/Core`
   * `swift test --package-path Packages/Data`
   * `swift test --package-path Packages/Feature.Clients`
   * `swift test --package-path Packages/Feature.Invoices`
   * `swift test --package-path Packages/Feature.Calendar`
   * `swift test --package-path Packages/Feature.Settings`
3. Profile database queries using Instruments (Core Data / SwiftData template) to ensure loop queries ($N$ fetches) are replaced by a single batch SELECT query.
