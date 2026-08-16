import SwiftUI

struct InvoiceDocumentPreviewSheet: View {
    @Bindable var viewModel: InvoiceEditorViewModel
    @Bindable var toolbarState: InvoiceEditorToolbarState
    let inspectorInteraction: InvoicePreviewInspectorInteraction
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        InvoiceDocumentPreview(
            viewModel: viewModel,
            zoom: $toolbarState.zoom,
            viewport: toolbarState.viewport,
            inspectorInteraction: inspectorInteraction
        )
        .navigationTitle("Invoice Preview")
        .frame(
            minWidth: 760,
            idealWidth: 1_000,
            minHeight: 560,
            idealHeight: 760
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", action: dismiss.callAsFunction)
                    .keyboardShortcut(.cancelAction)
            }

            ToolbarItem(placement: .automatic) {
                InvoicePreviewZoomControls(toolbarState: toolbarState)
            }
        }
    }
}
