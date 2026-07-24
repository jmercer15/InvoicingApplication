# Data-Fetching Inefficiencies and Concurrency Remediation Plan (Milestone 2)

## 1. Executive Summary
This report outlines the proposed remediation changes for 10 files in the `InvoicingApplication` codebase. The focus of this audit is:
1. **Thread Concurrency Violations**: Resolving instances where a non-thread-safe `ModelContext` is accessed on a cooperative background thread.
2. **Main Thread Blocking**: Replacing loops that resolve lists of `PersistentIdentifier` instances using synchronous `modelContext.model(for:)` calls on the `@MainActor` with optimized batch fetches using SwiftData `FetchDescriptor`.

---

## 2. Target Files Analysis & Proposed Snippets

### File 1: `Packages/Feature.Clients/Sources/Feature_Clients/Views/ServiceAssignmentSheetView.swift`
* **Issue Type**: Thread Concurrency Violation
* **Location**: Lines 61-76
* **Rationale**: The `.task` modifier executes its closure on a cooperative background thread. Accessing `modelContext.model(for:)` directly on this background thread violates the thread-safety rules of `ModelContext`. Wrapping the resolution logic in `MainActor.run` or using a batch fetch ensures thread safety.
* **Proposed Snippet**:
```swift
// Target File: Packages/Feature.Clients/Sources/Feature_Clients/Views/ServiceAssignmentSheetView.swift
// Replacement for lines 61-76:

        .task {
            isLoadingItems = true
            let actor = ReferenceDataWorkflowActor(modelContainer: modelContext.container)
            do {
                let ids = try await actor.fetchAllNDISItemIDs()
                await MainActor.run {
                    let items = ids.compactMap { modelContext.model(for: $0) as? NDISItem }
                    self.availableNDISItems = items
                    self.updateFilteredItems()
                    self.isLoadingItems = false
                }
            } catch {
                print("Failed to fetch NDIS items: \(error)")
                await MainActor.run { self.isLoadingItems = false }
            }
        }
```
* **Alternative (Optimal Batch Fetch)**:
```swift
// Target File: Packages/Feature.Clients/Sources/Feature_Clients/Views/ServiceAssignmentSheetView.swift
// Replacement for lines 61-76:

        .task {
            isLoadingItems = true
            await MainActor.run {
                do {
                    let descriptor = FetchDescriptor<NDISItem>(sortBy: [SortDescriptor(\.itemNumber)])
                    let items = try modelContext.fetch(descriptor)
                    self.availableNDISItems = items
                    self.updateFilteredItems()
                    self.isLoadingItems = false
                } catch {
                    print("Failed to fetch NDIS items: \(error)")
                    self.isLoadingItems = false
                }
            }
        }
```

---

### File 2: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Editor/ModernTemplateEditorView.swift`
* **Issue Type**: Thread Concurrency Violation
* **Location**: Lines 58-71
* **Rationale**: `modelContext` is accessed on a cooperative background thread inside the `.task(id:)` modifier. The mapping must occur inside a `MainActor.run` block, or alternatively use batch fetches directly on the main context.
* **Proposed Snippet**:
```swift
// Target File: Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Editor/ModernTemplateEditorView.swift
// Replacement for lines 58-71:

        .task(id: refreshTaskID) {
            let actor = ReferenceDataWorkflowActor(modelContainer: modelContext.container)
            do {
                let invoiceIDs = try await actor.fetchAllInvoiceIDs()
                let businessIDs = try await actor.fetchAllBusinessIDs()
                
                let (invoices, businesses) = await MainActor.run {
                    (
                        invoiceIDs.compactMap { modelContext.model(for: $0) as? Invoice },
                        businessIDs.compactMap { modelContext.model(for: $0) as? Business }
                    )
                }
                
                await templateDataService.refreshSelectedInvoice(from: invoices)
                await MainActor.run {
                    templateDataService.updateFallbackBusiness(businesses.first)
                }
            } catch {
                print("Failed to load reference data for template editor: \(error)")
            }
        }
```

---

