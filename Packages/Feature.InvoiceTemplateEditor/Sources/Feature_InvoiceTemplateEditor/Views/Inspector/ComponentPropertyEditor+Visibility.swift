import SwiftUI
import Core
import SharedUI

extension ComponentPropertyEditor {
    @ViewBuilder
    func visibilitySection(for component: InvoiceComponent) -> some View {
        let factory = ComponentInspectorControlFactory(component: component, document: document)
        
        InspectorGroupBox(title: "Visibility", icon: "fluent-ic_fluent_eye_show_20_regular") {
            InspectorControlGroup {
                // Bill To
                if component.type == .billTo {
                    toggleControl(factory, id: "Name", label: "Name")
                    toggleControl(factory, id: "Email", label: "Email")
                    toggleControl(factory, id: "Address", label: "Address")
                    toggleControl(factory, id: "Phone", label: "Phone")
                    toggleControl(factory, id: "Authority", label: "Authority")
                }
                
                // Participant
                if component.type == .participant {
                    toggleControl(factory, id: "Name", label: "Name")
                    toggleControl(factory, id: "NDIS No.", label: "NDIS No.")
                    toggleControl(factory, id: "Email", label: "Email")
                    toggleControl(factory, id: "Phone", label: "Phone")
                    toggleControl(factory, id: "Address", label: "Address")
                }
                
                // Invoice Dates
                if component.type == .invoiceNumberAndDates {
                    toggleControl(factory, id: "Invoice #", label: "Invoice #")
                    toggleControl(factory, id: "Date", label: "Date")
                    toggleControl(factory, id: "Due Date", label: "Due Date")
                }
                
                // Payment Details
                if component.type == .paymentDetails {
                    toggleControl(factory, id: "Bank Name", label: "Bank Name")
                    toggleControl(factory, id: "Account Name", label: "Account Name")
                    toggleControl(factory, id: "BSB", label: "BSB")
                    toggleControl(factory, id: "Account No.", label: "Account No.")
                }
            }
        }
    }
    
    private func toggleControl(_ factory: ComponentInspectorControlFactory, id: String, label: String) -> InspectorControl {
        // Logic: specific field is visible if NOT in hiddenFields.
        // So isOn means NOT hidden.
        let componentId = component.id
        
        let binding = Binding<Bool>(
            get: {
                !self.component.style.hiddenFields.contains(id)
            },
            set: { isVisible in
                self.document.updateComponentStyle(for: componentId, actionName: "Toggle Field Visibility") { style in
                    if isVisible {
                        style.hiddenFields.remove(id)
                    } else {
                        style.hiddenFields.insert(id)
                    }
                }
            }
        )
        
        return .toggle(id, icon: "fluent-ic_fluent_text_font_20_regular", tooltip: label, isOn: binding)
    }
}
