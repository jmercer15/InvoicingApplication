import SwiftUI

struct ZoomableCanvasContainer<Content: View>: View {
    @EnvironmentObject private var document: InvoiceDocument
    @State private var zoomScale: CGFloat = 1.0
    @State private var viewportOffset: CGSize = .zero
    @State private var lastMagnificationValue: CGFloat = 1.0
    @State private var isPanning: Bool = false
    @State private var panStartOffset: CGSize = .zero
    @State private var panStartTranslation: CGSize = .zero
    @State private var panVelocity: CGSize = .zero
    @State private var lastPanTime: Date = Date()
    @State private var lastPanTranslation: CGSize = .zero
    @State private var isDropTargeted = false
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color(.windowBackgroundColor)
                ScrollView([.horizontal, .vertical]) {
                    content
                        .scaleEffect(zoomScale, anchor: .center)
                        .offset(viewportOffset)
                        .gesture(canvasGestures(in: geometry))
                }
            }
        }
    }

    private func canvasGestures(in geometry: GeometryProxy) -> some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    let newScale = zoomScale + (value - lastMagnificationValue)
                    zoomScale = min(max(newScale, 0.25), 4.0)
                    lastMagnificationValue = value
                }
                .onEnded { _ in
                    lastMagnificationValue = 1.0
                },
            DragGesture()
                .onChanged { value in
                    if !isPanning {
                        isPanning = true
                        panStartOffset = viewportOffset
                        panStartTranslation = value.translation
                        lastPanTranslation = value.translation
                        lastPanTime = Date()
                        panVelocity = .zero
                    }

                    let currentTime = Date()
                    let timeDelta = currentTime.timeIntervalSince(lastPanTime)
                    if timeDelta > 0 {
                        let deltaTranslation = CGSize(
                            width: value.translation.width - lastPanTranslation.width,
                            height: value.translation.height - lastPanTranslation.height
                        )
                        panVelocity = CGSize(
                            width: deltaTranslation.width / CGFloat(timeDelta),
                            height: deltaTranslation.height / CGFloat(timeDelta)
                        )
                        lastPanTranslation = value.translation
                        lastPanTime = currentTime
                    }

                    let deltaTranslation = CGSize(
                        width: value.translation.width - panStartTranslation.width,
                        height: value.translation.height - panStartTranslation.height
                    )

                    viewportOffset = CGSize(
                        width: panStartOffset.width + deltaTranslation.width,
                        height: panStartOffset.height + deltaTranslation.height
                    )
                }
                .onEnded { _ in
                    isPanning = false
                    panVelocity = .zero
                }
        )
    }
}
