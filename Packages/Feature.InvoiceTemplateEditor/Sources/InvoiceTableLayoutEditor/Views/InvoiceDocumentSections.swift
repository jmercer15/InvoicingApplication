import SwiftUI

enum InvoiceDocumentLayout {
  static let sectionSpacing: CGFloat = 12
  static let lineItemsTitleSpacing: CGFloat = 7
  static let compactRowSpacing: CGFloat = 3
  static let compactBlockSpacing: CGFloat = 7
  /// Top padding above the line items table after the document header/parties block.
  static let lineItemsTopPadding: CGFloat = 12
  static let footerSpacing: CGFloat = 7
  static let footerRowSpacing: CGFloat = 3
  static let partyBlockTitleSpacing: CGFloat = 4
  /// Horizontal gap between party columns (From | Billed To | For) on wide layouts.
  static let partyColumnSpacing: CGFloat = 14
  static func sectionSpacing(scale: CGFloat) -> CGFloat {
    (sectionSpacing * scale).rounded(.toNearestOrAwayFromZero)
  }

  static func lineItemsTitleSpacing(scale: CGFloat) -> CGFloat {
    (lineItemsTitleSpacing * scale).rounded(.toNearestOrAwayFromZero)
  }

  static func compactBlockSpacing(scale: CGFloat) -> CGFloat {
    (compactBlockSpacing * scale).rounded(.toNearestOrAwayFromZero)
  }

  static func lineItemsTopPadding(scale: CGFloat) -> CGFloat {
    (lineItemsTopPadding * scale).rounded(.toNearestOrAwayFromZero)
  }

  static func footerSpacing(scale: CGFloat) -> CGFloat {
    (footerSpacing * scale).rounded(.toNearestOrAwayFromZero)
  }

  static func partyColumnSpacing(scale: CGFloat) -> CGFloat {
    (partyColumnSpacing * scale).rounded(.toNearestOrAwayFromZero)
  }

}

/// Which provider/participant fields appear on an NDIS-compliant invoice document.
enum PartyPreviewProfile {
  /// Provider: business name, address, contact details, ABN.
  case provider
  /// Participant: name and NDIS number only.
  case participant
  /// Invoice recipient when plan-managed (name and email).
  case billingContact
}

/// Shared invoice document sections used by the preview and pagination measurement.
@MainActor
enum InvoiceDocumentSections {
  // MARK: - Header & parties

  @ViewBuilder
  static func documentHeader(
    viewModel: InvoiceEditorViewModel,
    contentWidth: CGFloat,
    bleed: CGFloat = 0,
    margin: CGFloat = 0,
    inspectorInteraction: InvoicePreviewInspectorInteraction? = nil
  ) -> some View {
    switch viewModel.headerStyle {
    case .fullBleed:
      fullBleedDocumentHeader(
        viewModel: viewModel,
        contentWidth: contentWidth,
        bleed: bleed,
        margin: margin,
        inspectorInteraction: inspectorInteraction
      )
    case .compact:
      compactDocumentHeader(
        viewModel: viewModel,
        contentWidth: contentWidth,
        margin: margin,
        inspectorInteraction: inspectorInteraction
      )
    }
  }

  @ViewBuilder
  private static func fullBleedDocumentHeader(
    viewModel: InvoiceEditorViewModel,
    contentWidth: CGFloat,
    bleed: CGFloat,
    margin: CGFloat,
    inspectorInteraction: InvoicePreviewInspectorInteraction?
  ) -> some View {
    let sideBySide = viewModel.partyLayout.usesSideBySide(contentWidth: contentWidth)
    // On the wide (trailing) layout the details table bleeds its white cell
    // surface past the content margin to the physical right page edge, so it
    // must extend by the banner's horizontal inset plus the page margin
    // (`bleed`). Only bleed when there is a real margin (bleed > 0); the
    // pagination measurer renders with bleed == 0 and stays content-hugging.
    let detailsTrailingBleed =
      (sideBySide && bleed > 0)
      ? bleed + InvoiceDocumentDesign.bannerPaddingHorizontal
      : 0
    let invoiceDetailsBlock = invoiceDetailsBlock(
      for: viewModel,
      contentWidth: contentWidth,
      trailingBleed: detailsTrailingBleed,
      inspectorInteraction: inspectorInteraction
    )
    // Square corners on all four edges so the banner reads as a crisp,
    // full-bleed block against the page edges and document content.
    let bannerShape = Rectangle()

    // Full-width banner: title (leading) + invoice details (trailing) on a
    // solid teal fill. On narrow paper the title stacks above the details;
    // the banner still spans the full content width.
    Group {
      if sideBySide {
        // The title frame flexes to fill the leading region so it can
        // scale up as large as fits; the content-hugging details table
        // stays pinned trailing (no flexible Spacer competing for width).
        HStack(
          alignment: .center,
          spacing: InvoiceDocumentLayout.partyColumnSpacing(
            scale: viewModel.resolvedDocumentStyle.spacingScale)
        ) {
          headerLeadingCluster(
            viewModel: viewModel,
            wide: true,
            margin: margin,
            onAccent: true,
            showsTitleUnderline: viewModel.showTitleUnderline
          )
          .previewInspectorTargetIfPresent(.header, interaction: inspectorInteraction)
          if viewModel.logoPlacement == .trailing {
            businessMark(
              sellerName: viewModel.sellerName,
              onAccent: true,
              theme: viewModel.themePalette
            )
          }
          invoiceDetailsBlock
        }
      } else {
        VStack(alignment: .leading, spacing: 0) {
          headerLeadingCluster(
            viewModel: viewModel,
            wide: false,
            margin: margin,
            onAccent: true,
            showsTitleUnderline: viewModel.showTitleUnderline
          )
          .previewInspectorTargetIfPresent(.header, interaction: inspectorInteraction)
          if viewModel.logoPlacement == .trailing {
            businessMark(
              sellerName: viewModel.sellerName,
              onAccent: true,
              theme: viewModel.themePalette
            )
              .padding(
                .top,
                InvoiceDocumentLayout.compactBlockSpacing(
                  scale: viewModel.resolvedDocumentStyle.spacingScale) / 2)
          }
          invoiceDetailsBlock
        }
      }
    }
    .padding(.horizontal, InvoiceDocumentDesign.bannerPaddingHorizontal)
    .padding(.vertical, InvoiceDocumentDesign.bannerPaddingVertical)
    .frame(maxWidth: .infinity, alignment: .leading)
    // Breathing room below the title/details before the banner's bottom edge,
    // equal to half the page margin. Applied inside the background so the solid
    // teal fill extends down to cover it. `margin` is passed identically by the
    // preview and the pagination measurer so measured and rendered heights match.
    .padding(.bottom, margin / 2)
    // The fill bleeds past the page margins to the page edges (left, right,
    // and top) via negative padding equal to `bleed` (the page margin). This
    // only expands the drawn background — the header keeps its content-width
    // layout size, so measured height and content alignment are unaffected.
    .background {
      bannerShape
        .fill(viewModel.themePalette.bannerFill)
        .padding(.horizontal, -bleed)
        .padding(.top, -bleed)
    }
  }

