import SwiftUI
import SwiftData
import Core
import PersistenceModels
import SharedUI

struct SessionEditorSheetContainer: View {
    @Bindable var viewModel: CalendarViewModel
    let sessionInfo: (session: Session?, instanceStart: Date?, instanceEnd: Date?)
    let onDismiss: () -> Void
    let onSave: (RecurringEditMode, NewSessionViewModel) -> Void
    let onDelete: (RecurringEditMode, NewSessionViewModel) -> Void

    var body: some View {
        DeferredSessionEditorSheet(
            onDismiss: onDismiss,
            onSave: onSave,
            onDelete: onDelete,
            makeEditor: {
                viewModel.makeNewSessionViewModel(
                    session: sessionInfo.session,
                    instanceDate: sessionInfo.instanceStart,
                    instanceEndDate: sessionInfo.instanceEnd
                )
            }
        )
    }
}

/// Shared deferred-load scaffold for session editor and EventKit conversion sheets.
struct DeferredSessionEditorSheet: View {
    let onDismiss: () -> Void
    let onSave: (RecurringEditMode, NewSessionViewModel) -> Void
    let onDelete: (RecurringEditMode, NewSessionViewModel) -> Void
    let makeEditor: () -> NewSessionViewModel

    @State private var editorViewModel: NewSessionViewModel?

    var body: some View {
        Group {
            if let editorViewModel {
                NativeSessionSheetView(viewModel: editorViewModel, onDismiss: onDismiss)
                    .onAppear {
                        editorViewModel.onSave = { mode in
                            onSave(mode, editorViewModel)
                        }
                        editorViewModel.onDelete = { mode in
                            onDelete(mode, editorViewModel)
                        }
                    }
            } else {
                DeferredSheetPlaceholder(
                    minWidth: StyleGuide.Dimensions.sessionSheetMinWidth,
                    minHeight: StyleGuide.Dimensions.sessionSheetMinHeight
                )
                .task {
                    guard await DeferredSheetPresentation.waitForReveal() else { return }
                    let vm = makeEditor()
                    DeferredSheetPresentation.reveal {
                        editorViewModel = vm
                    }
                }
            }
        }
    }
}