### File 3: `Packages/Feature.Settings/Sources/Feature_Settings/Views/TravelCharge/TravelChargeAutomationTestView.swift`
* **Issue Type**: Thread Concurrency Violation
* **Location**: Lines 121-137
* **Rationale**: Same as above; mapping of `sessionIDs` and `businessIDs` using the non-thread-safe `modelContext` is executed on cooperative background threads.
* **Proposed Snippet**:
```swift
// Target File: Packages/Feature.Settings/Sources/Feature_Settings/Views/TravelCharge/TravelChargeAutomationTestView.swift
// Replacement for lines 121-137:

        .task(id: refreshTaskID) {
            let actor = ReferenceDataWorkflowActor(modelContainer: modelContext.container)
            do {
                let sessionIDs = try await actor.fetchAllSessionIDs()
                let businessIDs = try await actor.fetchAllBusinessIDs()
                
                await MainActor.run {
                    let sessions = sessionIDs.compactMap { modelContext.model(for: $0) as? Session }
                    let businesses = businessIDs.compactMap { modelContext.model(for: $0) as? Business }
                    viewModel.updateSessions(sessions)
                    viewModel.updateBusiness(businesses.first)
                }
            } catch {
                print("Failed to fetch data for TravelChargeAutomationTestView: \(error)")
            }
        }
```

---

### File 4: `Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/ClientDetailViewModel+Loading.swift`
* **Issue Type**: Main Thread Blocking / Loop-Based Resolution
* **Location**: Lines 17-31 (`refreshProjectedData`) and Lines 37-48 (`loadReferencePickers`)
* **Rationale**: The view model is marked `@MainActor`. Loop-based resolution of IDs (`compactMap` calling `model(for:)`) causes Main Thread pauses on large lists. Performing a single batch query via `FetchDescriptor` directly on the Main Actor's `modelContext` is optimized by SQLite.
* **Proposed Snippet**:
```swift
// Target File: Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/ClientDetailViewModel+Loading.swift
// Replacement for lines 17-31 and lines 37-48:

    /// Fetches all relationship data for the client asynchronously to prevent UI blocks.
    func refreshProjectedData(using workflowActor: ReferenceDataWorkflowActor) async {
        let clientId = client.id
        let servicesDescriptor = FetchDescriptor<ClientService>(
            predicate: #Predicate<ClientService> { $0.client?.id == clientId },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let invoicesDescriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { $0.client?.id == clientId },
            sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
        )
        let agreementsDescriptor = FetchDescriptor<ServiceAgreement>(
            predicate: #Predicate<ServiceAgreement> { $0.client?.id == clientId },
            sortBy: [SortDescriptor(\.effectiveFrom, order: .reverse)]
        )
        
        let services = (try? self.modelContext.fetch(servicesDescriptor)) ?? []
        let invoices = (try? self.modelContext.fetch(invoicesDescriptor)) ?? []
        let agreements = (try? self.modelContext.fetch(agreementsDescriptor)) ?? []
        
        await refreshProjectedData(
            clientServices: services,
            relatedInvoices: invoices,
            serviceAgreements: agreements
        )
    }

    func loadReferencePickers(using workflowActor: ReferenceDataWorkflowActor) async {
        let payeesDescriptor = FetchDescriptor<Payee>(sortBy: [SortDescriptor(\.fullName)])
        let planManagersDescriptor = FetchDescriptor<PlanManager>(sortBy: [SortDescriptor(\.name)])
        
        let payees = (try? self.modelContext.fetch(payeesDescriptor)) ?? []
        let planManagers = (try? self.modelContext.fetch(planManagersDescriptor)) ?? []
        
        self.payeeCatalogue = payees
        self.planManagerCatalogue = planManagers
        
        if let id = selectedPayee?.id {
            selectedPayee = payees.first { $0.id == id } ?? selectedPayee
        }
        if let id = selectedPlanManager?.id {
            selectedPlanManager = planManagers.first { $0.id == id } ?? selectedPlanManager
        }
    }
```

---

