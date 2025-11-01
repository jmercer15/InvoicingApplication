import SwiftUI
extension InvoiceComponentType {
    var iconName: String {
        switch self {
        case .invoiceNumberAndDates: return "doc.text"
        case .billTo: return "person.circle.fill"
        case .participant: return "person.crop.circle"
        case .servicesTable: return "tablecells"
        case .documentGrid: return "tablecells.fill"
        case .totals: return "dollarsign.square"
        case .paymentDetails: return "creditcard"
        case .paymentTerms: return "doc.plaintext"
        case .invoiceTitle: return "doc.text.magnifyingglass"
        case .companyName: return "building.2"
        case .companyLogo: return "photo.circle"
        case .companyABN: return "number.circle"
        case .companyEmail: return "envelope.circle"
        case .notes: return "note.text"
        case .textBox: return "textformat"
        case .rectangleShape: return "square"
        case .ellipseShape: return "circle"
        case .lineShape: return "line.horizontal.3"
        case .triangleShape: return "triangle"
        case .starShape: return "star"
        case .imagePlaceholder: return "photo"
        @unknown default: return "questionmark"
        }
    }
    var iconColor: Color {
        switch self {
        case .invoiceNumberAndDates, .billTo, .participant, .servicesTable, .documentGrid, .totals, .paymentDetails,
             .paymentTerms, .invoiceTitle, .companyName, .companyABN, .companyEmail, .companyLogo:
            return .blue
        case .notes:
            return .gray
        case .textBox:
            return .primary
        case .rectangleShape, .ellipseShape, .lineShape, .triangleShape, .starShape, .imagePlaceholder:
            return .gray
        @unknown default:
            return .primary
        }
    }
    var description: String {
        switch self {
        case .invoiceNumberAndDates:
            return "Invoice number and issue/due dates"
        case .billTo:
            return "Billing contact details"
        case .participant:
            return "Participant details (e.g., client, participant)"
        case .servicesTable:
            return "Services/products list and their prices"
        case .documentGrid:
            return "Advanced document-style table with perfect gridlines"
        case .totals:
            return "Subtotal, discount, tax, and final total"
        case .paymentDetails:
            return "Payment terms and bank details"
        case .paymentTerms:
            return "Payment terms text"
        case .invoiceTitle:
            return "Invoice title/number"
        case .companyName:
            return "Your business name"
        case .companyABN:
            return "Business ABN number"
        case .companyEmail:
            return "Business email address"
        case .companyLogo:
            return "Company logo/image"
        case .notes:
            return "Additional notes"
        case .textBox:
            return "Editable text box"
        case .rectangleShape:
            return "Simple rectangle shape"
        case .ellipseShape:
            return "Simple oval/ellipse"
        case .lineShape:
            return "Horizontal or vertical divider"
        case .triangleShape:
            return "Add a triangle shape"
        case .starShape:
            return "Add a star shape"
        case .imagePlaceholder:
            return "Placeholder for an image"
        }
    }
    var defaultSize: CGSize {
        switch self {
        case .invoiceNumberAndDates:
            return CGSize(width: 280, height: 45)
        case .billTo:
            return CGSize(width: 220, height: 60)
        case .participant:
            return CGSize(width: 220, height: 45)
        case .servicesTable:
            return CGSize(width: 380, height: 90)
        case .documentGrid:
            return CGSize(width: 400, height: 120)
        case .totals:
            return CGSize(width: 280, height: 70)
        case .paymentDetails:
            return CGSize(width: 280, height: 70)
        case .paymentTerms:
            return CGSize(width: 280, height: 45)
        case .invoiceTitle:
            return CGSize(width: 180, height: 30)
        case .companyName:
            return CGSize(width: 220, height: 45)
        case .companyABN:
            return CGSize(width: 180, height: 30)
        case .companyEmail:
            return CGSize(width: 180, height: 30)
        case .companyLogo:
            return CGSize(width: 80, height: 80)
        case .notes:
            return CGSize(width: 280, height: 70)
        case .textBox:
            return CGSize(width: 180, height: 30)
        case .rectangleShape:
            return CGSize(width: 160, height: 60)
        case .ellipseShape:
            return CGSize(width: 120, height: 60)
        case .lineShape:
            return CGSize(width: 280, height: 6)
        case .triangleShape:
            return CGSize(width: 100, height: 80)
        case .starShape:
            return CGSize(width: 100, height: 100)
        case .imagePlaceholder:
            return CGSize(width: 140, height: 90)
        }
    }
    var isTextComponent: Bool {
        switch self {
        case .companyName, .companyABN, .companyEmail, .invoiceNumberAndDates, .billTo, .participant, 
             .servicesTable, .documentGrid, .totals, .paymentDetails, .paymentTerms, .invoiceTitle, .notes, .textBox:
            return true
        case .companyLogo, .rectangleShape, .ellipseShape, .lineShape, .triangleShape, .starShape, .imagePlaceholder:
            return false
        }
    }
}
func fontWeightFromString(_ string: String) -> Font.Weight {
    switch string.lowercased() {
    case "regular": return .regular
    case "medium": return .medium
    case "semibold": return .semibold
    case "bold": return .bold
    default: return .regular
    }
}
extension TextAlignment {
    var swiftUIAlignment: SwiftUI.TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
    var frameAlignment: Alignment {
        switch self {
        case .leading: return .topLeading
        case .center: return .top
        case .trailing: return .topTrailing
        }
    }
}
extension TextTransform {
    var swiftUITextCase: Text.Case? {
        switch self {
        case .none: return nil
        case .uppercase: return .uppercase
        case .lowercase: return .lowercase
        case .capitalize: return nil 
        }
    }
}
extension ComponentStyle {
    func fontFamily(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        switch fontFamily.lowercased() {
        case "serif": return .system(size: size, weight: weight, design: .serif)
        case "monospace": return .system(size: size, weight: weight, design: .monospaced)
        default: return .system(size: size, weight: weight, design: .default)
        }
    }
    var fontWeightValue: Font.Weight {
        return fontWeightFromString(self.fontWeight)
    }
    var borderStrokeStyle: StrokeStyle {
        return StrokeStyle(lineWidth: borderWidth)
    }
}
extension VerticalAlignment {
    var frameAlignment: Alignment {
        switch self {
        case .top: return .top
        case .center: return .center
        case .bottom: return .bottom
        case .firstTextBaseline: return .top
        case .lastTextBaseline: return .bottom
        default:
                return .center
        }
    }
}
