import SwiftUI
import Data
import Core
import AppKit
import SharedUI
import Observation
import Foundation
import SwiftData

@Observable
@MainActor
public final class CompanyViewModel {
    // MARK: - Dependencies
    private let modelContext: ModelContext
    private let geocodingService: any Core.GeocodingServiceProtocol
    @ObservationIgnored private var persistedBusiness: Business?
    @ObservationIgnored private var isDismissing = false
    
    // MARK: - Published Properties
    var business: Business?
    var isLoading: Bool = false
    var companyLogo: NSImage?
    var saveErrorMessage: String?
    
    // Address-specific state
    var addressSearchText: String = ""
    var unitNumber: String = ""
    var streetNumber: String = ""
    var streetName: String = ""
    var suburb: String = ""
    var state: String = ""
    var postcode: String = ""
    var country: String = ""
    var poBox: String = ""
    var isEditingAddress: Bool = false
    
    // MARK: - Initialization
    public init(modelContext: ModelContext, geocodingService: any Core.GeocodingServiceProtocol) {
        self.modelContext = modelContext
        self.geocodingService = geocodingService
    }

    var hasUnsavedChanges: Bool {
        guard !isDismissing else { return false }
        guard let draft = draftSnapshotForComparison() else { return false }
        let baseline = persistedBusiness.map(BusinessSnapshot.init)
            ?? BusinessSnapshot(emptyBusiness(withID: draft.id))
        return draft != baseline
    }
    
    // MARK: - Public API

    /// Pass `businessEntities.first` from the owning view’s `@Query` so the VM does not duplicate a primary-business fetch.
    func refreshPersistedBusiness(snapshot: Business?) {
        guard !isDismissing else { return }

        if let snapshot {
            persistedBusiness = snapshot
        }

        let loadedBusiness = snapshot ?? emptyBusiness()

        guard self.business == nil || !hasUnsavedChanges || self.business?.id != loadedBusiness.id else {
            return
        }

        applyDraftState(from: loadedBusiness)
    }

    /// Stops layout-time draft mutations while the settings scene tears down.
    func prepareForViewDismiss() {
        isDismissing = true
    }
    
