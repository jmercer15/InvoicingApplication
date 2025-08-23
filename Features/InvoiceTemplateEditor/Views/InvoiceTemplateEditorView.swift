import SwiftUI

struct InvoiceTemplateEditorView: View {
    @StateObject private var viewModel = InvoiceTemplateEditorViewModel()

    var body: some View {
        InvoiceBuilderView()
            .environmentObject(viewModel.document)
    }
}
