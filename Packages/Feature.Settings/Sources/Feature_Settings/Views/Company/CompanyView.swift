import SwiftUI
import SharedUI
import Core
import Data

struct CompanyView: View {
// Placeholder for removal
    @StateObject private var viewModel: CompanyViewModel
    
    public init(viewModel: @autoclosure @escaping () -> CompanyViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }
    
    private var companyNameBinding: Binding<String> {
        Binding<String>(
            get: { viewModel.business?.name ?? "" },
            set: { if viewModel.business != nil { viewModel.business!.name = $0 } }
        )
    }
    private var companyABNBinding: Binding<String> {
        Binding<String>(
            get: { viewModel.business?.abn ?? "" },
            set: { if viewModel.business != nil { viewModel.business!.abn = $0 } }
        )
    }
    private var companyPhoneBinding: Binding<String> {
        Binding<String>(
            get: { viewModel.business?.phone ?? "" },
            set: { if viewModel.business != nil { viewModel.business!.phone = $0 } }
        )
    }
    private var companyEmailBinding: Binding<String> {
        Binding<String>(
            get: { viewModel.business?.email ?? "" },
            set: { if viewModel.business != nil { viewModel.business!.email = $0 } }
        )
    }

    private var companyBankNameBinding: Binding<String> {
        Binding<String>(
            get: { viewModel.business?.bankDetails?.bankName ?? "" },
            set: { newValue in
                if var business = viewModel.business {
                    var details = business.bankDetails ?? BankDetails(accountName: "", accountNumber: "", bsb: "", bankName: "")
                    details.bankName = newValue
                    business.bankDetails = details
                    viewModel.business = business
                }
            }
        )
    }
    private var companyBankBSBBinding: Binding<String> {
        Binding<String>(
            get: { viewModel.business?.bankDetails?.bsb ?? "" },
            set: { newValue in
                if var business = viewModel.business {
                    var details = business.bankDetails ?? BankDetails(accountName: "", accountNumber: "", bsb: "", bankName: "")
                    details.bsb = newValue
                    business.bankDetails = details
                    viewModel.business = business
                }
            }
        )
    }
    private var companyBankAccountNameBinding: Binding<String> {
        Binding<String>(
            get: { viewModel.business?.bankDetails?.accountName ?? "" },
            set: { newValue in
                if var business = viewModel.business {
                    var details = business.bankDetails ?? BankDetails(accountName: "", accountNumber: "", bsb: "", bankName: "")
                    details.accountName = newValue
                    business.bankDetails = details
                    viewModel.business = business
                }
            }
        )
    }
    private var companyBankAccountNumberBinding: Binding<String> {
        Binding<String>(
            get: { viewModel.business?.bankDetails?.accountNumber ?? "" },
            set: { newValue in
                if var business = viewModel.business {
                    var details = business.bankDetails ?? BankDetails(accountName: "", accountNumber: "", bsb: "", bankName: "")
                    details.accountNumber = newValue
                    business.bankDetails = details
                    viewModel.business = business
                }
            }
        )
    }
    
    private var companyAccountingMethodBinding: Binding<String> {
        Binding<String>(
            get: { viewModel.business?.accountingMethod ?? "Accrual" },
            set: { if viewModel.business != nil { viewModel.business!.accountingMethod = $0 } }
        )
    }

    private var isRegisteredProviderBinding: Binding<Bool> {
        Binding<Bool>(
            get: { viewModel.business?.isRegisteredProvider ?? false },
            set: { if viewModel.business != nil { viewModel.business!.isRegisteredProvider = $0 } }
        )
    }

    private var ndiaOrganisationIDBinding: Binding<String> {
        Binding<String>(
            get: { viewModel.business?.ndiaOrganisationID ?? "" },
            set: { viewModel.setNDIAOrganisationID($0) }
        )
    }

    private var defaultGstCodeBinding: Binding<String> {
        Binding<String>(
            get: { viewModel.business?.defaultGstCode ?? GSTCode.p2.rawValue },
            set: { viewModel.setDefaultGSTCode($0) }
        )
    }
    