### File 5: `Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/PayeeDetailViewModel.swift`
* **Issue Type**: Main Thread Blocking / Loop-Based Resolution
* **Location**: Lines 90-111
* **Rationale**: Similar to the Client VM, this resolver performs sequential `model(for:)` lookups on the Main Actor. Replacing it with batch `FetchDescriptor` queries removes the thread blockage.
* **Proposed Snippet**:
```swift
// Target File: Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/PayeeDetailViewModel.swift
// Replacement for lines 90-111:

    func refreshRelatedInvoices(using workflowActor: ReferenceDataWorkflowActor) async {
        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        let payeeID = payee.id
        let clientsDescriptor = FetchDescriptor<Client>(
            predicate: #Predicate<Client> { $0.payee?.id == payeeID },
            sortBy: [SortDescriptor(\.fullName)]
        )
        let invoicesDescriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { $0.payee?.id == payeeID },
            sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
        )
        
        let linkedClients = (try? self.modelContext.fetch(clientsDescriptor)) ?? []
        let fetchedInvoices = (try? self.modelContext.fetch(invoicesDescriptor)) ?? []
        
        self.lastAllInvoices = fetchedInvoices
        let fetchedIDs = Set(linkedClients.map(\.id))
        if selectedClientIDs.isEmpty {
            selectedClientIDs = fetchedIDs
        }
        self.relatedInvoices = fetchedInvoices
        self.linkedClients = linkedClients
    }
```

---

### File 6: `Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/PlanManagerDetailViewModel.swift`
* **Issue Type**: Main Thread Blocking / Loop-Based Resolution
* **Location**: Lines 82-99
* **Rationale**: Resolves relations sequentially in a loop. Replacing it with direct batch fetches optimizes performance.
* **Proposed Snippet**:
```swift
// Target File: Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/PlanManagerDetailViewModel.swift
// Replacement for lines 82-99:

    func refreshRelatedInvoices(using workflowActor: ReferenceDataWorkflowActor) async {
        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        let planManagerID = planManager.id
        let clientsDescriptor = FetchDescriptor<Client>(
            predicate: #Predicate<Client> { $0.planManager?.id == planManagerID },
            sortBy: [SortDescriptor(\.fullName)]
        )
        let invoicesDescriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { $0.client?.planManager?.id == planManagerID },
            sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
        )
        
        let linkedClients = (try? self.modelContext.fetch(clientsDescriptor)) ?? []
        let fetchedInvoices = (try? self.modelContext.fetch(invoicesDescriptor)) ?? []
        
        self.lastAllInvoices = fetchedInvoices
        self.relatedInvoices = fetchedInvoices
        self.linkedClients = linkedClients
    }
```

---

### File 7: `Packages/Feature.Invoices/Sources/Feature_Invoices/ViewModels/InvoicesContainerViewModel+List.swift`
* **Issue Type**: Main Thread Blocking / Loop-Based Resolution
* **Location**: Lines 29-45
* **Rationale**: `reloadInvoices` fetches model IDs from `listFetcher` in the background and resolves the actual models on the main actor thread one-by-one. Since `FetchDescriptor<Invoice>` is already available, we can fetch all instances directly in one batch query.
* **Proposed Snippet**:
```swift
// Target File: Packages/Feature.Invoices/Sources/Feature_Invoices/ViewModels/InvoicesContainerViewModel+List.swift
// Replacement for lines 29-45:

    func reloadInvoices(matching descriptor: FetchDescriptor<Invoice>) async {
        do {
            try Task.checkCancellation()
            let invoices = try modelContext.fetch(descriptor)
            try Task.checkCancellation()

            invoiceEntities = invoices
            updateVisibleInvoices(invoices)
        } catch is CancellationError {
            return
        } catch {
            invoiceEntities = []
            updateVisibleInvoices([])
            print("❌ [InvoicesContainerViewModel] Failed loading invoices: \(error)")
        }
    }
```

---

### File 8: `Packages/Feature.Settings/Sources/Feature_Settings/ViewModels/ClaimBatchesViewModel.swift`
* **Issue Type**: Main Thread Blocking / Loop-Based Resolution
* **Location**: Lines 46-54 (`refreshBatches`) and Lines 56-64 (`fetchLines`)
* **Rationale**: Resolves `BulkClaimBatch` and `BulkClaimLine` entities synchronously on the main thread inside mapping loops. Replacing with `modelContext.fetch` executes a single SQL query.
* **Proposed Snippet**:
```swift
// Target File: Packages/Feature.Settings/Sources/Feature_Settings/ViewModels/ClaimBatchesViewModel.swift
// Replacement for lines 46-64:

    public func refreshBatches() async {
        do {
            let descriptor = FetchDescriptor<BulkClaimBatch>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let batches = (try? self.modelContext.fetch(descriptor)) ?? []
            self.displayedBatches = batches
        } catch {
            self.errorMessage = "Failed to fetch batches."
        }
    }

    public func fetchLines(forBatch batchId: UUID) async -> [BulkClaimLine] {
        do {
            let descriptor = FetchDescriptor<BulkClaimLine>(
                predicate: #Predicate<BulkClaimLine> { line in line.batch?.id == batchId },
                sortBy: [SortDescriptor(\.supportsDeliveredFrom)]
            )
            return (try? self.modelContext.fetch(descriptor)) ?? []
        } catch {
            print("Failed to fetch lines for batch: \(error)")
            return []
        }
    }
```

