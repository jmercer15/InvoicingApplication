//
//  NativeSessionFormNotesSection.swift
//

import SwiftUI
import SharedUI

struct NativeSessionFormNotesSection: View {
    @Bindable var viewModel: NewSessionViewModel

    var body: some View {
        GroupBox("Notes") {
            VStack(spacing: FormSectionTokens.fieldStackSpacing) {
                TextEditor(text: viewModel.formBinding(\.notes))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(StyleGuide.Colors.text)
                    .tint(ColorSystem.Primary.blue)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .background(StyleGuide.Colors.background.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall))
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .background(Color.clear)
    }
}
