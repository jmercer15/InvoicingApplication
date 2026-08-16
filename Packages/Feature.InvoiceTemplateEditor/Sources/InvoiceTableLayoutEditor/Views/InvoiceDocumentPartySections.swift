import SwiftUI

extension InvoiceDocumentSections {
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

}
