import SwiftUI
import Core
import PersistenceModels
import SharedUI

// An enum to represent the two pricing modes.
enum BulkPriceMode: String, CaseIterable, Identifiable {
    case ndis = "NDIS Rate"
    case custom = "Custom Rate"
    var id: String { self.rawValue }
}

// A temporary model to hold data for services being created in bulk.
struct ClientServiceTemplate: Identifiable {
    let id = UUID()
    let sourceNdisItem: NDISItem
    
    // Editable properties
    var serviceName: String
    var ndisCode: String
    var rate: Decimal
    var unit: String
    /// `nil` = no establishment fee. When set, live NDIS billing may emit one.
    var consecutiveMonths: Int?

    // Price selection logic
    var priceMode: BulkPriceMode
    var availableNdisPrices: [String: Decimal] = [:]
    var selectedNdisPriceKey: String? // e.g., "Remote"

    // Initializer to create a template from an NDIS item
    init(from ndisItem: NDISItem) {
        self.sourceNdisItem = ndisItem
        self.serviceName = ndisItem.name
        self.ndisCode = ndisItem.itemNumber
        self.unit = ndisItem.unit ?? "hour"
        self.consecutiveMonths = nil

        // Process regional prices from the NDIS item
        if let regionalPrices = ndisItem.regionalPrices, !regionalPrices.isEmpty {
            self.priceMode = .ndis
            var priceDict: [String: Decimal] = [:]
            for price in regionalPrices {
                guard let key = price.regionIdentifier, !key.isEmpty else { continue }
                priceDict[key] = price.amount
            }
            self.availableNdisPrices = priceDict
            self.selectedNdisPriceKey = priceDict.keys.sorted().first
            self.rate = self.selectedNdisPriceKey.flatMap { priceDict[$0] } ?? 0
        } else {
            // No regional prices available - use custom mode with fallback
            self.priceMode = .custom
            // Use the price from the domain model if available, otherwise 0.0
            self.rate = ndisItem.price ?? 0
        }
        
        // Ensure ndisCode is properly set from itemNumber
        if self.ndisCode.isEmpty && !ndisItem.itemNumber.isEmpty {
            self.ndisCode = ndisItem.itemNumber
        }
    }
}

struct ServiceBulkEditorView: View {
    @Environment(\.dismiss) var dismiss
    
    @Binding var templates: [ClientServiceTemplate]
    let onSave: ([ClientServiceTemplate]) -> Void
    let onBackToServiceSelection: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
                Text("Configure New Services")
                    .font(StyleGuide.Typography.hero)
                Text("Review and edit the details for the \(templates.count) services you are about to assign.")
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }
            .padding(StyleGuide.Dimensions.paddingMedium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StyleGuide.Colors.background)

            // Form
            if templates.isEmpty {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: "No Service Templates",
                    message: "All service templates have been removed. Go back to service selection to add some."
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: StyleGuide.Dimensions.paddingLarge) {
                        ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                            HStack(alignment: .center, spacing: StyleGuide.Dimensions.paddingLarge) {
                                Text("\(index + 1)")
                                    .font(StyleGuide.Typography.sectionTitle)
                                    .frame(
                                        width: StyleGuide.Dimensions.indexBadgeSize,
                                        height: StyleGuide.Dimensions.indexBadgeSize
                                    )
                                    .background(Circle().fill(ColorSystem.Primary.blue.opacity(0.7)))
                                    .foregroundStyle(StyleGuide.Colors.text)
                                    .accessibilityLabel("Template number \(index + 1)")

                                ServiceTemplateRow(template: binding(for: template))

                                ServiceTemplateDeleteButton(action: {
                                    removeTemplate(template)
                                })
                            }
                        }
                    }
                    .padding(StyleGuide.Dimensions.paddingMedium)
                }
            }
            
            // Footer
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                
                Button("Back to Service Selection") {
                    onBackToServiceSelection()
                    dismiss()
                }
                
                Spacer()
                
                Button("Assign \(templates.count) Services") {
                    onSave(templates)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(templates.isEmpty)
            }
            .padding(StyleGuide.Dimensions.paddingMedium)
            .background(.bar)
        }
        .background(StyleGuide.Colors.background)
    }

    private func binding(for template: ClientServiceTemplate) -> Binding<ClientServiceTemplate> {
        Binding(
            get: { templates.first(where: { $0.id == template.id }) ?? template },
            set: { updated in
                guard let index = templates.firstIndex(where: { $0.id == template.id }) else { return }
                templates[index] = updated
            }
        )
    }

    private func removeTemplate(_ template: ClientServiceTemplate) {
        withAnimation(.easeInOut) {
            templates.removeAll { $0.id == template.id }
        }
    }
}

