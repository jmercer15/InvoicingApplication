import SwiftUI
import Combine
import Data
import Core
import AppKit
import SharedUI

@MainActor
public final class CompanyViewModel: ObservableObject {
    // MARK: - Dependencies
    private let unitOfWork: UnitOfWorkService
    private let geocodingService: GeocodingService
    
    // MARK: - Published Properties
    @Published var business: Business?
    @Published var isLoading: Bool = false
    @Published var companyLogo: NSImage?
    
    // Address-specific state
    @Published var addressSearchText: String = ""
    @Published var unitNumber: String = ""
    @Published var streetNumber: String = ""
    @Published var streetName: String = ""
    @Published var suburb: String = ""
    @Published var state: String = ""
    @Published var postcode: String = ""
    @Published var country: String = ""
    @Published var poBox: String = ""
    @Published var isEditingAddress: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public init(unitOfWork: UnitOfWorkService, geocodingService: GeocodingService = .shared) {
        self.unitOfWork = unitOfWork
        self.geocodingService = geocodingService
    }
    
    // MARK: - Public API
    
    func loadBusiness() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if let existingBusiness = try await unitOfWork.business.fetchFirst() {
                self.business = existingBusiness
                if let logoData = existingBusiness.logo {
                    self.companyLogo = NSImage(data: logoData)
                }
                loadAddressFields()
                self.isEditingAddress = existingBusiness.address?.fullFormattedAddress.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty ?? true
            } else {
                // Initialize default case
                let newBusiness = Business(id: UUID(), name: "", abn: "")
                self.business = newBusiness
                self.isEditingAddress = true
            }
        } catch {
            print("❌ [CompanyViewModel] Failed to load business: \(error)")
        }
    }
    
    func saveBusiness() async {
        guard var currentBusiness = business else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Update logo if changed
        if let logoImage = companyLogo {
            currentBusiness.logo = logoImage.tiffRepresentation
        }
        
        // Rebuild immutable domain address from editable fields
        let existingAddress = currentBusiness.address
        var latitude = existingAddress?.latitude ?? 0.0
        var longitude = existingAddress?.longitude ?? 0.0

        var updatedAddress = Address(
            id: existingAddress?.id ?? UUID(),
            unitNumber: unitNumber,
            streetNumber: streetNumber,
            streetName: streetName,
            suburb: suburb,
            city: existingAddress?.city ?? "",
            state: state,
            postcode: postcode,
            country: country,
            poBox: poBox,
            latitude: latitude,
            longitude: longitude
        )
        
        // Geocode address if it has content
        if !updatedAddress.fullFormattedAddress.isEmpty,
           let coords = await geocodingService.geocodeAddress(updatedAddress) {
            latitude = coords.latitude
            longitude = coords.longitude
            updatedAddress = Address(
                id: updatedAddress.id,
                unitNumber: updatedAddress.unitNumber,
                streetNumber: updatedAddress.streetNumber,
                streetName: updatedAddress.streetName,
                suburb: updatedAddress.suburb,
                city: updatedAddress.city,
                state: updatedAddress.state,
                postcode: updatedAddress.postcode,
                country: updatedAddress.country,
                poBox: updatedAddress.poBox,
                latitude: latitude,
                longitude: longitude
            )
        }
        
        currentBusiness.address = updatedAddress
        
        do {
            self.business = try await unitOfWork.business.update(currentBusiness)
            try await unitOfWork.saveChanges()
            print("✅ [CompanyViewModel] Business saved successfully")
        } catch {
            print("❌ [CompanyViewModel] Failed to save business: \(error)")
        }
    }
    
    func selectLogoImage() {
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
    
    func cancelAddressEdit() {
        loadAddressFields()
        isEditingAddress = false
    }
    
    func commitAddressEdit() {
        isEditingAddress = false
        // Saving is handled by manual save action or onDisappear in view
    }
    
    func updateAddressFields(from addressData: AddressData) {
        self.unitNumber = addressData.unitNumber
        self.streetNumber = addressData.streetNumber
        self.streetName = addressData.streetName
        self.suburb = addressData.suburb
        self.state = addressData.state
        self.postcode = addressData.postcode
        self.country = addressData.country
        self.poBox = addressData.poBox
    }

    func sanitizedNDIAOrganisationID(_ value: String) -> String {
        let digitsOnly = value.filter(\.isNumber)
        return String(digitsOnly.prefix(30))
    }

    func setNDIAOrganisationID(_ value: String) {
        guard business != nil else { return }
        business?.ndiaOrganisationID = sanitizedNDIAOrganisationID(value)
    }

    func setDefaultGSTCode(_ value: String) {
        guard business != nil else { return }
        if GSTCode.allCases.map(\.rawValue).contains(value) {
            business?.defaultGstCode = value
        } else {
            business?.defaultGstCode = GSTCode.p2.rawValue
        }
    }
    
    // MARK: - Private Helpers
    
    private func loadAddressFields() {
        guard let address = business?.address else { return }
        self.unitNumber = address.unitNumber
        self.streetNumber = address.streetNumber
        self.streetName = address.streetName
        self.suburb = address.suburb
        self.state = address.state
        self.postcode = address.postcode
        self.country = address.country
        self.poBox = address.poBox
        self.addressSearchText = address.fullFormattedAddress
    }
}