    private var maxLabelWidth: CGFloat {
        let labels = [
            "Company Name:", "ABN:", "Phone:", "Email:", "Address:", 
            "Accounting Method:", "Registered Provider:", "NDIA Org ID:", "Default GST Code:", "Bank Name:", "BSB:", "Account Name:",
            "Account Number:", "Logo:"
        ]
        return labels.map { $0.width() }.max() ?? 120
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                SettingsSection(
                    icon: "building.2",
                    title: "Company Details",
                    description: "Enter your company information. This will be displayed on invoices and used for business communications."
                ) {
                    SettingsCard(title: "Basic Information") {
                        SettingsRow(label: "Company Name:", labelWidth: maxLabelWidth) { 
                            TextField("Enter company name", text: companyNameBinding)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Company name")
                                .accessibilityHint("Enter your company name")
                        }
                        
                        SettingsRow(label: "ABN:", labelWidth: maxLabelWidth) { 
                            TextField("Enter ABN", text: companyABNBinding)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("ABN")
                                .accessibilityHint("Enter your Australian Business Number")
                        }
                    }
                    
                    SettingsCard(title: "Contact Information") {
                        SettingsRow(label: "Phone:", labelWidth: maxLabelWidth) { 
                            TextField("Enter phone number", text: companyPhoneBinding)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Company phone")
                                .accessibilityHint("Enter your company phone number")
                        }
                        
                        SettingsRow(label: "Email:", labelWidth: maxLabelWidth) { 
                            TextField("Enter email address", text: companyEmailBinding)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Company email")
                                .accessibilityHint("Enter your company email address")
                        }
                    }
                    
                    SettingsCard(title: "Address") {
                        SettingsRow(label: "Address:", labelWidth: maxLabelWidth) {
                            if viewModel.isEditingAddress {
                                VStack(alignment: .trailing, spacing: 8) {
                                    TextField("Search address", text: $viewModel.addressSearchText)
                                        .textFieldStyle(.roundedBorder)
                                        .accessibilityLabel("Address search")
                                        .accessibilityHint("Search for an address")
//                                    AddressSearchField(
//                                        searchText: $viewModel.addressSearchText,
//                                        selectedAddress: Binding<AddressData?>(
//                                            get: { nil },
//                                            set: { if let addr = $0 { viewModel.updateAddressFields(from: addr) } }
//                                        )
//                                    )
                                    
                                    HStack {
                                        Button("Cancel") {
                                            viewModel.cancelAddressEdit()
                                        }
                                        .buttonStyle(.glass)
                                        .pointerStyle(.link)
                                        
                                        Button("Save") {
                                            viewModel.commitAddressEdit()
                                        }
                                        .buttonStyle(.glassProminent)
                                        .pointerStyle(.link)
                                    }
                                }
                            } else {
                                HStack {
                                    Text(viewModel.business?.address?.fullFormattedAddress ?? "No address provided.")
                                        .foregroundColor((viewModel.business?.address?.fullFormattedAddress ?? "").isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Button("Edit") {
                                        viewModel.isEditingAddress = true
                                    }
                                    .buttonStyle(.glass)
                                    .pointerStyle(.link)
                                }
                            }
                        }
                    }
                    
                    SettingsCard(title: "Financial Settings") {
                        SettingsRow(label: "Accounting Method:", labelWidth: maxLabelWidth) {
                            Picker("", selection: companyAccountingMethodBinding) {
                                Text("Accrual").tag("Accrual")
                                Text("Cash").tag("Cash")
                            }
                            .pickerStyle(.menu)
                            .accessibilityLabel("Accounting method")
                            .accessibilityHint("Select the accounting method")
                        }
                    }

                    SettingsCard(title: "NDIS Claiming Configuration") {
                        SettingsRow(label: "Registered Provider:", labelWidth: maxLabelWidth) {
                            Toggle("", isOn: isRegisteredProviderBinding)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }

                        SettingsRow(label: "NDIA Org ID:", labelWidth: maxLabelWidth) {
                            TextField("Numeric ID (1-30 digits)", text: ndiaOrganisationIDBinding)
                                .textFieldStyle(.roundedBorder)
                                .disabled(!(viewModel.business?.isRegisteredProvider ?? false))
                                .onChange(of: viewModel.business?.ndiaOrganisationID ?? "") { _, newValue in
                                    let sanitized = viewModel.sanitizedNDIAOrganisationID(newValue)
                                    if sanitized != newValue {
                                        viewModel.setNDIAOrganisationID(sanitized)
                                    }
                                }
                        }

                        SettingsRow(label: "Default GST Code:", labelWidth: maxLabelWidth) {
                            Picker("", selection: defaultGstCodeBinding) {
                                Text(GSTCode.p1.rawValue).tag(GSTCode.p1.rawValue)
                                Text(GSTCode.p2.rawValue).tag(GSTCode.p2.rawValue)
                                Text(GSTCode.p5.rawValue).tag(GSTCode.p5.rawValue)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
                
                SettingsSection(
                    icon: "creditcard",
                    title: "Banking Details",
                    description: "Configure your banking information for invoice payments and financial transactions."
                ) {
                    SettingsCard(title: "Bank Information") {
                        SettingsRow(label: "Bank Name:", labelWidth: maxLabelWidth) { 
                            TextField("Enter bank name", text: companyBankNameBinding)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Bank name")
                                .accessibilityHint("Enter your bank name")
                        }
                        
                        SettingsRow(label: "BSB:", labelWidth: maxLabelWidth) { 
                            TextField("Enter BSB", text: companyBankBSBBinding)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("BSB")
                                .accessibilityHint("Enter your bank BSB code")
                        }
                    }
                    
                    SettingsCard(title: "Account Details") {
                        SettingsRow(label: "Account Name:", labelWidth: maxLabelWidth) { 
                            TextField("Enter account name", text: companyBankAccountNameBinding)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Account name")
                                .accessibilityHint("Enter your bank account name")
                        }
                        
                        SettingsRow(label: "Account Number:", labelWidth: maxLabelWidth) { 
                            TextField("Enter account number", text: companyBankAccountNumberBinding)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Account number")
                                .accessibilityHint("Enter your bank account number")
                        }
                    }
                }
                
                SettingsSection(
                    icon: "paintbrush",
                    title: "Branding",
                    description: "Upload your company logo to be displayed on invoices and other business documents."
                ) {
                    SettingsCard(title: "Logo Upload") {
                        SettingsRow(label: "Logo:", labelWidth: maxLabelWidth) {
                            Button("Upload Logo") {
                                viewModel.selectLogoImage()
                            }
                            .buttonStyle(.glass)
                            .pointerStyle(.link)
                        }
                    }
                    
                    if let logoImage = viewModel.companyLogo {
                        SettingsCard(title: "Current Logo") {
                            HStack {
                                Spacer().frame(width: 120)
                                Image(nsImage: logoImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 100)
                                    .padding(.vertical)
                                Spacer()
                            }
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
        .overlay(loadingOverlay)
        .onAppear {
            Task { await viewModel.loadBusiness() }
        }
        .onDisappear {
            Task { await viewModel.saveBusiness() }
        }
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.1))
        }
    }
}
