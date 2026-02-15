import Foundation

public struct GeometryUtils {
    /// Performs a binary search to find the index where `value` fits in `cumulativeOffsets`.
    /// - Parameters:
    ///   - value: The coordinate value (x or y) to search for.
    ///   - offsets: An array of cumulative offsets (e.g., [0, 100, 250, ...]).
    /// - Returns: The index `i` such that `offsets[i] <= value < offsets[i+1]`.
    public static func binarySearch(value: CGFloat, in offsets: [CGFloat]) -> Int? {
        guard !offsets.isEmpty else { return nil }
        
        var low = 0
        var high = offsets.count - 1
        
        while low <= high {
            let mid = (low + high) / 2
            let midVal = offsets[mid]
            
            // Check if value is in the range [midVal, nextVal)
            let nextVal = (mid + 1 < offsets.count) ? offsets[mid + 1] : CGFloat.infinity
            
            if value >= midVal && value < nextVal {
                return mid
            } else if value < midVal {
                high = mid - 1
            } else {
                low = mid + 1
            }
        }
        
        return nil
    }
    
    /// Computes cumulative offsets from a list of sizes.
    /// - Parameter sizes: List of widths or heights.
    /// - Parameter spacing: Spacing between elements.
    /// - Returns: Array of offsets starting at 0.
    public static func computeCumulative(sizes: [CGFloat], spacing: CGFloat) -> [CGFloat] {
        var offsets: [CGFloat] = [0]
        var current: CGFloat = 0
        for size in sizes {
            current += size + spacing
            offsets.append(current)
        }
        return offsets
    }
}
