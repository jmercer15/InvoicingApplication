import SwiftUI

// MARK: - Shared overlap geometry (layout + block sizing)

public enum CalendarItemOverlapGeometry {
    public struct RelativePlacement: Equatable, Sendable {
        public let columnIndex: Int
        public let columnSpan: Int
        public let totalColumns: Int
        
        public init(columnIndex: Int, columnSpan: Int, totalColumns: Int) {
            self.columnIndex = columnIndex
            self.columnSpan = columnSpan
            self.totalColumns = totalColumns
        }
    }

    static func calculateRelativePlacements(
        for items: [DisplayableCalendarItem]
    ) -> [String: RelativePlacement] {
        guard !items.isEmpty else { return [:] }

        let sortedIndices = items.indices.sorted { idx1, idx2 in
            let item1 = items[idx1]
            let item2 = items[idx2]
            if item1.startHour != item2.startHour {
                return item1.startHour < item2.startHour
            }
            return item1.durationHours > item2.durationHours
        }

        let indexPosition = Dictionary(uniqueKeysWithValues: sortedIndices.enumerated().map { ($1, $0) })

        var visited = Set<Int>()
        var clusters: [[Int]] = []

        for idx in sortedIndices {
            if visited.contains(idx) { continue }

            var cluster = [Int]()
            var queue = [idx]
            visited.insert(idx)

            while !queue.isEmpty {
                let current = queue.removeFirst()
                cluster.append(current)

                let itemCurrent = items[current]
                let startCurrent = itemCurrent.startHour
                let endCurrent = itemCurrent.startHour + itemCurrent.durationHours

                for other in sortedIndices {
                    if visited.contains(other) { continue }
                    let itemOther = items[other]
                    let startOther = itemOther.startHour
                    let endOther = itemOther.startHour + itemOther.durationHours

                    if startCurrent < endOther && startOther < endCurrent {
                        visited.insert(other)
                        queue.append(other)
                    }
                }
            }

            let sortedCluster = cluster.sorted {
                (indexPosition[$0] ?? 0) < (indexPosition[$1] ?? 0)
            }
            clusters.append(sortedCluster)
        }

        var results = [String: RelativePlacement]()
        results.reserveCapacity(items.count)

        for cluster in clusters {
            var columns: [[Int]] = []
            var itemToColumn = [Int: Int]()

            for idx in cluster {
                let item = items[idx]
                var placed = false
                for colIdx in 0..<columns.count {
                    if let lastIdx = columns[colIdx].last {
                        let lastItem = items[lastIdx]
                        let lastEnd = lastItem.startHour + lastItem.durationHours
                        if item.startHour >= lastEnd {
                            columns[colIdx].append(idx)
                            itemToColumn[idx] = colIdx
                            placed = true
                            break
                        }
                    }
                }
                if !placed {
                    columns.append([idx])
                    itemToColumn[idx] = columns.count - 1
                }
            }

            let columnCount = columns.count

            for idx in cluster {
                let colI = itemToColumn[idx]!
                let itemI = items[idx]
                let startI = itemI.startHour
                let endI = itemI.startHour + itemI.durationHours

                var nextCol = columnCount
                for otherIdx in cluster {
                    if otherIdx == idx { continue }
                    let colJ = itemToColumn[otherIdx]!
                    if colJ > colI {
                        let itemJ = items[otherIdx]
                        let startJ = itemJ.startHour
                        let endJ = itemJ.startHour + itemJ.durationHours

                        if startI < endJ && startJ < endI {
                            nextCol = min(nextCol, colJ)
                        }
                    }
                }

                results[itemI.id] = RelativePlacement(columnIndex: colI, columnSpan: nextCol - colI, totalColumns: columnCount)
            }
        }

        return results
    }

