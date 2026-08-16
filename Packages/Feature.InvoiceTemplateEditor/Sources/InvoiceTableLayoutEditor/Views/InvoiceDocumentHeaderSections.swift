import SwiftUI

extension InvoiceDocumentSections {
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

}
