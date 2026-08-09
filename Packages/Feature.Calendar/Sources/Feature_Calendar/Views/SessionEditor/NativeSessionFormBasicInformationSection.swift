import SwiftUI
import SharedUI

struct NativeSessionFormBasicInformationSection: View {
    @Bindable var viewModel: NewSessionViewModel
    @Binding var validationErrors: [String: String]

    var body: some View {
        GroupBox("Basic Information") {
            VStack(spacing: FormSectionTokens.fieldStackSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Title:")
                        .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                        .foregroundStyle(StyleGuide.Colors.text)

                    VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
                        TextField("Session title", text: viewModel.formBinding(\.title))
                            .textFieldStyle(.roundedBorder)
                            .foregroundStyle(StyleGuide.Colors.text)
                            .accentColor(ColorSystem.Primary.blue)
                            .font(StyleGuide.Typography.sectionTitle)
                            .fontWeight(.semibold)
                            .onChange(of: viewModel.formModel.title) { _, newValue in
                                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    validationErrors["title"] = "Title is required."
                                } else {
                                    validationErrors["title"] = nil
                                }
                            }
                            .onSubmit {
                                var updated = viewModel.formModel
                                updated.title = updated.title.trimmingCharacters(in: .whitespacesAndNewlines)
                                viewModel.formModel = updated
                            }

                        if let error = validationErrors["title"] {
                            Text(error)
                                .foregroundStyle(ColorSystem.Status.error)
                                .font(StyleGuide.Typography.itemSubtitle)
                                .fluidListTransition()
                                .animation(.easeInOut(duration: 0.3), value: validationErrors["title"])
                        }
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Date:")
                        .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                        .foregroundStyle(StyleGuide.Colors.text)

                    HStack(spacing: FormSectionTokens.sectionStackSpacing) {
                        DatePicker("", selection: viewModel.formBinding(\.startTime), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .foregroundStyle(StyleGuide.Colors.text)
                            .accentColor(ColorSystem.Primary.blue)
                            .onChange(of: viewModel.formModel.startTime) { _, newValue in
                                var updated = viewModel.formModel
                                if updated.isAllDay {
                                    if updated.endTime < newValue {
                                        updated.endTime = newValue
                                    }
                                } else if updated.endTime <= newValue {
                                    updated.endTime = newValue.addingTimeInterval(3600)
                                }
                                viewModel.formModel = updated
                            }

                        Toggle("All Day", isOn: viewModel.formBinding(\.isAllDay))
                            .toggleStyle(.switch)
                            .foregroundStyle(StyleGuide.Colors.text)
                            .onChange(of: viewModel.formModel.isAllDay) { _, isAllDay in
                                if isAllDay {
                                    let cal = Calendar.current
                                    var updated = viewModel.formModel
                                    let dayStart = cal.startOfDay(for: updated.startTime)
                                    updated.startTime = dayStart
                                    if updated.endTime < updated.startTime {
                                        updated.endTime = updated.startTime
                                    }
                                    viewModel.formModel = updated
                                } else {
                                    var updated = viewModel.formModel
                                    if updated.endTime <= updated.startTime {
                                        updated.endTime = updated.startTime.addingTimeInterval(3600)
                                    }
                                    viewModel.formModel = updated
                                }
                            }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !viewModel.formModel.isAllDay {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Time:")
                            .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                            .foregroundStyle(StyleGuide.Colors.text)

                        HStack(spacing: FormSectionTokens.sectionStackSpacing) {
                            DatePicker("Start", selection: viewModel.formBinding(\.startTime), displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .foregroundStyle(StyleGuide.Colors.text)
                                .accentColor(ColorSystem.Primary.blue)
                                .onChange(of: viewModel.formModel.startTime) { _, newValue in
                                    var updated = viewModel.formModel
                                    if !updated.isAllDay && updated.endTime <= newValue {
                                        updated.endTime = newValue.addingTimeInterval(3600)
                                    }
                                    viewModel.formModel = updated
                                }

                            Text("to")
                                .foregroundStyle(StyleGuide.Colors.textSecondary)

                            DatePicker("End", selection: viewModel.formBinding(\.endTime), displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .foregroundStyle(StyleGuide.Colors.text)
                                .accentColor(ColorSystem.Primary.blue)
                                .onChange(of: viewModel.formModel.endTime) { _, newValue in
                                    var updated = viewModel.formModel
                                    if !updated.isAllDay && newValue <= updated.startTime {
                                        updated.endTime = updated.startTime.addingTimeInterval(3600)
                                    }
                                    viewModel.formModel = updated
                                }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fluidListTransition()
                    .animation(.easeInOut(duration: 0.3), value: viewModel.formModel.isAllDay)
                }
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .background(Color.clear)
    }
}
