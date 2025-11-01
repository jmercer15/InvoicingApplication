import SwiftUI
import Data
import SharedUI


// Notification name for reopening service assignment sheet
extension Notification.Name {
    static let reopenServiceAssignmentSheet = Notification.Name("reopenServiceAssignmentSheet")
}

// An enum to represent the two pricing modes.
enum BulkPriceMode: String, CaseIterable, Identifiable {
    case ndis = "NDIS Rate"
    case custom = "Custom Rate"
    var id: String { self.rawValue }
}

// A temporary model to hold data for services being created in bulk.
struct ClientServiceTemplate: Identifiable {
    let id = UUID()
    let sourceNdisItem: NDISItemEntity
    
    // Editable properties
    var serviceName: String
    var ndisCode: String
    var rate: Double
    var unit: String

    // Price selection logic
    var priceMode: BulkPriceMode
    var availableNdisPrices: [String: Double] = [:]
    var selectedNdisPriceKey: String? // e.g., "Remote"

    // Initializer to create a template from an NDIS item
    init(from ndisItem: NDISItemEntity) {
        self.sourceNdisItem = ndisItem
        self.serviceName = ndisItem.name
        self.ndisCode = ndisItem.itemNumber
        self.unit = ndisItem.unit ?? "hour"

        // Process regional prices from the NDIS item
        if !ndisItem.regionalPrices.isEmpty {
            self.priceMode = .ndis
            var priceDict: [String: Double] = [:]
            for price in ndisItem.regionalPrices {
                if let key = price.regionIdentifier {
                    priceDict[key] = price.amount
                }
            }
            self.availableNdisPrices = priceDict
            self.selectedNdisPriceKey = priceDict.keys.sorted().first
            self.rate = self.selectedNdisPriceKey.flatMap { priceDict[$0] } ?? 0.0
        } else {
            // No regional prices available - use custom mode with fallback
            self.priceMode = .custom
            // Use the extracted price from the domain model if available, otherwise 0.0
            self.rate = 0.0 // NDISItemEntity doesn't have rate property
        }
        
        // Ensure ndisCode is properly set from itemNumber
        if self.ndisCode.isEmpty && !ndisItem.itemNumber.isEmpty {
            self.ndisCode = ndisItem.itemNumber
        }
    }
}

struct ServiceBulkEditorView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var templates: [ClientServiceTemplate]
    let onSave: ([ClientServiceTemplate]) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Configure New Services")
                    .font(.largeTitle.bold())
                Text("Review and edit the details for the \(templates.count) services you are about to assign.")
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect())

            // Form
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(templates.indices, id: \.self) { index in
                        HStack(alignment: .center, spacing: 16) {
                            Text("\(index + 1)")
                                .font(.title2.bold())
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.blue.opacity(0.7)))
                                .foregroundColor(Color("Text", bundle: .sharedUI))

                            ServiceTemplateRow(template: $templates[index])

                            Button(action: {
                                removeTemplate(at: index)
                            }) {
                                Image(systemName: "xmark")
                                    .font(.title2.bold())
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(Color.red.opacity(0.7)))
                                    .foregroundColor(Color("Text", bundle: .sharedUI))
                            }
                            .buttonStyle(.plain)
                            .appInteractiveCursor()
                        }
                    }
                }
                .padding()
            }
            
            // Footer
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                
                Button("Back to Service Selection") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(name: .reopenServiceAssignmentSheet, object: nil)
                    }
                }
                
                Spacer()
                
                Button("Assign \(templates.count) Services") {
                    onSave(templates)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(templates.isEmpty)
            }
            .padding()
            .background(.bar)
        }
        .background(Color("Background", bundle: .sharedUI).ignoresSafeArea())
    }

    private func removeTemplate(at index: Int) {
        // Apply animation when removing templates
        _ = withAnimation(.easeInOut) {
            templates.remove(at: index)
        }
    }
}

// A row view for editing a single service template
struct ServiceTemplateRow: View {
    @Binding var template: ClientServiceTemplate
    
    private let unitOptions = ["hour", "session", "day", "week", "month", "item"]
    @State private var rateString: String = ""

    private var ndisPriceLabels: [String: String] {
        Dictionary(uniqueKeysWithValues: template.availableNdisPrices.keys.sorted().map { key in
            let price = template.availableNdisPrices[key] ?? 0.0
            let formattedPrice = String(format: "$%.2f", price)
            return (key, "\(key) (\(formattedPrice))")
        })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(template.serviceName)
                .font(.headline)
                .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(white: 0.2))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.white.opacity(0.1)),
                    alignment: .bottom
                )

            HStack(alignment: .top, spacing: 16) {
                FormField("NDIS Code") {
                    TextField("NDIS Code", text: $template.ndisCode)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
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
                            template.rate = value
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
                                template.rate = template.availableNdisPrices[key] ?? 0.0
                                rateString = String(format: "%.2f", template.rate)
                            }
                        }
                    } else {
                        Text("No NDIS price available.")
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            .font(.caption)
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                }
                FormField("Unit") {
                    TextField("Unit", text: $template.unit)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                }
            }
            .padding(16)
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .overlay(
             RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            rateString = String(format: "%.2f", template.rate)
        }
        .onChange(of: template.priceMode) {
            // When price mode changes, update the rate and rateString
            if template.priceMode == .ndis, let key = template.selectedNdisPriceKey {
                template.rate = template.availableNdisPrices[key] ?? 0.0
            }
            rateString = String(format: "%.2f", template.rate)
        }
    }
} 