---

### File 9: `Packages/Feature.Settings/Sources/Feature_Settings/Views/TravelCharge/TravelChargeReviewViewModel.swift`
* **Issue Type**: Main Thread Blocking / Loop-Based Resolution
* **Location**: Lines 48-56
* **Rationale**: Fetches `TravelChargeReviewItem` ids via the actor and resolves the models sequentially in a main actor loop. Batch fetching directly is much faster and cleaner.
* **Proposed Snippet**:
```swift
// Target File: Packages/Feature.Settings/Sources/Feature_Settings/Views/TravelCharge/TravelChargeReviewViewModel.swift
// Replacement for lines 48-56:

    public func refreshReviews() async {
        do {
            let descriptor = FetchDescriptor<TravelChargeReviewItem>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let reviews = (try? self.modelContext.fetch(descriptor)) ?? []
            self.reviewItemEntities = reviews
        } catch {
            print("❌ [TravelChargeReviewViewModel] Error fetching reviews: \(error)")
        }
    }
```

---

### File 10: `Packages/Feature.Calendar/Sources/Feature_Calendar/ViewModels/CalendarViewModel+Fetching.swift`
* **Issue Type**: Main Thread Blocking / Loop-Based Resolution
* **Location**: Lines 163-178
* **Rationale**: The calendar fetches projected session IDs from the background `CalendarWorkflowActor` but resolves all corresponding `Session` entities on the main thread via a synchronous mapping loop. Using a batch `FetchDescriptor` directly on the Main Actor context eliminates the double DB query/round-trip and performs a single optimized database fetch.
* **Proposed Snippet**:
```swift
// Target File: Packages/Feature.Calendar/Sources/Feature_Calendar/ViewModels/CalendarViewModel+Fetching.swift
// Replacement for lines 163-178:

            let fetchedSessions: [Session]
            do {
                let descriptor = FetchDescriptor<Session>(
                    predicate: #Predicate<Session> { session in
                        if let st = session.startTime {
                            if st < viewEndDate {
                                if session.recurrenceRuleData != nil {
                                    return true
                                } else {
                                    return st >= viewStartDate
                                }
                            } else {
                                return false
                            }
                        } else {
                            return false
                        }
                    },
                    sortBy: [SortDescriptor(\.startTime)]
                )
                let rawSessions = try self.modelContext.fetch(descriptor)
                fetchedSessions = rawSessions.filter { s in
                    let statusToken = SessionStatus(normalized: s.status?.rawValue ?? "")?.token
                    if !showCancelled && statusToken == SessionStatus.cancelled.token {
                        return false
                    }

                    if hasFilter {
                        guard let token = statusToken, statusFilter.contains(token) else {
                            return false
                        }
                    }

                    if !clientIds.isEmpty {
                        guard let clientID = s.clientId, clientIds.contains(clientID) else {
                            return false
                        }
                    }

                    if !searchTextFilter.isEmpty {
                        let haystack = [
                            s.title,
                            s.location ?? "",
                            s.notes ?? ""
                        ]
                        .joined(separator: " ")
                        .lowercased()

                        if !haystack.contains(searchTextFilter) {
                            return false
                        }
                    }

                    if s.recurrenceRuleData != nil {
                        return (s.startTime ?? .distantFuture) < viewEndDate
                    }
                    guard let sessionStart = s.startTime else { return false }
                    return sessionStart >= viewStartDate && sessionStart < viewEndDate
                }
            } catch {
                fetchedSessions = []
            }
```
