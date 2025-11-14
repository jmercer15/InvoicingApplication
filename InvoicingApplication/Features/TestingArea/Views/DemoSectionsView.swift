import SwiftUI

// MARK: - Demo Sections Tab
struct DemoSectionsTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Demo Sections")
                    .font(.largeTitle)
                
                Text("Testing different Form-content grouping/sectioning approaches")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VariationCard(variation: 2, view: Variation2View())
            }
            .padding()
        }
    }
}

// MARK: - Variation Card
private struct VariationCard<Content: View>: View {
    let variation: Int
    let view: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Variation \(variation)")
                .font(.headline)
                .foregroundColor(.primary)
            
            view
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
}

// MARK: - Variation 2: DisclosureGroup > Form > Section > DisclosureGroup > Controls
// Level 1: DisclosureGroup, Level 2: Form, Level 3: Section, Level 4: DisclosureGroup, Level 5: Controls
private struct Variation2View: View {
    // DisclosureGroup 1 states
    @State private var dg1Expanded = true
    @State private var dg1Inner2Expanded = true
    @State private var gb1Section1Expanded = true
    @State private var gb1Section1DGExpanded = true
    @State private var gb1Section1DG2Expanded = true
    @State private var gb1Section2Expanded = true
    @State private var gb1Section2DGExpanded = true
    @State private var gb1Section2DG2Expanded = true
    
    // DisclosureGroup 2 states
    @State private var dg2Expanded = true
    @State private var gb2Section1Expanded = true
    @State private var gb2Section1DGExpanded = true
    @State private var gb2Section2Expanded = true
    @State private var gb2Section2DGExpanded = true
    @State private var gb2Section3Expanded = true
    @State private var gb2Section3DGExpanded = true
    
    // DisclosureGroup 3 states
    @State private var dg3Expanded = true
    @State private var gb3Section1Expanded = true
    @State private var gb3Section1DGExpanded = true
    @State private var gb3Section2Expanded = true
    @State private var gb3Section2DGExpanded = true
    
    // DisclosureGroup 4 states
    @State private var dg4Expanded = true
    @State private var gb4Section1Expanded = true
    @State private var gb4Section1DGExpanded = true
    @State private var gb4Section2Expanded = true
    @State private var gb4Section2DGExpanded = true
    @State private var gb4Section3Expanded = true
    @State private var gb4Section3DGExpanded = true
    @State private var gb4Section4Expanded = true
    @State private var gb4Section4DGExpanded = true
    
