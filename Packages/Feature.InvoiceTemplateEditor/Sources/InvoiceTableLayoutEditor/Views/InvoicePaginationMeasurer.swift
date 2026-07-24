import AppKit
import Observation
import SwiftUI

/// Renders invoice sections at document width and reports measured heights for pagination.
///
/// Mounted off-screen in `InvoiceEditorView`; coalesces section-height reports so page breaks
/// reflect actual rendered layout rather than height estimates.
struct InvoicePaginationMeasurer: View {
    @Bindable var viewModel: InvoiceEditorViewModel
    let contentWidth: CGFloat
    let printableHeight: CGFloat
    let onDimensionsChange: (InvoicePagination.MeasuredDimensions) -> Void

    @State private var sectionReporter = InvoicePaginationSectionReporter()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            measureSection(.documentHeader) {
                // Pass the real page margin (not bleed) so the measured header
                // height includes the margin/2 bottom padding rendered in the
                // preview. The fill bleed is irrelevant to layout height, so it is
                // intentionally left at its default (0) here.
                InvoiceDocumentSections.documentHeader(
                    viewModel: viewModel,
                    contentWidth: contentWidth,
                    margin: viewModel.effectiveMarginPoints
                )
            }

            measureSection(.parties) {
                InvoiceDocumentSections.parties(
                    viewModel: viewModel,
                    contentWidth: contentWidth
                )
            }

            measureSection(.lineItemsSectionTitle) {
                if viewModel.showLineItemsSectionTitle {
                    InvoiceDocumentSections.lineItemsSectionTitle()
                }
            }

            measureSection(.tableHeader) {
                if viewModel.showLineItemsTableHeader {
                    InvoiceLineItemsPreviewTable(
                        viewModel: viewModel,
                        contentWidth: contentWidth,
                        lineItemIDs: [],
                        showsHeader: true
                    )
                }
            }

            measureSection(.totalsGrid) {
                InvoiceLineItemsPreviewTable(
                    viewModel: viewModel,
                    contentWidth: contentWidth,
                    lineItemIDs: [],
                    showsHeader: false,
                    showsTotals: true
                )
            }

            measureSection(.footerBlock) {
                InvoiceDocumentSections.documentFooterBlock(
                    viewModel: viewModel,
                    contentWidth: contentWidth
                )
            }

            measureSection(.pageNumberLabel) {
                InvoiceDocumentSections.pageNumberLabel(
                    pageIndex: 0,
                    totalPages: 1,
                    showsChrome: viewModel.showPageNumberChrome
                )
            }
        }
        .frame(width: contentWidth, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .hidden()
        .allowsHitTesting(false)
        .invoiceTemplateAppearance(
            theme: viewModel.themePalette,
            tableStyle: viewModel.tableStyle,
            fontFamily: viewModel.fontFamily,
            borderWeight: viewModel.borderWeight,
            tablePresentation: InvoiceTablePresentation(
                showsGridLines: viewModel.showTableGridLines,
                showsZebraRows: viewModel.showTableZebraRows,
                showsHeaderFill: viewModel.showTableHeaderFill,
                showsTotalsFill: viewModel.showTotalsFill
            ),
            resolvedStyle: viewModel.resolvedDocumentStyle
        )
        .task(id: measurementInputToken) {
            sectionReporter.invalidate()
        }
        .onChange(of: sectionReporter.publicationRevision) { _, _ in
            publishDimensions()
        }
    }

    private var measurementInputToken: String {
        return [
            viewModel.paginationMeasurementToken,
            String(describing: contentWidth),
            String(describing: printableHeight),
        ].joined(separator: "|")
    }

    private func publishDimensions() {
        let heights = sectionReporter.heights
        let rowHeights = LineItemRowHeightMeasurer.heights(
            for: viewModel.lineItems,
            presentation: .preview,
            density: viewModel.typographyDensity,
            typographyScale: viewModel.resolvedDocumentStyle.typographyScale,
            showsItemCode: viewModel.showItemCode
        )
        let dimensions = InvoicePagination.MeasuredDimensions(
            printableHeight: printableHeight,
            contentWidth: contentWidth,
            sectionSpacing: InvoiceDocumentLayout.sectionSpacing(scale: viewModel.resolvedDocumentStyle.spacingScale),
            lineItemsTitleSpacing: InvoiceDocumentLayout.lineItemsTitleSpacing(scale: viewModel.resolvedDocumentStyle.spacingScale),
            lineItemsTopPadding: InvoiceDocumentLayout.lineItemsTopPadding(scale: viewModel.resolvedDocumentStyle.spacingScale),
            pageNumberLabelHeight: heights.pageNumberLabel,
            documentHeaderHeight: heights.documentHeader,
            partiesHeight: heights.parties,
            lineItemsSectionTitleHeight: viewModel.showLineItemsSectionTitle ? heights.lineItemsSectionTitle : 0,
            tableHeaderHeight: viewModel.showLineItemsTableHeader ? heights.tableHeader : 0,
            lineItemRowHeights: rowHeights,
            totalsGridHeight: heights.totalsGrid,
            footerBlockContentHeight: heights.footerBlock
        )
        onDimensionsChange(dimensions)
    }

    private func measureSection(
        _ section: InvoicePaginationMeasuredSection,
        @ViewBuilder content: () -> some View
    ) -> some View {
        content()
            .frame(width: contentWidth, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            .background {
                InvoicePaginationSectionHeightReader(section: section) { measuredSection, height in
                    sectionReporter.receive(height, for: measuredSection)
                }
            }
            .id(section)
    }
}

