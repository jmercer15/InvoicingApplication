import Foundation

enum FoldPaperKeyboardNavigation {
    enum Move: Equatable {
        case previous
        case next
    }

    static func adjacentItemID(
        currentID: String?,
        itemIDs: [String],
        move: Move
    ) -> String? {
        guard !itemIDs.isEmpty else { return nil }
        guard let currentID,
              let currentIndex = itemIDs.firstIndex(of: currentID)
        else {
            return move == .next ? itemIDs.first : itemIDs.last
        }

        switch move {
        case .previous:
            return itemIDs[max(0, currentIndex - 1)]
        case .next:
            return itemIDs[min(itemIDs.count - 1, currentIndex + 1)]
        }
    }
}
