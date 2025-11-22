import SwiftUI
import CoreGraphics

// MARK: - Zoom and Pan Logic

struct CanvasZoomPan {
    // Helper function for smooth boundary resistance with exponential decay
    static func constrainWithResistance(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat, resistance: CGFloat) -> CGFloat {
        if value < minValue {
            let excess = minValue - value
            // Exponential resistance curve for more natural feel
            let resistanceFactor = 1.0 - pow(resistance, excess / 50.0)
            return minValue - excess * resistanceFactor
        } else if value > maxValue {
            let excess = value - maxValue
            // Exponential resistance curve for more natural feel
            let resistanceFactor = 1.0 - pow(resistance, excess / 50.0)
            return maxValue + excess * resistanceFactor
        }
        return value
    }
    
    // Helper function to calculate optimal pan boundaries
    static func calculatePanBoundaries(geometrySize: CGSize, zoomScale: CGFloat) -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        let canvasSize = CGSize(width: A4.width, height: A4.height)
        let scaledCanvasSize = CGSize(
            width: canvasSize.width * zoomScale,
            height: canvasSize.height * zoomScale
        )
        
        // Only apply boundaries when zoomed in enough to have overflow
        let hasOverflowX = scaledCanvasSize.width > geometrySize.width
        let hasOverflowY = scaledCanvasSize.height > geometrySize.height
        
        let maxOffsetX = hasOverflowX ? (scaledCanvasSize.width - geometrySize.width) / 2 : 0
        let maxOffsetY = hasOverflowY ? (scaledCanvasSize.height - geometrySize.height) / 2 : 0
        
        return (
            minX: hasOverflowX ? -maxOffsetX : 0,
            maxX: hasOverflowX ? maxOffsetX : 0,
            minY: hasOverflowY ? -maxOffsetY : 0,
            maxY: hasOverflowY ? maxOffsetY : 0
        )
    }
    
    // Helper function to apply momentum-based panning
    static func applyMomentum(
        geometry: GeometryProxy,
        zoomScale: CGFloat,
        viewportOffset: CGSize,
        panVelocity: CGSize,
        setViewportOffset: @escaping (CGSize) -> Void
    ) {
        // For now, just apply a small momentum offset without complex animation
        // This avoids concurrency issues while still providing some momentum feel
        let momentumFactor: CGFloat = 0.3
        let momentumOffset = CGSize(
            width: panVelocity.width * momentumFactor,
            height: panVelocity.height * momentumFactor
        )
        
        let newOffset = CGSize(
            width: viewportOffset.width + momentumOffset.width,
            height: viewportOffset.height + momentumOffset.height
        )
        
        // Apply boundary constraints
        let boundaries = calculatePanBoundaries(geometrySize: geometry.size, zoomScale: zoomScale)
        let constrainedOffsetX = constrainWithResistance(
            newOffset.width,
            min: boundaries.minX,
            max: boundaries.maxX,
            resistance: 0.1
        )
        
        let constrainedOffsetY = constrainWithResistance(
            newOffset.height,
            min: boundaries.minY,
            max: boundaries.maxY,
            resistance: 0.1
        )
        
        withAnimation(.easeOut(duration: 0.3)) {
            setViewportOffset(CGSize(width: constrainedOffsetX, height: constrainedOffsetY))
        }
    }
    
    // Calculate zoom scale with resistance near boundaries
    static func calculateZoomScale(
        currentScale: CGFloat,
        rawDelta: CGFloat,
        gestureVelocity: CGFloat,
        lastMagnificationValue: CGFloat
    ) -> (scale: CGFloat, newLastMagnificationValue: CGFloat) {
        // Logarithmic dampening based on current zoom level
        let logDampening = log(currentScale + 0.5) / log(2.0)
        let adaptiveDampening = max(0.1, 0.5 - logDampening * 0.2)
        
        // Velocity-based dampening (faster gestures = less dampening)
        let velocityDampening = min(1.0, max(0.3, 1.0 - gestureVelocity * 2.0))
        
        // Combined dampening factor
        let combinedDampening = adaptiveDampening * velocityDampening
        
        // Apply logarithmic scaling for more natural feel
        let dampenedDelta = rawDelta * combinedDampening
        let newScale = currentScale + dampenedDelta
        
        // Apply exponential resistance near boundaries
        let minScale: CGFloat = 0.25
        let maxScale: CGFloat = 4.0
        let resistanceFactor: CGFloat = 0.3
        
        let finalScale: CGFloat
        if newScale < minScale {
            let excess = minScale - newScale
            finalScale = minScale - excess * resistanceFactor
        } else if newScale > maxScale {
            let excess = newScale - maxScale
            finalScale = maxScale + excess * resistanceFactor
        } else {
            finalScale = newScale
        }
        
        let clampedScale = max(minScale, min(finalScale, maxScale))
        
        return (scale: clampedScale, newLastMagnificationValue: lastMagnificationValue + rawDelta)
    }
    
    // Snap zoom to common levels
    static func snapZoomScale(_ scale: CGFloat) -> CGFloat {
        let snapThreshold: CGFloat = 0.1
        
        if abs(scale - 0.5) < snapThreshold {
            return 0.5
        } else if abs(scale - 1.0) < snapThreshold {
            return 1.0
        } else if abs(scale - 1.5) < snapThreshold {
            return 1.5
        } else if abs(scale - 2.0) < snapThreshold {
            return 2.0
        } else if abs(scale - 3.0) < snapThreshold {
            return 3.0
        }
        
        return scale
    }
    
    // Calculate viewport offset adjustment when zoom changes
    static func adjustViewportOffsetForZoom(
        oldScale: CGFloat,
        newScale: CGFloat,
        currentOffset: CGSize
    ) -> CGSize {
        guard oldScale != newScale else { return currentOffset }
        
        let scaleRatio = newScale / oldScale
        return CGSize(
            width: currentOffset.width * scaleRatio,
            height: currentOffset.height * scaleRatio
        )
    }
}