    static func placements(
        indexedItems: [(subviewIndex: Int, item: CalendarItemLayoutValue)],
        relativePlacements: [String: RelativePlacement],
        containerWidth: CGFloat,
        hourHeight: CGFloat
    ) -> [CalendarItemLayout.Placement] {
        return indexedItems.map { pair in
            let item = pair.item
            let relative = relativePlacements[item.id] ?? RelativePlacement(columnIndex: 0, columnSpan: 1, totalColumns: 1)
            let colWidth = containerWidth / CGFloat(relative.totalColumns)
            let x = CGFloat(relative.columnIndex) * colWidth
            let width = CGFloat(relative.columnSpan) * colWidth
            
            let rawHeight = item.durationHours * hourHeight
            let itemHeight = max(18.0, rawHeight)
            return CalendarItemLayout.Placement(
                subviewIndex: pair.subviewIndex,
                x: x,
                y: item.startHour * hourHeight,
                width: width,
                height: itemHeight
            )
        }
    }
}

public struct CalendarItemLayout: Layout {
    public let hourHeight: CGFloat
    public let relativePlacements: [String: CalendarItemOverlapGeometry.RelativePlacement]

    public init(hourHeight: CGFloat, relativePlacements: [String: CalendarItemOverlapGeometry.RelativePlacement]) {
        self.hourHeight = hourHeight
        self.relativePlacements = relativePlacements
    }

    public struct Cache: Equatable {
        public let containerWidth: CGFloat
        public let layoutSignature: UInt64
        public let placements: [Placement]
    }

    public struct Placement: Equatable {
        public let subviewIndex: Int
        public let x: CGFloat
        public let y: CGFloat
        public let width: CGFloat
        public let height: CGFloat
    }

    public func makeCache(subviews: Subviews) -> Cache {
        Cache(containerWidth: -1, layoutSignature: 0, placements: [])
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width ?? 0
        let signature = layoutSignature(subviews: subviews, containerWidth: width)
        if cache.containerWidth != width || cache.layoutSignature != signature {
            cache = Cache(
                containerWidth: width,
                layoutSignature: signature,
                placements: computePlacements(subviews: subviews, containerWidth: width)
            )
        }
        return CGSize(width: width, height: 24 * hourHeight)
    }

    /// Stable identity + geometry inputs for overlap layout. Avoids O(n²) recompute on unrelated layout passes.
    private func layoutSignature(subviews: Subviews, containerWidth: CGFloat) -> UInt64 {
        var hasher = Hasher()
        hasher.combine(hourHeight)
        hasher.combine(containerWidth) // Combine containerWidth so it recomputes if width changes
        for index in subviews.indices {
            guard let item = subviews[index][CalendarItemKey.self] else { continue }
            hasher.combine(index)
            hasher.combine(item.id)
            hasher.combine(item.startHour)
            hasher.combine(item.durationHours)
        }
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        guard !cache.placements.isEmpty else { return }

        for placement in cache.placements {
            guard placement.subviewIndex < subviews.count else { continue }
            subviews[placement.subviewIndex].place(
                at: CGPoint(x: bounds.minX + placement.x, y: bounds.minY + placement.y),
                proposal: ProposedViewSize(width: placement.width, height: placement.height)
            )
        }
    }

    private func computePlacements(subviews: Subviews, containerWidth: CGFloat) -> [Placement] {
        let indexedItems = subviews.indices.compactMap { index -> (subviewIndex: Int, item: CalendarItemLayoutValue)? in
            guard let item = subviews[index][CalendarItemKey.self] else { return nil }
            return (subviewIndex: index, item: item)
        }
        guard !indexedItems.isEmpty, containerWidth > 0 else { return [] }

        return CalendarItemOverlapGeometry.placements(
            indexedItems: indexedItems,
            relativePlacements: relativePlacements,
            containerWidth: containerWidth,
            hourHeight: hourHeight
        )
    }
}

struct CalendarItemLayoutValue: Sendable {
    let id: String
    let startHour: CGFloat
    let durationHours: CGFloat

    init(_ item: DisplayableCalendarItem) {
        self.id = item.id
        self.startHour = item.startHour
        self.durationHours = item.durationHours
    }
}

struct CalendarItemKey: LayoutValueKey {
    typealias Value = CalendarItemLayoutValue?
    static let defaultValue: Value = nil
}
