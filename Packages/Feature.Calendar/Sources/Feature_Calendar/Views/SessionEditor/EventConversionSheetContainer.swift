import SwiftUI
import SwiftData
import EventKit
import Core
import SharedUI

struct EventConversionSheetContainer: View {
    @Bindable var viewModel: CalendarViewModel
    let event: EKEvent
    let onDismiss: () -> Void
    let onSave: (RecurringEditMode, NewSessionViewModel) -> Void
    let onDelete: (RecurringEditMode, NewSessionViewModel) -> Void

    var body: some View {
        DeferredSessionEditorSheet(
            onDismiss: onDismiss,
            onSave: onSave,
            onDelete: onDelete,
            makeEditor: {
                viewModel.makeNewSessionViewModel(from: event)
            }
        )
    }
}