    var body: some View {
        Form {
            // Section 1: Basic Controls
            Section(isExpanded: $gb1Section1Expanded) {
                DisclosureGroup(isExpanded: $gb1Section1DGExpanded) {
                    DisclosureGroup(isExpanded: $dg1Expanded) {
                        Slider(value: .constant(0.5)) {
                            Text("Slider 1")
                        }
                        Slider(value: .constant(0.3)) {
                            Text("Slider 2")
                        }
                        Toggle("Enable Feature", isOn: .constant(true))
                    } label: {
                        Button(action: {
                            withAnimation {
                                dg1Expanded.toggle()
                            }
                        }) {
                            Text("Inner DisclosureGroup 1")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                    )
                    
                    DisclosureGroup(isExpanded: $dg1Inner2Expanded) {
                        TextField("Input 1", text: .constant("Value 1"))
                        TextField("Input 2", text: .constant("Value 2"))
                        Toggle("Option A", isOn: .constant(false))
                        Toggle("Option B", isOn: .constant(true))
                    } label: {
                        Button(action: {
                            withAnimation {
                                dg1Inner2Expanded.toggle()
                            }
                        }) {
                            Text("Inner DisclosureGroup 2")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                    )
                } label: {
                    Button(action: {
                        withAnimation {
                            gb1Section1DGExpanded.toggle()
                        }
                    }) {
                        Text("Outer DisclosureGroup 1")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                )
                
                DisclosureGroup(isExpanded: $gb1Section1DG2Expanded) {
                    DisclosureGroup(isExpanded: $dg2Expanded) {
                        ColorPicker("Primary Color", selection: .constant(.red))
                        ColorPicker("Secondary Color", selection: .constant(.blue))
                        DatePicker("Date", selection: .constant(Date()))
                    } label: {
                        Button(action: {
                            withAnimation {
                                dg2Expanded.toggle()
                            }
                        }) {
                            Text("Inner DisclosureGroup 1")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                    )
                    
                    DisclosureGroup(isExpanded: $gb3Section1DGExpanded) {
                        Slider(value: .constant(0.8)) {
                            Text("Intensity")
                        }
                        Slider(value: .constant(0.2)) {
                            Text("Speed")
                        }
                        Toggle("Advanced Mode", isOn: .constant(false))
                    } label: {
                        Button(action: {
                            withAnimation {
                                gb3Section1DGExpanded.toggle()
                            }
                        }) {
                            Text("Inner DisclosureGroup 2")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                    )
                } label: {
                    Button(action: {
                        withAnimation {
                            gb1Section1DG2Expanded.toggle()
                        }
                    }) {
                        Text("Outer DisclosureGroup 2")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                )
            } header: {
                Button(action: {
                    withAnimation {
                        gb1Section1Expanded.toggle()
                    }
                }) {
                    Text("Section 1")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listRowSeparator(.visible)
            
            // Section 2: Advanced Settings
            Section(isExpanded: $gb1Section2Expanded) {
                DisclosureGroup(isExpanded: $gb1Section2DGExpanded) {
                    DisclosureGroup(isExpanded: $dg3Expanded) {
                        TextField("Name", text: .constant("Value"))
                        TextField("Email", text: .constant("email@example.com"))
                        ColorPicker("Theme Color", selection: .constant(.blue))
                    } label: {
                        Button(action: {
                            withAnimation {
                                dg3Expanded.toggle()
                            }
                        }) {
                            Text("Inner DisclosureGroup 1")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                    )
                    
                    DisclosureGroup(isExpanded: $gb3Section2DGExpanded) {
                        Toggle("Feature A", isOn: .constant(true))
                        Toggle("Feature B", isOn: .constant(false))
                        TextField("Setting", text: .constant("Default"))
                    } label: {
                        Button(action: {
                            withAnimation {
                                gb3Section2DGExpanded.toggle()
                            }
                        }) {
                            Text("Inner DisclosureGroup 2")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                    )
                } label: {
                    Button(action: {
                        withAnimation {
                            gb1Section2DGExpanded.toggle()
                        }
                    }) {
                        Text("Outer DisclosureGroup 1")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                )
                
                DisclosureGroup(isExpanded: $gb1Section2DG2Expanded) {
                    DisclosureGroup(isExpanded: $dg4Expanded) {
                        Slider(value: .constant(0.6)) {
                            Text("Level")
                        }
                        Slider(value: .constant(0.4)) {
                            Text("Rate")
                        }
                        Toggle("Enabled", isOn: .constant(true))
                    } label: {
                        Button(action: {
                            withAnimation {
                                dg4Expanded.toggle()
                            }
                        }) {
                            Text("Inner DisclosureGroup 1")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                    )
                    
                    DisclosureGroup(isExpanded: $gb4Section1DGExpanded) {
                        DatePicker("Start", selection: .constant(Date()))
                        DatePicker("End", selection: .constant(Date()))
                        ColorPicker("Accent", selection: .constant(.green))
                    } label: {
                        Button(action: {
                            withAnimation {
                                gb4Section1DGExpanded.toggle()
                            }
                        }) {
                            Text("Inner DisclosureGroup 2")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                    )
                } label: {
                    Button(action: {
                        withAnimation {
                            gb1Section2DG2Expanded.toggle()
                        }
                    }) {
                        Text("Outer DisclosureGroup 2")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                )
            } header: {
                Button(action: {
                    withAnimation {
                        gb1Section2Expanded.toggle()
                    }
                }) {
                    Text("Section 2")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listRowSeparator(.visible)
            
            // Section 3: Advanced Settings
            Section(isExpanded: $gb2Section1Expanded) {
                DisclosureGroup(isExpanded: $gb2Section1DGExpanded) {
                    DisclosureGroup(isExpanded: $dg3Expanded) {
                        Toggle("Auto-save", isOn: .constant(true))
                        Toggle("Notifications", isOn: .constant(false))
                        Toggle("Dark Mode", isOn: .constant(true))
                    } label: {
                        Button(action: {
                            withAnimation {
                                dg3Expanded.toggle()
                            }
                        }) {
                            Text("Inner DisclosureGroup")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                    )
                } label: {
                    Button(action: {
                        withAnimation {
                            gb2Section1DGExpanded.toggle()
                        }
                    }) {
                        Text("Outer DisclosureGroup")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                )
            } header: {
                Button(action: {
                    withAnimation {
                        gb2Section1Expanded.toggle()
                    }
                }) {
                    Text("Section 3")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listRowSeparator(.visible)
            
            // Section 4: Display Options
            Section(isExpanded: $gb2Section2Expanded) {
                DisclosureGroup(isExpanded: $gb2Section2DGExpanded) {
                    DisclosureGroup(isExpanded: $dg4Expanded) {
                        Slider(value: .constant(0.7)) {
                            Text("Volume")
                        }
                        Slider(value: .constant(0.5)) {
                            Text("Brightness")
                        }
                    } label: {
                        Button(action: {
                            withAnimation {
                                dg4Expanded.toggle()
                            }
                        }) {
                            Text("Inner DisclosureGroup")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                    )
                } label: {
                    Button(action: {
                        withAnimation {
                            gb2Section2DGExpanded.toggle()
                        }
                    }) {
                        Text("Outer DisclosureGroup")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                )
            } header: {
                Button(action: {
                    withAnimation {
                        gb2Section2Expanded.toggle()
                    }
                }) {
                    Text("Section 4")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listRowSeparator(.visible)
            
            // Section 5: Server Settings
            Section(isExpanded: $gb2Section3Expanded) {
                DisclosureGroup(isExpanded: $gb2Section3DGExpanded) {
                    DisclosureGroup(isExpanded: $gb3Section1DGExpanded) {
                        TextField("Server URL", text: .constant("https://example.com"))
                        TextField("API Key", text: .constant("key123"))
                        DatePicker("Last Updated", selection: .constant(Date()))
                    } label: {
                        Button(action: {
                            withAnimation {
                                gb3Section1DGExpanded.toggle()
                            }
                        }) {
                            Text("Inner DisclosureGroup")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                    )
                } label: {
                    Button(action: {
                        withAnimation {
                            gb2Section3DGExpanded.toggle()
                        }
                    }) {
                        Text("Outer DisclosureGroup")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                )
            } header: {
                Button(action: {
                    withAnimation {
                        gb2Section3Expanded.toggle()
                    }
                }) {
                    Text("Section 5")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listRowSeparator(.visible)
        }
        .formStyle(.grouped)
        .frame(width: 400)
    }
}
