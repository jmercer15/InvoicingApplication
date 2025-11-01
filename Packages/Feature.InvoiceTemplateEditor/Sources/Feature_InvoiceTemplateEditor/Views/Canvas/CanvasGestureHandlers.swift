import SwiftUI
import CoreGraphics

// MARK: - Canvas Gesture Handlers

struct CanvasGestureHandlers: ViewModifier {
    @Binding var zoomScale: CGFloat
    @Binding var viewportOffset: CGSize
    @Binding var lastMagnificationValue: CGFloat
    @Binding var gestureVelocity: CGFloat
    @Binding var lastGestureTime: Date
    @Binding var isPanning: Bool
    @Binding var panStartOffset: CGSize
    @Binding var panStartTranslation: CGSize
    @Binding var panVelocity: CGSize
    @Binding var lastPanTime: Date
    @Binding var lastPanTranslation: CGSize
    
    let geometry: GeometryProxy
    
    func body(content: Content) -> some View {
        content
            .gesture(
                SimultaneousGesture(
                    // Magnification gesture for zoom
                    MagnificationGesture()
                        .onChanged { value in
                            let currentTime = Date()
                            let timeDelta = currentTime.timeIntervalSince(lastGestureTime)
                            
                            // Calculate gesture velocity for adaptive dampening
                            if timeDelta > 0 {
                                let deltaValue = value - lastMagnificationValue
                                gestureVelocity = abs(deltaValue) / CGFloat(timeDelta)
                            }
                            
                            // Calculate new zoom scale
                            let rawDelta = value - lastMagnificationValue
                            let result = CanvasZoomPan.calculateZoomScale(
                                currentScale: zoomScale,
                                rawDelta: rawDelta,
                                gestureVelocity: gestureVelocity,
                                lastMagnificationValue: lastMagnificationValue
                            )
                            
                            let oldScale = zoomScale
                            zoomScale = result.scale
                            
                            // Adjust viewport offset to maintain zoom center point
                            viewportOffset = CanvasZoomPan.adjustViewportOffsetForZoom(
                                oldScale: oldScale,
                                newScale: zoomScale,
                                currentOffset: viewportOffset
                            )
                            
                            lastMagnificationValue = result.newLastMagnificationValue
                            lastGestureTime = currentTime
                        }
                        .onEnded { _ in
                            // Smart snapping to common zoom levels
                            zoomScale = CanvasZoomPan.snapZoomScale(zoomScale)
                            
                            // Reset gesture tracking
                            lastMagnificationValue = 1.0
                            gestureVelocity = 0.0
                        },
                    
                    // Drag gesture for panning when zoomed
                    DragGesture()
                        .onChanged { value in
                            let currentTime = Date()
                            
                            if !isPanning {
                                isPanning = true
                                panStartOffset = viewportOffset
                                panStartTranslation = value.translation
                                lastPanTime = currentTime
                                lastPanTranslation = value.translation
                                panVelocity = .zero
                            }
                            
                            // Calculate velocity for momentum and feedback
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
                            }
                            
                            // Calculate new viewport offset based on drag translation
                            let deltaTranslation = CGSize(
                                width: value.translation.width - panStartTranslation.width,
                                height: value.translation.height - panStartTranslation.height
                            )
                            
                            let newOffset = CGSize(
                                width: panStartOffset.width + deltaTranslation.width,
                                height: panStartOffset.height + deltaTranslation.height
                            )
                            
                            // Get optimized pan boundaries
                            let boundaries = CanvasZoomPan.calculatePanBoundaries(
                                geometrySize: geometry.size,
                                zoomScale: zoomScale
                            )
                            
                            // Apply constraints with refined resistance
                            let resistance: CGFloat = 0.2 // Reduced for more responsive feel
                            let constrainedOffsetX = CanvasZoomPan.constrainWithResistance(
                                newOffset.width,
                                min: boundaries.minX,
                                max: boundaries.maxX,
                                resistance: resistance
                            )
                            
                            let constrainedOffsetY = CanvasZoomPan.constrainWithResistance(
                                newOffset.height,
                                min: boundaries.minY,
                                max: boundaries.maxY,
                                resistance: resistance
                            )
                            
                            viewportOffset = CGSize(width: constrainedOffsetX, height: constrainedOffsetY)
                            
                            // Update tracking variables
                            lastPanTime = currentTime
                            lastPanTranslation = value.translation
                        }
                        .onEnded { _ in
                            isPanning = false
                            
                            // Apply momentum if velocity is high enough
                            let momentumThreshold: CGFloat = 100.0
                            if abs(panVelocity.width) > momentumThreshold || abs(panVelocity.height) > momentumThreshold {
                                CanvasZoomPan.applyMomentum(
                                    geometry: geometry,
                                    zoomScale: zoomScale,
                                    viewportOffset: viewportOffset,
                                    panVelocity: panVelocity,
                                    setViewportOffset: { newOffset in
                                        viewportOffset = newOffset
                                    }
                                )
                            }
                            
                            // Reset velocity tracking
                            panVelocity = .zero
                        }
                )
            )
    }
}

extension View {
    func canvasGestures(
        zoomScale: Binding<CGFloat>,
        viewportOffset: Binding<CGSize>,
        lastMagnificationValue: Binding<CGFloat>,
        gestureVelocity: Binding<CGFloat>,
        lastGestureTime: Binding<Date>,
        isPanning: Binding<Bool>,
        panStartOffset: Binding<CGSize>,
        panStartTranslation: Binding<CGSize>,
        panVelocity: Binding<CGSize>,
        lastPanTime: Binding<Date>,
        lastPanTranslation: Binding<CGSize>,
        geometry: GeometryProxy
    ) -> some View {
        modifier(CanvasGestureHandlers(
            zoomScale: zoomScale,
            viewportOffset: viewportOffset,
            lastMagnificationValue: lastMagnificationValue,
            gestureVelocity: gestureVelocity,
            lastGestureTime: lastGestureTime,
            isPanning: isPanning,
            panStartOffset: panStartOffset,
            panStartTranslation: panStartTranslation,
            panVelocity: panVelocity,
            lastPanTime: lastPanTime,
            lastPanTranslation: lastPanTranslation,
            geometry: geometry
        ))
    }
}

