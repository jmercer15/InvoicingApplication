import SwiftUI

struct ProfileView: View {
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userEmail") private var userEmail: String = ""
    @AppStorage("userPhone") private var userPhone: String = ""
    @AppStorage("userRole") private var userRole: String = ""
    
    var body: some View {
        FormComponentContainer {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(icon: "person.crop.circle", title: "Personal Information")
                    VStack(alignment: .leading, spacing: 8) {
                        SettingsRow(label: "Name:") { TextField("", text: $userName) }
                        SettingsRow(label: "Email:") { TextField("", text: $userEmail) }
                        SettingsRow(label: "Phone:") { TextField("", text: $userPhone) }
                        SettingsRow(label: "Role:") { TextField("", text: $userRole) }
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
