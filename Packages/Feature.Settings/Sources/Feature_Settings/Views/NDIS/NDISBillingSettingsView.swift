import SwiftUI
import Data
import Core
import SharedUI

struct NDISBillingSettingsView: View {
    @AppStorage("ndisBillingRate") private var billingRate: Double = 0.0
    @AppStorage("ndisAutoGenerateCharges") private var autoGenerateCharges: Bool = true
    @AppStorage("ndisIncludeTravelCharges") private var includeTravelCharges: Bool = true
    @AppStorage("ndisDefaultChargeType") private var defaultChargeType: String = "Support Item"
    
    private let decimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()
    
    private let chargeTypeOptions = ["Support Item", "Travel", "Equipment", "Consumables"]
    
    private var maxLabelWidth: CGFloat {
        let labels = ["Billing Rate:", "Auto-generate Charges:", "Include Travel Charges:", "Default Charge Type:"]
        return labels.map { $0.width() }.max() ?? 120
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                SettingsSection(
                    icon: "creditcard.fill",
                    title: "NDIS Billing Settings",
                    description: "Configure NDIS billing preferences and automation settings for generating charges and invoices."
                ) {
                    SettingsCard(title: "Billing Configuration") {
                        SettingsRow(label: "Billing Rate:", labelWidth: maxLabelWidth) {
                            TextField("Enter billing rate", value: $billingRate, formatter: decimalFormatter)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Billing rate")
                                .accessibilityHint("Enter your NDIS billing rate")
                        }
                        
                        SettingsRow(label: "Default Charge Type:", labelWidth: maxLabelWidth) {
                            Picker("", selection: $defaultChargeType) {
                                ForEach(chargeTypeOptions, id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            .accessibilityLabel("Default charge type")
                            .accessibilityHint("Select the default charge type for NDIS items")
                        }
                    }
                    
                    SettingsCard(title: "Automation Settings") {
                        SettingsRow(label: "Auto-generate Charges:", labelWidth: maxLabelWidth) {
                            Toggle("", isOn: $autoGenerateCharges)
                                .toggleStyle(.switch)
                                .accessibilityLabel("Auto-generate charges")
                                .accessibilityHint("Toggle to automatically generate NDIS charges")
                        }
                        
                        SettingsRow(label: "Include Travel Charges:", labelWidth: maxLabelWidth) {
                            Toggle("", isOn: $includeTravelCharges)
                                .toggleStyle(.switch)
                                .accessibilityLabel("Include travel charges")
                                .accessibilityHint("Toggle to include travel charges in NDIS billing")
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
    }
}

struct NDISBillingSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NDISBillingSettingsView()
    }
}