    @discardableResult
    func saveBusiness() async -> Bool {
        guard let currentBusiness = currentDraftBusiness() else { return false }
        
        isLoading = true
        saveErrorMessage = nil
        defer { isLoading = false }
        
        if let updatedAddress = currentBusiness.address,
           !updatedAddress.fullFormattedAddress.isEmpty,
           let coords = await geocodingService.geocodeAddressString(updatedAddress.fullFormattedAddress) {
            updatedAddress.latitude = coords.latitude
            updatedAddress.longitude = coords.longitude
        }

        do {
            if let persistedBusiness {
                applyDraftFields(from: currentBusiness, to: persistedBusiness)
                if let address = persistedBusiness.address, address.modelContext == nil {
                    modelContext.insert(address)
                }
            } else {
                if let address = currentBusiness.address, address.modelContext == nil {
                    modelContext.insert(address)
                }
                modelContext.insert(currentBusiness)
                persistedBusiness = currentBusiness
            }
            await Task.yield()
            try modelContext.save()
            applyDraftState(from: persistedBusiness ?? currentBusiness)
            return true
        } catch {
            saveErrorMessage = "The company settings could not be saved. \(error.localizedDescription)"
            return false
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
                Task {
                    if let image = await Task.detached(priority: .userInitiated, operation: {
                        NSImage(contentsOf: url)
                    }).value {
                        self.companyLogo = image
                    }
                }
            }
        }
    }
    
    func cancelAddressEdit() {
        loadAddressFields(from: business?.address)
        isEditingAddress = false
    }
    
    func commitAddressEdit() {
        isEditingAddress = false
    }

    func discardChanges() {
        applyDraftState(from: persistedBusiness ?? emptyBusiness())
        saveErrorMessage = nil
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

    private func loadAddressFields(from address: Address?) {
        guard let address else {
            unitNumber = ""
            streetNumber = ""
            streetName = ""
            suburb = ""
            state = ""
            postcode = ""
            country = ""
            poBox = ""
            addressSearchText = ""
            return
        }

        unitNumber = address.unitNumber
        streetNumber = address.streetNumber
        streetName = address.streetName
        suburb = address.suburb
        state = address.state
        postcode = address.postcode
        country = address.country
        poBox = address.poBox
        addressSearchText = address.fullFormattedAddress
    }

    private func emptyBusiness(withID id: UUID = UUID()) -> Business {
        let business = Business(id: id, abn: "")
        business.name = ""
        business.accountingMethod = "Accrual"
        business.defaultGstCode = GSTCode.p2.rawValue
        return business
    }

    private func applyDraftState(from source: Business) {
        if source.modelContext != nil {
            persistedBusiness = source
        }
        business = detachedCopy(from: source)
        if let logoData = business?.logo {
            companyLogo = NSImage(data: logoData)
        } else {
            companyLogo = nil
        }
        loadAddressFields(from: business?.address)
        isEditingAddress = business?.address?.fullFormattedAddress
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty ?? true
    }

    /// Draft edits stay off the persisted SwiftData instance until save.
    private func detachedCopy(from source: Business) -> Business {
        let copy = Business(id: source.id, abn: source.abn)
        applyDraftFields(from: source, to: copy)
        return copy
    }

    private func applyDraftFields(from source: Business, to destination: Business) {
        destination.name = source.name
        destination.abn = source.abn
        destination.email = source.email
        destination.phone = source.phone
        destination.logo = source.logo
        destination.bankAccountName = source.bankAccountName
        destination.bankAccountNumber = source.bankAccountNumber
        destination.bankBSB = source.bankBSB
        destination.bankName = source.bankName
        destination.accountingMethod = source.accountingMethod
        destination.ndiaOrganisationID = source.ndiaOrganisationID
        destination.isRegisteredProvider = source.isRegisteredProvider
        destination.defaultGstCode = source.defaultGstCode

        if let sourceAddress = source.address {
            let destinationAddress = destination.address ?? Address()
            destinationAddress.id = sourceAddress.id
            destinationAddress.unitNumber = sourceAddress.unitNumber
            destinationAddress.streetNumber = sourceAddress.streetNumber
            destinationAddress.streetName = sourceAddress.streetName
            destinationAddress.suburb = sourceAddress.suburb
            destinationAddress.city = sourceAddress.city
            destinationAddress.state = sourceAddress.state
            destinationAddress.postcode = sourceAddress.postcode
            destinationAddress.country = sourceAddress.country
            destinationAddress.poBox = sourceAddress.poBox
            destinationAddress.latitude = sourceAddress.latitude
            destinationAddress.longitude = sourceAddress.longitude
            destinationAddress.fullAddressText = sourceAddress.fullFormattedAddress
            destination.address = destinationAddress
        } else {
            destination.address = nil
        }
    }

    private func currentDraftBusiness() -> Business? {
        guard let currentBusiness = business else { return nil }
        applyNormalizedDraftFields(to: currentBusiness)
        return currentBusiness
    }

    /// Compares draft vs persisted without mutating the live draft instance (avoids layout loops).
    private func draftSnapshotForComparison() -> BusinessSnapshot? {
        guard let source = business else { return nil }
        let scratch = detachedCopy(from: source)
        applyNormalizedDraftFields(to: scratch)
        return BusinessSnapshot(scratch)
    }

    private func applyNormalizedDraftFields(to destination: Business) {
        destination.abn = normalizedRequiredString(destination.abn)
        destination.email = normalizedRequiredString(destination.email)
        destination.phone = normalizedRequiredString(destination.phone)
        destination.ndiaOrganisationID = normalizedOptionalString(destination.ndiaOrganisationID)
        destination.logo = companyLogo?.tiffRepresentation
        destination.address = draftAddress(existingAddress: destination.address)

        destination.bankAccountName = normalizedOptionalString(destination.bankAccountName)
        destination.bankAccountNumber = normalizedOptionalString(destination.bankAccountNumber)
        destination.bankBSB = normalizedOptionalString(destination.bankBSB)
        destination.bankName = normalizedOptionalString(destination.bankName)
    }

    private func draftAddress(existingAddress: Address?) -> Address? {
        let candidate = existingAddress ?? Address()
        if let existingAddress {
            candidate.id = existingAddress.id
            candidate.latitude = existingAddress.latitude
            candidate.longitude = existingAddress.longitude
        }
        candidate.unitNumber = unitNumber
        candidate.streetNumber = streetNumber
        candidate.streetName = streetName
        candidate.suburb = suburb
        candidate.city = existingAddress?.city ?? ""
        candidate.state = state
        candidate.postcode = postcode
        candidate.country = country
        candidate.poBox = poBox
        candidate.fullAddressText = candidate.fullFormattedAddress

        return candidate.fullFormattedAddress
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty ? nil : candidate
    }

    private func normalizedRequiredString(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedOptionalString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
