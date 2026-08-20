import SwiftUI
import SharedUI

struct ProfileView: View {
    @State private var viewModel: ProfileViewModel

    init(viewModel: @autoclosure @escaping () -> ProfileViewModel) {
        _viewModel = State(initialValue: viewModel())
    }
    
    // Cached to avoid NSString sizing during layout (constraint update loops).
    @State private var maxLabelWidth: CGFloat = 120

    @ScaledMetric(relativeTo: .body) private var paddingXXLarge = StyleGuide.Dimensions.paddingXXLarge
    @ScaledMetric(relativeTo: .body) private var paddingXLarge = StyleGuide.Dimensions.paddingXLarge

    var body: some View {
        ScrollView {
            VStack(spacing: FormSectionTokens.pageStackSpacing) {
                SettingsSection(
                    icon: "person.crop.circle",
                    title: "Personal Information",
                    description: "Enter your personal information. This will be used for invoice generation and client communications."
                ) {
                        SettingsCard(title: "Personal Details") {
                        SettingsRow(label: "Name:", labelWidth: maxLabelWidth) { 
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Enter your full name", text: $viewModel.name)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("User name")
                                    .accessibilityHint("Enter your full name")
                                if let error = viewModel.validationErrors["name"] {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        
                        SettingsRow(label: "Role:", labelWidth: maxLabelWidth) { 
                            TextField("Enter your job role", text: $viewModel.role)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("User role")
                                .accessibilityHint("Enter your job role")
                        }
                    }
                    
                    SettingsCard(title: "Contact Information") {
                        SettingsRow(label: "Email:", labelWidth: maxLabelWidth) { 
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Enter your email address", text: $viewModel.email)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("User email")
                                    .accessibilityHint("Enter your email address")
                                if let error = viewModel.validationErrors["email"] {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        
                        SettingsRow(label: "Phone:", labelWidth: maxLabelWidth) { 
                            TextField("Enter your phone number", text: $viewModel.phone)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("User phone")
                                .accessibilityHint("Enter your phone number")
                        }
                    }
                }
            }
            .padding(.vertical, paddingXXLarge)
            .padding(.horizontal, paddingXLarge)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
#if os(macOS)
        .scrollIndicators(.visible)
#endif
        .onAppear {
            let labels = ["Name:", "Email:", "Phone:", "Role:"]
            maxLabelWidth = labels.map { $0.width() }.max() ?? 120
        }
        .onDisappear {
            viewModel.save()
        }
        .onChange(of: viewModel.name) { _, _ in
            _ = viewModel.validate()
        }
        .onChange(of: viewModel.email) { _, _ in
            _ = viewModel.validate()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