// A row view for editing a single service template
struct ServiceTemplateRow: View {
    @Binding var template: ClientServiceTemplate
    
    @State private var rateString: String = ""

    private var ndisPriceLabels: [String: String] {
        Dictionary(uniqueKeysWithValues: template.availableNdisPrices.keys.sorted().map { key in
            let price = template.availableNdisPrices[key] ?? 0.0
            let formattedPrice = CurrencyFormatting.display(price)
            return (key, "\(key) (\(formattedPrice))")
        })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FormField("Service Name") {
                TextField("Service Name", text: $template.serviceName)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(EdgeInsets(
                top: StyleGuide.Dimensions.paddingMediumLarge,
                leading: StyleGuide.Dimensions.paddingLarge,
                bottom: StyleGuide.Dimensions.paddingMediumLarge,
                trailing: StyleGuide.Dimensions.paddingLarge
            ))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StyleGuide.Colors.background)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(StyleGuide.Colors.border),
                alignment: .bottom
            )

            HStack(alignment: .top, spacing: StyleGuide.Dimensions.paddingLarge) {
                FormField("NDIS Code") {
                    TextField("NDIS Code", text: $template.ndisCode)
                        .textFieldStyle(.roundedBorder)
                }
                FormField("Price Mode") {
                    Picker("", selection: $template.priceMode) {
                        ForEach(BulkPriceMode.allCases, id: \.self) { mode in
                            Text(String(describing: mode)).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if template.priceMode == .custom {
                    FormField("Custom Rate") {
                        HStack {
                            Text("$")
                            TextField("0.00", text: $rateString)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .onChange(of: rateString) {
                        if let value = Double(rateString.filter("0123456789.".contains)) {
                            template.rate = Decimal(value)
                        }
                    }
                } else {
                    if !template.availableNdisPrices.isEmpty {
                        FormField("NDIS Rate") {
                            Picker("", selection: $template.selectedNdisPriceKey) {
                                ForEach(template.availableNdisPrices.keys.sorted(), id: \.self) { key in
                                    Text(ndisPriceLabels[key] ?? key).tag(key as String?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .onChange(of: template.selectedNdisPriceKey) {
                            if let key = template.selectedNdisPriceKey {
                                template.rate = template.availableNdisPrices[key] ?? 0
                                rateString = CurrencyFormatting.editableAmount(template.rate)
                            }
                        }
                    } else {
                        Text("No NDIS price available.")
                            .foregroundStyle(StyleGuide.Colors.textSecondary)
                            .font(StyleGuide.Typography.caption)
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                }
                FormField("Unit") {
                    TextField("Unit", text: $template.unit)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(StyleGuide.Dimensions.paddingLarge)

            ConsecutiveMonthsStepperField(consecutiveMonths: $template.consecutiveMonths)
                .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
                .padding(.bottom, StyleGuide.Dimensions.paddingLarge)
        }
        .standardCardStyle()
        .onAppear {
            rateString = CurrencyFormatting.editableAmount(template.rate)
        }
        .onChange(of: template.priceMode) {
            // When price mode changes, update the rate and rateString
            if template.priceMode == .ndis, let key = template.selectedNdisPriceKey {
                template.rate = template.availableNdisPrices[key] ?? 0.0
            }
            rateString = CurrencyFormatting.editableAmount(template.rate)
        }
    }
}

struct ServiceTemplateDeleteButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(StyleGuide.Typography.sectionTitle)
                .frame(
                    width: StyleGuide.Dimensions.indexBadgeSize,
                    height: StyleGuide.Dimensions.indexBadgeSize
                )
                .background(Circle().fill(ColorSystem.Status.error.opacity(0.7)))
                .foregroundStyle(StyleGuide.Colors.text)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .accessibilityLabel("Remove service template")
        .accessibilityHint("Removes this service template from the bulk creation queue")
    }
}
