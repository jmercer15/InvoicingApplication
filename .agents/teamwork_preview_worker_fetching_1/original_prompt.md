## 2026-06-05T12:40:49Z

Objective: Implement data-fetching and concurrency remediation fixes for InvoicingApplication.

Apply the following changes to the 10 target files:

1. `Packages/Feature.Clients/Sources/Feature_Clients/Views/ServiceAssignmentSheetView.swift`
   Replace the task block lines 61-76:
   Before:
   ```swift
        .task {
            isLoadingItems = true
            let actor = ReferenceDataWorkflowActor(modelContainer: modelContext.container)
            do {
                let ids = try await actor.fetchAllNDISItemIDs()
                let items = ids.compactMap { modelContext.model(for: $0) as? NDISItem }
                await MainActor.run {
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
   After:
   ```swift
        .task {
            isLoadingItems = true
            let actor = ReferenceDataWorkflowActor(modelContainer: modelContext.container)
            do {
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
            } catch {
                print("Failed to fetch NDIS items: \(error)")
                await MainActor.run { self.isLoadingItems = false }
            }
        }
   ```

2. `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Editor/ModernTemplateEditorView.swift`
   Replace:
   Before:
   ```swift
                let invoiceIDs = try await actor.fetchAllInvoiceIDs()
                let businessIDs = try await actor.fetchAllBusinessIDs()
                let invoices = invoiceIDs.compactMap { modelContext.model(for: $0) as? Invoice }
                let businesses = businessIDs.compactMap { modelContext.model(for: $0) as? Business }
                
                await templateDataService.refreshSelectedInvoice(from: invoices)
                templateDataService.updateFallbackBusiness(businesses.first)
   ```
   After:
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

3. `Packages/Feature.Settings/Sources/Feature_Settings/Views/TravelCharge/TravelChargeAutomationTestView.swift`
   Replace:
   Before:
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
   After:
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

4. `Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/ClientDetailViewModel+Loading.swift`
   Replace both occurrences:
   Before (first occurrence, loading services/invoices/agreements):
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
   After:
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

   Before (second occurrence, loading payees/plan managers):
   ```swift
            let payees = payeeIDs.compactMap { self.modelContext.model(for: $0) as? Payee }
            let planManagers = planManagerIDs.compactMap { self.modelContext.model(for: $0) as? PlanManager }
            
            self.payeeCatalogue = payees
            self.planManagerCatalogue = planManagers
   ```
   After:
   ```swift
            let payees = (try? modelContext.fetch(FetchDescriptor<Payee>())) ?? []
            let planManagers = (try? modelContext.fetch(FetchDescriptor<PlanManager>())) ?? []
            
            self.payeeCatalogue = payees
            self.planManagerCatalogue = planManagers
   ```

5. `Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/PayeeDetailViewModel.swift`
   Replace:
   Before:
   ```swift
            let linkedClients = clientIDs.compactMap { self.modelContext.model(for: $0) as? Client }
            let fetchedInvoices = invoiceIDs.compactMap { self.modelContext.model(for: $0) as? Invoice }
   ```
   After:
   ```swift
            let payeeID = payee.id
            let linkedClients = (try? modelContext.fetch(FetchDescriptor<Client>(
                predicate: #Predicate { $0.payee?.id == payeeID }
            ))) ?? []
            let fetchedInvoices = (try? modelContext.fetch(FetchDescriptor<Invoice>(
                predicate: #Predicate { $0.payee?.id == payeeID }
            ))) ?? []
   ```

6. `Packages/Feature.Clients/Sources/Feature_Clients/ViewModels/PlanManagerDetailViewModel.swift`
   Replace:
   Before:
   ```swift
            let linkedClients = clientIDs.compactMap { self.modelContext.model(for: $0) as? Client }
            let fetchedInvoices = invoiceIDs.compactMap { self.modelContext.model(for: $0) as? Invoice }
   ```
   After:
   ```swift
            let managerID = planManager.id
            let linkedClients = (try? modelContext.fetch(FetchDescriptor<Client>(
                predicate: #Predicate { $0.planManager?.id == managerID }
            ))) ?? []
            let fetchedInvoices = (try? modelContext.fetch(FetchDescriptor<Invoice>(
                predicate: #Predicate { $0.client?.planManager?.id == managerID }
            ))) ?? []
   ```

7. `Packages/Feature.Invoices/Sources/Feature_Invoices/ViewModels/InvoicesContainerViewModel+List.swift`
   Replace:
   Before:
   ```swift
            let modelIDs = try await listFetcher.invoiceModelIDs(matching: descriptor)
            try Task.checkCancellation()

            let invoices = modelIDs.compactMap { modelContext.model(for: $0) as? Invoice }
            invoiceEntities = invoices
            updateVisibleInvoices(invoices)
   ```
   After:
   ```swift
            let invoices = try modelContext.fetch(descriptor)
            try Task.checkCancellation()

            invoiceEntities = invoices
            updateVisibleInvoices(invoices)
   ```

8. `Packages/Feature.Settings/Sources/Feature_Settings/ViewModels/ClaimBatchesViewModel.swift`
   Replace both occurrences:
   Before (first occurrence in refreshBatches):
   ```swift
            let ids = try await workflow.fetchAllBulkClaimBatchIDs()
            let batches = ids.compactMap { self.modelContext.model(for: $0) as? BulkClaimBatch }
            self.displayedBatches = batches
   ```
   After:
   ```swift
            let descriptor = FetchDescriptor<BulkClaimBatch>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let batches = (try? modelContext.fetch(descriptor)) ?? []
            self.displayedBatches = batches
   ```

   Before (second occurrence in fetchLines):
   ```swift
            let ids = try await workflow.fetchBulkClaimLineIDs(forBatch: batchId)
            return ids.compactMap { self.modelContext.model(for: $0) as? BulkClaimLine }
   ```
   After:
   ```swift
            let descriptor = FetchDescriptor<BulkClaimLine>(
                predicate: #Predicate { $0.batch?.id == batchId }
            )
            return (try? modelContext.fetch(descriptor)) ?? []
   ```

9. `Packages/Feature.Settings/Sources/Feature_Settings/Views/TravelCharge/TravelChargeReviewViewModel.swift`
   Replace:
   Before:
   ```swift
            let ids = try await workflow.fetchAllTravelChargeReviewItemIDs()
            let reviews = ids.compactMap { modelContext.model(for: $0) as? TravelChargeReviewItem }
            self.reviewItemEntities = reviews
   ```
   After:
   ```swift
            let descriptor = FetchDescriptor<TravelChargeReviewItem>()
            let reviews = (try? modelContext.fetch(descriptor)) ?? []
            self.reviewItemEntities = reviews
   ```

10. `Packages/Feature.Calendar/Sources/Feature_Calendar/ViewModels/CalendarViewModel+Fetching.swift`
    Replace:
    Before:
    ```swift
                fetchedSessions = sessionIDs.compactMap {
                    self.modelContext.model(for: $0) as? Session
                }
    ```
    After:
    ```swift
                let descriptor = FetchDescriptor<Session>(
                    predicate: #Predicate { sessionIDs.contains($0.persistentModelID) }
                )
                fetchedSessions = (try? modelContext.fetch(descriptor)) ?? []
    ```

After applying these changes:
- Run verification script: `bash scripts/refactor-verify.sh`.
- Ensure everything compiles and tests pass.