  @ViewBuilder
  private static func compactDocumentHeader(
    viewModel: InvoiceEditorViewModel,
    contentWidth: CGFloat,
    margin: CGFloat,
    inspectorInteraction: InvoicePreviewInspectorInteraction?
  ) -> some View {
    let sideBySide = viewModel.partyLayout.usesSideBySide(contentWidth: contentWidth)
    let invoiceDetailsBlock = invoiceDetailsBlock(
      for: viewModel,
      contentWidth: contentWidth,
      trailingBleed: 0,
      inspectorInteraction: inspectorInteraction
    )

    Group {
      if sideBySide {
        HStack(
          alignment: .top,
          spacing: InvoiceDocumentLayout.partyColumnSpacing(
            scale: viewModel.resolvedDocumentStyle.spacingScale)
        ) {
          headerLeadingCluster(
            viewModel: viewModel,
            wide: true,
            margin: margin,
            onAccent: false,
            showsTitleUnderline: viewModel.showTitleUnderline
          )
          .previewInspectorTargetIfPresent(.header, interaction: inspectorInteraction)
          if viewModel.logoPlacement == .trailing {
            businessMark(
              sellerName: viewModel.sellerName,
              onAccent: false,
              theme: viewModel.themePalette
            )
          }
          invoiceDetailsBlock
        }
      } else {
        VStack(
          alignment: .leading,
          spacing: InvoiceDocumentLayout.compactBlockSpacing(
            scale: viewModel.resolvedDocumentStyle.spacingScale)
        ) {
          headerLeadingCluster(
            viewModel: viewModel,
            wide: false,
            margin: 0,
            onAccent: false,
            showsTitleUnderline: viewModel.showTitleUnderline
          )
          .previewInspectorTargetIfPresent(.header, interaction: inspectorInteraction)
          if viewModel.logoPlacement == .trailing {
            businessMark(
              sellerName: viewModel.sellerName,
              onAccent: false,
              theme: viewModel.themePalette
            )
          }
          invoiceDetailsBlock
        }
      }
    }
    .padding(
      .bottom,
      InvoiceDocumentLayout.compactBlockSpacing(scale: viewModel.resolvedDocumentStyle.spacingScale)
        / 2)
  }

