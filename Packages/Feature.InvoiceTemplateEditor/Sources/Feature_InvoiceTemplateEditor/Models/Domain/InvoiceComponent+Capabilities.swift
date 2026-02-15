import SwiftUI

extension InvoiceComponentType {
    var supportsTypography: Bool {
        switch self {
        case .rectangleShape, .ellipseShape, .lineShape, .triangleShape, .starShape, .imagePlaceholder, .companyLogo:
            return false
        default:
            return true
        }
    }
    
    var supportsPlaceholderText: Bool {
        switch self {
        case .textBox, .notes, .invoiceTitle, .companyName, .companyABN, .companyEmail, .paymentTerms:
            return true
        default:
            return false
        }
    }
    
    var supportsBackgroundFill: Bool {
        switch self {
        case .textBox, .notes, .invoiceTitle, .companyName, .companyABN, .companyEmail, .paymentTerms:
            return true
        case .rectangleShape, .ellipseShape, .triangleShape, .starShape:
            return true
        case .imagePlaceholder, .companyLogo:
            return true
        default:
            return false
        }
    }
    
    var supportsBorderControls: Bool {
        switch self {
        case .textBox, .notes, .invoiceTitle, .companyName, .companyABN, .companyEmail, .paymentTerms:
            return true
        case .rectangleShape, .ellipseShape, .triangleShape, .starShape:
            return true
        case .imagePlaceholder, .companyLogo:
            return true
        default:
            return false
        }
    }
    
    var supportsCornerRadius: Bool {
        switch self {
        case .lineShape, .triangleShape, .starShape:
            return false
        default:
            return supportsBorderControls || supportsBackgroundFill
        }
    }
    
    var supportsFillOrBorder: Bool {
        supportsBackgroundFill || supportsBorderControls
    }
    
    var supportsShadow: Bool {
        switch self {
        case .textBox, .notes, .invoiceTitle, .companyName, .companyABN, .companyEmail, .paymentTerms:
            return true
        case .rectangleShape, .ellipseShape, .triangleShape, .starShape:
            return true
        case .imagePlaceholder, .companyLogo:
            return true
        default:
            return false
        }
    }
    
    var isMultilineText: Bool {
        switch self {
        case .textBox, .notes, .paymentTerms, .paymentDetails:
            return true
        default:
            return false
        }
    }
    
    var supportsLayoutControls: Bool {
        switch self {
        case .rectangleShape, .ellipseShape, .lineShape, .triangleShape, .starShape:
            return false
        default:
            return true
        }
    }
    
    var isImageComponent: Bool {
        self == .imagePlaceholder || self == .companyLogo
    }
    
    var isShape: Bool {
        switch self {
        case .rectangleShape, .ellipseShape, .lineShape, .triangleShape, .starShape:
            return true
        default:
            return false
        }
    }
    
    /// Returns true if this component type uses table/grid properties (uses DocumentGridComponent)
    var usesTableProperties: Bool {
        switch self {
        case .documentGrid, .servicesTable, .billTo, .participant, 
             .invoiceNumberAndDates, .paymentDetails, .totals:
            return true
        default:
            return false
        }
    }
}
