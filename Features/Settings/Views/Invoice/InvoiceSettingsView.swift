import SwiftUI

struct InvoiceSettingsView: View {
    @AppStorage("defaultPaymentTerms") private var defaultPaymentTerms: Int = 14
    @AppStorage("taxRate") private var taxRate: Double = 10.0
    @AppStorage("showTaxColumn") private var showTaxColumn: Bool = true
    @AppStorage("autogenerateInvoiceNumbers") private var autogenerateInvoiceNumbers: Bool = true
    @AppStorage("defaultNotes") private var defaultNotes: String = ""
    @AppStorage("defaultPaymentTermsText") private var defaultPaymentTermsText: String = "Payment due within 14 days."
    
    private let paymentTermOptions = [7, 14, 30, 45, 60]
    private let taxRateOptions = [0.0, 10.0, 15.0, 20.0]
    
    var body: some View {
        FormComponentContainer {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(icon: "doc.text", title: "Invoice Defaults")
                    VStack(alignment: .leading, spacing: 8) {
                        SettingsRow(label: "Payment Terms (Days):") {
                            Picker("", selection: $defaultPaymentTerms) {
                                ForEach(paymentTermOptions, id: \.self) { days in
                                    Text("\(days) days").tag(days)
                                }
                            }.labelsHidden()
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Default Payment Terms Text")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $defaultPaymentTermsText)
                                .frame(height: 100)
                                .padding(6)
                                .glassEffect(.regular, in: .rect(cornerRadius: 6))
                        }.padding(.top, 8)
                        
                        SettingsRow(label: "Default Tax Rate:") {
                            Picker("", selection: $taxRate) {
                                ForEach(taxRateOptions, id: \.self) { rate in
                                    Text("\(Int(rate))%").tag(rate)
                                }
                            }.labelsHidden()
                        }

                        // Currency is fixed to AUD for now
                        
                        Toggle("Show Tax Column in Editor", isOn: $showTaxColumn)
                        Toggle("Auto-generate Invoice Numbers", isOn: $autogenerateInvoiceNumbers)
                        
                        VStack(alignment: .leading) {
                            Text("Default Notes")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        
                            TextEditor(text: $defaultNotes)
                                .frame(height: 100)
                                .padding(6)
                                .glassEffect(.regular, in: .rect(cornerRadius: 6))
                        }.padding(.top, 8)
                    }
                }
                .padding(20)
                .sectionCardStyle()
                
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(icon: "tray.full", title: "Templates")
                    VStack(alignment: .leading, spacing: 8) {
                        NavigationLink("Manage Invoice Templates") {
                            InvoiceTemplateManagementView()
                        }
                        .appInteractiveCursor()
                        .buttonStyle(.glass)
                        .padding(.bottom, 4)
                        
                        NavigationLink("Manage Email Templates") {
                            EmailTemplateManagementView()
                        }
                        .appInteractiveCursor()
                        .buttonStyle(.glass)
                    }
                }
                .padding(20)
                .sectionCardStyle()
                
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 24)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black.opacity(0.15))
                    .shadow(radius: 8)
            )
#if os(macOS)
            .scrollIndicators(.visible)
#endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct InvoiceTemplateManagementView: View {
    @State private var templates = ["Default", "Professional", "Minimal"]
    @State private var selectedTemplate = "Default"
    @State private var showingNewTemplateSheet = false
    
    var body: some View {
        List {
            Section(header: Text("Current Templates")) {
                ForEach(templates, id: \.self) { template in
                    HStack {
                        Text(template)
                        Spacer()
                        if template == selectedTemplate {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTemplate = template
                    }
                    .appInteractiveCursor()
                }
                .onDelete { indexSet in
                    let templatesToDelete = indexSet.map { templates[$0] }
                    guard !templatesToDelete.contains("Default") else {
                        // Don't allow deleting the default template
                        return
                    }
                    templates.remove(atOffsets: indexSet)
                }
            }
            
            Section {
                Button("Add New Template") {
                    showingNewTemplateSheet = true
                }
                .appInteractiveCursor()
            }
        }
        .navigationTitle("Invoice Templates")
    }
}

struct EmailTemplateManagementView: View {
    @State private var templates = ["Invoice Sending", "Payment Reminder", "Thank You"]
    @State private var showingTemplateEditor = false
    @State private var selectedTemplate: String?
    
    var body: some View {
        List {
            Section(header: Text("Email Templates")) {
                ForEach(templates, id: \.self) { template in
                    Text(template)
                        .onTapGesture {
                            selectedTemplate = template
                            showingTemplateEditor = true
                        }
                        .appInteractiveCursor()
                }
                .onDelete { indexSet in
                    templates.remove(atOffsets: indexSet)
                }
            }
            
            Section {
                Button("Add New Template") {
                    selectedTemplate = nil
                    showingTemplateEditor = true
                }
                .appInteractiveCursor()
            }
        }
        .navigationTitle("Email Templates")
    }
}
