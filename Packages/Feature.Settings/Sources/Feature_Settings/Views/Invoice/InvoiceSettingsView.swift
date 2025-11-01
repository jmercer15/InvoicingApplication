import SwiftUI
import Data
import Core
import SharedUI

struct InvoiceSettingsView: View {
    @AppStorage("defaultPaymentTerms") private var defaultPaymentTerms: Int = 14
    @AppStorage("taxRate") private var taxRate: Double = 10.0
    @AppStorage("showTaxColumn") private var showTaxColumn: Bool = true
    @AppStorage("autogenerateInvoiceNumbers") private var autogenerateInvoiceNumbers: Bool = true
    @AppStorage("defaultNotes") private var defaultNotes: String = ""
    @AppStorage("defaultPaymentTermsText") private var defaultPaymentTermsText: String = "Payment due within 14 days."
    
    private let paymentTermOptions = [7, 14, 30, 45, 60]
    private let taxRateOptions = [0.0, 10.0, 15.0, 20.0]
    
    private var maxLabelWidth: CGFloat {
        let labels = ["Payment Terms:", "Payment Terms Text:", "Default Tax Rate:", "Show Tax Column:", "Auto-generate Invoice Numbers:", "Default Notes:"]
        return labels.map { $0.width() }.max() ?? 120
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                SettingsSection(
                    icon: "doc.text",
                    title: "Invoice Defaults",
                    description: "Configure default settings for new invoices. These settings will be applied to all new invoices you create."
                ) {
                    SettingsCard(title: "Payment Settings") {
                        SettingsRow(label: "Payment Terms:", labelWidth: maxLabelWidth) {
                            Picker("", selection: $defaultPaymentTerms) {
                                ForEach(paymentTermOptions, id: \.self) { days in
                                    Text("\(days) days").tag(days)
                                }
                            }
                            .pickerStyle(.menu)
                            .accessibilityLabel("Payment terms")
                            .accessibilityHint("Select payment terms in days")
                        }
                        
                        SettingsRow(label: "Payment Terms Text:", labelWidth: maxLabelWidth) {
                            TextEditor(text: $defaultPaymentTermsText)
                                .frame(height: 100)
                                .textFieldStyle(.roundedBorder)
                                .glassEffect(.regular, in: .rect(cornerRadius: 8))
                                .accessibilityLabel("Payment terms text")
                                .accessibilityHint("Enter default payment terms text")
                        }
                        
                        SettingsRow(label: "Default Tax Rate:", labelWidth: maxLabelWidth) {
                            Picker("", selection: $taxRate) {
                                ForEach(taxRateOptions, id: \.self) { rate in
                                    Text("\(Int(rate))%").tag(rate)
                                }
                            }
                            .pickerStyle(.menu)
                            .accessibilityLabel("Tax rate")
                            .accessibilityHint("Select default tax rate percentage")
                        }
                    }
                    
                    SettingsCard(title: "Display Settings") {
                        SettingsRow(label: "Show Tax Column:", labelWidth: maxLabelWidth) {
                            Toggle("", isOn: $showTaxColumn)
                                .toggleStyle(.switch)
                                .accessibilityLabel("Show tax column")
                                .accessibilityHint("Toggle to show or hide tax column in invoice editor")
                        }
                        
                        SettingsRow(label: "Auto-generate Invoice Numbers:", labelWidth: maxLabelWidth) {
                            Toggle("", isOn: $autogenerateInvoiceNumbers)
                                .toggleStyle(.switch)
                                .accessibilityLabel("Auto-generate invoice numbers")
                                .accessibilityHint("Toggle to automatically generate invoice numbers")
                        }
                    }
                    
                    SettingsCard(title: "Default Content") {
                        SettingsRow(label: "Default Notes:", labelWidth: maxLabelWidth) {
                            TextEditor(text: $defaultNotes)
                                .frame(height: 100)
                                .textFieldStyle(.roundedBorder)
                                .glassEffect(.regular, in: .rect(cornerRadius: 8))
                                .accessibilityLabel("Default notes")
                                .accessibilityHint("Enter default notes for invoices")
                        }
                    }
                }
            }
            .padding(.vertical, StyleGuide.Dimensions.paddingXXLarge)
            .padding(.horizontal, StyleGuide.Dimensions.paddingXLarge)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
#if os(macOS)
        .scrollIndicators(.visible)
#endif
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
