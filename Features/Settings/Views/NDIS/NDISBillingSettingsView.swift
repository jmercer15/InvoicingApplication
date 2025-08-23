import SwiftUI

struct NDISBillingSettingsView: View {
    @State private var billingRate: Double = 0.0
    @State private var isBillingEnabled: Bool = false
    private let decimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    var body: some View {
        FormComponentContainer {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(icon: "creditcard.fill", title: "NDIS Billing Settings")
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable Billing", isOn: $isBillingEnabled)
                        SettingsRow(label: "Billing Rate:") {
                            TextField("", value: $billingRate, formatter: decimalFormatter)
                        }
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

struct NDISBillingSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NDISBillingSettingsView()
    }
}


