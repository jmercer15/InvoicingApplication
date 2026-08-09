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

    @State private var editorViewModel: NewSessionViewModel? = nil

    init(
        viewModel: CalendarViewModel,
        sessionInfo: (session: Session?, instanceStart: Date?, instanceEnd: Date?),
        onDismiss: @escaping () -> Void,
        onSave: @escaping (RecurringEditMode, NewSessionViewModel) -> Void,
        onDelete: @escaping (RecurringEditMode, NewSessionViewModel) -> Void
    ) {
        self.viewModel = viewModel
        self.sessionInfo = sessionInfo
        self.onDismiss = onDismiss
        self.onSave = onSave
        self.onDelete = onDelete
        _editorViewModel = State(initialValue: nil)
    }

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
                ZStack {
                    LinearGradient(
                        colors: [
                            StyleGuide.Colors.background,
                            StyleGuide.Colors.background.opacity(0.95),
                            StyleGuide.Colors.background.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    ProgressView()
                        .progressViewStyle(.circular)
                }
                .frame(minWidth: StyleGuide.Dimensions.sessionSheetMinWidth, minHeight: StyleGuide.Dimensions.sessionSheetMinHeight)
                .task {
                    // Small delay to let the sheet presentation animation finish smoothly
                    guard await Task.waitUnlessCancelled(for: .milliseconds(150)) else { return }
                    let vm = viewModel.makeNewSessionViewModel(
                        session: sessionInfo.session,
                        instanceDate: sessionInfo.instanceStart,
                        instanceEndDate: sessionInfo.instanceEnd
                    )
                    withAnimation(.easeOut(duration: 0.15)) {
                        editorViewModel = vm
                    }
                }
            }
        }
    }
}
