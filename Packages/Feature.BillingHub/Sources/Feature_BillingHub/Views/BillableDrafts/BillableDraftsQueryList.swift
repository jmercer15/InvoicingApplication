import Core
import PersistenceModels
import SharedUI
import SwiftData
import SwiftUI

struct BillableDraftFilterSpec: Equatable {
    let status: DraftStatus?
    let dateRange: ClosedRange<Date>?
    let clientId: UUID?
    let planType: String?
    let sectionByStatus: Bool
}

struct BillableDraftsQueryList: View {
    @Query private var drafts: [BillableDraft]
    let filterSpec: BillableDraftFilterSpec

    init(filterSpec: BillableDraftFilterSpec) {
        self.filterSpec = filterSpec

        let statusRaw = filterSpec.status?.rawValue
        let rangeLower = filterSpec.dateRange?.lowerBound
        let rangeUpper = filterSpec.dateRange?.upperBound
        let clientId = filterSpec.clientId

        let planTypeRaw = filterSpec.planType.flatMap { $0.isEmpty ? nil : $0 }

        if let statusRaw, let rangeLower, let rangeUpper, let clientId, let planTypeRaw {
            _drafts = Query(
                filter: EntityPredicateBuilders.billableDrafts(
                    statusRaw: statusRaw,
                    rangeLower: rangeLower,
                    rangeUpper: rangeUpper,
                    clientId: clientId,
                    planType: planTypeRaw
                ),
                sort: \.computedAt,
                order: .reverse
            )
        } else if let planTypeRaw {
            _drafts = Query(
                filter: EntityPredicateBuilders.billableDrafts(planType: planTypeRaw),
                sort: \.computedAt,
                order: .reverse
            )
        } else if let statusRaw, let rangeLower, let rangeUpper, let clientId {
            _drafts = Query(
                filter: #Predicate<BillableDraft> { draft in
                    draft.draftStatus == statusRaw
                        && draft.computedAt >= rangeLower
                        && draft.computedAt <= rangeUpper
                },
                sort: \.computedAt,
                order: .reverse
            )
        } else if let statusRaw, let clientId {
            _drafts = Query(
                filter: #Predicate<BillableDraft> { draft in
                    draft.draftStatus == statusRaw && draft.clientId == clientId
                },
                sort: \.computedAt,
                order: .reverse
            )
        } else if let statusRaw {
            _drafts = Query(
                filter: #Predicate<BillableDraft> { draft in
                    draft.draftStatus == statusRaw
                },
                sort: \.computedAt,
                order: .reverse
            )
        } else if let rangeLower, let rangeUpper, let clientId {
            _drafts = Query(
                filter: #Predicate<BillableDraft> { draft in
                    draft.computedAt >= rangeLower
                        && draft.computedAt <= rangeUpper
                        && draft.clientId == clientId
                },
                sort: \.computedAt,
                order: .reverse
            )
        } else if let rangeLower, let rangeUpper {
            _drafts = Query(
                filter: #Predicate<BillableDraft> { draft in
                    draft.computedAt >= rangeLower && draft.computedAt <= rangeUpper
                },
                sort: \.computedAt,
                order: .reverse
            )
        } else if let clientId {
            _drafts = Query(
                filter: #Predicate<BillableDraft> { draft in
                    draft.clientId == clientId
                },
                sort: \.computedAt,
                order: .reverse
            )
        } else {
            _drafts = Query(sort: \.computedAt, order: .reverse)
        }
    }

    private var visibleDrafts: [BillableDraft] {
        drafts
    }

    private var statusSections: [(title: String, drafts: [BillableDraft])] {
        let grouped = Dictionary(grouping: visibleDrafts, by: \.draftStatus)
        return DraftStatus.allCases.compactMap { status in
            guard let sectionDrafts = grouped[status.rawValue], !sectionDrafts.isEmpty else {
                return nil
            }
            return (statusLabel(status), sectionDrafts)
        }
    }

    var body: some View {
        Group {
            if visibleDrafts.isEmpty {
                ContentUnavailableView(
                    "No Drafts Found",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Try changing the status filter or date range, or generate new drafts.")
                )
            } else {
                List {
                    if filterSpec.sectionByStatus, filterSpec.status == nil {
                        ForEach(statusSections, id: \.title) { section in
                            Section(section.title) {
                                draftRows(section.drafts)
                            }
                        }
                    } else {
                        draftRows(visibleDrafts)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    @ViewBuilder
    private func draftRows(_ rows: [BillableDraft]) -> some View {
        ForEach(rows) { draft in
            NavigationLink(value: draft.id) {
                DraftRowView(draft: draft)
            }
        }
    }

    private func statusLabel(_ status: DraftStatus) -> String {
        switch status {
        case .open: return "Open"
        case .needsInfo: return "Needs info"
        case .needsReview: return "Needs review"
        case .ready: return "Ready"
        case .locked: return "Locked"
        }
    }
}

struct DraftRowView: View {
    let draft: BillableDraft

    var body: some View {
        HStack(spacing: DetailToolbarTokens.titleBadgeSpacing) {
            VStack(alignment: .leading, spacing: DetailToolbarTokens.titleSubtitleSpacing) {
                Text("Session \(draft.sessionId.uuidString.prefix(8))...")
                    .font(StyleGuide.Typography.compactRowTitle)
                    .foregroundStyle(StyleGuide.Colors.text)
                Text(draft.draftStatus)
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }

            Spacer(minLength: 0)

            StatusBadge(status: draft.draftStatus)
                .scaleEffect(0.85)
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
        .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
    }
}
