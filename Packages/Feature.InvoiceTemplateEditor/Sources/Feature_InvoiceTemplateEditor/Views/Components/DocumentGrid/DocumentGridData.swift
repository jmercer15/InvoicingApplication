import SwiftUI

// MARK: - Document Grid Data Generation

@MainActor
struct DocumentGridDataGenerator {
    let component: InvoiceComponent
    let templateDataService: TemplateDataService
    let clientId: UUID?
    let invoiceId: UUID?
    
    /// Determines if this is a section component that should use section-specific data
    var isSectionComponent: Bool {
        switch component.type {
        case .billTo, .participant, .invoiceNumberAndDates, .paymentDetails, .servicesTable:
            return true
        default:
            return false
        }
    }
    
    /// Generates sample data for the document grid component
    func generateSampleData() -> [[DocumentTableItem]] {
        var data: [[DocumentTableItem]] = []
        
        // Check if this is a section component that should use section-specific data
        if isSectionComponent {
            return generateSectionData()
        }
        
        // Default DocumentGrid data for non-section components
        switch component.style.tableDirection {
        case .horizontal:
            // Horizontal layout: headers as first row
            if component.style.showTableHeader {
                data.append([
                    DocumentTableItem(content: "Service", alignment: nil, verticalAlignment: nil, isHeader: true, rowIndex: 0, columnIndex: 0),
                    DocumentTableItem(content: "Quantity", alignment: nil, verticalAlignment: nil, isHeader: true, rowIndex: 0, columnIndex: 1),
                    DocumentTableItem(content: "Rate", alignment: nil, verticalAlignment: nil, isHeader: true, rowIndex: 0, columnIndex: 2),
                    DocumentTableItem(content: "Amount", alignment: nil, verticalAlignment: nil, isHeader: true, rowIndex: 0, columnIndex: 3)
                ])
            }
            
            // Data rows
            let serviceData = [
                ("Consultation Session", "2.0 hr", "$75.00", "$150.00"),
                ("Assessment Report", "1.5 hr", "$100.00", "$150.00"),
                ("Follow-up Meeting", "1.0 hr", "$100.00", "$100.00")
            ]
            
            let startRow = component.style.showTableHeader ? 1 : 0
            for (index, service) in serviceData.enumerated() {
                data.append([
                    DocumentTableItem(content: service.0, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 0),
                    DocumentTableItem(content: service.1, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 1),
                    DocumentTableItem(content: service.2, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 2),
                    DocumentTableItem(content: service.3, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 3)
                ])
            }
            
        case .vertical:
            // Vertical layout: headers as first column
            let headerData = [
                ["Service", "Consultation Session", "Assessment Report", "Follow-up Meeting"],
                ["Quantity", "2.0 hr", "1.5 hr", "1.0 hr"],
                ["Rate", "$75.00", "$100.00", "$100.00"],
                ["Amount", "$150.00", "$150.00", "$100.00"]
            ]
            
            for (rowIndex, row) in headerData.enumerated() {
                var rowItems: [DocumentTableItem] = []
                for (colIndex, content) in row.enumerated() {
                    let isHeader = colIndex == 0 && component.style.showTableHeader
                    rowItems.append(
                        DocumentTableItem(
                            content: content,
                            alignment: nil,
                            verticalAlignment: nil,
                            isHeader: isHeader,
                            rowIndex: rowIndex,
                            columnIndex: colIndex
                        )
                    )
                }
                data.append(rowItems)
            }
        }
        
        return data
    }
    
    /// Generates section-specific data for section components
    func generateSectionData() -> [[DocumentTableItem]] {
        switch component.type {
        case .billTo:
            return generateBillToData()
        case .participant:
            return generateParticipantData()
        case .invoiceNumberAndDates:
            return generateInvoiceDatesData()
        case .paymentDetails:
            return generatePaymentDetailsData()
        case .servicesTable:
            return generateServicesTableData()
        default:
            return generateDefaultSectionData()
        }
    }
    
