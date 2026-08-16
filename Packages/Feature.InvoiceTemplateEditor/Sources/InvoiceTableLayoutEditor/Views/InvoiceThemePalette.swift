import Core
import CoreGraphics
import Foundation
import SharedUI
import SwiftUI

/// Resolved accent-derived colors for a single invoice document render pass.
struct InvoiceThemePalette: Equatable {
  let accent: Color
  /// Whether black content yields greater contrast than white on the accent banner.
  let usesDarkOnAccentContent: Bool

  init(accent: Color, usesDarkOnAccentContent: Bool = false) {
    self.accent = accent
    self.usesDarkOnAccentContent = usesDarkOnAccentContent
  }

  init(customAccentColor: InvoiceCustomAccentColor) {
    self.init(
      accent: Color(
        red: customAccentColor.red,
        green: customAccentColor.green,
        blue: customAccentColor.blue,
        opacity: customAccentColor.opacity
      ),
      usesDarkOnAccentContent: Self.prefersDarkContent(on: customAccentColor)
    )
  }

  static let `default` = InvoiceAccentTheme.default.palette

  var accentMuted: Color {
    accent.opacity(0.72)
  }

  var accentEmphasisTint: Color {
    accent.opacity(0.09)
  }

  /// Stronger tint behind line-items column headers (ruled table style).
  var tableHeaderFill: Color {
    accent.opacity(0.12)
  }

  var partyBandFill: Color {
    accent.opacity(0.08)
  }

  var partyCardOutline: Color {
    accent.opacity(0.22)
  }

  var partyBandRule: Color {
    accent.opacity(0.22)
  }

  var paymentBandFill: Color {
    accent.opacity(0.11)
  }

  var paymentCardOutline: Color {
    accent.opacity(0.42)
  }

  var paymentBandRule: Color {
    accent.opacity(0.42)
  }

  var paymentRowRule: Color {
    accent.opacity(0.14)
  }

  var bannerFill: Color {
    accent
  }

  /// Text and strokes on the printable accent banner always use the higher-contrast
  /// of opaque black and white. This matters most for arbitrary user-selected accents:
  /// partially transparent small text can fall below macOS's 4.5:1 contrast target,
  /// even when the underlying black-or-white choice is correct.
  var onAccentText: Color {
    usesDarkOnAccentContent ? .black : .white
  }

  /// Keep secondary accent-banner text at the same contrast-safe foreground tone.
  /// Hierarchy comes from its native font role and supporting placement, rather than
  /// a transparency reduction that can make custom-accent text illegible.
  var onAccentTextMuted: Color {
    onAccentText
  }

  var onAccentStroke: Color {
    usesDarkOnAccentContent ? .black.opacity(0.42) : .white.opacity(0.5)
  }

  var onAccentSurface: Color {
    usesDarkOnAccentContent ? .black.opacity(0.08) : .white.opacity(0.12)
  }

  var headerFill: Color {
    tableHeaderFill
  }

  var emphasisFill: Color {
    accentEmphasisTint
  }

  var detailsGridLineColor: Color {
    accent.opacity(0.35)
  }

  var detailsOuterBorderColor: Color {
    accent.opacity(0.5)
  }

  private static func prefersDarkContent(on color: InvoiceCustomAccentColor) -> Bool {
    // The document banner prints over a white page. Composite a translucent
    // custom color over that page before comparing standard WCAG contrast ratios.
    let alpha = color.opacity.clamped(to: 0...1)
    let red = color.red * alpha + (1 - alpha)
    let green = color.green * alpha + (1 - alpha)
    let blue = color.blue * alpha + (1 - alpha)
    let luminance =
      0.2126 * linearized(red)
      + 0.7152 * linearized(green)
      + 0.0722 * linearized(blue)
    let whiteContrast = 1.05 / (luminance + 0.05)
    let blackContrast = (luminance + 0.05) / 0.05
    return blackContrast > whiteContrast
  }

  private static func linearized(_ component: Double) -> Double {
    let value = component.clamped(to: 0...1)
    return value <= 0.04045
      ? value / 12.92
      : pow((value + 0.055) / 1.055, 2.4)
  }
}
extension Double {
  fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
    min(max(self, range.lowerBound), range.upperBound)
  }
}

extension InvoiceAccentTheme {
  var palette: InvoiceThemePalette {
    InvoiceThemePalette(accent: accentColor)
  }
}

