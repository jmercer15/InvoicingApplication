//
//  NativeSessionFormStatusSection.swift
//

import SwiftUI
import Core
import Data
import SharedUI

struct NativeSessionFormStatusSection: View {
    @Bindable var viewModel: NewSessionViewModel

    private var statusBinding: Binding<Core.SessionStatus> {
        Binding(
            get: {
                Core.SessionStatus(normalized: viewModel.formModel.status) ?? .scheduled
            },
            set: { newValue in
                var updated = viewModel.formModel
                updated.status = newValue.rawValue
                viewModel.formModel = updated
            }
        )
    }

    var body: some View {
        GroupBox("Status") {
            VStack(spacing: FormSectionTokens.fieldStackSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Status:")
                        .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)

                    Picker("", selection: statusBinding) {
                        Text("Scheduled").tag(Core.SessionStatus.scheduled)
                        Text("Completed").tag(Core.SessionStatus.completed)
                        Text("Cancelled").tag(Core.SessionStatus.cancelled)
                        Text("No Show").tag(Core.SessionStatus.noShow)
                        Text("Rescheduled").tag(Core.SessionStatus.rescheduled)
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .background(Color.clear)
    }
}
