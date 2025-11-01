import SwiftUI
import AppKit
import SwiftData // Import SwiftData
import CoreLocation
import Data
import Core
import SharedUI

struct CompanyView: View {
    @Environment(\.modelContext) private var modelContext // Change to modelContext
    
    @State private var business: BusinessEntity?
    
    @Query // Use @Query
    private var businesses: [BusinessEntity]

    @State private var showingImagePicker = false
    @State private var companyLogo: NSImage?
    
    // Address-specific state for the AddressSearchField
    @State private var addressSearchText: String = ""
    @State private var selectedAddress: AddressData?
    @State private var unitNumber: String = ""
    @State private var streetNumber: String = ""
    @State private var streetName: String = ""
    @State private var suburb: String = ""
    @State private var state: String = ""
    @State private var postcode: String = ""
    @State private var country: String = ""
    @State private var poBox: String = ""
    @State private var isEditingAddress: Bool = false
    
    private var companyNameBinding: Binding<String> {
        Binding<String>(
            get: { self.business?.name ?? "" },
            set: { if self.business != nil { self.business!.name = $0 } }
        )
    }
    private var companyABNBinding: Binding<String> {
        Binding<String>(
            get: { self.business?.abn ?? "" },
            set: { if self.business != nil { self.business!.abn = $0 } }
        )
    }
    private var companyPhoneBinding: Binding<String> {
        Binding<String>(
            get: { self.business?.phone ?? "" },
            set: { if self.business != nil { self.business!.phone = $0 } }
        )
    }
    private var companyEmailBinding: Binding<String> {
        Binding<String>(
            get: { self.business?.email ?? "" },
            set: { if self.business != nil { self.business!.email = $0 } }
        )
    }

    private var companyBankNameBinding: Binding<String> {
        Binding<String>(
            get: { self.business?.bankName ?? "" },
            set: { if self.business != nil { self.business!.bankName = $0 } }
        )
    }
    private var companyBankBSBBinding: Binding<String> {
        Binding<String>(
            get: { self.business?.bankBSB ?? "" },
            set: { if self.business != nil { self.business!.bankBSB = $0 } }
        )
    }
    private var companyBankAccountNameBinding: Binding<String> {
        Binding<String>(
            get: { self.business?.bankAccountName ?? "" },
            set: { if self.business != nil { self.business!.bankAccountName = $0 } }
        )
    }
    private var companyBankAccountNumberBinding: Binding<String> {
        Binding<String>(
            get: { self.business?.bankAccountNumber ?? "" },
            set: { if self.business != nil { self.business!.bankAccountNumber = $0 } }
        )
    }
    
    private var companyAccountingMethodBinding: Binding<String> {
        Binding<String>(
            get: { self.business?.accountingMethod ?? "Accrual" },
            set: { if self.business != nil { self.business!.accountingMethod = $0 } }
        )
    }
    
