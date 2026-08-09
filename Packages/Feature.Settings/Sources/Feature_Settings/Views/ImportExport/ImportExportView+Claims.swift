import SwiftUI
import Core
import PersistenceModels
import SharedUI

extension ImportExportView {
    
    @ViewBuilder internal func claimsExportSection() -> some View {
        if viewModel.claimsExportEnabled {
            SettingsSection(
                icon: "list.bullet.rectangle.portrait",
                title: "NDIS Claims Export",
                description: "Create, validate, preview, and export NDIS claim batches as CSV."
            ) {
                Text("Claim CSV exports include participant identifiers, NDIS item codes, service dates, and payment amounts. Store exported files securely.")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    .padding(.bottom, StyleGuide.Dimensions.paddingSmall)

                SettingsCard(title: "Batch Setup") {
                    HStack(spacing: FormSectionTokens.formGroupSpacing) {
                        DatePicker("From", selection: $viewModel.claimFromDate, displayedComponents: .date)
                        DatePicker("To", selection: $viewModel.claimToDate, displayedComponents: .date)
                    }

                    Toggle("Include Travel Claims", isOn: $viewModel.includeTravelClaims)
                    Toggle("Include Cancellation Claims", isOn: $viewModel.includeCancellationClaims)

                    Picker("Claim Reference", selection: $viewModel.claimReferenceStrategy) {
                        Text("Invoice Number").tag("invoice_number")
                        Text("Invoice Item ID").tag("invoice_item_id")
                        Text("Session ID").tag("session_id")
                    }
                    .pickerStyle(.menu)
                }

                SettingsCard(title: "Actions") {
                    HStack {
                        Button("Create Batch") {
                            viewModel.createClaimBatch()
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(viewModel.isLoading)

                        Button("Validate Batch") {
                            viewModel.validateClaimBatch()
                        }
                        .buttonStyle(.glass)
                        .disabled(viewModel.claimBatch == nil || viewModel.isLoading)

                        Button("Preview Rows") {
                            viewModel.previewClaimBatch()
                        }
                        .buttonStyle(.glass)
                        .disabled(viewModel.claimBatch == nil || viewModel.isLoading)

                        Button("Export CSV") {
                            viewModel.exportClaimBatchCSV()
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(!viewModel.canExportClaimCSV || viewModel.isLoading)
                    }
                }

                if let summary = viewModel.claimValidationSummary {
                    Text(summary)
                        .formDescriptionStyle()
                }

                if let message = viewModel.claimExportStatusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }

                if let batch = viewModel.claimBatch {
                    SettingsCard(title: "Current Batch") {
                        SettingsRow(label: "Status:", labelWidth: maxLabelWidth) {
                            Text(batch.status)
                        }
                        SettingsRow(label: "Rows:", labelWidth: maxLabelWidth) {
                            Text("\(batch.rowCount)")
                        }
                        SettingsRow(label: "Errors:", labelWidth: maxLabelWidth) {
                            Text("\(batch.errorCount)")
                                .foregroundColor(batch.errorCount > 0 ? .red : .green)
                        }
                    }
                }

                if !viewModel.claimPreviewLines.isEmpty {
                    SettingsCard(title: "Preview (First 100 Rows)") {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(viewModel.claimPreviewLines.enumerated()), id: \.element.id) { index, line in
                                    Text("\(index + 1). \(line.ndisNumber) · \(line.supportNumber) · \(ExportMachineFormatting.exportDecimal2(line.unitPrice)) · \(line.isValid ? "valid" : "invalid")")
                                        .font(.caption)
                                        .foregroundColor(line.isValid ? Color("TextSecondary", bundle: .sharedUI) : .red)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 180)
                    }
                }

                claimHistoryCard()
            }
        }
    }

