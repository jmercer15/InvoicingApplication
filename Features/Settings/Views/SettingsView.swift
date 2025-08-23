//
//  SettingsView.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Binding var selectedSection: SettingsSection? // Receive selection from ContentView

    // Local state for sheets/alerts
    @State private var isShowingAbout = false
    @State private var showingResetConfirmation = false
    
    // AppStorage variables for settings
    @AppStorage("companyName") private var companyName: String = ""
    @AppStorage("companyAddress") private var companyAddress: String = ""
    @AppStorage("companyABN") private var companyABN: String = ""
    @AppStorage("companyPhone") private var companyPhone: String = ""
    @AppStorage("companyEmail") private var companyEmail: String = ""
    @AppStorage("companyWebsite") private var companyWebsite: String = ""
    
    @AppStorage("companyBankName") private var companyBankName: String = ""
    @AppStorage("companyBankBSB") private var companyBankBSB: String = ""
    @AppStorage("companyBankAccountName") private var companyBankAccountName: String = ""
    @AppStorage("companyBankAccountNumber") private var companyBankAccountNumber: String = ""
    
    @AppStorage("defaultInvoiceDueDays") private var defaultInvoiceDueDays: Int = 14
    @AppStorage("defaultInvoiceTemplate") private var defaultInvoiceTemplate: String = "Standard"
    
    // States for UI interaction
    @State private var showLogoPicker = false
    @State private var selectedLogoData: Data? = nil // Store logo data

    // List of available invoice templates
    let invoiceTemplates = ["Standard", "Modern", "Professional", "Simple", "Elegant"]
    
    // Initializer to accept the binding
    init(selectedSection: Binding<SettingsSection?>) {
        self._selectedSection = selectedSection
    }
    
    // For initializing with a specific tab (for preview and backward compatibility)
    init(initialTab: SettingsSection? = nil) {
        self._selectedSection = .constant(initialTab)
    }
    
    // Enum to track selected settings section
    enum SettingsSection: String, Identifiable, CaseIterable {
        case profile = "Profile"
        case company = "Company Details"
        case invoice = "Invoice Preferences"
        case ndisBilling = "NDIS Billing"
        case calendar = "Calendar"
        case importExport = "Import/Export"
        case formComponents = "Form Components"
        case travelChargeTest = "Travel Charge Automation Test"
        case travelChargeReview = "Travel Charge Review"
        case systemHealth = "System Health"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .profile: return "person.crop.circle"
            case .company: return "building.2"
            case .invoice: return "doc.text"
            case .ndisBilling: return "creditcard.fill"
            case .calendar: return "calendar"
            case .importExport: return "arrow.up.arrow.down"
            case .formComponents: return "slider.horizontal.3"
            case .travelChargeTest: return "car"
            case .travelChargeReview: return "exclamationmark.triangle.fill"
            case .systemHealth: return "heart.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // The List now acts as the primary content view for the 'content' column
            List(selection: $selectedSection) {
            Section {
                // Use CaseIterable for cleaner iteration
                ForEach(SettingsSection.allCases) { section in
                    NavigationLink(value: section) {
                        // Use Label instead of the old SettingsRow
                        Label(section.rawValue, systemImage: section.icon)
                    }
                    .appInteractiveCursor()
                }
            } header: {
                Text("Settings Categories") // More descriptive header
            }
            
            Section {
                Button {
                    isShowingAbout = true
                } label: {
                    // Use Label here too
                    Label("About", systemImage: "info.circle")
                }
                .buttonStyle(.plain) // Make it look like a list item
                .appInteractiveCursor()
                
                Link(destination: URL(string: "https://www.ndis.gov.au/providers/pricing-arrangements")!) {
                    // Use Label here too
                    Label("NDIS Resources", systemImage: "link")
                }
                .buttonStyle(.plain)
                .appInteractiveCursor()
                
                Link(destination: URL(string: "mailto:support@invoiceapp.com")!) {
                     // Use Label here too
                    Label("Support", systemImage: "envelope")
                }
                .buttonStyle(.plain)
                .appInteractiveCursor()
            } header: {
                Text("Information")
            }
            }
        }
        .listStyle(.sidebar) // Keep sidebar style for the content list
        .toolbar {
            // Secondary actions
            ToolbarItemGroup(placement: .secondaryAction) {
                Menu {
                    Button("Import Settings") { print("Import settings") }
                    Button("Export Settings") { print("Export settings") }
                } label: {
                    Label("Import/Export", systemImage: "arrow.up.arrow.down")
                }
                    .help("Import or export app settings")
                .appInteractiveCursor()
            }
            // Destructive action slot for reset
            ToolbarItem(placement: .destructiveAction) {
                Button("Reset to Defaults", systemImage: "arrow.counterclockwise") {
                    showingResetConfirmation = true
                }
                .tint(Color.red.opacity(0.7))
                    .help("Reset all settings to their defaults")
                .appInteractiveCursor()
            }
        }
        .alert("Reset All Settings", isPresented: $showingResetConfirmation) { // Keep local alerts
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This will reset all app settings to their default values. This action cannot be undone.")
        }
        .sheet(isPresented: $isShowingAbout) { // Keep local sheets
            AboutView()
        }
        
    }
    
    // Helper function to reset all settings
    private func resetAllSettings() {
        // Reset AppStorage values directly
        UserDefaults.standard.removeObject(forKey: "companyName")
        UserDefaults.standard.removeObject(forKey: "companyAddress")
        UserDefaults.standard.removeObject(forKey: "companyABN")
        UserDefaults.standard.removeObject(forKey: "companyPhone")
        UserDefaults.standard.removeObject(forKey: "companyEmail")
        UserDefaults.standard.removeObject(forKey: "companyWebsite")
        UserDefaults.standard.removeObject(forKey: "companyBankName")
        UserDefaults.standard.removeObject(forKey: "companyBankBSB")
        UserDefaults.standard.removeObject(forKey: "companyBankAccountName")
        UserDefaults.standard.removeObject(forKey: "companyBankAccountNumber")
        UserDefaults.standard.removeObject(forKey: "defaultInvoiceDueDays")
        UserDefaults.standard.removeObject(forKey: "defaultInvoiceTemplate")
        // Force UI update if needed, though AppStorage should trigger it
    }
}

// About View
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Image("AppIcon")
                .resizable()
                .frame(width: 128, height: 128)
                .cornerRadius(20)
                .shadow(radius: 5)
            
            Text("Invoicing Application")
                .font(.largeTitle.bold())
            
            VStack(spacing: 6) {
                Text("Version \(Bundle.main.appVersion) (\(Bundle.main.buildNumber))")
                Text("© 2025 Your Company Name")
            }
            .font(.body)
            .foregroundColor(.secondary)
            
            Text("This application helps you manage invoices, track clients, and handle NDIS billing with ease.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .padding(.bottom, 30)
        }
        .padding(.top, 40)
        .frame(width: 400, height: 500)
    }
}

// Helper Extension for Bundle Info
extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
    }
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
    }
}
