import AppKit

enum RelationshipDetailLabelMetrics {
    static func maxWidth(for labels: [String], fontSize: CGFloat = 14, padding: CGFloat = 20) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize)
        let maxWidth = labels.map { label in
            (label as NSString).size(withAttributes: [.font: font]).width
        }.max() ?? 80
        return maxWidth + padding
    }
}
