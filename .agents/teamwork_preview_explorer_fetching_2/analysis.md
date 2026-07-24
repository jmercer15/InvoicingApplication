# Data-Fetching & Concurrency Remediation Plan (Milestone 2)

This report details the remediation plan for SwiftData fetching inefficiencies and thread concurrency violations in the `InvoicingApplication` codebase. The plan addresses synchronous Main Thread loops that use `model(for:)` to resolve persistent objects, and thread-safety violations caused by accessing the `ModelContext` on background cooperative task threads.

---

## 1. Executive Summary & Consensus

Based on the global scan audit and detailed analysis of the target files, we identify two core anti-patterns:
1. **Thread Concurrency Violations**: `@Environment(\.modelContext)` is a MainActor-bound context in SwiftUI. Accessing `modelContext.model(for:)` directly inside background `.task` modifiers without dispatching back to the `MainActor` violates SwiftData's thread isolation principles.
2. **Main-Thread Blocking loops (`model(for:)`)**: ViewModels fetch arrays of `PersistentIdentifier`s asynchronously using the background `ReferenceDataWorkflowActor`, but immediately loop over these IDs on the `MainActor` using `modelContext.model(for:)`. This causes synchronous database hit overhead for every item.

### General Remediation Strategy
- **Direct Batch Fetching**: Replace background ID fetches + main-thread loop resolutions with direct single-query batch fetches using `FetchDescriptor` on the `MainActor`. This leverages SQLite's set-based query optimizer and reduces database hits from $O(N)$ to $O(1)$.
- **MainActor Isolation**: Ensure all interactions with the view-bound `ModelContext` are isolated to the `MainActor` by wrapping task actions or using the `@MainActor` attribute.

---

## 2. Target File Remediation Plans

### Target 1: ServiceAssignmentSheetView
- **File**: `Packages/Feature.Clients/Sources/Feature_Clients/Views/ServiceAssignmentSheetView.swift`
- **Lines**: 61-76
- **Problem**: Thread-safety violation (accessing `modelContext` in a background cooperative task) and $O(N)$ synchronous resolution loop over all NDIS catalog items.
- **Proposed Solution**: Wrap execution in `MainActor.run` and perform a direct batch query using `FetchDescriptor<NDISItem>` on the main context.
- **Proposed Diff**:
```swift
// Replace lines 61-76:
        .task {
            isLoadingItems = true
            await MainActor.run {
                do {
                    let descriptor = FetchDescriptor<NDISItem>(sortBy: [SortDescriptor(\.itemNumber)])
                    self.availableNDISItems = try modelContext.fetch(descriptor)
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

### Target 2: ModernTemplateEditorView
- **File**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Editor/ModernTemplateEditorView.swift`
- **Lines**: 58-71
- **Problem**: Concurrency violation (accessing `modelContext` in background cooperative thread) and eager main thread resolution loop of all invoices and businesses.
- **Proposed Solution**: Fetch the lists in a single batch fetch directly on the `MainActor`.
- **Proposed Diff**:
```swift
// Replace lines 58-71:
        .task(id: refreshTaskID) {
            await MainActor.run {
                do {
                    let invoiceDescriptor = FetchDescriptor<Invoice>(sortBy: [SortDescriptor(\.issueDate, order: .reverse)])
                    let businessDescriptor = FetchDescriptor<Business>(sortBy: [SortDescriptor(\.name)])
                    
                    let invoices = try modelContext.fetch(invoiceDescriptor)
                    let businesses = try modelContext.fetch(businessDescriptor)
                    
                    await templateDataService.refreshSelectedInvoice(from: invoices)
                    templateDataService.updateFallbackBusiness(businesses.first)
                } catch {
                    print("Failed to load reference data for template editor: \(error)")
                }
            }
        }
```

---

### Target 3: TravelChargeAutomationTestView
- **File**: `Packages/Feature.Settings/Sources/Feature_Settings/Views/TravelCharge/TravelChargeAutomationTestView.swift`
- **Lines**: 121-137
- **Problem**: Concurrency violation (accessing `modelContext` in background task) and synchronous mapping of all sessions and businesses in the database during view load.
- **Proposed Solution**: Perform batch fetches on the `MainActor` context inside `MainActor.run`.
- **Proposed Diff**:
```swift
// Replace lines 121-137:
        .task(id: refreshTaskID) {
            await MainActor.run {
                do {
                    let sessionDescriptor = FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startTime)])
                    let businessDescriptor = FetchDescriptor<Business>(sortBy: [SortDescriptor(\.name)])
                    
                    let sessions = try modelContext.fetch(sessionDescriptor)
                    let businesses = try modelContext.fetch(businessDescriptor)
                    
                    viewModel.updateSessions(sessions)
                    viewModel.updateBusiness(businesses.first)
                } catch {
                    print("Failed to fetch data for TravelChargeAutomationTestView: \(error)")
                }
            }
        }
```

