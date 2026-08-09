//
//  NativeSessionFormStatusSection.swift
//

import SwiftUI
import Core
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

    private var currentStatus: Core.SessionStatus {
        Core.SessionStatus(normalized: viewModel.formModel.status) ?? .scheduled
    }

    var body: some View {
        GroupBox("Status") {
            VStack(alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
                if CalendarSessionStatusGuidance.isBillingManaged(currentStatus) {
                    LabeledContent("Current Status") {
                        Text(currentStatus.displayName)
                            .fontWeight(.semibold)
                            .foregroundStyle(ColorSystem.Primary.blue)
                    }
                } else {
                    Picker("", selection: statusBinding) {
                        Text("Scheduled").tag(Core.SessionStatus.scheduled)
                        Text("Completed").tag(Core.SessionStatus.completed)
                        Text("Cancelled").tag(Core.SessionStatus.cancelled)
                        Text("No Show").tag(Core.SessionStatus.noShow)
                        Text("Rescheduled").tag(Core.SessionStatus.rescheduled)
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Session status")
                }

                Label(
                    CalendarSessionStatusGuidance.message(
                        for: currentStatus,
                        isInvoiced: viewModel.isEditingInvoicedSession
                    ),
                    systemImage: currentStatus == .completed
                        ? "arrow.right.circle.fill"
                        : "info.circle"
                )
                .font(StyleGuide.Typography.itemSubtitle)
                .foregroundStyle(
                    currentStatus == .completed
                        ? ColorSystem.Status.success
                        : StyleGuide.Colors.textSecondary
                )
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .background(Color.clear)
    }
}
