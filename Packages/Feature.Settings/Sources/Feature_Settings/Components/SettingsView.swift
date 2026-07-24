//
//  SettingsView.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//

import SwiftUI
import UniformTypeIdentifiers
import SharedUI

struct SettingsView: View {
    @Binding var selectedSection: SettingsSection? // Receive selection from ContentView


    
    // Initializer to accept the binding
    init(selectedSection: Binding<SettingsSection?>) {
        self._selectedSection = selectedSection
    }

    // Enum to track selected settings section
    enum SettingsSection: String, Identifiable, CaseIterable, Hashable {
        case profile = "Profile"
        case company = "Company Details"
        case invoice = "Invoice Preferences"
        case ndisBilling = "NDIS Billing"
        case calendar = "Calendar"
        case importExport = "Import/Export"
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
            case .travelChargeTest: return "car"
            case .travelChargeReview: return "exclamationmark.triangle.fill"
            case .systemHealth: return "heart.fill"
            }
        }
    }
    
    var body: some View {
        settingsList
    }
    
    // MARK: - Settings List
    private var settingsList: some View {
        List(selection: $selectedSection) {
            Section("Settings Categories") {
                ForEach(SettingsSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
