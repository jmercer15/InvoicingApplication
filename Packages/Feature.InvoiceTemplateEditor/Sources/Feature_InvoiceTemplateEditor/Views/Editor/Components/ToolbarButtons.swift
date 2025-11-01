import SwiftUI
import CoreGraphics

// MARK: - Toolbar Buttons and Controls

struct ZoomPanControlsView: View {
    @Binding var zoomScale: CGFloat
    @Binding var viewportOffset: CGSize
    let geometry: GeometryProxy
    
    private let minZoom: CGFloat = 0.25
    private let maxZoom: CGFloat = 4.0
    
    var body: some View {
        VStack(spacing: 8) {
            // Zoom Level Indicator
            Text("\(Int(zoomScale * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color.primaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primarySurface.opacity(0.9))
                .cornerRadius(6)
                .shadow(color: Color.subtleShadow, radius: 2, x: 0, y: 1)
            
            // Zoom Controls
            HStack(spacing: 4) {
                // Zoom Out Button
                Button(action: zoomOut) {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.primaryText)
                        .frame(width: 24, height: 24)
                        .background(Color.primarySurface.opacity(0.9))
                        .cornerRadius(4)
                }
                .pointerStyle(.link)
                .buttonStyle(PlainButtonStyle())
                .disabled(zoomScale <= minZoom)
                
                // Zoom to Fit Button
                Button(action: zoomToFit) {
                    Image(systemName: "arrow.down.left.and.arrow.up.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.primaryText)
                        .frame(width: 24, height: 24)
                        .background(Color.primarySurface.opacity(0.9))
                        .cornerRadius(4)
                }
                .pointerStyle(.link)
                .buttonStyle(PlainButtonStyle())
                
                // Zoom In Button
                Button(action: zoomIn) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.primaryText)
                        .frame(width: 24, height: 24)
                        .background(Color.primarySurface.opacity(0.9))
                        .cornerRadius(4)
                }
                .pointerStyle(.link)
                .buttonStyle(PlainButtonStyle())
                .disabled(zoomScale >= maxZoom)
            }
            
            // Pan Controls
            VStack(spacing: 2) {
                // Up Pan Button
                Button(action: { panUp() }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.primaryText)
                        .frame(width: 24, height: 16)
                        .background(Color.primarySurface.opacity(0.9))
                        .cornerRadius(4)
                }
                .pointerStyle(.link)
                .buttonStyle(PlainButtonStyle())
                
                HStack(spacing: 2) {
                    // Left Pan Button
                    Button(action: { panLeft() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.primaryText)
                            .frame(width: 16, height: 24)
                            .background(Color.primarySurface.opacity(0.9))
                            .cornerRadius(4)
                    }
                    .pointerStyle(.link)
                    .buttonStyle(PlainButtonStyle())
                    
                    // Center Button
                    Button(action: centerView) {
                        Image(systemName: "dot.circle")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(Color.primaryText)
                            .frame(width: 16, height: 24)
                            .background(Color.primarySurface.opacity(0.9))
                            .cornerRadius(4)
                    }
                    .pointerStyle(.link)
                    .buttonStyle(PlainButtonStyle())
                    
                    // Right Pan Button
                    Button(action: { panRight() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.primaryText)
                            .frame(width: 16, height: 24)
                            .background(Color.primarySurface.opacity(0.9))
                            .cornerRadius(4)
                    }
                    .pointerStyle(.link)
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Down Pan Button
                Button(action: { panDown() }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.primaryText)
                        .frame(width: 24, height: 16)
                        .background(Color.primarySurface.opacity(0.9))
                        .cornerRadius(4)
                }
                .pointerStyle(.link)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(8)
        .background(Color.primarySurface.opacity(0.8))
        .cornerRadius(8)
        .shadow(color: Color.subtleShadow, radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Zoom Actions
    
    private func zoomIn() {
        let newScale = min(zoomScale * 1.2, maxZoom)
        updateZoom(newScale)
    }
    
    private func zoomOut() {
        let newScale = max(zoomScale / 1.2, minZoom)
        updateZoom(newScale)
    }
    
    private func zoomToFit() {
        let canvasSize = CGSize(width: A4.width, height: A4.height)
        let scaleX = geometry.size.width / canvasSize.width
        let scaleY = geometry.size.height / canvasSize.height
        let fitScale = min(scaleX, scaleY) * 0.9 // 90% to leave some margin
        
        let newScale = max(min(fitScale, maxZoom), minZoom)
        updateZoom(newScale)
        centerView()
    }
    
    private func updateZoom(_ newScale: CGFloat) {
        withAnimation(.easeInOut(duration: 0.2)) {
            let oldScale = zoomScale
            zoomScale = newScale
            
            // Adjust viewport offset to maintain zoom center point
            viewportOffset = CanvasZoomPan.adjustViewportOffsetForZoom(
                oldScale: oldScale,
                newScale: zoomScale,
                currentOffset: viewportOffset
            )
        }
    }
    
    // MARK: - Pan Actions
    
    private func panUp() {
        panBy(CGSize(width: 0, height: 50))
    }
    
    private func panDown() {
        panBy(CGSize(width: 0, height: -50))
    }
    
    private func panLeft() {
        panBy(CGSize(width: 50, height: 0))
    }
    
    private func panRight() {
        panBy(CGSize(width: -50, height: 0))
    }
    
    private func centerView() {
        withAnimation(.easeInOut(duration: 0.3)) {
            viewportOffset = .zero
        }
    }
    
    private func panBy(_ delta: CGSize) {
        let newOffset = CGSize(
            width: viewportOffset.width + delta.width,
            height: viewportOffset.height + delta.height
        )
        
        // Apply boundary constraints using extracted utilities
        let boundaries = CanvasZoomPan.calculatePanBoundaries(
            geometrySize: geometry.size,
            zoomScale: zoomScale
        )
        let constrainedOffsetX = CanvasZoomPan.constrainWithResistance(
            newOffset.width,
            min: boundaries.minX,
            max: boundaries.maxX,
            resistance: 0.1
        )
        
        let constrainedOffsetY = CanvasZoomPan.constrainWithResistance(
            newOffset.height,
            min: boundaries.minY,
            max: boundaries.maxY,
            resistance: 0.1
        )
        
        withAnimation(.easeInOut(duration: 0.2)) {
            viewportOffset = CGSize(width: constrainedOffsetX, height: constrainedOffsetY)
        }
    }
}