private struct InvoiceThemeKey: EnvironmentKey {
  static let defaultValue = InvoiceThemePalette.default
}

struct InvoiceDocumentResolvedStyle: Equatable {
  var typographyScale: CGFloat
  var spacingScale: CGFloat
  /// Baseline stroke used by details tables and banded cards.
  var borderWidth: CGFloat

  var lineItemsBorderWidth: CGFloat {
    max(0.1, borderWidth * 0.5)
  }

  var detailsBorderWidth: CGFloat {
    max(0.1, borderWidth)
  }

  var bandedCardBorderWidth: CGFloat {
    max(0.1, borderWidth)
  }

  static let `default` = InvoiceDocumentResolvedStyle(
    typographyScale: InvoiceTypographyDensity.default.scale,
    spacingScale: InvoiceDocumentSpacingPreset.default.scale,
    borderWidth: InvoiceBorderWeight.default.detailsBorderWidth
  )
}

private struct InvoiceDocumentResolvedStyleKey: EnvironmentKey {
  static let defaultValue = InvoiceDocumentResolvedStyle.default
}

struct InvoiceTablePresentation: Equatable {
  var showsGridLines: Bool = true
  var showsZebraRows: Bool = true
  var showsHeaderFill: Bool = true
  var showsTotalsFill: Bool = true
}

private struct InvoiceTablePresentationKey: EnvironmentKey {
  static let defaultValue = InvoiceTablePresentation()
}

extension EnvironmentValues {
  var invoiceTheme: InvoiceThemePalette {
    get { self[InvoiceThemeKey.self] }
    set { self[InvoiceThemeKey.self] = newValue }
  }

  var invoiceDocumentStyle: InvoiceDocumentResolvedStyle {
    get { self[InvoiceDocumentResolvedStyleKey.self] }
    set { self[InvoiceDocumentResolvedStyleKey.self] = newValue }
  }

  var invoiceTablePresentation: InvoiceTablePresentation {
    get { self[InvoiceTablePresentationKey.self] }
    set { self[InvoiceTablePresentationKey.self] = newValue }
  }
}

extension View {
  func resolvedInvoiceFont(_ role: ResolvedInvoiceFontRole) -> some View {
    modifier(ResolvedInvoiceFontModifier(role: role))
  }

  func invoiceTheme(_ palette: InvoiceThemePalette) -> some View {
    environment(\.invoiceTheme, palette)
  }

  func invoiceTableStyle(_ style: InvoiceTableStyle) -> some View {
    environment(\.invoiceTableStyle, style)
  }

  func invoiceFontFamily(_ family: InvoiceFontFamilyPreset) -> some View {
    environment(\.invoiceFontFamily, family)
  }

  func invoiceBorderWeight(_ weight: InvoiceBorderWeight) -> some View {
    environment(\.invoiceBorderWeight, weight)
  }

  func invoiceTemplateAppearance(
    theme: InvoiceThemePalette,
    tableStyle: InvoiceTableStyle,
    fontFamily: InvoiceFontFamilyPreset,
    borderWeight: InvoiceBorderWeight = .default,
    tablePresentation: InvoiceTablePresentation = .init(),
    resolvedStyle: InvoiceDocumentResolvedStyle = .default
  ) -> some View {
    invoiceTheme(theme)
      .invoiceTableStyle(tableStyle)
      .invoiceFontFamily(fontFamily)
      .invoiceBorderWeight(borderWeight)
      .environment(\.invoiceTablePresentation, tablePresentation)
      .environment(\.invoiceDocumentStyle, resolvedStyle)
  }
}

enum ResolvedInvoiceFontRole {
  case body, emphasis, meta, fieldLabel
}

private struct ResolvedInvoiceFontModifier: ViewModifier {
  @Environment(\.invoiceDocumentStyle) private var style
  @Environment(\.invoiceFontFamily) private var family
  let role: ResolvedInvoiceFontRole

  func body(content: Content) -> some View {
    content.font(font)
  }

  private var font: Font {
    switch role {
    case .body: InvoiceDocumentDesign.bodyFont(scale: style.typographyScale, family: family)
    case .emphasis:
      InvoiceDocumentDesign.bodyEmphasisFont(scale: style.typographyScale, family: family)
    case .meta: InvoiceDocumentDesign.metaFont(scale: style.typographyScale, family: family)
    case .fieldLabel:
      InvoiceDocumentDesign.metaLabelFont(scale: style.typographyScale, family: family)
    }
  }
}
