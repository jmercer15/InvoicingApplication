import SwiftUI
import AppKit
import MapKit
import SwiftData
import Core
import Data
import SharedUI
import Observation

@Observable
@MainActor
public class ClientDetailViewModel {
    
    // MARK: - Core Dependencies
    let modelContext: ModelContext
    var dismiss: () -> Void = {}

    // MARK: - Published Properties
    var client: Client
    let isCreatingNew: Bool

    // Editable Client Properties
    var editableFullName: String = ""
    var editableNdisNumber: String = ""
    var editableStatus: String = "Active"
    var editableColor: NSColor = .systemBlue // Using system color instead of hex
    var editableIsMinor: Bool = false
    var editableHasNdisPlan: Bool = false
    var editablePlanManagementType: String? = nil
    var editableCreditAmountString: String = "0.00"
    var editableBillingAuthority: Core.BillingAuthority = .client
    var editableNotes: String = ""

    // Formatters & Validation
    var phoneFormatter: PhoneNumberFormatter
    var emailValidator: EmailValidator
    var fullNameError: String?

    // Address Properties
    var editableUnitNumber: String = ""
    var editableStreetNumber: String = ""
    var editableStreetName: String = ""
    var editableSuburb: String = ""
    var editableCity: String = ""
    var editablePostcode: String = ""
    var editableState: String = ""
    var editableCountry: String = ""
    var editablePoBox: String = ""
    var addressSearchText: String = ""
    var selectedSearchAddress: AddressData?

    // Services Management (Domain Models)
    var clientServices: [ClientService] = []
    var serviceAgreements: [ServiceAgreement] = []
    var serviceAgreementToEdit: ServiceAgreement?
    var isPresentingServiceAgreementSheet: Bool = false
    var serviceAgreementValidationError: String?

    // UI State
    var isPresentingServiceBulkEditor = false
    var isEditingAddress: Bool = false
    var isLoading: Bool = false
    var showAlert: Bool = false
    var alertTitle: String = ""
    var alertMessage: String = ""

    // Bulk Editing
    var serviceTemplates: [ClientServiceTemplate] = []
    
    /// Latest relationship pickers from `@Query` (used to resolve selection by id without ad-hoc fetches).
    var payeeCatalogue: [Payee] = []
    var planManagerCatalogue: [PlanManager] = []
    
    // Invoices (Domain Models)
    var relatedInvoices: [Invoice] = []

    // Payee & Plan Manager selection (resolved via catalogue in +Saving)
    var selectedPayee: Payee?
    var selectedPlanManager: PlanManager?

    // MARK: - Initializer
    public init(
        client: Client,
        modelContext: ModelContext,
        isCreating: Bool
    ) {
        self.client = client
        self.modelContext = modelContext
        self.isCreatingNew = isCreating
        self.phoneFormatter = PhoneNumberFormatter(initialPhoneNumber: client.phone ?? "")
        self.emailValidator = EmailValidator(initialEmail: client.email ?? "")
        
        // Initialize selected payee and plan manager from client
        selectedPayee = client.payee
        selectedPlanManager = client.planManager
        
        loadAllDetails()
    }
}
