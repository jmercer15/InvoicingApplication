//
//  SettingsView.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//

import SwiftUI
import UniformTypeIdentifiers
import Data
import Core
import SharedUI

struct SettingsView: View {
    @Binding var selectedSection: SettingsSection? // Receive selection from ContentView


    
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
        // Settings list with real-time selection
        settingsList
    }
    
    // MARK: - Settings List
    private var settingsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                Section {
                    ForEach(SettingsSection.allCases) { section in
                        SettingsRowView(
                            section: section,
                            isSelected: selectedSection == section,
                            onTap: { selectedSection = section }
                        )
                    }
                } header: {
                    HStack {
                        Text("Settings Categories")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        Spacer()
                    }
                    .padding(.horizontal, 12) // Reduced horizontal padding
                    .padding(.vertical, 10) // Reduced vertical padding
                }
            }
            .padding(.horizontal, 12) // Reduced horizontal padding
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Settings Row View
struct SettingsRowView: View {
    let section: SettingsView.SettingsSection
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? Color("Text", bundle: .sharedUI) : Color("TextSecondary", bundle: .sharedUI))
                    .frame(width: 24)
                
                Text(section.rawValue)
                    .font(.body)
                    .foregroundColor(isSelected ? Color("Text", bundle: .sharedUI) : Color("TextSecondary", bundle: .sharedUI))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                }
            }
            .padding(.horizontal, 12) // Reduced horizontal padding
            .padding(.vertical, 10) // Reduced vertical padding
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
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
            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            
            Text("This application helps you manage invoices, track clients, and handle NDIS billing with ease.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
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