private enum InvoicePaginationMeasuredSection: Hashable {
    case documentHeader
    case parties
    case lineItemsSectionTitle
    case tableHeader
    case totalsGrid
    case footerBlock
    case pageNumberLabel
}

private struct InvoicePaginationSectionHeights: Equatable {
    var documentHeader: CGFloat = 0
    var parties: CGFloat = 0
    var lineItemsSectionTitle: CGFloat = 0
    var tableHeader: CGFloat = 0
    var totalsGrid: CGFloat = 0
    var footerBlock: CGFloat = 0
    var pageNumberLabel: CGFloat = 0

    subscript(section: InvoicePaginationMeasuredSection) -> CGFloat {
        get {
            switch section {
            case .documentHeader: documentHeader
            case .parties: parties
            case .lineItemsSectionTitle: lineItemsSectionTitle
            case .tableHeader: tableHeader
            case .totalsGrid: totalsGrid
            case .footerBlock: footerBlock
            case .pageNumberLabel: pageNumberLabel
            }
        }
        set {
            switch section {
            case .documentHeader: documentHeader = newValue
            case .parties: parties = newValue
            case .lineItemsSectionTitle: lineItemsSectionTitle = newValue
            case .tableHeader: tableHeader = newValue
            case .totalsGrid: totalsGrid = newValue
            case .footerBlock: footerBlock = newValue
            case .pageNumberLabel: pageNumberLabel = newValue
            }
        }
    }
}

/// Reads the final AppKit frame without participating in SwiftUI's preference update cycle.
/// Reports on the next main-actor turn so no state changes occur during AppKit layout.
private struct InvoicePaginationSectionHeightReader: NSViewRepresentable {
    let section: InvoicePaginationMeasuredSection
    let onHeightChange: @MainActor (InvoicePaginationMeasuredSection, CGFloat) -> Void

    func makeNSView(context: Context) -> InvoicePaginationSectionHeightReportingView {
        let view = InvoicePaginationSectionHeightReportingView()
        view.configure(section: section, onHeightChange: onHeightChange)
        return view
    }

    func updateNSView(
        _ nsView: InvoicePaginationSectionHeightReportingView,
        context: Context
    ) {
        nsView.configure(section: section, onHeightChange: onHeightChange)
    }
}

private final class InvoicePaginationSectionHeightReportingView: NSView {
    private var section: InvoicePaginationMeasuredSection?
    private var onHeightChange: (@MainActor (InvoicePaginationMeasuredSection, CGFloat) -> Void)?
    private var latestHeight: CGFloat = 0
    private var lastReportedHeight: CGFloat?
    private var reportScheduled = false

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        scheduleReport(height: newSize.height)
    }

    func configure(
        section: InvoicePaginationMeasuredSection,
        onHeightChange: @escaping @MainActor (InvoicePaginationMeasuredSection, CGFloat) -> Void
    ) {
        self.section = section
        self.onHeightChange = onHeightChange
        scheduleReport(height: frame.height)
    }

    private func scheduleReport(height: CGFloat) {
        let normalizedHeight = InvoicePaginationMeasurementStability.normalizedHeight(height)
        latestHeight = normalizedHeight
        guard lastReportedHeight != normalizedHeight else { return }
        guard !reportScheduled else { return }
        reportScheduled = true

        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            self.reportScheduled = false
            guard let section = self.section else { return }
            let height = self.latestHeight
            guard self.lastReportedHeight != height else { return }
            self.lastReportedHeight = height
            self.onHeightChange?(section, height)
        }
    }
}

/// Collects every section frame update, then publishes one observation after
/// measurements settle. Seven reporters never mutate SwiftUI state during AppKit layout.
@Observable
@MainActor
final class InvoicePaginationSectionReporter {
    private let reportingDelay: Duration

    private(set) var publicationRevision = 0
    fileprivate private(set) var heights = InvoicePaginationSectionHeights()
    @ObservationIgnored
    private var latestHeights = InvoicePaginationSectionHeights()
    @ObservationIgnored
    private var revision = 0
    @ObservationIgnored
    private var reportingTask: Task<Void, Never>?

    init(reportingDelay: Duration = .milliseconds(80)) {
        self.reportingDelay = reportingDelay
    }

    func invalidate() {
        revision &+= 1
        schedulePublication()
    }

    fileprivate func receive(_ height: CGFloat, for section: InvoicePaginationMeasuredSection) {
        let normalizedHeight = InvoicePaginationMeasurementStability.normalizedHeight(height)
        guard latestHeights[section] != normalizedHeight else { return }
        latestHeights[section] = normalizedHeight
        revision &+= 1
        schedulePublication()
    }

    private func schedulePublication() {
        guard reportingTask == nil else { return }
        reportingTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let observedRevision = self.revision
                do {
                    try await Task.sleep(for: self.reportingDelay)
                } catch {
                    break
                }

                guard observedRevision == self.revision else { continue }
                if self.heights != self.latestHeights {
                    self.heights = self.latestHeights
                }
                self.publicationRevision &+= 1
                self.reportingTask = nil
                return
            }

            self.reportingTask = nil
        }
    }
}

enum InvoicePaginationMeasurementStability {
    /// Half-point precision exceeds visible pagination accuracy while collapsing
    /// subpixel AppKit differences that can alternate between layout passes.
    private static let resolution: CGFloat = 0.5

    static func normalizedHeight(_ height: CGFloat) -> CGFloat {
        guard height.isFinite else { return 0 }
        return max((height / resolution).rounded() * resolution, 0)
    }
}