    @ViewBuilder internal func claimHistoryCard() -> some View {
        SettingsCard(title: "Batch History") {
            Toggle("Filter by Date", isOn: $viewModel.claimHistoryUseDateFilter)

            if viewModel.claimHistoryUseDateFilter {
                HStack(spacing: FormSectionTokens.formGroupSpacing) {
                    DatePicker("Created From", selection: $viewModel.claimHistoryFromDate, displayedComponents: .date)
                    DatePicker("Created To", selection: $viewModel.claimHistoryToDate, displayedComponents: .date)
                }
            }

            HStack(spacing: FormSectionTokens.formGroupSpacing) {
                Picker("Status", selection: $viewModel.claimHistoryStatusFilter) {
                    Text("All").tag("all")
                    ForEach(viewModel.claimHistoryStatusOptions.filter { $0 != "all" }, id: \.self) { status in
                        Text(status).tag(status)
                    }
                }
                .pickerStyle(.menu)

                Picker("Client", selection: $viewModel.claimHistoryClientFilter) {
                    Text("All Clients").tag("all")
                    ForEach(viewModel.claimHistoryClientOptions) { option in
                        Text(option.displayName).tag(option.id.uuidString)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Button("Refresh") {
                    viewModel.refreshClaimBatchHistory()
                }
                .buttonStyle(.glass)
                .disabled(viewModel.isRefreshingClaimHistory || viewModel.isLoading)

                Button("Clear Filters") {
                    viewModel.clearClaimHistoryFilters()
                }
                .buttonStyle(.glass)
                .disabled(viewModel.isRefreshingClaimHistory || viewModel.isLoading)
            }

            if let historyMessage = viewModel.claimHistoryStatusMessage {
                Text(historyMessage)
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }

            if viewModel.filteredClaimBatchHistoryRows.isEmpty {
                Text("No batches match the current filters.")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                        ForEach(viewModel.filteredClaimBatchHistoryRows) { row in
                            claimHistoryRowView(row)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 220)
            }
        }
    }

    @ViewBuilder internal func claimHistoryRowView(_ row: ClaimBatchHistoryRow) -> some View {
        VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
            Text("\(row.batch.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(row.batch.status)")
                .font(.caption.weight(.semibold))

            Text("Rows \(row.batch.rowCount) · Errors \(row.batch.errorCount)")
                .font(.caption)
                .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))

            if row.lineCount > 0 {
                Text(row.reconciliationSummary)
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
            }

            if !row.clientNames.isEmpty {
                Text("Clients: \(row.clientNames.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
            }

            if let fileName = row.batch.exportFileName {
                Text("File: \(fileName)")
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
            }

            if let checksum = row.batch.checksumSHA256 {
                let statusText: String = {
                    if let verified = row.exportHashVerified {
                        return verified ? "verified" : "mismatch"
                    }
                    return "not verified"
                }()
                let statusSymbol = row.exportHashVerified == true
                    ? "checkmark.seal.fill"
                    : (row.exportHashVerified == false ? "xmark.seal.fill" : "questionmark.circle")
                Label("SHA256: \(checksum) (\(statusText))", systemImage: statusSymbol)
                    .font(.caption)
                    .foregroundStyle(row.exportHashVerified == false ? ColorSystem.Status.error : Color("TextSecondary", bundle: .sharedUI))
                    .accessibilityLabel("Export checksum \(statusText)")
            }

            HStack {
                Spacer()
                Button("Reconcile") {
                    viewModel.beginClaimReconciliation(for: row)
                }
                .buttonStyle(.glass)
                .disabled(viewModel.isLoading || viewModel.isApplyingClaimReconciliation || row.lineCount == 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
    }

    @ViewBuilder internal func claimReconciliationSheetView() -> some View {
        NavigationStack {
            Form {
                Section("Batch") {
                    Text(viewModel.claimReconciliationTargetTitle.isEmpty ? "Selected Batch" : viewModel.claimReconciliationTargetTitle)
                        .font(.callout)
                }

                Section("Submission") {
                    Picker("Status", selection: $viewModel.claimReconciliationStatus) {
                        ForEach(viewModel.claimReconciliationStatusOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    TextField("Submission Reference", text: $viewModel.claimReconciliationSubmissionRef)
                        .disableAutocorrection(true)
                }

                Section("Notes") {
                    TextField("Reconciliation notes", text: $viewModel.claimReconciliationNotes, axis: .vertical)
                        .lineLimit(3...8)
                }

                if let message = viewModel.claimReconciliationResultMessage, !message.isEmpty {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Reconcile Batch")
            .toolbar {
                AppToolbarSheetBar(
                    confirmTitle: viewModel.isApplyingClaimReconciliation ? "Applying…" : "Apply",
                    isCancelDisabled: viewModel.isApplyingClaimReconciliation,
                    isConfirmDisabled: viewModel.isApplyingClaimReconciliation,
                    onCancel: { viewModel.cancelClaimReconciliation() },
                    onConfirm: { viewModel.applyClaimReconciliation() }
                )
            }
        }
        .frame(minWidth: StyleGuide.Dimensions.settingsSheetMinWidth, minHeight: StyleGuide.Dimensions.settingsSheetMinHeight)
    }
}