    private func generateBillToData() -> [[DocumentTableItem]] {
        let payeeData = templateDataService.getPayeeData(for: clientId)
        // Also fetch authority if available (from invoice snapshot primarily)
        let invoiceData = templateDataService.getInvoiceData(for: invoiceId)
        
        var fields: [(String, String)] = []
        
        if !component.style.hiddenFields.contains("Name") {
            fields.append(("Name", payeeData.name))
        }
        if !component.style.hiddenFields.contains("Email") {
            fields.append(("Email", payeeData.email))
        }
        if !component.style.hiddenFields.contains("Address") {
            fields.append(("Address", payeeData.address))
        }
        if !component.style.hiddenFields.contains("Phone") {
            // Prefer payee phone, fallback to billTo phone if needed or empty
            let phone = !payeeData.phone.isEmpty ? payeeData.phone : (invoiceData.billToEmail ?? "") // Fallback logic is fuzzy, sticking to filtered data
             // Actually, the payeeData should already have the best available phone from the service layer init
             fields.append(("Phone", payeeData.phone))
        }
        if !component.style.hiddenFields.contains("Authority") {
            fields.append(("Authority", invoiceData.billingAuthority ?? ""))
        }
        
        return keyValueGrid(for: fields)
    }
    
    private func generateParticipantData() -> [[DocumentTableItem]] {
        let clientData = templateDataService.getClientData(for: clientId)
        var fields: [(String, String)] = []
        
        if !component.style.hiddenFields.contains("Name") {
            fields.append(("Name", clientData.name))
        }
        if !component.style.hiddenFields.contains("NDIS No.") && !clientData.ndisNumber.isEmpty {
            fields.append(("NDIS No.", clientData.ndisNumber))
        }
        if !component.style.hiddenFields.contains("Email") {
            fields.append(("Email", clientData.email))
        }
        if !component.style.hiddenFields.contains("Phone") {
            fields.append(("Phone", clientData.phone))
        }
        if !component.style.hiddenFields.contains("Address") {
            fields.append(("Address", clientData.address))
        }
        
        return keyValueGrid(for: fields)
    }
    
    private func generateInvoiceDatesData() -> [[DocumentTableItem]] {
        let invoiceData = templateDataService.getInvoiceData(for: invoiceId)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        var fields: [(String, String)] = []
        
        if !component.style.hiddenFields.contains("Invoice #") {
            fields.append(("Invoice #", invoiceData.invoiceNumber))
        }
        if !component.style.hiddenFields.contains("Date") {
            fields.append(("Date", formatter.string(from: invoiceData.issueDate)))
        }
        if !component.style.hiddenFields.contains("Due Date") {
            fields.append(("Due Date", formatter.string(from: invoiceData.dueDate)))
        }
        
        return keyValueGrid(for: fields)
    }
    
    private func generatePaymentDetailsData() -> [[DocumentTableItem]] {
        let businessData = templateDataService.getBusinessData()
        var fields: [(String, String)] = []
        
        if !component.style.hiddenFields.contains("Bank Name") {
            fields.append(("Bank Name", businessData.bankName))
        }
        if !component.style.hiddenFields.contains("Account Name") {
            fields.append(("Account Name", businessData.bankAccountName))
        }
        if !component.style.hiddenFields.contains("BSB") {
            fields.append(("BSB", businessData.bankBSB))
        }
        if !component.style.hiddenFields.contains("Account No.") {
            fields.append(("Account No.", businessData.bankAccountNumber))
        }

        return keyValueGrid(for: fields)
    }
    
    private func generateServicesTableData() -> [[DocumentTableItem]] {
        let services = templateDataService.getServiceData(for: clientId)
        let serviceData = services.map { service in
            (service.name, "\(service.quantity) \(service.unit)", String(format: "$%.2f", service.rate), String(format: "$%.2f", service.amount))
        }
        let invoiceData = templateDataService.getInvoiceData(for: invoiceId)
        let totalsData = [
            ("Subtotal", String(format: "$%.2f", invoiceData.subtotal)),
            ("Tax (\(Int(invoiceData.taxRate * 100))%)", String(format: "$%.2f", invoiceData.totalAmount - invoiceData.subtotal)),
            ("Total", String(format: "$%.2f", invoiceData.totalAmount))
        ]
        
        switch component.style.tableDirection {
        case .horizontal:
            return generateServicesHorizontalData(serviceData: serviceData, totalsData: totalsData)
        case .vertical:
            return generateServicesVerticalData(serviceData: serviceData, totalsData: totalsData)
        }
    }
    
    private func generateDefaultSectionData() -> [[DocumentTableItem]] {
        return keyValueGrid(for: [("Label", "Value")])
    }
    
