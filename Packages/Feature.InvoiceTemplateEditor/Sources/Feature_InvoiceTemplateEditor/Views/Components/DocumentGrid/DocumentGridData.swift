import SwiftUI
import SwiftData

// MARK: - Document Grid Data Generation

@MainActor
struct DocumentGridDataGenerator {
    let component: InvoiceComponent
    let modelContext: ModelContext
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
        // Initialize shared instance if not already done
        if TemplateDataService.shared == nil {
            TemplateDataService.initializeShared(with: modelContext)
        }
        
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
        let payeeData = TemplateDataService.getShared().getPayeeData(for: clientId)
        
        // Match Invoices feature: Name, Email, Address only
        let fields = [
            ("Name", payeeData.name),
            ("Email", payeeData.email),
            ("Address", payeeData.address)
        ]
        
        var data: [[DocumentTableItem]] = []
        for (index, field) in fields.enumerated() {
            data.append([
                DocumentTableItem(content: field.0, alignment: nil, isHeader: true, rowIndex: index, columnIndex: 0),
                DocumentTableItem(content: field.1, alignment: nil, isHeader: false, rowIndex: index, columnIndex: 1)
            ])
        }
        return data
    }
    
    private func generateParticipantData() -> [[DocumentTableItem]] {
        let clientData = TemplateDataService.getShared().getClientData(for: clientId)
        
        // Match Invoices feature: Name and NDIS No. (if available)
        var fields: [(String, String)] = [
            ("Name", clientData.name)
        ]
        
        // Only add NDIS Number if it's not empty (matching Invoices feature behavior)
        if !clientData.ndisNumber.isEmpty {
            fields.append(("NDIS No.", clientData.ndisNumber))
        }
        
        var data: [[DocumentTableItem]] = []
        for (index, field) in fields.enumerated() {
            data.append([
                DocumentTableItem(content: field.0, alignment: nil, isHeader: true, rowIndex: index, columnIndex: 0),
                DocumentTableItem(content: field.1, alignment: nil, isHeader: false, rowIndex: index, columnIndex: 1)
            ])
        }
        return data
    }
    
    private func generateInvoiceDatesData() -> [[DocumentTableItem]] {
        let invoiceData = TemplateDataService.getShared().getInvoiceData(for: invoiceId)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        let fields = [
            ("Invoice #", invoiceData.invoiceNumber),
            ("Date", formatter.string(from: invoiceData.issueDate)),
            ("Due Date", formatter.string(from: invoiceData.dueDate))
        ]
        
        var data: [[DocumentTableItem]] = []
        for (index, field) in fields.enumerated() {
            data.append([
                DocumentTableItem(content: field.0, alignment: nil, isHeader: true, rowIndex: index, columnIndex: 0),
                DocumentTableItem(content: field.1, alignment: nil, isHeader: false, rowIndex: index, columnIndex: 1)
            ])
        }
        return data
    }
    
    private func generatePaymentDetailsData() -> [[DocumentTableItem]] {
        let businessData = TemplateDataService.getShared().getBusinessData()
        
        // Match Invoices feature: Bank Name, Account Name, BSB, Account No.
        let fields = [
            ("Bank Name", businessData.bankName),
            ("Account Name", businessData.bankAccountName),
            ("BSB", businessData.bankBSB),
            ("Account No.", businessData.bankAccountNumber)
        ]
        
        var data: [[DocumentTableItem]] = []
        for (index, field) in fields.enumerated() {
            data.append([
                DocumentTableItem(content: field.0, alignment: nil, isHeader: true, rowIndex: index, columnIndex: 0),
                DocumentTableItem(content: field.1, alignment: nil, isHeader: false, rowIndex: index, columnIndex: 1)
            ])
        }
        return data
    }
    
    private func generateServicesTableData() -> [[DocumentTableItem]] {
        // Services table uses horizontal layout (headers as first row)
        var data: [[DocumentTableItem]] = []
        
        // Header row
        if component.style.showTableHeader {
            data.append([
                DocumentTableItem(content: "Service", alignment: nil, isHeader: true, rowIndex: 0, columnIndex: 0),
                DocumentTableItem(content: "Quantity", alignment: nil, isHeader: true, rowIndex: 0, columnIndex: 1),
                DocumentTableItem(content: "Rate", alignment: nil, isHeader: true, rowIndex: 0, columnIndex: 2),
                DocumentTableItem(content: "Amount", alignment: nil, isHeader: true, rowIndex: 0, columnIndex: 3)
            ])
        }
        
        // Service data rows - use real data from TemplateDataService
        let services = TemplateDataService.getShared().getServiceData(for: clientId)
        
        let serviceData = services.map { service in
            (service.name, "\(service.quantity) \(service.unit)", String(format: "$%.2f", service.rate), String(format: "$%.2f", service.amount))
        }
        
        let startRow = component.style.showTableHeader ? 1 : 0
        for (index, service) in serviceData.enumerated() {
            data.append([
                DocumentTableItem(content: service.0, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 0),
                DocumentTableItem(content: service.1, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 1),
                DocumentTableItem(content: service.2, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 2),
                DocumentTableItem(content: service.3, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 3)
            ])
        }
        
        // Totals rows (appear in the last two columns) - use real invoice data
        let invoiceData = TemplateDataService.getShared().getInvoiceData(for: invoiceId)
        let totalsData = [
            ("Subtotal", String(format: "$%.2f", invoiceData.subtotal)),
            ("Tax (\(Int(invoiceData.taxRate * 100))%)", String(format: "$%.2f", invoiceData.totalAmount - invoiceData.subtotal)),
            ("Total", String(format: "$%.2f", invoiceData.totalAmount))
        ]
        
        let totalsStartRow = startRow + serviceData.count
        for (index, total) in totalsData.enumerated() {
            data.append([
                DocumentTableItem(content: " ", alignment: nil, isHeader: false, rowIndex: totalsStartRow + index, columnIndex: 0, isTransparent: true), // Empty first column - transparent
                DocumentTableItem(content: " ", alignment: nil, isHeader: false, rowIndex: totalsStartRow + index, columnIndex: 1, isTransparent: true), // Empty second column - transparent
                DocumentTableItem(content: total.0, alignment: nil, isHeader: true, rowIndex: totalsStartRow + index, columnIndex: 2), // Label in Rate column
                DocumentTableItem(content: total.1, alignment: nil, isHeader: false, rowIndex: totalsStartRow + index, columnIndex: 3)  // Value in Amount column
            ])
        }
        
        return data
    }
    
    private func generateDefaultSectionData() -> [[DocumentTableItem]] {
        return [
            [
                DocumentTableItem(content: "Label", alignment: nil, isHeader: true, rowIndex: 0, columnIndex: 0),
                DocumentTableItem(content: "Value", alignment: nil, isHeader: false, rowIndex: 0, columnIndex: 1)
            ]
        ]
    }
}