  /// Title and optional leading logo for the document header.
  private static func headerLeadingCluster(
    viewModel: InvoiceEditorViewModel,
    wide: Bool,
    margin: CGFloat,
    onAccent: Bool,
    showsTitleUnderline: Bool
  ) -> some View {
    HStack(alignment: .center, spacing: 10) {
      if viewModel.logoPlacement == .leading {
        businessMark(
          sellerName: viewModel.sellerName,
          onAccent: onAccent,
          theme: viewModel.themePalette
        )
      }
      if viewModel.showTitleOnDocument {
        previewTitle(
          viewModel.title,
          wide: wide,
          margin: margin,
          density: viewModel.typographyDensity,
          typographyScale: viewModel.resolvedDocumentStyle.typographyScale,
          family: viewModel.fontFamily,
          onAccent: onAccent,
          theme: viewModel.themePalette
        )
        .modifier(
          DocumentTitleUnderlineIfNeeded(
            onAccent: onAccent,
            showsUnderline: showsTitleUnderline,
            theme: viewModel.themePalette
          ))
      } else if viewModel.logoPlacement != .leading {
        Spacer(minLength: 0)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// Printable business monogram. Uses seller data already present in both mock and real invoices.
  @ViewBuilder
  private static func businessMark(
    sellerName: String,
    onAccent: Bool,
    theme: InvoiceThemePalette
  ) -> some View {
    let stroke =
      onAccent
      ? theme.onAccentStroke
      : InvoiceDocumentDesign.strokeStrong
    let fill =
      onAccent
      ? theme.onAccentSurface
      : InvoiceDocumentDesign.panelFill
    let labelColor =
      onAccent
      ? theme.onAccentTextMuted
      : InvoiceDocumentDesign.inkMuted

    let initials = InvoiceBrandMark.initials(for: sellerName)

    Text(initials)
      .font(.system(size: 14, weight: .bold, design: .rounded))
      .tracking(0.6)
      .foregroundStyle(labelColor)
      .frame(width: 48, height: 40)
      .background(fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(stroke, lineWidth: 1)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Business mark, \(initials)")
  }

  @ViewBuilder
  private static func previewTitle(
    _ title: String,
    wide: Bool,
    margin: CGFloat = 0,
    density: InvoiceTypographyDensity = .default,
    typographyScale: CGFloat? = nil,
    family: InvoiceFontFamilyPreset = .default,
    onAccent: Bool,
    theme: InvoiceThemePalette
  ) -> some View {
    let displayTitle = title.isEmpty ? "Tax Invoice" : title
    // Dynamic fill: start from a large base font and let `minimumScaleFactor`
    // shrink it to fit the available width on a single line. `lineLimit(1)`
    // keeps the vertical footprint the (deterministic) single-line height so
    // the pagination measurer and the preview — which both render at the same
    // `contentWidth` — report identical header heights. The flexible frame
    // hands the title all the leading space so it grows as large as possible.
    Text(displayTitle)
      .font(
        InvoiceDocumentDesign.documentTitleFont(
          wide: wide, scale: typographyScale ?? density.scale, family: family)
      )
      .tracking(InvoiceDocumentDesign.titleTracking)
      .foregroundStyle(
        onAccent
          ? (title.isEmpty ? theme.onAccentTextMuted : theme.onAccentText)
          : (title.isEmpty ? InvoiceDocumentDesign.inkFaint : InvoiceDocumentDesign.ink)
      )
      .lineLimit(1)
      .minimumScaleFactor(InvoiceDocumentDesign.titleMinimumScaleFactor)
      .frame(maxWidth: .infinity, alignment: .leading)
      // Breathing room between the title and the invoice details table (wide
      // layout) or the right content edge / details below (narrow layout),
      // equal to the page margin. `margin` is passed identically by the
      // preview and the pagination measurer so the reduced width the title
      // scales within is measured and rendered consistently.
      .padding(.trailing, margin)
  }

  @ViewBuilder
  private static func invoiceDetailsBlock(
    for viewModel: InvoiceEditorViewModel,
    contentWidth: CGFloat,
    trailingBleed: CGFloat = 0,
    inspectorInteraction: InvoicePreviewInspectorInteraction? = nil
  ) -> some View {
    let showsDetails =
      viewModel.showInvoiceNumberOnDocument
      || viewModel.showIssueDateOnDocument
      || viewModel.showDueDateOnDocument
    if showsDetails {
      InvoiceDetailsPreviewBlock(
        invoiceNumber: viewModel.invoiceNumber,
        issueDate: viewModel.issueDate,
        dueDate: viewModel.dueDate,
        showInvoiceNumber: viewModel.showInvoiceNumberOnDocument,
        showIssueDate: viewModel.showIssueDateOnDocument,
        showDueDate: viewModel.showDueDateOnDocument,
        dateFormatStyle: viewModel.dateFormatStyle,
        alignsTrailing: viewModel.partyLayout.usesSideBySide(contentWidth: contentWidth),
        trailingBleed: trailingBleed,
        showsOutline: viewModel.showInvoiceDetailsBorders,
        showsLabels: viewModel.showInvoiceDetailLabels,
        showsGridLines: viewModel.showInvoiceDetailGridLines,
        inspectorInteraction: inspectorInteraction
      )
    }
  }

  static func lineItemsSectionTitle() -> some View {
    LineItemsSectionTitleView()
  }

  @ViewBuilder
  static func parties(
    viewModel: InvoiceEditorViewModel,
    contentWidth: CGFloat,
    inspectorInteraction: InvoicePreviewInspectorInteraction? = nil
  ) -> some View {
    let sideBySide = viewModel.partyLayout.usesSideBySide(contentWidth: contentWidth)
    let spacingScale = viewModel.resolvedDocumentStyle.spacingScale
    // The custom row measures each card at its allocated width, then gives
    // every card the tallest resulting intrinsic height—never the parent’s
    // available height.
    let equalizePartyHeights = sideBySide

    // Side-by-side: hug each card's content width.
    // Stacked: fill the content column width; keep intrinsic heights.
    let expandsPartyWidth = !sideBySide

    let fromBlock = PartyPreviewBlock(
      title: "From",
      profile: .provider,
      name: viewModel.sellerName,
      address: viewModel.sellerAddress,
      phone: viewModel.sellerPhone,
      email: viewModel.sellerEmail,
      taxID: viewModel.sellerTaxID,
      showPhone: viewModel.showProviderPhone,
      showEmail: viewModel.showProviderEmail,
      showTaxID: viewModel.showProviderTaxID,
      density: viewModel.typographyDensity,
      typographyScale: viewModel.resolvedDocumentStyle.typographyScale,
      family: viewModel.fontFamily,
      showsLabel: viewModel.showPartyLabels,
      showsContactLabels: viewModel.showPartyContactLabels,
      showsOutline: viewModel.showPartyCardBorders,
      showsFill: viewModel.showPartyCardFill,
      expandsToFillHeight: equalizePartyHeights,
      expandsToFillWidth: expandsPartyWidth,
      inspectorTargets: .init(
        name: .sellerName, address: .sellerAddress, phone: .sellerPhone,
        email: .sellerEmail, taxID: .sellerTaxID
      ),
      inspectorInteraction: inspectorInteraction
    )

    let forBlock = PartyPreviewBlock(
      title: "For",
      profile: .participant,
      name: viewModel.clientName,
      taxID: viewModel.clientTaxID,
      density: viewModel.typographyDensity,
      typographyScale: viewModel.resolvedDocumentStyle.typographyScale,
      family: viewModel.fontFamily,
      showsLabel: viewModel.showPartyLabels,
      showsContactLabels: viewModel.showPartyContactLabels,
      showsOutline: viewModel.showPartyCardBorders,
      showsFill: viewModel.showPartyCardFill,
      expandsToFillHeight: equalizePartyHeights,
      expandsToFillWidth: expandsPartyWidth,
      inspectorTargets: .init(
        name: .clientName, address: .clientAddress, phone: .clientPhone,
        email: .clientEmail, taxID: .clientTaxID
      ),
      inspectorInteraction: inspectorInteraction
    )

    let showsFor = InvoiceParticipantVisibility.showsParticipantSection(
      billParticipantDirectly: viewModel.billParticipantDirectly,
      showParticipantSection: viewModel.showParticipantSection
    )
    let billedToName =
      viewModel.billParticipantDirectly
      ? viewModel.clientName
      : viewModel.billToName
    let billedToEmail =
      viewModel.billParticipantDirectly
      ? viewModel.clientEmail
      : viewModel.billToEmail
    let billedToAddress =
      viewModel.billParticipantDirectly
      ? viewModel.clientAddress
      : viewModel.billToAddress
    let billedToPhone =
      viewModel.billParticipantDirectly
      ? viewModel.clientPhone
      : viewModel.billToPhone
    let billedToTaxID =
      viewModel.billParticipantDirectly
      ? viewModel.clientTaxID
      : viewModel.billingAuthority
    let billedToBlock = PartyPreviewBlock(
      title: "Billed To",
      profile: .billingContact,
      name: billedToName,
      address: billedToAddress,
      phone: billedToPhone,
      email: billedToEmail,
      taxID: billedToTaxID,
      density: viewModel.typographyDensity,
      typographyScale: viewModel.resolvedDocumentStyle.typographyScale,
      family: viewModel.fontFamily,
      showsLabel: viewModel.showPartyLabels,
      showsContactLabels: viewModel.showPartyContactLabels,
      showsOutline: viewModel.showPartyCardBorders,
      showsFill: viewModel.showPartyCardFill,
      expandsToFillHeight: equalizePartyHeights,
      expandsToFillWidth: expandsPartyWidth,
      inspectorTargets: viewModel.billParticipantDirectly
        ? .init(
          name: .clientName, address: .clientAddress, phone: .clientPhone, email: .clientEmail,
          taxID: .clientTaxID)
        : .init(
          name: .billToName, address: .billToAddress, phone: .billToPhone, email: .billToEmail,
          taxID: .billingAuthority),
      inspectorInteraction: inspectorInteraction
    )

    VStack(
      alignment: .leading,
      spacing: InvoiceDocumentLayout.compactBlockSpacing(
        scale: viewModel.resolvedDocumentStyle.spacingScale)
    ) {
      if sideBySide {
        if showsFor {
          partyThreeColumnRow(
            from: fromBlock,
            for: forBlock,
            billedTo: billedToBlock,
            spacingScale: spacingScale
          )
        } else {
          partyTwoColumnRow(
            from: fromBlock,
            billedTo: billedToBlock,
            spacingScale: spacingScale
          )
        }
      } else {
        partyStackedColumn(
          from: fromBlock,
          for: showsFor ? forBlock : nil,
          billedTo: billedToBlock,
          spacingScale: spacingScale
        )
      }
    }
    // The party cards are document content, so their combined width must
    // never extend into the page margins. This explicit proposal also keeps
    // preview rendering and pagination measurement in agreement.
    .frame(width: contentWidth, alignment: .leading)
  }

  /// From | Billed To on wide paper when the For section is hidden.
  /// Content-hugging columns. The parent proposes the document width, so text
  /// wraps only when the cards' combined intrinsic widths no longer fit.
  @ViewBuilder
  private static func partyTwoColumnRow(
    from fromBlock: PartyPreviewBlock,
    billedTo billedToBlock: PartyPreviewBlock,
    spacingScale: CGFloat
  ) -> some View {
    let gap = InvoiceDocumentLayout.partyColumnSpacing(scale: spacingScale)
    IntrinsicPartyRowLayout(spacing: gap) {
      equalHeightPartyColumn(fromBlock)
      equalHeightPartyColumn(billedToBlock)
    }
  }

  /// Content-hugging columns that retain their natural widths until they need
  /// to compress within the document content width.
  @ViewBuilder
  private static func partyThreeColumnRow(
    from fromBlock: PartyPreviewBlock,
    for forBlock: PartyPreviewBlock,
    billedTo billedToBlock: PartyPreviewBlock,
    spacingScale: CGFloat
  ) -> some View {
    let gap = InvoiceDocumentLayout.partyColumnSpacing(scale: spacingScale)
    IntrinsicPartyRowLayout(spacing: gap) {
      equalHeightPartyColumn(fromBlock)
      equalHeightPartyColumn(billedToBlock)
      equalHeightPartyColumn(forBlock)
    }
  }

  /// Keeps its intrinsic width when space permits, but accepts a narrower
  /// proposal from the row so its text can wrap under pressure.
  private static func equalHeightPartyColumn(_ block: PartyPreviewBlock) -> some View {
    block
  }

  /// Stacked From / Billed To / For on narrow paper (A5).
  private static func partyStackedColumn(
    from fromBlock: PartyPreviewBlock,
    for forBlock: PartyPreviewBlock?,
    billedTo billedToBlock: PartyPreviewBlock,
    spacingScale: CGFloat
  ) -> some View {
    VStack(
      alignment: .leading, spacing: InvoiceDocumentLayout.compactBlockSpacing(scale: spacingScale)
    ) {
      fromBlock
      billedToBlock
      if let forBlock {
        forBlock
      }
    }
  }

  // MARK: - Totals & footer

  /// Totals rows for the unified line-items preview grid (Date | Description | Qty | Unit | Rate | Total).
  @ViewBuilder
  static func totalsGridRows(
    viewModel: InvoiceEditorViewModel,
    columnWidths: LineItemTableColumnWidths,
    descriptionColumnWidth: CGFloat,
    rowHeight: CGFloat,
    inspectorInteraction: InvoicePreviewInspectorInteraction? = nil
  ) -> some View {
    let emphasis = viewModel.totalsEmphasis
    let amountFont: Font =
      emphasis.usesCompactType
      ? InvoiceDocumentDesign.metaFont(
        scale: viewModel.resolvedDocumentStyle.typographyScale, family: viewModel.fontFamily)
      : InvoiceDocumentDesign.bodyFont(
        scale: viewModel.resolvedDocumentStyle.typographyScale, family: viewModel.fontFamily)
    let emphasizeRows = emphasis.emphasizesAllRows
    let labelColumnWidth = LineItemColumnWidthMeasurer.measureTotalsLabelWidth(
      density: viewModel.typographyDensity,
      typographyScale: viewModel.resolvedDocumentStyle.typographyScale
    )
    let labelRegionWidth = columnWidths.qtyUnitRateWidth
    let labelColumnSpan = viewModel.columnVisibility.totalsLabelColumnSpan

    let discountValue = InvoiceCalculations.discountValue(
      subtotal: viewModel.liveTotals.subtotal,
      discountAmount: viewModel.discountAmount,
      discountPercent: viewModel.discountPercent
    )

    totalsAmountGridRow(
      label: "Subtotal",
      amount: viewModel.liveTotals.subtotal,
      amountFont: amountFont,
      currencyCode: viewModel.currencyCode,
      columnWidths: columnWidths,
      descriptionColumnWidth: descriptionColumnWidth,
      labelColumnWidth: labelColumnWidth,
      labelRegionWidth: labelRegionWidth,
      labelColumnSpan: labelColumnSpan,
      rowHeight: rowHeight,
      visibility: viewModel.columnVisibility,
      currencyDisplayStyle: viewModel.currencyDisplayStyle,
      emphasized: emphasizeRows
    )
    .previewInspectorTargetIfPresent(.currencyCode, interaction: inspectorInteraction)

    if viewModel.discountPercent != 0 {
      totalsRateValueGridRow(
        label: "Disc %",
        value: "\(InvoiceDecimalFormatter.string(for: viewModel.discountPercent))%",
        columnWidths: columnWidths,
        descriptionColumnWidth: descriptionColumnWidth,
        labelColumnWidth: labelColumnWidth,
        labelRegionWidth: labelRegionWidth,
        labelColumnSpan: labelColumnSpan,
        font: amountFont,
        rowHeight: rowHeight,
        visibility: viewModel.columnVisibility,
        emphasized: emphasizeRows
      )
      .previewInspectorTargetIfPresent(.discountPercent, interaction: inspectorInteraction)
    }

    if discountValue != 0 {
      totalsAmountGridRow(
        label: "Discount",
        amount: discountValue,
        amountFont: amountFont,
        currencyCode: viewModel.currencyCode,
        columnWidths: columnWidths,
        descriptionColumnWidth: descriptionColumnWidth,
        labelColumnWidth: labelColumnWidth,
        labelRegionWidth: labelRegionWidth,
        labelColumnSpan: labelColumnSpan,
        rowHeight: rowHeight,
        visibility: viewModel.columnVisibility,
        currencyDisplayStyle: viewModel.currencyDisplayStyle,
        emphasized: emphasizeRows
      )
      .previewInspectorTargetIfPresent(.discountAmount, interaction: inspectorInteraction)
    }

    if viewModel.showsTaxSummary {
      if viewModel.liveTotals.taxTotal != 0 {
        totalsAmountGridRow(
        label: viewModel.taxLabelStyle.appliedLabel,
        amount: viewModel.liveTotals.taxTotal,
        amountFont: amountFont,
        currencyCode: viewModel.currencyCode,
        columnWidths: columnWidths,
        descriptionColumnWidth: descriptionColumnWidth,
        labelColumnWidth: labelColumnWidth,
        labelRegionWidth: labelRegionWidth,
        labelColumnSpan: labelColumnSpan,
        rowHeight: rowHeight,
        visibility: viewModel.columnVisibility,
        currencyDisplayStyle: viewModel.currencyDisplayStyle,
        emphasized: emphasizeRows
        )
        .previewInspectorTargetIfPresent(.defaultTaxRate, interaction: inspectorInteraction)
      } else {
        totalsRateValueGridRow(
        label: viewModel.taxLabelStyle.appliedLabel,
        value: viewModel.taxLabelStyle.zeroTaxLabel,
        columnWidths: columnWidths,
        descriptionColumnWidth: descriptionColumnWidth,
        labelColumnWidth: labelColumnWidth,
        labelRegionWidth: labelRegionWidth,
        labelColumnSpan: labelColumnSpan,
        font: amountFont,
        rowHeight: rowHeight,
        visibility: viewModel.columnVisibility,
        emphasized: emphasizeRows
        )
        .previewInspectorTargetIfPresent(.defaultTaxRate, interaction: inspectorInteraction)
      }
    }

    if viewModel.creditApplied != 0 {
      totalsAmountGridRow(
        label: "Credit",
        amount: viewModel.creditApplied,
        amountFont: amountFont,
        currencyCode: viewModel.currencyCode,
        columnWidths: columnWidths,
        descriptionColumnWidth: descriptionColumnWidth,
        labelColumnWidth: labelColumnWidth,
        labelRegionWidth: labelRegionWidth,
        labelColumnSpan: labelColumnSpan,
        rowHeight: rowHeight,
        visibility: viewModel.columnVisibility,
        currencyDisplayStyle: viewModel.currencyDisplayStyle,
        emphasized: emphasizeRows
      )
      .previewInspectorTargetIfPresent(.creditApplied, interaction: inspectorInteraction)
    }

    totalsGrandTotalGridRow(
      viewModel: viewModel,
      columnWidths: columnWidths,
      descriptionColumnWidth: descriptionColumnWidth,
      labelColumnWidth: labelColumnWidth,
      labelRegionWidth: labelRegionWidth,
      rowHeight: rowHeight
    )
  }

  /// Payment details and payment terms — pinned to the bottom of the last page in preview.
  @ViewBuilder
  static func documentPaymentFooter(
    viewModel: InvoiceEditorViewModel,
    contentWidth: CGFloat,
    inspectorInteraction: InvoicePreviewInspectorInteraction? = nil
  ) -> some View {
    let sideBySide = viewModel.partyLayout.usesSideBySide(contentWidth: contentWidth)
    let showsDetails = viewModel.showPaymentDetails
    let showsTerms = viewModel.showPaymentTerms

    if !showsDetails, !showsTerms {
      EmptyView()
    } else if showsDetails, showsTerms {
      if sideBySide {
        // Equalize to the taller card only. `.fixedSize(vertical: true)`
        // keeps the row from growing into leftover page space offered by
        // the footer Spacer that pins this block to the page bottom.
        HStack(
          alignment: .top,
          spacing: InvoiceDocumentLayout.partyColumnSpacing(
            scale: viewModel.resolvedDocumentStyle.spacingScale)
        ) {
          paymentDetailsCard(
            viewModel: viewModel, expandsToFillHeight: true,
            showsOutline: viewModel.showPaymentCardBorders,
            showsFill: viewModel.showPaymentCardFill,
            showsLabels: viewModel.showPaymentDetailLabels,
            showsRowRules: viewModel.showPaymentDetailRowRules,
            inspectorInteraction: inspectorInteraction
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          paymentTermsCard(
            terms: viewModel.paymentTerms, notes: viewModel.notes, expandsToFillHeight: true,
            showsOutline: viewModel.showPaymentCardBorders, showsFill: viewModel.showPaymentCardFill
          )
          .previewInspectorTargetIfPresent(.paymentTerms, interaction: inspectorInteraction)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .fixedSize(horizontal: false, vertical: true)
      } else {
        VStack(
          alignment: .leading,
          spacing: InvoiceDocumentLayout.footerSpacing(
            scale: viewModel.resolvedDocumentStyle.spacingScale)
        ) {
          paymentDetailsCard(
            viewModel: viewModel, showsOutline: viewModel.showPaymentCardBorders,
            showsFill: viewModel.showPaymentCardFill,
            showsLabels: viewModel.showPaymentDetailLabels,
            showsRowRules: viewModel.showPaymentDetailRowRules,
            inspectorInteraction: inspectorInteraction)
          paymentTermsCard(
            terms: viewModel.paymentTerms, notes: viewModel.notes,
            showsOutline: viewModel.showPaymentCardBorders,
            showsFill: viewModel.showPaymentCardFill
          )
          .previewInspectorTargetIfPresent(.paymentTerms, interaction: inspectorInteraction)
        }
      }
    } else if showsDetails {
      paymentDetailsCard(
        viewModel: viewModel, showsOutline: viewModel.showPaymentCardBorders,
        showsFill: viewModel.showPaymentCardFill, showsLabels: viewModel.showPaymentDetailLabels,
        showsRowRules: viewModel.showPaymentDetailRowRules,
        inspectorInteraction: inspectorInteraction)
    } else {
      paymentTermsCard(
        terms: viewModel.paymentTerms, notes: viewModel.notes,
        showsOutline: viewModel.showPaymentCardBorders,
        showsFill: viewModel.showPaymentCardFill
      )
      .previewInspectorTargetIfPresent(.paymentTerms, interaction: inspectorInteraction)
    }
  }

  /// Payment details and payment terms — measured for pagination when totals live in the line-items grid.
  static func documentFooterBlock(
    viewModel: InvoiceEditorViewModel,
    contentWidth: CGFloat
  ) -> some View {
    documentPaymentFooter(
      viewModel: viewModel,
      contentWidth: contentWidth
    )
  }

  private static func totalsAmountGridRow(
    label: String,
    amount: Decimal,
    amountFont: Font,
    currencyCode: String,
    columnWidths: LineItemTableColumnWidths,
    descriptionColumnWidth: CGFloat,
    labelColumnWidth: CGFloat,
    labelRegionWidth: CGFloat,
    labelColumnSpan: Int,
    rowHeight: CGFloat,
    visibility: LineItemColumnVisibility,
    currencyDisplayStyle: InvoiceCurrencyDisplayStyle = .default,
    emphasized: Bool = false
  ) -> some View {
    GridRow {
      totalsEmptyDateCell(columnWidths: columnWidths, visibility: visibility)
      totalsEmptyDescriptionCell(width: descriptionColumnWidth)
      totalsLabelRegion(
        labelColumnWidth: labelColumnWidth,
        labelRegionWidth: labelRegionWidth,
        emphasized: emphasized
      ) {
        totalsLabel(label)
      }
      .gridCellColumns(max(labelColumnSpan, 1))
      totalsAmountText(
        amount,
        font: amountFont,
        currencyCode: currencyCode,
        displayStyle: currencyDisplayStyle
      )
      .lineItemPreviewTotalsValueCell(
        width: columnWidths.total,
        emphasized: emphasized
      )
    }
    .frame(height: rowHeight)
  }

  private static func totalsRateValueGridRow(
    label: String,
    value: String,
    columnWidths: LineItemTableColumnWidths,
    descriptionColumnWidth: CGFloat,
    labelColumnWidth: CGFloat,
    labelRegionWidth: CGFloat,
    labelColumnSpan: Int,
    font: Font,
    rowHeight: CGFloat,
    visibility: LineItemColumnVisibility,
    emphasized: Bool = false
  ) -> some View {
    GridRow {
      totalsEmptyDateCell(columnWidths: columnWidths, visibility: visibility)
      totalsEmptyDescriptionCell(width: descriptionColumnWidth)
      totalsLabelRegion(
        labelColumnWidth: labelColumnWidth,
        labelRegionWidth: labelRegionWidth,
        emphasized: emphasized
      ) {
        totalsLabel(label)
      }
      .gridCellColumns(max(labelColumnSpan, 1))
      Text(value)
        .font(font)
        .monospacedDigit()
        .lineItemPreviewTotalsValueCell(
          width: columnWidths.total,
          emphasized: emphasized
        )
    }
    .frame(height: rowHeight)
  }

  private static func totalsGrandTotalGridRow(
    viewModel: InvoiceEditorViewModel,
    columnWidths: LineItemTableColumnWidths,
    descriptionColumnWidth: CGFloat,
    labelColumnWidth: CGFloat,
    labelRegionWidth: CGFloat,
    rowHeight: CGFloat
  ) -> some View {
    TotalsGrandTotalGridRow(
      viewModel: viewModel,
      columnWidths: columnWidths,
      descriptionColumnWidth: descriptionColumnWidth,
      labelColumnWidth: labelColumnWidth,
      labelRegionWidth: labelRegionWidth,
      labelColumnSpan: viewModel.columnVisibility.totalsLabelColumnSpan,
      rowHeight: rowHeight
    )
  }

  @ViewBuilder
  private static func totalsEmptyDateCell(
    columnWidths: LineItemTableColumnWidths,
    visibility: LineItemColumnVisibility
  ) -> some View {
    if visibility.showDate {
      Color.clear
        .lineItemPreviewTotalsEmptyCell(
          column: .date,
          width: columnWidths.date
        )
    }
  }

  private static func totalsEmptyDescriptionCell(width: CGFloat) -> some View {
    Color.clear
      .lineItemPreviewTotalsEmptyCell(
        column: .description,
        width: width
      )
  }

  private static func totalsLabelRegion<Label: View>(
    labelColumnWidth: CGFloat,
    labelRegionWidth: CGFloat,
    emphasized: Bool = false,
    @ViewBuilder label: () -> Label
  ) -> some View {
    Color.clear
      .lineItemPreviewTotalsLabelRegionCell(
        regionWidth: labelRegionWidth,
        labelColumnWidth: labelColumnWidth,
        emphasized: emphasized,
        label: label
      )
  }

  private static func totalsLabel(_ label: String) -> some View {
    Text(label)
      .resolvedInvoiceFont(.fieldLabel)
      .foregroundStyle(InvoiceDocumentDesign.inkMuted)
      .frame(maxWidth: .infinity, alignment: InvoiceDocumentDesign.labelValueLabelAlignment)
  }

  private static func totalsAmountText(
    _ amount: Decimal,
    font: Font,
    currencyCode: String,
    displayStyle: InvoiceCurrencyDisplayStyle = .default
  ) -> some View {
    Text(
      InvoiceMoneyFormatter.string(
        for: amount, currencyCode: currencyCode, displayStyle: displayStyle)
    )
    .font(font)
    .monospacedDigit()
  }

  /// Payment Details rendered as a ruled label/value table so it reads as a
  /// tabular echo of the invoice details table in the header.
  @ViewBuilder
  private static func paymentDetailsCard(
    viewModel: InvoiceEditorViewModel,
    expandsToFillHeight: Bool = false,
    showsOutline: Bool = true,
    showsFill: Bool = true,
    showsLabels: Bool = true,
    showsRowRules: Bool = true,
    inspectorInteraction: InvoicePreviewInspectorInteraction? = nil
  ) -> some View {
    let rows: [(label: String, value: String, target: InvoiceInspectorFocusTarget)] = [
      ("Bank", viewModel.bankName, .bankName),
      ("Account", viewModel.bankAccountName, .bankAccountName),
      ("BSB", viewModel.bankBSB, .bankBSB),
      ("Acc No.", viewModel.bankAccountNumber, .bankAccountNumber),
    ]

    ThemedDocumentBandedCard(
      label: "Payment Details",
      kind: .payment,
      flushBody: true,
      showsOutline: showsOutline,
      showsFill: showsFill,
      expandsToFillHeight: expandsToFillHeight,
      inspectorHeaderTarget: .paymentDetails,
      inspectorInteraction: inspectorInteraction
    ) {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
          PaymentDetailRowView(
            label: row.label,
            value: row.value,
            isLast: index == rows.count - 1,
            showsLabel: showsLabels,
            showsRowRule: showsRowRules
          )
          .previewInspectorTargetIfPresent(row.target, interaction: inspectorInteraction)
        }
      }
    }
  }

  /// Payment Terms in a card matching the payment details styling so the two
  /// read as one unified footer block.
  private static func paymentTermsCard(
    terms: String,
    notes: String,
    expandsToFillHeight: Bool = false,
    showsOutline: Bool = true,
    showsFill: Bool = true
  ) -> some View {
    ThemedDocumentBandedCard(
      label: notes.isEmpty ? "Payment Terms" : "Payment Terms & Notes",
      kind: .payment,
      showsOutline: showsOutline,
      showsFill: showsFill,
      expandsToFillHeight: expandsToFillHeight
    ) {
      if terms.isEmpty, notes.isEmpty {
        Text("—")
          .resolvedInvoiceFont(.body)
          .foregroundStyle(InvoiceDocumentDesign.inkFaint)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        VStack(alignment: .leading, spacing: 6) {
          if !terms.isEmpty {
            Text(terms)
              .resolvedInvoiceFont(.body)
              .foregroundStyle(InvoiceDocumentDesign.ink)
              .fixedSize(horizontal: false, vertical: true)
          }
          if !notes.isEmpty {
            if !terms.isEmpty { Divider() }
            Text("Notes")
              .resolvedInvoiceFont(.meta)
              .foregroundStyle(InvoiceDocumentDesign.inkMuted)
            Text(notes)
              .resolvedInvoiceFont(.body)
              .foregroundStyle(InvoiceDocumentDesign.ink)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  static func pageNumberLabel(pageIndex: Int, totalPages: Int, showsChrome: Bool = true)
    -> some View
  {
    Group {
      if showsChrome {
        Text("Page \(pageIndex + 1) of \(totalPages)")
          .font(InvoiceDocumentDesign.chromeFont)
          .foregroundStyle(InvoiceDocumentDesign.inkMuted)
          .monospacedDigit()
          .documentChromeCapsule()
      } else {
        Text("Page \(pageIndex + 1) of \(totalPages)")
          .font(InvoiceDocumentDesign.chromeFont)
          .foregroundStyle(InvoiceDocumentDesign.inkMuted)
          .monospacedDigit()
      }
    }
    .padding(.bottom, 5)
  }
}

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
private struct IntrinsicPartyRowLayout: Layout {
  let spacing: CGFloat

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
    let rowHeight = measuredHeight(for: subviews, widths: widths)
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
    var overflow = widths.reduce(0, +) - targetWidth
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

struct InvoiceDetailsPreviewBlock: View {
  @Environment(\.invoiceTheme) private var theme
  @Environment(\.invoiceDocumentStyle) private var documentStyle
  @Environment(\.invoiceFontFamily) private var fontFamily

  let invoiceNumber: String?
  let issueDate: Date
  let dueDate: Date
  var showInvoiceNumber: Bool = true
  var showIssueDate: Bool = true
  var showDueDate: Bool = true
  var dateFormatStyle: InvoiceDateFormatStyle = .default
  var alignsTrailing: Bool = true
  /// Distance the value column (and white surface) extends past its trailing
  /// edge so the cell backgrounds bleed to the physical right page edge on the
  /// wide layout. `0` keeps the table content-hugging (narrow paper / measurer).
  var trailingBleed: CGFloat = 0
  /// Nil in the pagination measurer; the live preview maps individual date
  /// rows to their corresponding DatePickers.
  var showsOutline: Bool = true
  var showsLabels: Bool = true
  var showsGridLines: Bool = true
  var inspectorInteraction: InvoicePreviewInspectorInteraction?

  var body: some View {
    // Tabular metadata rendered as a standalone bordered two-column grid
    // (right-aligned label column + left-aligned value column) so the
    // invoice number and dates read as neatly aligned, visibly ruled rows.
    detailsTable
      .frame(
        maxWidth: alignsTrailing ? nil : .infinity,
        alignment: alignsTrailing ? .trailing : .leading
      )
  }

  /// Bordered two-column table. Cells abut (zero grid spacing) and draw their
  /// own teal grid lines so the row separators and the label/value column
  /// divider stay straight and aligned; an outer accent stroke frames it.
  @ViewBuilder
  private var detailsTable: some View {
    let number = invoiceNumber ?? "—"
    // Square corners on all four edges so the details table reads as a
    // crisp, sharply-ruled block on the banner.
    let shape = Rectangle()
    let strokeWidth = documentStyle.detailsBorderWidth

    Grid(alignment: .trailing, horizontalSpacing: 0, verticalSpacing: 0) {
      if showInvoiceNumber {
        detailRow(
          label: "Invoice #",
          value: number,
          labelColor: theme.accent,
          valueFont: InvoiceDocumentDesign.bodyStrongFont(
            scale: documentStyle.typographyScale, family: fontFamily
          ).monospacedDigit(),
          valueColor: number == "—" ? InvoiceDocumentDesign.inkFaint : theme.accent,
          isFirstRow: true,
          isLastRow: !showIssueDate && !showDueDate
        )
        .previewInspectorTargetIfPresent(.invoiceNumber, interaction: inspectorInteraction)
      }
      if showIssueDate {
        detailRow(
          label: "Issued",
          value: InvoiceDateFormatter.documentString(for: issueDate, style: dateFormatStyle),
          isFirstRow: !showInvoiceNumber,
          isLastRow: !showDueDate
        )
        .previewInspectorTargetIfPresent(.issueDate, interaction: inspectorInteraction)
      }
      if showDueDate {
        detailRow(
          label: "Due",
          value: InvoiceDateFormatter.documentString(for: dueDate, style: dateFormatStyle),
          isFirstRow: !showInvoiceNumber && !showIssueDate,
          isLastRow: true
        )
        .previewInspectorTargetIfPresent(.dueDate, interaction: inspectorInteraction)
      }
    }
    // Size the grid to its natural content width AND height so the whole
    // table hugs its content and does not stretch to fill the header's
    // available width (nor match a taller sibling in the header HStack).
    // The grid resolves each column to its widest content; cells then use
    // maxWidth: .infinity (see detailTableCell) to fill only those
    // content-determined column widths, so the teal grid lines still span
    // the full cell while the table as a whole hugs its content. The value
    // column additionally reserves `trailingBleed` of trailing space so its
    // cell background grows to the right without moving its left-aligned text.
    .fixedSize(horizontal: true, vertical: true)
    // Sit the details card on a crisp white surface so its teal grid lines,
    // labels, and values stay legible on the solid teal header banner.
    .background(InvoiceDetailsTableStyle.surfaceFill, in: shape)
    .clipShape(shape)
    .overlay {
      if showsOutline {
        shape.strokeBorder(
          InvoiceDetailsTableStyle.outerBorderColor(theme: theme),
          lineWidth: strokeWidth
        )
      }
    }
    // Pull the reported layout width back by the bleed so the table stays
    // anchored at the content trailing edge while the extended surface + cells
    // overflow to the right, reaching the page edge on the wide layout.
    .padding(.trailing, -trailingBleed)
  }

  /// One aligned label/value row in the bordered metadata grid. Both cells use
  /// uniform padding and fill the row height so their grid lines line up: the
  /// label cell draws a trailing (column) divider, and every row but the last
  /// draws a bottom (row) separator.
  private func detailRow(
    label: String,
    value: String,
    labelColor: Color? = nil,
    valueFont: Font? = nil,
    valueColor: Color? = nil,
    isFirstRow _: Bool = false,
    isLastRow: Bool = false
  ) -> some View {
    let resolvedLabelColor = labelColor ?? theme.accentMuted
    let valueTrailingBleed = trailingBleed
    return GridRow(alignment: .center) {
      if showsLabels {
        Text(label)
          .resolvedInvoiceFont(.fieldLabel)
          .foregroundStyle(resolvedLabelColor)
          .detailTableCell(
            drawsBottomBorder: showsGridLines && !isLastRow,
            drawsTrailingBorder: showsGridLines,
            alignment: InvoiceDocumentDesign.labelValueLabelAlignment
          )
          .gridColumnAlignment(InvoiceDocumentDesign.labelValueLabelColumnAlignment)
      }
      Text(value)
        .font(
          valueFont
            ?? InvoiceDocumentDesign.bodyFont(
              scale: documentStyle.typographyScale, family: fontFamily)
        )
        .foregroundStyle(
          valueColor
            ?? (value == "—" ? InvoiceDocumentDesign.inkFaint : InvoiceDocumentDesign.ink)
        )
        .lineLimit(1)
        .detailTableCell(
          drawsBottomBorder: showsGridLines && !isLastRow,
          drawsTrailingBorder: false,
          alignment: InvoiceDocumentDesign.labelValueValueAlignment,
          trailingBleed: valueTrailingBleed
        )
        .gridColumnAlignment(InvoiceDocumentDesign.labelValueValueColumnAlignment)
    }
  }
}

/// Visual tokens for the invoice details bordered table. Mirrors the line-items
/// table border language (thin rules) but tinted with the accent so the
/// details card reads as a related, clearly ruled table.
private enum InvoiceDetailsTableStyle {
  static var surfaceFill: Color {
    Color.white
  }

  static let cellHorizontalPadding: CGFloat = 9
  static let cellVerticalPadding: CGFloat = 3

  static func gridLineColor(theme: InvoiceThemePalette) -> Color {
    theme.detailsGridLineColor
  }

  static func outerBorderColor(theme: InvoiceThemePalette) -> Color {
    theme.detailsOuterBorderColor
  }
}

extension View {
  /// Uniform cell padding plus optional teal grid lines (trailing column
  /// divider and bottom row separator), stretched to fill the allocated grid
  /// column width and row height so borders stay straight and span the full
  /// cell across the 2×3 grid.
  fileprivate func detailTableCell(
    drawsBottomBorder: Bool,
    drawsTrailingBorder: Bool,
    alignment: Alignment = .trailing,
    trailingBleed: CGFloat = 0
  ) -> some View {
    padding(.horizontal, InvoiceDetailsTableStyle.cellHorizontalPadding)
      .padding(.vertical, InvoiceDetailsTableStyle.cellVerticalPadding)
      // Reserve trailing space so the value cell's background (and its
      // bottom row separator) extends to the right page edge without
      // shifting the left-aligned text.
      .padding(.trailing, trailingBleed)
      // Fill the allocated grid column width (not just the content width) so
      // the bottom row separator spans the full cell; `alignment` keeps the
      // label trailing-aligned and the value leading-aligned within the cell.
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
      .overlay {
        DetailTableCellBorders(
          drawsBottomBorder: drawsBottomBorder,
          drawsTrailingBorder: drawsTrailingBorder
        )
      }
  }
}

/// Draws the trailing and bottom grid lines for a single details-table cell.
private struct DetailTableCellBorders: View {
  @Environment(\.invoiceTheme) private var theme
  @Environment(\.invoiceDocumentStyle) private var documentStyle

  let drawsBottomBorder: Bool
  let drawsTrailingBorder: Bool

  private var width: CGFloat {
    documentStyle.detailsBorderWidth
  }

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let color = InvoiceDetailsTableStyle.gridLineColor(theme: theme)

      if drawsTrailingBorder {
        Rectangle()
          .fill(color)
          .frame(width: width, height: size.height)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }

      if drawsBottomBorder {
        Rectangle()
          .fill(color)
          .frame(width: size.width, height: width)
          .frame(maxHeight: .infinity, alignment: .bottom)
      }
    }
    .allowsHitTesting(false)
  }
}

private struct ThemedDocumentBandedCard<Content: View>: View {
  @Environment(\.invoiceTheme) private var theme

  enum Kind { case party, payment }

  let label: String
  var kind: Kind = .party
  var flushBody: Bool = false
  var showsOutline: Bool = true
  var showsFill: Bool = true
  /// Stretches the card to match a sibling column in an equal-height row.
  var expandsToFillHeight: Bool = false
  var inspectorHeaderTarget: InvoiceInspectorFocusTarget?
  var inspectorInteraction: InvoicePreviewInspectorInteraction?
  @ViewBuilder var content: () -> Content

  private var resolvedStyle: DocumentBandedCardStyle {
    switch kind {
    case .party: .party(theme: theme)
    case .payment: .payment(theme: theme)
    }
  }

  var body: some View {
    DocumentBandedCard(
      label: label,
      style: displayStyle,
      flushBody: flushBody,
      showsOutline: showsOutline,
      expandsToFillHeight: expandsToFillHeight,
      inspectorHeaderTarget: inspectorHeaderTarget,
      inspectorInteraction: inspectorInteraction,
      content: content
    )
  }

  private var displayStyle: DocumentBandedCardStyle {
    guard !showsFill else { return resolvedStyle }
    return DocumentBandedCardStyle(
      bandFill: .clear,
      bodyFill: .clear,
      outline: resolvedStyle.outline,
      bandRule: resolvedStyle.bandRule
    )
  }
}

private struct LineItemsSectionTitleView: View {
  @Environment(\.invoiceTheme) private var theme

  var body: some View {
    HStack(spacing: 8) {
      Rectangle()
        .fill(theme.accent)
        .frame(width: 3, height: 12)
      Text("Line Items")
        .documentSectionLabel(accent: true, theme: theme)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct TotalsGrandTotalGridRow: View {
  @Environment(\.invoiceTheme) private var theme

  let viewModel: InvoiceEditorViewModel
  let columnWidths: LineItemTableColumnWidths
  let descriptionColumnWidth: CGFloat
  let labelColumnWidth: CGFloat
  let labelRegionWidth: CGFloat
  let labelColumnSpan: Int
  let rowHeight: CGFloat

  var body: some View {
    GridRow {
      if viewModel.columnVisibility.showDate {
        Color.clear
          .lineItemPreviewTotalsEmptyCell(column: .date, width: columnWidths.date)
      }
      Color.clear
        .lineItemPreviewTotalsEmptyCell(column: .description, width: descriptionColumnWidth)
      Color.clear
        .lineItemPreviewTotalsLabelRegionCell(
          regionWidth: labelRegionWidth,
          labelColumnWidth: labelColumnWidth,
          emphasized: true
        ) {
          Text("Total Payable")
            .resolvedInvoiceFont(.emphasis)
            .foregroundStyle(theme.accent)
        }
        .gridCellColumns(max(labelColumnSpan, 1))
      Text(
        InvoiceMoneyFormatter.string(
          for: viewModel.liveTotals.grandTotal,
          currencyCode: viewModel.currencyCode,
          displayStyle: viewModel.currencyDisplayStyle
        )
      )
      .font(
        viewModel.totalsEmphasis.usesCompactType
          ? InvoiceDocumentDesign.bodyEmphasisFont(
            scale: viewModel.resolvedDocumentStyle.typographyScale, family: viewModel.fontFamily)
          : InvoiceDocumentDesign.bodyStrongFont(
            scale: viewModel.resolvedDocumentStyle.typographyScale, family: viewModel.fontFamily)
      )
      .foregroundStyle(theme.accent)
      .monospacedDigit()
      .lineItemPreviewTotalsValueCell(
        width: columnWidths.total,
        emphasized: true
      )
    }
    .frame(height: rowHeight)
  }
}

private struct DocumentTitleUnderlineIfNeeded: ViewModifier {
  let onAccent: Bool
  let showsUnderline: Bool
  let theme: InvoiceThemePalette

  func body(content: Content) -> some View {
    if onAccent || !showsUnderline {
      content
    } else {
      content.documentTitleUnderline(theme: theme)
    }
  }
}

private struct PaymentDetailRowView: View {
  @Environment(\.invoiceTheme) private var theme
  @Environment(\.invoiceDocumentStyle) private var documentStyle
  @Environment(\.invoiceFontFamily) private var fontFamily

  let label: String
  let value: String
  let isLast: Bool
  var showsLabel: Bool = true
  var showsRowRule: Bool = true

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      if showsLabel {
        Text(label)
          .font(
            InvoiceDocumentDesign.metaLabelFont(
              scale: documentStyle.typographyScale, family: fontFamily
            ).smallCaps()
          )
          .foregroundStyle(theme.accentMuted)
          .tracking(0.4)
          .multilineTextAlignment(.trailing)
          .frame(
            width: InvoiceDocumentDesign.inlineLabelWidth,
            alignment: InvoiceDocumentDesign.labelValueLabelAlignment
          )
          .lineLimit(1)
          .minimumScaleFactor(0.85)
      }
      Text(value.isEmpty ? "—" : value)
        .resolvedInvoiceFont(.body)
        .foregroundStyle(value.isEmpty ? InvoiceDocumentDesign.inkFaint : InvoiceDocumentDesign.ink)
        .lineLimit(1)
        .frame(
          maxWidth: .infinity,
          alignment: InvoiceDocumentDesign.labelValueValueAlignment
        )
    }
    .padding(.horizontal, InvoiceDocumentDesign.bandPaddingHorizontal)
    .padding(.vertical, InvoiceDocumentLayout.footerRowSpacing * documentStyle.spacingScale)
    .overlay(alignment: .bottom) {
      if showsRowRule && !isLast {
        Rectangle()
          .fill(theme.paymentRowRule)
          .frame(height: InvoiceDocumentDesign.bandedCardBorderWidth)
      }
    }
  }
}
