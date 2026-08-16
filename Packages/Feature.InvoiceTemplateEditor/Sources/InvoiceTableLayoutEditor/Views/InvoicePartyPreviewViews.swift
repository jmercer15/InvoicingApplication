import SwiftUI

// MARK: - Party Preview Inspector Targets & Layout

struct PartyPreviewInspectorTargets {
  let name: InvoiceInspectorFocusTarget
  let address: InvoiceInspectorFocusTarget
  let phone: InvoiceInspectorFocusTarget
  let email: InvoiceInspectorFocusTarget
  let taxID: InvoiceInspectorFocusTarget
}

/// Lays out party cards at their intrinsic widths, then removes width from the
/// widest card first when the document column is too narrow. This preserves
/// compact cards without making every sibling wrap at the same time.
struct IntrinsicPartyRowLayout: Layout {
  let spacing: CGFloat
  var expandsToFillWidth = false

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache _: inout ()
  ) -> CGSize {
    let widths = allocatedWidths(for: subviews, availableWidth: proposal.width)
    let height = measuredHeight(for: subviews, widths: widths)
    let naturalWidth =
      subviews.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width }
      + spacing * CGFloat(max(subviews.count - 1, 0))
    return CGSize(width: proposal.width ?? naturalWidth, height: height)
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal _: ProposedViewSize,
    subviews: Subviews,
    cache _: inout ()
  ) {
    let widths = allocatedWidths(for: subviews, availableWidth: bounds.width)
    let rowHeight = bounds.height
    var x = bounds.minX
    for (subview, width) in zip(subviews, widths) {
      subview.place(
        at: CGPoint(x: x, y: bounds.minY),
        anchor: .topLeading,
        proposal: ProposedViewSize(width: width, height: rowHeight)
      )
      x += width + spacing
    }
  }

  private func measuredHeight(for subviews: Subviews, widths: [CGFloat]) -> CGFloat {
    zip(subviews, widths).map { subview, width in
      subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
    }.max() ?? 0
  }

  private func allocatedWidths(for subviews: Subviews, availableWidth: CGFloat?) -> [CGFloat] {
    var widths = subviews.map { $0.sizeThatFits(.unspecified).width }
    guard let availableWidth else { return widths }

    let targetWidth = max(0, availableWidth - spacing * CGFloat(max(subviews.count - 1, 0)))
    let allocatedWidth = widths.reduce(0, +)
    if expandsToFillWidth, allocatedWidth < targetWidth, !widths.isEmpty {
      let additionalWidth = (targetWidth - allocatedWidth) / CGFloat(widths.count)
      return widths.map { $0 + additionalWidth }
    }

    var overflow = allocatedWidth - targetWidth
    let minimumWidth = min(120, targetWidth / CGFloat(max(subviews.count, 1)))

    // Shrink the currently widest card before considering smaller siblings.
    while overflow > 0.5, let widestIndex = widths.indices.max(by: { widths[$0] < widths[$1] }) {
      let reducible = max(0, widths[widestIndex] - minimumWidth)
      guard reducible > 0 else { break }
      let reduction = min(overflow, reducible)
      widths[widestIndex] -= reduction
      overflow -= reduction
    }

    // At extremely small widths, share any remaining compression so the row
    // still honours the document width instead of overflowing its margins.
    if overflow > 0.5 {
      let total = widths.reduce(0, +)
      guard total > 0 else { return widths }
      let scale = max(0, (total - overflow) / total)
      widths = widths.map { $0 * scale }
    }
    return widths
  }
}

struct PartyPreviewBlock: View {
  @Environment(\.invoiceTheme) private var theme
  @Environment(\.invoiceDocumentStyle) private var documentStyle

  let title: String
  var profile: PartyPreviewProfile = .provider
  var name: String = ""
  var address: String = ""
  var phone: String = ""
  var email: String = ""
  var taxID: String = ""
  var showPhone: Bool = true
  var showEmail: Bool = true
  var showTaxID: Bool = true
  var density: InvoiceTypographyDensity = .default
  var typographyScale: CGFloat?
  var family: InvoiceFontFamilyPreset = .default
  var showsLabel: Bool = true
  var showsContactLabels: Bool = true
  var showsOutline: Bool = true
  var showsFill: Bool = true
  /// Stretches the banded card to match sibling column height in side-by-side rows.
  var expandsToFillHeight: Bool = false
  /// When false (side-by-side), the card hugs content width instead of sharing the row evenly.
  var expandsToFillWidth: Bool = true
  var inspectorTargets: PartyPreviewInspectorTargets?
  var inspectorInteraction: InvoicePreviewInspectorInteraction?

  private var resolvedTypographyScale: CGFloat {
    typographyScale ?? density.scale
  }

  private var bodyFont: Font {
    InvoiceDocumentDesign.bodyFont(scale: resolvedTypographyScale, family: family)
  }

  private var bodyEmphasisFont: Font {
    InvoiceDocumentDesign.bodyEmphasisFont(scale: resolvedTypographyScale, family: family)
  }

  private var metaFont: Font {
    InvoiceDocumentDesign.metaFont(scale: resolvedTypographyScale, family: family)
  }

  private var fieldLabelFont: Font {
    InvoiceDocumentDesign.metaLabelFont(scale: resolvedTypographyScale, family: family)
  }

  var body: some View {
    let card = DocumentBandedCard(
      label: title,
      style: partyStyle,
      showsHeaderBand: showsLabel,
      showsOutline: showsOutline,
      expandsToFillHeight: expandsToFillHeight,
      expandsToFillWidth: expandsToFillWidth,
      inspectorHeaderTarget: inspectorSectionTarget,
      inspectorInteraction: inspectorInteraction
    ) {
      VStack(
        alignment: .leading,
        spacing: InvoiceDocumentLayout.partyBlockTitleSpacing * documentStyle.spacingScale
      ) {
        partyNameText(name)
          .previewInspectorTargetIfPresent(
            inspectorTargets?.name, interaction: inspectorInteraction)
        details
      }
    }
    card
  }