---

### Target 4: ClientDetailViewModel+Loading
- **File**: `Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/ClientDetailViewModel+Loading.swift`
- **Lines**: 17-31 (`refreshProjectedData`), 37-48 (`loadReferencePickers`)
- **Problem**: Main-thread blocking loop resolving all client services, client invoices, service agreements, payees, and plan managers using `model(for:)`.
- **Proposed Solution**: Replace loops with direct `FetchDescriptor` calls utilizing database predicates and sorting.
- **Proposed Diff**:
```swift
// Replace lines 17-31:
    func refreshProjectedData(using workflowActor: ReferenceDataWorkflowActor) async {
        do {
            let clientId = client.id
            let serviceDescriptor = FetchDescriptor<ClientService>(
                predicate: #Predicate<ClientService> { $0.client?.id == clientId },
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            let invoiceDescriptor = FetchDescriptor<Invoice>(
                predicate: #Predicate<Invoice> { $0.client?.id == clientId },
                sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
            )
            let agreementDescriptor = FetchDescriptor<ServiceAgreement>(
                predicate: #Predicate<ServiceAgreement> { $0.client?.id == clientId },
                sortBy: [SortDescriptor(\.effectiveFrom, order: .reverse)]
            )
            
            let services = (try? modelContext.fetch(serviceDescriptor)) ?? []
            let invoices = (try? modelContext.fetch(invoiceDescriptor)) ?? []
            let agreements = (try? modelContext.fetch(agreementDescriptor)) ?? []
            
            await refreshProjectedData(
                clientServices: services,
                relatedInvoices: invoices,
                serviceAgreements: agreements
            )
        } catch {
            print("Failed to fetch client relationships: \(error)")
        }
    }

// Replace lines 37-48:
    func loadReferencePickers(using workflowActor: ReferenceDataWorkflowActor) async {
        do {
            let payeeDescriptor = FetchDescriptor<Payee>(sortBy: [SortDescriptor(\.fullName)])
            let planManagerDescriptor = FetchDescriptor<PlanManager>(sortBy: [SortDescriptor(\.name)])
            
            let payees = (try? modelContext.fetch(payeeDescriptor)) ?? []
            let planManagers = (try? modelContext.fetch(planManagerDescriptor)) ?? []
            
            self.payeeCatalogue = payees
            self.planManagerCatalogue = planManagers
            
            if let id = selectedPayee?.id {
                selectedPayee = payees.first { $0.id == id } ?? selectedPayee
            }
            if let id = selectedPlanManager?.id {
                selectedPlanManager = planManagers.first { $0.id == id } ?? selectedPlanManager
            }
        } catch {
            print("Failed to fetch reference pickers: \(error)")
        }
    }
```

---

### Target 5: PayeeDetailViewModel
- **File**: `Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/PayeeDetailViewModel.swift`
- **Lines**: 90-111
- **Problem**: Main-thread blocking loop using `model(for:)` to resolve related clients and invoices.
- **Proposed Solution**: Fetch the lists in a single batch fetch using `FetchDescriptor` directly.
- **Proposed Diff**:
```swift
// Replace lines 90-111:
    func refreshRelatedInvoices(using workflowActor: ReferenceDataWorkflowActor) async {
        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let payeeID = payee.id
            let clientDescriptor = FetchDescriptor<Client>(
                predicate: #Predicate<Client> { $0.payee?.id == payeeID },
                sortBy: [SortDescriptor(\.fullName)]
            )
            let invoiceDescriptor = FetchDescriptor<Invoice>(
                predicate: #Predicate<Invoice> { $0.payee?.id == payeeID },
                sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
            )
            
            let linkedClients = (try? modelContext.fetch(clientDescriptor)) ?? []
            let fetchedInvoices = (try? modelContext.fetch(invoiceDescriptor)) ?? []
            
            self.lastAllInvoices = fetchedInvoices
            let fetchedIDs = Set(linkedClients.map(\.id))
            if selectedClientIDs.isEmpty {
                selectedClientIDs = fetchedIDs
            }
            self.relatedInvoices = fetchedInvoices
            self.linkedClients = linkedClients
        } catch {
            print("Failed to fetch payee relationships: \(error)")
        }
    }
```

---

