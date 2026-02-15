import Foundation

// Extension to split an array into chunks of a given size
extension Array {
    public func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] } // Handle invalid size
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
} 