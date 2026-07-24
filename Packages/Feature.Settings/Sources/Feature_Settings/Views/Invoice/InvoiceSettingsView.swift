import Core
import SwiftUI
import SharedUI

struct InvoiceSettingsView: View {
    @AppStorage(InvoicePreferenceKey.paymentTermsDays)
    private var defaultPaymentTerms = InvoiceCreationDefaults.standard.paymentTermsDays
    @AppStorage(InvoicePreferenceKey.taxRate)
    private var taxRate = InvoiceCreationDefaults.standard.taxRate
    @AppStorage(InvoicePreferenceKey.showsTaxSummary)
    private var showTaxSummary = InvoiceCreationDefaults.standard.showsTaxSummary
    @AppStorage(InvoicePreferenceKey.autoGeneratesInvoiceNumbers)
    private var autogenerateInvoiceNumbers = InvoiceCreationDefaults.standard.autoGeneratesInvoiceNumbers
    @AppStorage(InvoicePreferenceKey.notes)
    private var defaultNotes = InvoiceCreationDefaults.standard.notes
    @AppStorage(InvoicePreferenceKey.paymentTermsText)
    private var defaultPaymentTermsText = InvoiceCreationDefaults.standard.paymentTermsText
    
    private let paymentTermOptions = [7, 14, 30, 45, 60]
    private let taxRateOptions = [0.0, 10.0, 15.0, 20.0]
    
    private var maxLabelWidth: CGFloat {
        let labels = ["Payment Terms:", "Payment Terms Text:", "Default Tax Rate:", "Show Tax Summary:", "Auto-generate Invoice Numbers:", "Default Notes:"]
        return labels.map { $0.width() }.max() ?? 120
    }
    
    @ScaledMetric(relativeTo: .body) private var paddingXXLarge = StyleGuide.Dimensions.paddingXXLarge
    @ScaledMetric(relativeTo: .body) private var paddingXLarge = StyleGuide.Dimensions.paddingXLarge

    var body: some View {
        ScrollView {
            VStack(spacing: FormSectionTokens.pageStackSpacing) {
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
                                .standardCardStyle()
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
                        SettingsRow(label: "Show Tax Summary:", labelWidth: maxLabelWidth) {
                            Toggle("", isOn: $showTaxSummary)
                                .toggleStyle(.switch)
                                .accessibilityLabel("Show tax summary")
                                .accessibilityHint("Show or hide the tax summary on new invoice documents")
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
                                .standardCardStyle()
                                .accessibilityLabel("Default notes")
                                .accessibilityHint("Enter default notes for invoices")
                        }
                    }
                }
            }
            .padding(.vertical, paddingXXLarge)
            .padding(.horizontal, paddingXLarge)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
#if os(macOS)
        .scrollIndicators(.visible)
#endif
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