### Target 6: PlanManagerDetailViewModel
- **File**: `Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/PlanManagerDetailViewModel.swift`
- **Lines**: 82-99
- **Problem**: Main-thread blocking loop resolving managed clients and invoices.
- **Proposed Solution**: Query `Client` and `Invoice` using batch fetches via `FetchDescriptor`.
- **Proposed Diff**:
```swift
// Replace lines 82-99:
    func refreshRelatedInvoices(using workflowActor: ReferenceDataWorkflowActor) async {
        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let planManagerID = planManager.id
            let clientDescriptor = FetchDescriptor<Client>(
                predicate: #Predicate<Client> { $0.planManager?.id == planManagerID },
                sortBy: [SortDescriptor(\.fullName)]
            )
            let invoiceDescriptor = FetchDescriptor<Invoice>(
                predicate: #Predicate<Invoice> { $0.client?.planManager?.id == planManagerID },
                sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
            )
            
            let linkedClients = (try? modelContext.fetch(clientDescriptor)) ?? []
            let fetchedInvoices = (try? modelContext.fetch(invoiceDescriptor)) ?? []
            
            self.lastAllInvoices = fetchedInvoices
            self.relatedInvoices = fetchedInvoices
            self.linkedClients = linkedClients
        } catch {
            print("Failed to fetch plan manager relationships: \(error)")
        }
    }
```

---

### Target 7: InvoicesContainerViewModel+List
- **File**: `Packages/Feature.Invoices/Sources/Feature_Invoices/ViewModels/InvoicesContainerViewModel+List.swift`
- **Lines**: 29-45
- **Problem**: Fetches matching IDs in background actor, then does $O(N)$ synchronous main thread model loop resolution for all list entities.
- **Proposed Solution**: Perform a single optimized batch fetch of `Invoice`s directly on the Main Actor context using the passed-in `FetchDescriptor`.
- **Proposed Diff**:
```swift
// Replace lines 29-45:
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

### Target 8: ClaimBatchesViewModel
- **File**: `Packages/Feature.Settings/Sources/Feature_Settings/ViewModels/ClaimBatchesViewModel.swift`
- **Lines**: 46-64
- **Problem**: Loops in `refreshBatches` and `fetchLines` to resolve database entities from actor-fetched IDs.
- **Proposed Solution**: Batch fetch `BulkClaimBatch` and `BulkClaimLine` directly on the Main Actor context.
- **Proposed Diff**:
```swift
// Replace lines 46-64:
    public func refreshBatches() async {
        do {
            let descriptor = FetchDescriptor<BulkClaimBatch>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            let batches = (try? modelContext.fetch(descriptor)) ?? []
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
            return (try? modelContext.fetch(descriptor)) ?? []
        } catch {
            print("Failed to fetch lines for batch: \(error)")
            return []
        }
    }
```

---

### Target 9: TravelChargeReviewViewModel
- **File**: `Packages/Feature.Settings/Sources/Feature_Settings/Views/TravelCharge/TravelChargeReviewViewModel.swift`
- **Lines**: 48-56
- **Problem**: Main-thread loop to resolve `TravelChargeReviewItem` entities from ID list.
- **Proposed Solution**: Use a direct batch fetch using `FetchDescriptor`.
- **Proposed Diff**:
```swift
// Replace lines 48-56:
    public func refreshReviews() async {
        do {
            let descriptor = FetchDescriptor<TravelChargeReviewItem>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
            let reviews = (try? modelContext.fetch(descriptor)) ?? []
            self.reviewItemEntities = reviews
        } catch {
            print("❌ [TravelChargeReviewViewModel] Error fetching reviews: \(error)")
        }
    }
```

---

### Target 10: CalendarViewModel+Fetching
- **File**: `Packages/Feature.Calendar/Sources/Feature_Calendar/ViewModels/CalendarViewModel+Fetching.swift`
- **Lines**: 163-178
- **Problem**: Loops synchronously on the Main Actor to resolve all visible session entities in the date range.
- **Proposed Solution**: Batch fetch candidates matching the date range directly on the Main Actor, then apply in-memory filtering.
- **Proposed Diff**:
```swift
// Replace lines 163-178:
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
                let candidates = try modelContext.fetch(descriptor)
                
                fetchedSessions = candidates.filter { s in
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

---

## 3. Verification Method

To verify the proposed changes:
1. Compile the project:
   `xcodebuild -workspace InvoicingApplication.xcworkspace -scheme "InvoicingApplication" -destination "platform=macOS" build`
2. Run unit tests to verify no regressions in data loading logic:
   `xcodebuild -workspace InvoicingApplication.xcworkspace -scheme "InvoicingApplication" -destination "platform=macOS" test`
3. Inspect database hit logs or use Instruments to profile UI thread responsiveness during list rendering (e.g. Invoices list and Calendar view).
