import Foundation
import CoreGraphics

// MARK: - Snapping Functionality

extension InvoiceDocument {
    func getSnappedPosition(for proposedPosition: CGPoint, size: CGSize, excludeID: UUID? = nil) -> CGPoint {
        let snapDistance: CGFloat = 10 
        var snappedPosition = proposedPosition
        var hasSnapped = false
        let allItems = components.map { component in
            (id: component.id, position: component.position, size: component.size)
        }
        let otherItems = allItems.filter { $0.id != excludeID }
        for otherItem in otherItems {
            let currentLeft = proposedPosition.x - size.width / 2
            let currentRight = proposedPosition.x + size.width / 2
            let currentCenter = proposedPosition.x
            let otherLeft = otherItem.position.x - otherItem.size.width / 2
            let otherRight = otherItem.position.x + otherItem.size.width / 2
            let otherCenter = otherItem.position.x
            if abs(currentLeft - otherLeft) < snapDistance {
                snappedPosition.x = otherLeft + size.width / 2
                hasSnapped = true
            }
            else if abs(currentLeft - otherRight) < snapDistance {
                snappedPosition.x = otherRight + size.width / 2
                hasSnapped = true
            }
            else if abs(currentRight - otherLeft) < snapDistance {
                snappedPosition.x = otherLeft - size.width / 2
                hasSnapped = true
            }
            else if abs(currentRight - otherRight) < snapDistance {
                snappedPosition.x = otherRight - size.width / 2
                hasSnapped = true
            }
            else if abs(currentCenter - otherCenter) < snapDistance {
                snappedPosition.x = otherCenter
                hasSnapped = true
            }
            let currentTop = proposedPosition.y - size.height / 2
            let currentBottom = proposedPosition.y + size.height / 2
            let currentVCenter = proposedPosition.y
            let otherTop = otherItem.position.y - otherItem.size.height / 2
            let otherBottom = otherItem.position.y + otherItem.size.height / 2
            let otherVCenter = otherItem.position.y
            if abs(currentTop - otherTop) < snapDistance {
                snappedPosition.y = otherTop + size.height / 2
                hasSnapped = true
            }
            else if abs(currentTop - otherBottom) < snapDistance {
                snappedPosition.y = otherBottom + size.height / 2
                hasSnapped = true
            }
            else if abs(currentBottom - otherTop) < snapDistance {
                snappedPosition.y = otherTop - size.height / 2
                hasSnapped = true
            }
            else if abs(currentBottom - otherBottom) < snapDistance {
                snappedPosition.y = otherBottom - size.height / 2
                hasSnapped = true
            }
            else if abs(currentVCenter - otherVCenter) < snapDistance {
                snappedPosition.y = otherVCenter
                hasSnapped = true
            }
        }
        let currentLeft = snappedPosition.x - size.width / 2
        let currentRight = snappedPosition.x + size.width / 2
        let currentTop = snappedPosition.y - size.height / 2
        let currentBottom = snappedPosition.y + size.height / 2
        let (pageLeft, pageRight, pageTop, pageBottom, pageCenterX, pageCenterY) = CoordinateCalculator.pageBoundaries(pageSize: A4.size, margins: margins)
        let (marginLeft, marginRight, marginTop, marginBottom, _, _) = CoordinateCalculator.marginBoundaries(pageSize: A4.size)
        if abs(currentLeft - pageLeft) < snapDistance {
            snappedPosition.x = pageLeft + size.width / 2
            hasSnapped = true
        }
        else if abs(currentRight - pageRight) < snapDistance {
            snappedPosition.x = pageRight - size.width / 2
            hasSnapped = true
        }
        else if abs(currentLeft - pageCenterX) < snapDistance {
            snappedPosition.x = pageCenterX + size.width / 2
            hasSnapped = true
        }
        else if abs(currentRight - pageCenterX) < snapDistance {
            snappedPosition.x = pageCenterX - size.width / 2
            hasSnapped = true
        }
        else if abs(snappedPosition.x - pageCenterX) < snapDistance {
            snappedPosition.x = pageCenterX
            hasSnapped = true
        }
        else if abs(currentLeft - marginLeft) < snapDistance {
            snappedPosition.x = marginLeft + size.width / 2
            hasSnapped = true
        }
        else if abs(currentRight - marginRight) < snapDistance {
            snappedPosition.x = marginRight - size.width / 2
            hasSnapped = true
        }
        if abs(currentTop - pageTop) < snapDistance {
            snappedPosition.y = pageTop + size.height / 2
            hasSnapped = true
        }
        else if abs(currentBottom - pageBottom) < snapDistance {
            snappedPosition.y = pageBottom - size.height / 2
            hasSnapped = true
        }
        else if abs(currentTop - pageCenterY) < snapDistance {
            snappedPosition.y = pageCenterY + size.height / 2
            hasSnapped = true
        }
        else if abs(currentBottom - pageCenterY) < snapDistance {
            snappedPosition.y = pageCenterY - size.height / 2
            hasSnapped = true
        }
        else if abs(snappedPosition.y - pageCenterY) < snapDistance {
            snappedPosition.y = pageCenterY
            hasSnapped = true
        }
        else if abs(snappedPosition.x - pageCenterX) < snapDistance && abs(currentTop - pageTop) < snapDistance {
            snappedPosition.x = pageCenterX
            snappedPosition.y = pageTop + size.height / 2
            hasSnapped = true
        }
        else if abs(snappedPosition.x - pageCenterX) < snapDistance && abs(currentBottom - pageBottom) < snapDistance {
            snappedPosition.x = pageCenterX
            snappedPosition.y = pageBottom - size.height / 2
            hasSnapped = true
        }
        else if abs(currentLeft - pageLeft) < snapDistance && abs(snappedPosition.y - pageCenterY) < snapDistance {
            snappedPosition.x = pageLeft + size.width / 2
            snappedPosition.y = pageCenterY
            hasSnapped = true
        }
        else if abs(currentRight - pageRight) < snapDistance && abs(snappedPosition.y - pageCenterY) < snapDistance {
            snappedPosition.x = pageRight - size.width / 2
            snappedPosition.y = pageCenterY
            hasSnapped = true
        }
        else if abs(currentTop - marginTop) < snapDistance {
            snappedPosition.y = marginTop + size.height / 2
            hasSnapped = true
        }
        else if abs(currentBottom - marginBottom) < snapDistance {
            snappedPosition.y = marginBottom - size.height / 2
            hasSnapped = true
        }
        DispatchQueue.main.async { [weak self] in
            self?.isSnapping = hasSnapped
        }
        return snappedPosition
    }
    