    private var maxLabelWidth: CGFloat {
        let labels = [
            "Company Name:", "ABN:", "Phone:", "Email:", "Address:", 
            "Accounting Method:", "Bank Name:", "BSB:", "Account Name:", 
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
                            if isEditingAddress {
                                VStack(alignment: .trailing, spacing: 8) {
                                    TextField("Enter address", text: $addressSearchText)
                                        .textFieldStyle(.roundedBorder)
                                        .accessibilityLabel("Address")
                                        .accessibilityHint("Enter the company address")
                                    HStack {
                                        Button("Cancel") {
                                            if let address = business?.address {
                                                loadAddressFields(from: address)
                                            }
                                            isEditingAddress = false
                                        }
                                        .buttonStyle(.glass)
                                        .appInteractiveCursor()
                                        
                                        Button("Save") {
                                            commitAddressFields()
                                            isEditingAddress = false
                                        }
                                        .buttonStyle(.glassProminent)
                                        .appInteractiveCursor()
                                    }
                                }
                            } else {
                                HStack {
                                    Text(business?.address?.fullFormattedAddress ?? "No address provided.")
                                        .foregroundColor((business?.address?.fullFormattedAddress ?? "").isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Button("Edit") {
                                        isEditingAddress = true
                                    }
                                    .buttonStyle(.glass)
                                    .appInteractiveCursor()
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
                                        selectLogoImage()
                                    }
                                    .buttonStyle(.glass)
                                    .appInteractiveCursor()
                                }
                            }
                            
                            if let logoData = business?.logo, let logoImage = NSImage(data: logoData) {
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
                            } else if let localLogo = companyLogo {
                                SettingsCard(title: "Current Logo") {
                                    HStack {
                                        Spacer().frame(width: 120)
                                        Image(nsImage: localLogo)
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
        .onAppear(perform: loadBusinessEntity)
        .onDisappear(perform: saveBusinessEntity)
        .onChange(of: selectedAddress) { _, newAddress in
            updateAddressFields(from: newAddress)
        }
    }
    
    private func loadBusinessEntity() {
        if let existingBusiness = businesses.first {
            self.business = existingBusiness
            if existingBusiness.address == nil {
                let newAddress = AddressEntity()
                existingBusiness.address = newAddress
            }
            if let address = existingBusiness.address {
                loadAddressFields(from: address)
                self.isEditingAddress = address.fullFormattedAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            } else {
                self.isEditingAddress = true
            }
            if let logoData = existingBusiness.logo {
                self.companyLogo = NSImage(data: logoData)
            }
        } else {
            let newBusiness = BusinessEntity(id: UUID(), abn: "")
            let newAddress = AddressEntity()
            newBusiness.address = newAddress
            self.business = newBusiness
            self.isEditingAddress = true
        }
    }
    
    private func saveBusinessEntity() {
        if let localLogoImage = companyLogo, business?.logo == nil || NSImage(data: business!.logo!) != localLogoImage {
            business?.logo = localLogoImage.tiffRepresentation
        }
        
        // Commit address changes before saving
        commitAddressFields()

        if modelContext.hasChanges {
            do {
                try modelContext.save()
                print("[CompanyView] BusinessEntity and related AddressEntity saved.")
            } catch {
                let nsError = error as NSError
                print("[CompanyView] Error saving context: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func selectLogoImage() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Logo Image"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.image]
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                if let image = NSImage(contentsOf: url) {
                    self.companyLogo = image
                }
            }
        }
    }

    // MARK: - Address Field Helper Methods
    
    private func loadAddressFields(from address: AddressEntity) {
        self.unitNumber = address.unitNumber
        self.streetNumber = address.streetNumber
        self.streetName = address.streetName
        self.suburb = address.suburb
        self.state = address.state
        self.postcode = address.postcode
        self.country = address.country
        self.poBox = address.poBox
        
        // Construct a search string for display if needed, or leave it for user input
        self.addressSearchText = address.fullFormattedAddress
    }

    private func updateAddressFields(from addressData: AddressData?) {
        guard let addressData = addressData else { return }
        self.unitNumber = addressData.unitNumber
        self.streetNumber = addressData.streetNumber
        self.streetName = addressData.streetName
        self.suburb = addressData.suburb
        self.state = addressData.state
        self.postcode = addressData.postcode
        self.country = addressData.country
        self.poBox = addressData.poBox
    }
    
    private func commitAddressFields() {
        guard let address = business?.address else { return }
        
        address.unitNumber = unitNumber
        address.streetNumber = streetNumber
        address.streetName = streetName
        address.suburb = suburb
        address.state = state
        address.postcode = postcode
        address.country = country
        address.poBox = poBox
        
        GeocodingService.shared.geocodeAndSave(addressEntity: address, in: modelContext)

        // Update the fullAddressText for compatibility with other parts of the app
        address.fullAddressText = address.fullFormattedAddress
    }
}
