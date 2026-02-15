import SwiftUI

// MARK: - Company Email Component

struct CompanyEmailComponent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument
    @EnvironmentObject private var templateDataService: TemplateDataService
    
    private var businessData: BusinessTemplateData {
        templateDataService.getBusinessData()
    }

    @Environment(\.isMeasuringIdealSize) private var isMeasuringIdealSize
    
    var body: some View {
        let baseFontSize = component.style.fontSize > 0 ? component.style.fontSize : 12
        let alignment = component.style.textAlignment
        VStack(alignment: alignment.horizontalAlignment, spacing: 4) {
            Text(businessData.email)
                .standardTextStyle(component: component, baseFontSize: baseFontSize)
        }
        .standardComponentStyle(component: component, document: document, alignment: alignment.frameAlignment)
    }
}