    func getSnappedSizeAndPosition(for id: UUID, proposedSize: CGSize, proposedPosition: CGPoint) -> (size: CGSize, position: CGPoint) {
        guard component(id) != nil else { return (proposedSize, proposedPosition) }
        let snapDistance: CGFloat = 10 
        var snappedSize = proposedSize
        var snappedPosition = proposedPosition
        var hasSnapped = false
        let componentLeft = proposedPosition.x - proposedSize.width / 2
        let componentRight = proposedPosition.x + proposedSize.width / 2
        let componentTop = proposedPosition.y - proposedSize.height / 2
        let componentBottom = proposedPosition.y + proposedSize.height / 2
        let otherComponents = components.filter { $0.id != id }
        for otherComponent in otherComponents {
            let otherLeft = otherComponent.position.x - otherComponent.size.width / 2
            let otherRight = otherComponent.position.x + otherComponent.size.width / 2
            let otherTop = otherComponent.position.y - otherComponent.size.height / 2
            let otherBottom = otherComponent.position.y + otherComponent.size.height / 2
            if abs(proposedSize.width - otherComponent.size.width) < snapDistance {
                snappedSize.width = otherComponent.size.width
                hasSnapped = true
            }
            if abs(proposedSize.height - otherComponent.size.height) < snapDistance {
                snappedSize.height = otherComponent.size.height
                hasSnapped = true
            }
            if abs(componentRight - otherLeft) < snapDistance {
                let newWidth = otherLeft - componentLeft
                if newWidth > 50 && newWidth < 800 {
                    snappedSize.width = newWidth
                    snappedPosition.x = componentLeft + newWidth / 2
                    hasSnapped = true
                }
            }
            if abs(componentRight - otherRight) < snapDistance {
                let newWidth = otherRight - componentLeft
                if newWidth > 50 && newWidth < 800 {
                    snappedSize.width = newWidth
                    snappedPosition.x = componentLeft + newWidth / 2
                    hasSnapped = true
                }
            }
            if abs(componentLeft - otherLeft) < snapDistance {
                let newWidth = componentRight - otherLeft
                if newWidth > 50 && newWidth < 800 {
                    snappedSize.width = newWidth
                    snappedPosition.x = otherLeft + newWidth / 2
                    hasSnapped = true
                }
            }
            if abs(componentLeft - otherRight) < snapDistance {
                let newWidth = componentRight - otherRight
                if newWidth > 50 && newWidth < 800 {
                    snappedSize.width = newWidth
                    snappedPosition.x = otherRight + newWidth / 2
                    hasSnapped = true
                }
            }
            if abs(componentBottom - otherTop) < snapDistance {
                let newHeight = otherTop - componentTop
                if newHeight > 30 && newHeight < 600 {
                    snappedSize.height = newHeight
                    snappedPosition.y = componentTop + newHeight / 2
                    hasSnapped = true
                }
            }
            if abs(componentBottom - otherBottom) < snapDistance {
                let newHeight = otherBottom - componentTop
                if newHeight > 30 && newHeight < 600 {
                    snappedSize.height = newHeight
                    snappedPosition.y = componentTop + newHeight / 2
                    hasSnapped = true
                }
            }
            if abs(componentTop - otherTop) < snapDistance {
                let newHeight = componentBottom - otherTop
                if newHeight > 30 && newHeight < 600 {
                    snappedSize.height = newHeight
                    snappedPosition.y = otherTop + newHeight / 2
                    hasSnapped = true
                }
            }
            if abs(componentTop - otherBottom) < snapDistance {
                let newHeight = componentBottom - otherBottom
                if newHeight > 30 && newHeight < 600 {
                    snappedSize.height = newHeight
                    snappedPosition.y = otherBottom + newHeight / 2
                    hasSnapped = true
                }
            }
        }
        let (pageLeft, pageRight, pageTop, pageBottom, pageCenterX, pageCenterY) = CoordinateCalculator.pageBoundaries(pageSize: A4.size, margins: margins)
        let (marginLeft, marginRight, marginTop, marginBottom, _, _) = CoordinateCalculator.marginBoundaries(pageSize: A4.size)
        let newComponentLeft = snappedPosition.x - snappedSize.width / 2
        let newComponentRight = snappedPosition.x + snappedSize.width / 2
        let newComponentTop = snappedPosition.y - snappedSize.height / 2
        let newComponentBottom = snappedPosition.y + snappedSize.height / 2
        let newComponentCenterX = snappedPosition.x
        let newComponentCenterY = snappedPosition.y
        if abs(snappedSize.width - (pageRight - pageLeft)) < snapDistance {
            snappedSize.width = pageRight - pageLeft
            snappedPosition.x = pageLeft + snappedSize.width / 2
            hasSnapped = true
        }
        if abs(snappedSize.height - (pageBottom - pageTop)) < snapDistance {
            snappedSize.height = pageBottom - pageTop
            snappedPosition.y = pageTop + snappedSize.height / 2
            hasSnapped = true
        }
        if abs(newComponentCenterX - pageCenterX) < snapDistance {
            snappedPosition.x = pageCenterX
            hasSnapped = true
        }
        if abs(newComponentCenterY - pageCenterY) < snapDistance {
            snappedPosition.y = pageCenterY
            hasSnapped = true
        }
        let topEdgeMidpointX = pageCenterX
        let topEdgeMidpointY = pageTop
        if abs(newComponentCenterX - topEdgeMidpointX) < snapDistance {
            snappedPosition.x = topEdgeMidpointX
            hasSnapped = true
        }
        if abs(newComponentCenterY - topEdgeMidpointY) < snapDistance {
            snappedPosition.y = topEdgeMidpointY
            hasSnapped = true
        }
        let bottomEdgeMidpointX = pageCenterX
        let bottomEdgeMidpointY = pageBottom
        if abs(newComponentCenterX - bottomEdgeMidpointX) < snapDistance {
            snappedPosition.x = bottomEdgeMidpointX
            hasSnapped = true
        }
        if abs(newComponentCenterY - bottomEdgeMidpointY) < snapDistance {
            snappedPosition.y = bottomEdgeMidpointY
            hasSnapped = true
        }
        let leftEdgeMidpointX = pageLeft
        let leftEdgeMidpointY = pageCenterY
        if abs(newComponentCenterX - leftEdgeMidpointX) < snapDistance {
            snappedPosition.x = leftEdgeMidpointX
            hasSnapped = true
        }
        if abs(newComponentCenterY - leftEdgeMidpointY) < snapDistance {
            snappedPosition.y = leftEdgeMidpointY
            hasSnapped = true
        }
        let rightEdgeMidpointX = pageRight
        let rightEdgeMidpointY = pageCenterY
        if abs(newComponentCenterX - rightEdgeMidpointX) < snapDistance {
            snappedPosition.x = rightEdgeMidpointX
            hasSnapped = true
        }
        if abs(newComponentCenterY - rightEdgeMidpointY) < snapDistance {
            snappedPosition.y = rightEdgeMidpointY
            hasSnapped = true
        }
        if abs(newComponentLeft - pageLeft) < snapDistance {
            let newWidth = newComponentRight - pageLeft
            if newWidth > 50 && newWidth < 800 {
                snappedSize.width = newWidth
                snappedPosition.x = pageLeft + snappedSize.width / 2
                hasSnapped = true
            }
        }
        if abs(newComponentRight - pageRight) < snapDistance {
            let newWidth = pageRight - newComponentLeft
            if newWidth > 50 && newWidth < 800 {
                snappedSize.width = newWidth
                snappedPosition.x = newComponentLeft + newWidth / 2
                hasSnapped = true
            }
        }
        if abs(newComponentTop - pageTop) < snapDistance {
            let newHeight = newComponentBottom - pageTop
            if newHeight > 30 && newHeight < 600 {
                snappedSize.height = newHeight
                snappedPosition.y = pageTop + newHeight / 2
                hasSnapped = true
            }
        }
        if abs(newComponentBottom - pageBottom) < snapDistance {
            let newHeight = pageBottom - newComponentTop
            if newHeight > 30 && newHeight < 600 {
                snappedSize.height = newHeight
                snappedPosition.y = newComponentTop + newHeight / 2
                hasSnapped = true
            }
        }
        if abs(newComponentLeft - marginLeft) < snapDistance {
            let newWidth = newComponentRight - marginLeft
            if newWidth > 50 && newWidth < 800 {
                snappedSize.width = newWidth
                snappedPosition.x = marginLeft + snappedSize.width / 2
                hasSnapped = true
            }
        }
        if abs(newComponentRight - marginRight) < snapDistance {
            let newWidth = marginRight - newComponentLeft
            if newWidth > 50 && newWidth < 800 {
                snappedSize.width = newWidth
                snappedPosition.x = newComponentLeft + newWidth / 2
                hasSnapped = true
            }
        }
        if abs(newComponentTop - marginTop) < snapDistance {
            let newHeight = newComponentBottom - marginTop
            if newHeight > 30 && newHeight < 600 {
                snappedSize.height = newHeight
                snappedPosition.y = marginTop + newHeight / 2
                hasSnapped = true
            }
        }
        if abs(newComponentBottom - marginBottom) < snapDistance {
            let newHeight = marginBottom - newComponentTop
            if newHeight > 30 && newHeight < 600 {
                snappedSize.height = newHeight
                snappedPosition.y = newComponentTop + newHeight / 2
                hasSnapped = true
            }
        }
        DispatchQueue.main.async { [weak self] in
            self?.isSnapping = hasSnapped
        }
        return (snappedSize, snappedPosition)
    }
}

