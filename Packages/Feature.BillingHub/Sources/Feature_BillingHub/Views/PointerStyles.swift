//
//  PointerStyles.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 16/9/2025.
//

import SwiftUI

#if os(macOS)
import AppKit
#endif

// Custom pointer styles backed by AppKit NSCursor images.
extension PointerStyle {
    /// An open-hand cursor indicating draggable, idle state.
    static var openHand: PointerStyle {
        #if os(macOS)
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

    /// A pointing-hand cursor indicating a primary-press/click interaction.
    static var pointingHand: PointerStyle {
        #if os(macOS)
        let cursor = NSCursor.pointingHand
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

// Conditional application helper to avoid forcing `.default`.
// (Removed conditional helper by request)
