import AppKit
import SwiftUI

// MARK: - Command–scroll zoom (macOS)

/// Captures Command–scroll-wheel / Command–trackpad-scroll over the preview to adjust zoom.
struct PreviewCommandScrollZoomMonitor: NSViewRepresentable {
  var onZoomFactor: (CGFloat) -> Void

  func makeNSView(context _: Context) -> PreviewZoomScrollCatcherView {
    let view = PreviewZoomScrollCatcherView()
    view.onZoomFactor = onZoomFactor
    return view
  }

  func updateNSView(_ nsView: PreviewZoomScrollCatcherView, context _: Context) {
    nsView.onZoomFactor = onZoomFactor
  }
}

final class PreviewZoomScrollCatcherView: NSView {
  var onZoomFactor: ((CGFloat) -> Void)?
  private var monitor: Any?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window != nil {
      installMonitor()
    } else {
      removeMonitor()
    }
  }

  private func installMonitor() {
    removeMonitor()
    monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
      guard let self else { return event }
      guard event.modifierFlags.contains(.command) else { return event }
      guard self.isMouseInside(event) else { return event }

      // Positive scrollingDeltaY (scroll up) zooms in.
      let factor = pow(1.015, event.scrollingDeltaY)
      guard factor.isFinite, abs(factor - 1) > 0.000_1 else { return nil }
      self.onZoomFactor?(factor)
      return nil
    }
  }

  private func removeMonitor() {
    if let monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }
  }

  private func isMouseInside(_ event: NSEvent) -> Bool {
    guard let window else { return false }
    let eventWindow = event.window ?? window
    guard eventWindow === window else { return false }
    let locationInWindow = event.locationInWindow
    // Hit-test the SwiftUI host that fills the preview area.
    let hostBounds = superview?.bounds ?? bounds
    let locationInHost =
      superview?.convert(locationInWindow, from: nil)
      ?? convert(locationInWindow, from: nil)
    return hostBounds.contains(locationInHost)
  }
}
