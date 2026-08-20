import CoreGraphics
import Foundation
import Observation
import SwiftUI

/// The preview publishes its settled fit scale here. Keeping this observation scope out of
/// `InvoiceEditorView` lets the toolbar refresh without invalidating the preview and inspector.
@Observable
@MainActor
final class InvoicePreviewViewportState {
  var fitScale: CGFloat = 1
}

/// Preserves invalid exact numeric text while inspector fields leave the view hierarchy.
/// Valid values continue flowing through typed bindings; only uncommitted invalid text lives here.
final class InvoiceNumericInputDraftStore {
  struct Entry: Equatable, Codable {
    let text: String
    let baseline: String
  }

  private var entries: [String: Entry] = [:]
  var onChange: ((String) -> Void)?

  var inputIDs: Set<String> { Set(entries.keys) }

  var encodedSnapshot: String {
    guard !entries.isEmpty,
      let data = try? JSONEncoder().encode(entries)
    else { return "" }
    return data.base64EncodedString()
  }

  func restore(from encodedSnapshot: String) {
    guard !encodedSnapshot.isEmpty,
      let data = Data(base64Encoded: encodedSnapshot),
      let restored = try? JSONDecoder().decode([String: Entry].self, from: data)
    else {
      entries.removeAll()
      return
    }
    entries = restored
  }

  func restoredText(for inputID: String, baseline: String) -> String? {
    guard let entry = entries[inputID] else { return nil }
    guard entry.baseline == baseline else {
      entries.removeValue(forKey: inputID)
      publishChange()
      return nil
    }
    return entry.text
  }

  func preserve(_ text: String, for inputID: String, baseline: String) {
    let entry = Entry(text: text, baseline: baseline)
    guard entries[inputID] != entry else { return }
    entries[inputID] = entry
    publishChange()
  }

  func clear(_ inputID: String) {
    guard entries.removeValue(forKey: inputID) != nil else { return }
    publishChange()
  }

  @discardableResult
  func clearAll() -> [String] {
    let inputIDs = Array(entries.keys)
    guard !inputIDs.isEmpty else { return [] }
    entries.removeAll()
    publishChange()
    return inputIDs
  }

  private func publishChange() {
    onChange?(encodedSnapshot)
  }
}

/// State shared by the editor detail and the inspector's Format tab.
@Observable
@MainActor
final class InvoiceEditorToolbarState {
  var zoom = InvoiceDocumentPreviewZoom()
  var viewport = InvoicePreviewViewportState()
  let numericInputDrafts: InvoiceNumericInputDraftStore
  private(set) var numericInputResetRevision = 0
  var showsDeleteConfirmation = false
  private(set) var addLineItemRequestRevision = 0
  private(set) var invalidTemplateInputRecoveryRequestRevision = 0

  init(numericInputDrafts: InvoiceNumericInputDraftStore = InvoiceNumericInputDraftStore()) {
    self.numericInputDrafts = numericInputDrafts
  }

  func requestAddLineItem() {
    addLineItemRequestRevision &+= 1
  }

  func requestInvalidTemplateInputRecovery() {
    invalidTemplateInputRecoveryRequestRevision &+= 1
  }

  @discardableResult
  func resetNumericInputDrafts() -> [String] {
    let inputIDs = numericInputDrafts.clearAll()
    numericInputResetRevision &+= 1
    return inputIDs
  }

  func resetNumericInputDraft(_ inputID: String) {
    numericInputDrafts.clear(inputID)
    numericInputResetRevision &+= 1
  }
}

/// Compact, inspector-safe preview controls shared by Template Format and Invoice Data modes.
/// Keeping one implementation prevents command availability and visible controls drifting apart.
struct InvoicePreviewZoomControls: View {
  @Bindable var toolbarState: InvoiceEditorToolbarState

