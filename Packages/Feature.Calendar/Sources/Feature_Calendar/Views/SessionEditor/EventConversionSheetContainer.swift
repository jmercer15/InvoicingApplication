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

    @State private var editorViewModel: NewSessionViewModel? = nil

    init(
        viewModel: CalendarViewModel,
        event: EKEvent,
        onDismiss: @escaping () -> Void,
        onSave: @escaping (RecurringEditMode, NewSessionViewModel) -> Void,
        onDelete: @escaping (RecurringEditMode, NewSessionViewModel) -> Void
    ) {
        self.viewModel = viewModel
        self.event = event
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
                    try? await Task.sleep(for: .milliseconds(150))
                    let vm = viewModel.makeNewSessionViewModel(from: event)
                    withAnimation(.easeOut(duration: 0.15)) {
                        editorViewModel = vm
                    }
                }
            }
        }
    }
}
