//
//  PointerStyles.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 16/9/2025.
//

import SwiftUI
import Foundation

#if os(macOS)
import AppKit
#endif

enum BillingHubPreviewRuntime {
    static var isCanvasPreview: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
    }
}

// Custom pointer styles backed by AppKit NSCursor images.
extension PointerStyle {
    /// An open-hand cursor indicating draggable, idle state.
    static var openHand: PointerStyle {
        #if os(macOS)
        guard !BillingHubPreviewRuntime.isCanvasPreview else { return .default }
        let cursor = NSCursor.openHand
        let img = Image(nsImage: cursor.image)
        let size = cursor.image.size
        let hot = UnitPoint(
            x: size.width > 0 ? cursor.hotSpot.x / size.width : 0,
            y: size.height > 0 ? cursor.hotSpot.y / size.height : 0
        )
        return .image(img, hotSpot: hot)
        #else
        return .default
        #endif
    }

    /// A closed-hand cursor indicating active dragging.
    static var closedHand: PointerStyle {
        #if os(macOS)
        guard !BillingHubPreviewRuntime.isCanvasPreview else { return .default }
        let cursor = NSCursor.closedHand
        let img = Image(nsImage: cursor.image)
        let size = cursor.image.size
        let hot = UnitPoint(
            x: size.width > 0 ? cursor.hotSpot.x / size.width : 0,
            y: size.height > 0 ? cursor.hotSpot.y / size.height : 0
        )
        return .image(img, hotSpot: hot)
        #else
        return .default
        #endif
    }
}

extension View {
    @ViewBuilder
    func billingHubPointerStyle(_ style: PointerStyle) -> some View {
        if BillingHubPreviewRuntime.isCanvasPreview {
            self
        } else {
            pointerStyle(style)
        }
    }
}