    private func keyValueGrid(for pairs: [(String, String)]) -> [[DocumentTableItem]] {
        switch component.style.tableDirection {
        case .horizontal:
            var rows: [[DocumentTableItem]] = []
            if component.style.showTableHeader {
                let headerRow = pairs.enumerated().map { index, pair in
                    DocumentTableItem(
                        content: pair.0,
                        isHeader: true,
                        rowIndex: 0,
                        columnIndex: index
                    )
                }
                rows.append(headerRow)
            }
            
            let rowIndex = rows.count
            let valueRow = pairs.enumerated().map { index, pair in
                DocumentTableItem(
                    content: pair.1,
                    rowIndex: rowIndex,
                    columnIndex: index
                )
            }
            rows.append(valueRow)
            return rows
            
        case .vertical:
            return pairs.enumerated().map { index, pair in
                [
                    DocumentTableItem(
                        content: pair.0,
                        isHeader: component.style.showTableHeader,
                        rowIndex: index,
                        columnIndex: 0
                    ),
                    DocumentTableItem(
                        content: pair.1,
                        rowIndex: index,
                        columnIndex: 1
                    )
                ]
            }
        }
    }
    
    private func generateServicesHorizontalData(
        serviceData: [(String, String, String, String)],
        totalsData: [(String, String)]
    ) -> [[DocumentTableItem]] {
        var data: [[DocumentTableItem]] = []
        
        if component.style.showTableHeader {
            data.append([
                DocumentTableItem(content: "Service", isHeader: true, rowIndex: 0, columnIndex: 0),
                DocumentTableItem(content: "Quantity", isHeader: true, rowIndex: 0, columnIndex: 1),
                DocumentTableItem(content: "Rate", isHeader: true, rowIndex: 0, columnIndex: 2),
                DocumentTableItem(content: "Amount", isHeader: true, rowIndex: 0, columnIndex: 3)
            ])
        }
        
        let startRow = component.style.showTableHeader ? 1 : 0
        for (index, service) in serviceData.enumerated() {
            data.append([
                DocumentTableItem(content: service.0, rowIndex: startRow + index, columnIndex: 0),
                DocumentTableItem(content: service.1, rowIndex: startRow + index, columnIndex: 1),
                DocumentTableItem(content: service.2, rowIndex: startRow + index, columnIndex: 2),
                DocumentTableItem(content: service.3, rowIndex: startRow + index, columnIndex: 3)
            ])
        }
        
        let totalsStartRow = startRow + serviceData.count
        for (index, total) in totalsData.enumerated() {
            data.append([
                DocumentTableItem(content: " ", rowIndex: totalsStartRow + index, columnIndex: 0, isTransparent: true),
                DocumentTableItem(content: " ", rowIndex: totalsStartRow + index, columnIndex: 1, isTransparent: true),
                DocumentTableItem(content: total.0, isHeader: true, rowIndex: totalsStartRow + index, columnIndex: 2),
                DocumentTableItem(content: total.1, rowIndex: totalsStartRow + index, columnIndex: 3)
            ])
        }
        
        return data
    }
    
    private func generateServicesVerticalData(
        serviceData: [(String, String, String, String)],
        totalsData: [(String, String)]
    ) -> [[DocumentTableItem]] {
        let displayedServices = serviceData.isEmpty ? [("—", "—", "—", "—")] : serviceData
        var rows: [[DocumentTableItem]] = []
        let columnCount = displayedServices.count
        
        func paddedValues(from values: [String]) -> [String] {
            if values.count >= columnCount { return values }
            var padded = values
            while padded.count < columnCount { padded.append("") }
            return padded
        }
        
        func appendRow(label: String, values: [String], transparentValueIndices: Set<Int> = []) {
            let currentIndex = rows.count
            var row: [DocumentTableItem] = [
                DocumentTableItem(
                    content: label,
                    isHeader: component.style.showTableHeader,
                    rowIndex: currentIndex,
                    columnIndex: 0
                )
            ]
            
            let padded = paddedValues(from: values)
            for (valueIndex, value) in padded.enumerated() {
                row.append(
                    DocumentTableItem(
                        content: value,
                        rowIndex: currentIndex,
                        columnIndex: valueIndex + 1,
                        isTransparent: transparentValueIndices.contains(valueIndex) && value.isEmpty
                    )
                )
            }
            
            rows.append(row)
        }
        
        appendRow(label: "Service", values: displayedServices.map { $0.0 })
        appendRow(label: "Quantity", values: displayedServices.map { $0.1 })
        appendRow(label: "Rate", values: displayedServices.map { $0.2 })
        appendRow(label: "Amount", values: displayedServices.map { $0.3 })
        
        let transparentIndices = Set(0..<max(columnCount - 1, 0))
        let lastColumnIndex = max(columnCount - 1, 0)
        
        for total in totalsData {
            var values = Array(repeating: "", count: columnCount)
            values[lastColumnIndex] = total.1
            appendRow(
                label: total.0,
                values: values,
                transparentValueIndices: transparentIndices
            )
        }
        
        return rows
    }
}
