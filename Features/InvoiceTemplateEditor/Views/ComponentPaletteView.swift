import SwiftUI

struct ComponentPaletteView: View {
    @State private var expandedSections: Set<String> = ["Standard Elements", "Invoice Components"]
    
    // Filter to only include invoice-specific components (exclude standard elements)
    private var invoiceSpecificComponents: [InvoiceComponentType] {
        InvoiceComponentType.allCases.filter { componentType in
            switch componentType {
            case .invoiceNumberAndDates, .billTo, .participant, .servicesTable, .totals, .paymentDetails,
                 .paymentTerms, .invoiceTitle, .companyName, .companyABN, .companyEmail, .companyLogo, .notes:
                return true
            case .textBox, .rectangleShape, .ellipseShape, .lineShape, .triangleShape, .starShape, .imagePlaceholder:
                return false
            @unknown default:
                return false
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Components")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)

            // Scrollable palette content
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    // Standard Elements section (shapes, text, lines)
                    CollapsibleSection(
                        title: "Standard Elements",
                        isExpanded: expandedSections.contains("Standard Elements"),
                        onToggle: { toggleSection("Standard Elements") }
                    ) {
                        VStack(spacing: 8) {
                            standardPaletteRow(name: "Text", systemIcon: "textformat", description: "Add editable text", size: CGSize(width: 200, height: 40))
                            standardPaletteRow(name: "Rectangle", systemIcon: "square", description: "Add rectangle shape", size: CGSize(width: 200, height: 80))
                            standardPaletteRow(name: "Ellipse", systemIcon: "circle", description: "Add oval shape", size: CGSize(width: 160, height: 80))
                            standardPaletteRow(name: "Line", systemIcon: "line.horizontal.3", description: "Add divider/line", size: CGSize(width: 300, height: 8))
                            standardPaletteRow(name: "Triangle", systemIcon: "triangle", description: "Add triangle shape", size: CGSize(width: 120, height: 100))
                            standardPaletteRow(name: "Star", systemIcon: "star", description: "Add star shape", size: CGSize(width: 120, height: 120))
                            standardPaletteRow(name: "Image Placeholder", systemIcon: "photo", description: "Add image placeholder", size: CGSize(width: 180, height: 120))
                        }
                    }

                    // Invoice-specific components
                    CollapsibleSection(
                        title: "Invoice Components",
                        isExpanded: expandedSections.contains("Invoice Components"),
                        onToggle: { toggleSection("Invoice Components") }
                    ) {
                        VStack(spacing: 8) {
                            ForEach(invoiceSpecificComponents) { componentType in
                                paletteRow(for: componentType)
                                    .draggable(InvoiceComponent(type: componentType, position: .zero, size: componentType.defaultSize))
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.1))
    }

    private func paletteRow(for componentType: InvoiceComponentType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: componentType.iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(componentType.iconColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(componentType.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Text(componentType.description)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator, lineWidth: 1))
    }

    private func standardPaletteRow(name: String, systemIcon: String, description: String, size: CGSize) -> some View {
        HStack(spacing: 12) {
            // visual preview using the actual payload style
            let payload = payloadForStandardElement(named: name, size: size)
            ZStack {
                switch payload.type {
                case .textBox:
                    RoundedRectangle(cornerRadius: max(4, payload.style.cornerRadius))
                        .fill(payload.style.backgroundColorSwiftUI.opacity(0.6))
                        .frame(width: 56, height: 22)
                        .overlay(
                            Text(payload.style.placeholderText.isEmpty ? "Text" : payload.style.placeholderText)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: payload.style.textColor).opacity(0.7))
                                .lineLimit(1)
                        )
                case .rectangleShape:
                    RoundedRectangle(cornerRadius: payload.style.cornerRadius)
                        .fill(payload.style.backgroundColorSwiftUI)
                        .frame(width: 56, height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: payload.style.cornerRadius)
                                .stroke(payload.style.borderColorSwiftUI, lineWidth: max(0.5, payload.style.borderWidth))
                        )
                case .ellipseShape:
                    Ellipse()
                        .fill(payload.style.backgroundColorSwiftUI)
                        .frame(width: 48, height: 28)
                        .overlay(
                            Ellipse()
                                .stroke(payload.style.borderColorSwiftUI, lineWidth: max(0.5, payload.style.borderWidth))
                        )
                case .lineShape:
                    // horizontal line preview
                    Rectangle()
                        .fill(payload.style.borderColorSwiftUI)
                        .frame(width: 56, height: max(1, payload.style.borderWidth))
                
                // Previews for new shapes will be generic for now, and implemented with custom shapes later
                case .triangleShape:
                     Image(systemName: "triangle.fill")
                        .foregroundColor(payload.style.borderColorSwiftUI)
                        .font(.system(size: 24))
                case .starShape:
                     Image(systemName: "star.fill")
                        .foregroundColor(payload.style.borderColorSwiftUI)
                        .font(.system(size: 24))
                case .imagePlaceholder:
                     Image(systemName: "photo.on.rectangle")
                        .foregroundColor(payload.style.borderColorSwiftUI)
                        .font(.system(size: 24))
                        
                default:
                    Image(systemName: systemIcon)
                }
            }
            .frame(width: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Text(description)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator, lineWidth: 1))
        .draggable(payloadForStandardElement(named: name, size: size))
    }

    private func payloadForStandardElement(named: String, size: CGSize) -> InvoiceComponent {
        switch named {
        case "Text":
            return InvoiceComponent(type: .textBox, position: .zero, size: size)
        case "Rectangle":
            return InvoiceComponent(type: .rectangleShape, position: .zero, size: size)
        case "Ellipse":
            return InvoiceComponent(type: .ellipseShape, position: .zero, size: size)
        case "Line":
            return InvoiceComponent(type: .lineShape, position: .zero, size: size)
        case "Triangle":
            return InvoiceComponent(type: .triangleShape, position: .zero, size: size)
        case "Star":
            return InvoiceComponent(type: .starShape, position: .zero, size: size)
        case "Image Placeholder":
            return InvoiceComponent(type: .imagePlaceholder, position: .zero, size: size)
        default:
            return InvoiceComponent(type: .notes, position: .zero, size: size)
        }
    }

    private func toggleSection(_ name: String) {
        if expandedSections.contains(name) {
            expandedSections.remove(name)
        } else {
            expandedSections.insert(name)
        }
    }
    

}