  private var inspectorSectionTarget: InvoiceInspectorFocusTarget? {
    switch title {
    case "From": .from
    case "Billed To": .billedTo
    case "For": .recipient
    default: nil
    }
  }

  private var partyStyle: DocumentBandedCardStyle {
    let style = DocumentBandedCardStyle.party(theme: theme)
    guard !showsFill else { return style }
    return DocumentBandedCardStyle(
      bandFill: .clear,
      bodyFill: .clear,
      outline: style.outline,
      bandRule: style.bandRule
    )
  }

  @ViewBuilder
  private var details: some View {
    switch profile {
    case .provider:
      VStack(
        alignment: .leading,
        spacing: InvoiceDocumentLayout.compactRowSpacing * documentStyle.spacingScale
      ) {
        if !address.isEmpty {
          partyBodyText(address, lineLimit: 3)
            .previewInspectorTargetIfPresent(
              inspectorTargets?.address, interaction: inspectorInteraction)
        }
        contactGrid
      }
    case .participant:
      VStack(
        alignment: .leading,
        spacing: InvoiceDocumentLayout.compactRowSpacing * documentStyle.spacingScale
      ) {
        if !address.isEmpty {
          partyBodyText(address, lineLimit: 3)
            .previewInspectorTargetIfPresent(
              inspectorTargets?.address, interaction: inspectorInteraction)
        }
        contactGrid
      }
    case .billingContact:
      VStack(
        alignment: .leading,
        spacing: InvoiceDocumentLayout.compactRowSpacing * documentStyle.spacingScale
      ) {
        if !address.isEmpty {
          partyBodyText(address, lineLimit: 3)
            .previewInspectorTargetIfPresent(
              inspectorTargets?.address, interaction: inspectorInteraction)
        }
        contactGrid
      }
    }
  }

  /// Aligned label/value rows for the provider's phone, email, and ABN so the
  /// contact meta reads as a tidy mini-table rather than a loose list.
  /// Labels are trailing-aligned toward the values; values are leading-aligned.
  @ViewBuilder
  private var contactGrid: some View {
    let hasContact =
      (showPhone && !phone.isEmpty)
      || (showEmail && !email.isEmpty)
      || (showTaxID && !taxID.isEmpty)
    if hasContact, showsContactLabels {
      contactRowGrid {
        if showPhone, !phone.isEmpty {
          contactRow(label: "Phone", value: phone, target: inspectorTargets?.phone)
        }
        if showEmail, !email.isEmpty {
          contactRow(label: "Email", value: email, target: inspectorTargets?.email)
        }
        if showTaxID, !taxID.isEmpty {
          contactRow(label: taxIDLabel, value: taxID, target: inspectorTargets?.taxID)
        }
      }
    } else if hasContact {
      VStack(
        alignment: .leading,
        spacing: InvoiceDocumentLayout.compactRowSpacing * documentStyle.spacingScale
      ) {
        if showPhone, !phone.isEmpty { contactValue(phone, target: inspectorTargets?.phone) }
        if showEmail, !email.isEmpty { contactValue(email, target: inspectorTargets?.email) }
        if showTaxID, !taxID.isEmpty { contactValue(taxID, target: inspectorTargets?.taxID) }
      }
    }
  }

  private var taxIDLabel: String {
    switch profile {
    case .provider: "ABN"
    case .participant: "NDIS"
    case .billingContact: "Authority"
    }
  }

  private func contactRowGrid<Rows: View>(@ViewBuilder rows: () -> Rows) -> some View {
    Grid(alignment: .trailingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 2) {
      rows()
    }
  }

  private func contactRow(label: String, value: String, target: InvoiceInspectorFocusTarget?)
    -> some View
  {
    GridRow {
      Text(label)
        .font(fieldLabelFont.smallCaps())
        .foregroundStyle(theme.accentMuted)
        .tracking(0.4)
        .multilineTextAlignment(.trailing)
        .gridColumnAlignment(InvoiceDocumentDesign.labelValueLabelColumnAlignment)
      Text(value)
        .font(metaFont)
        .foregroundStyle(InvoiceDocumentDesign.ink)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: InvoiceDocumentDesign.labelValueValueAlignment)
        .gridColumnAlignment(InvoiceDocumentDesign.labelValueValueColumnAlignment)
    }
    .previewInspectorTargetIfPresent(target, interaction: inspectorInteraction)
  }

  private func contactValue(_ value: String, target: InvoiceInspectorFocusTarget?) -> some View {
    Text(value)
      .font(metaFont)
      .foregroundStyle(InvoiceDocumentDesign.ink)
      .lineLimit(2)
      .fixedSize(horizontal: false, vertical: true)
      .previewInspectorTargetIfPresent(target, interaction: inspectorInteraction)
  }

  private func partyNameText(_ text: String) -> some View {
    Text(text.isEmpty ? "—" : text)
      .font(bodyEmphasisFont)
      .foregroundStyle(text.isEmpty ? InvoiceDocumentDesign.inkFaint : InvoiceDocumentDesign.ink)
      .lineLimit(2)
      .fixedSize(horizontal: false, vertical: true)
  }

  private func partyBodyText(_ text: String, lineLimit: Int) -> some View {
    Text(text)
      .font(bodyFont)
      .foregroundStyle(InvoiceDocumentDesign.ink)
      .lineLimit(lineLimit)
      .fixedSize(horizontal: false, vertical: true)
  }
}