  var body: some View {
    let percentLabel = toolbarState.zoom.percentLabel(fitScale: toolbarState.viewport.fitScale)

    HStack(spacing: 8) {
      Button("Zoom Out", systemImage: "minus.magnifyingglass") {
        toolbarState.zoom.zoomOut(relativeTo: toolbarState.viewport.fitScale)
      }
      .labelStyle(.iconOnly)
      .disabled(!toolbarState.zoom.canZoomOut(relativeTo: toolbarState.viewport.fitScale))
      .help("Zoom out")

      Text(percentLabel)
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(minWidth: 44)
        .accessibilityLabel("Preview zoom")
        .accessibilityValue(percentLabel)

      Button("Zoom In", systemImage: "plus.magnifyingglass") {
        toolbarState.zoom.zoomIn(relativeTo: toolbarState.viewport.fitScale)
      }
      .labelStyle(.iconOnly)
      .disabled(!toolbarState.zoom.canZoomIn(relativeTo: toolbarState.viewport.fitScale))
      .help("Zoom in")

      Menu("Preview Zoom", systemImage: "doc.viewfinder") {
        Button("Actual Size", systemImage: "1.magnifyingglass") {
          toolbarState.zoom.setActualSize()
        }
        .disabled(toolbarState.zoom.isActualSize(fitScale: toolbarState.viewport.fitScale))

        Button("Fit Width", systemImage: "arrow.left.and.right.square") {
          toolbarState.zoom.setFitWidth()
        }
        .disabled(toolbarState.zoom.isFitWidth)
      }
      .labelStyle(.iconOnly)
      .menuStyle(.borderlessButton)
      .help("Preview zoom options")
      .accessibilityLabel("Preview zoom options")
    }
    .accessibilityElement(children: .contain)
  }
}

/// Presentational zoom for the invoice document preview.
///
/// Zoom is a view transform only — it does not change paper size or pagination measurement.
struct InvoiceDocumentPreviewZoom: Equatable {
  static let minimumScale: CGFloat = 0.25
  static let maximumScale: CGFloat = 4.0
  /// Multiplicative step used by zoom in / zoom out controls.
  static let stepFactor: CGFloat = 1.25

  enum Mode: Equatable {
    /// Scale so the page width fits the available preview width (never above 100%).
    case fitWidth
    /// Absolute scale where `1.0` is actual paper size in points.
    case absolute(CGFloat)
  }

  var mode: Mode = .fitWidth

  static func clamp(_ scale: CGFloat) -> CGFloat {
    min(max(scale, minimumScale), maximumScale)
  }

  /// Keeps live-resize geometry from producing effectively identical task IDs
  /// and toolbar publications for subpixel scale differences.
  static func stabilizedFitScale(_ scale: CGFloat) -> CGFloat {
    guard scale.isFinite else { return 1 }
    return clamp((scale * 1_000).rounded() / 1_000)
  }

  /// Resolved display scale for the current viewport fit scale.
  func displayScale(fitScale: CGFloat) -> CGFloat {
    switch mode {
    case .fitWidth:
      return Self.clamp(fitScale)
    case .absolute(let scale):
      return Self.clamp(scale)
    }
  }

  mutating func zoomIn(relativeTo fitScale: CGFloat) {
    let current = displayScale(fitScale: fitScale)
    mode = .absolute(Self.clamp(current * Self.stepFactor))
  }

  mutating func zoomOut(relativeTo fitScale: CGFloat) {
    let current = displayScale(fitScale: fitScale)
    mode = .absolute(Self.clamp(current / Self.stepFactor))
  }

  mutating func setActualSize() {
    mode = .absolute(1)
  }

  mutating func setFitWidth() {
    mode = .fitWidth
  }

  /// Sets an absolute scale (clamped). Used by gestures and scroll-wheel zoom.
  mutating func setAbsoluteScale(_ scale: CGFloat) {
    mode = .absolute(Self.clamp(scale))
  }

  /// Applies a magnification gesture multiplier against a base scale captured at gesture start.
  mutating func applyMagnification(_ magnification: CGFloat, baseScale: CGFloat) {
    mode = .absolute(Self.clamp(baseScale * magnification))
  }

  /// Multiplies the current display scale by `factor` (e.g. from Command–scroll).
  mutating func multiplyScale(by factor: CGFloat, relativeTo fitScale: CGFloat) {
    guard factor.isFinite, factor > 0 else { return }
    let current = displayScale(fitScale: fitScale)
    mode = .absolute(Self.clamp(current * factor))
  }

  func percentLabel(fitScale: CGFloat) -> String {
    let percent = Int((displayScale(fitScale: fitScale) * 100).rounded())
    return "\(percent)%"
  }

  var isFitWidth: Bool {
    if case .fitWidth = mode { return true }
    return false
  }

  func isActualSize(fitScale: CGFloat) -> Bool {
    abs(displayScale(fitScale: fitScale) - 1) < 0.001
  }

  func canZoomIn(relativeTo fitScale: CGFloat) -> Bool {
    displayScale(fitScale: fitScale) < Self.maximumScale - 0.000_1
  }

  func canZoomOut(relativeTo fitScale: CGFloat) -> Bool {
    displayScale(fitScale: fitScale) > Self.minimumScale + 0.000_1
  }
}
