import SwiftUI
import Data
import Core
import SharedUI

struct ProfileView: View {
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userEmail") private var userEmail: String = ""
    @AppStorage("userPhone") private var userPhone: String = ""
    @AppStorage("userRole") private var userRole: String = ""
    
    private var maxLabelWidth: CGFloat {
        let labels = ["Name:", "Email:", "Phone:", "Role:"]
        return labels.map { $0.width() }.max() ?? 120
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                SettingsSection(
                    icon: "person.crop.circle",
                    title: "Personal Information",
                    description: "Enter your personal information. This will be used for invoice generation and client communications."
                ) {
                    SettingsCard(title: "Personal Details") {
                        SettingsRow(label: "Name:", labelWidth: maxLabelWidth) { 
                            TextField("Enter your full name", text: $userName)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("User name")
                                .accessibilityHint("Enter your full name")
                        }
                        
                        SettingsRow(label: "Role:", labelWidth: maxLabelWidth) { 
                            TextField("Enter your job role", text: $userRole)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("User role")
                                .accessibilityHint("Enter your job role")
                        }
                    }
                    
                    SettingsCard(title: "Contact Information") {
                        SettingsRow(label: "Email:", labelWidth: maxLabelWidth) { 
                            TextField("Enter your email address", text: $userEmail)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("User email")
                                .accessibilityHint("Enter your email address")
                        }
                        
                        SettingsRow(label: "Phone:", labelWidth: maxLabelWidth) { 
                            TextField("Enter your phone number", text: $userPhone)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("User phone")
                                .accessibilityHint("Enter your phone number")
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
