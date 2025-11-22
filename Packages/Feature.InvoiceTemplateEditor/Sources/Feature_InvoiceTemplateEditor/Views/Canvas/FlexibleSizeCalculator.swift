//
//  FlexibleSizeCalculator.swift
//  Feature.InvoiceTemplateEditor
//
//  Helper to calculate sizes based on sizing modes (Fixed, Expand, Shrink)
//

import SwiftUI
import Core

struct FlexibleSizeCalculator {
    
    /// Calculate sizes for a linear layout (row or column)
    /// - Parameters:
    ///   - totalSize: The total available size (width or height)
    ///   - count: Number of items
    ///   - ratios: Array of ratios for Fixed items (should sum to 1.0 ideally, but we handle it)
    ///   - sizingModes: Array of sizing modes for each item
    ///   - intrinsicSizes: Map of item index to its intrinsic size (for Shrink mode)
    /// - Returns: Array of calculated sizes
    static func calculateSizes(
        totalSize: CGFloat,
        count: Int,
        ratios: [CGFloat],
        sizingModes: [SectionSplit.SizingMode],
        intrinsicSizes: [Int: CGFloat]
    ) -> [CGFloat] {
        var sizes = Array(repeating: CGFloat(0), count: count)
        var remainingSize = totalSize
        
        // 1. Calculate Shrink items
        for i in 0..<count {
            if i < sizingModes.count && sizingModes[i] == .shrink {
                let size = intrinsicSizes[i] ?? 50 // Default min size if unknown
                sizes[i] = size
                remainingSize -= size
            }
        }
        
        // Ensure remaining size is not negative
        remainingSize = max(0, remainingSize)
        
        // 2. Calculate Fixed items
        // Fixed items take a ratio of the *remaining* space?
        // Or ratio of *total* space?
        // Standard behavior: Ratio usually means "Ratio of Container".
        // But if Shrink items take space, Fixed items might overflow.
        // Let's assume Fixed items are proportional to the *available* space for non-Shrink items.
        // But "Expand" items also need space.
        
        // Let's try: Fixed items take (Ratio * TotalSize).
        // If that leaves no space for Expand, then Expand gets 0.
        // If Fixed + Shrink > TotalSize, we scale down?
        
        // Alternative: Fixed items take (Ratio * RemainingSize after Shrink).
        // This makes Fixed items depend on Shrink items.
        
        // Let's go with: Fixed items are calculated based on the *original* ratios relative to the *flexible* space.
        // But we have "Expand" items which are essentially "Auto" ratio.
        
        // Let's define:
        // Shrink: Absolute size.
        // Fixed: Proportional size (based on its ratio).
        // Expand: Shares remaining space equally.
        
        // Problem: Ratios sum to 1.0 usually.
        // If we have 1 Shrink item, and 2 Fixed items (0.5, 0.5).
        // Shrink takes 100. Remaining 900.
        // Fixed 1 takes 0.5 * 900 = 450.
        // Fixed 2 takes 0.5 * 900 = 450.
        // This works well.
        
        // What if we have 1 Expand item?
        // Fixed (0.5), Expand.
        // Ratios might be [0.5, 0.5] initially.
        // If user changes item 2 to Expand.
        // We ignore item 2's ratio?
        // Then item 1 takes 0.5 * 900 = 450.
        // Remaining 450 goes to Expand.
        // This seems consistent.
        
        // So:
        // 1. Subtract Shrink sizes from Total.
        // 2. Identify Fixed and Expand items.
        // 3. Sum ratios of Fixed items.
        // 4. If Expand items exist:
        //    - Distribute (FixedRatio / TotalFixedRatio) * (Remaining - ExpandAllocation)?
        //    - No, that's complicated.
        
        // Simpler model:
        // Fixed items have a specific ratio. We respect that ratio relative to the *flexible space*.
        // Expand items share the *rest*.
        // But what if Fixed items take 100%? Then Expand gets 0.
        
        // Let's refine "Fixed".
        // "Fixed" means "I want to control the size manually (via ratio)".
        // "Expand" means "I want to fill available space".
        
        // Algorithm:
        // 1. Calculate Shrink sizes. Deduct from Total. -> `flexibleSpace`
        // 2. Calculate Fixed sizes:
        //    - For each Fixed item, size = ratio * flexibleSpace.
        //    - Wait, if I have Fixed (0.2) and Expand.
        //    - Does Fixed take 0.2 of flexibleSpace? Then Expand takes 0.8?
        //    - But Expand doesn't have a ratio.
        //    - If I have Fixed (0.2) and Fixed (0.2) and Expand.
        //    - Fixed takes 0.2 + 0.2 = 0.4. Expand takes 0.6.
        //    - This implies Expand items effectively take up the "unused" ratio.
        //    - But what if Ratios sum to 1.0 (which they do)?
        //    - Then Fixed (0.5) + Fixed (0.5) leaves 0 for Expand.
        //    - This is bad UX.
        
        // Better Algorithm:
        // Treat "Expand" items as having a weight.
        // Treat "Fixed" items as having a weight (their ratio).
        // But we want Expand to "fill remaining".
        
        // Let's look at CSS Grid `fr`.
        // Fixed (px) -> Shrink.
        // Ratio (%) -> Fixed.
        // Fr -> Expand.
        
        // If we treat "Fixed" as "Percentage of Flexible Space".
        // And "Expand" as "Share of remaining space after Fixed".
        // If Fixed items sum to 100%, Expand gets nothing.
        // We need to normalize Fixed ratios if Expand exists?
        
        // Proposal:
        // 1. Shrink items take their size.
        // 2. Remaining space is `availableSpace`.
        // 3. Calculate Fixed items size = `ratio * availableSpace`.
        // 4. Sum of Fixed sizes = `totalFixedSize`.
        // 5. If `totalFixedSize` < `availableSpace`:
        //    - `remainingForExpand` = `availableSpace` - `totalFixedSize`.
        //    - Distribute `remainingForExpand` equally among Expand items.
        // 6. If `totalFixedSize` >= `availableSpace` (or no Expand items):
        //    - Normalize Fixed items to fit `availableSpace`.
        //    - Expand items get 0 (or min size).
        
        // This works if user manually adjusts ratios to make space for Expand.
        // But initially ratios sum to 1.
        // So if I switch one item to Expand, I should probably *remove* its ratio from the sum?
        // Yes. If I switch item 2 to Expand, I ignore its ratio.
        // Item 1 (Fixed 0.5) takes 0.5.
        // Item 2 (Expand) takes remainder.
        // But wait, if I have 2 items, 0.5 each.
        // Switch item 2 to Expand.
        // Item 1 takes 0.5 * available.
        // Item 2 takes 0.5 * available.
        // It looks the same.
        
        // What if I have 3 items: 0.33, 0.33, 0.33.
        // Switch item 3 to Expand.
        // Item 1: 0.33. Item 2: 0.33. Total Fixed: 0.66.
        // Item 3 (Expand): 0.34.
        // This works!
        
        // What if I have 3 items: 0.33, 0.33, 0.33.
        // Switch item 2 AND 3 to Expand.
        // Item 1: 0.33.
        // Remaining: 0.67.
        // Item 2: 0.335. Item 3: 0.335.
        // This works!
        
        // What if I have 1 item Fixed (1.0) and 1 Expand.
        // Fixed takes 100%. Expand takes 0.
        // This is expected. The user must lower the Fixed ratio to give space to Expand.
        // Or we can enforce a max ratio for Fixed items if Expand exists?
        // No, let the user control it.
        
        // Implementation:
        var flexibleSpace = remainingSize
        var usedFixedSpace: CGFloat = 0
        var expandCount = 0
        
        for i in 0..<count {
            if i < sizingModes.count {
                switch sizingModes[i] {
                case .fixed:
                    // Use ratio.
                    // Note: ratios array might be larger/smaller than count if not synced, handle safely.
                    let ratio = (i < ratios.count) ? ratios[i] : 0
                    let size = ratio * flexibleSpace
                    sizes[i] = size
                    usedFixedSpace += size
                case .expand:
                    expandCount += 1
                case .shrink:
                    // Already handled
                    break
                }
            } else {
                // Default to fixed if mode missing
                let ratio = (i < ratios.count) ? ratios[i] : 0
                let size = ratio * flexibleSpace
                sizes[i] = size
                usedFixedSpace += size
            }
        }
        
        // Distribute remaining to Expand
        if expandCount > 0 {
            let remainingForExpand = max(0, flexibleSpace - usedFixedSpace)
            let sizePerExpand = remainingForExpand / CGFloat(expandCount)
            
            for i in 0..<count {
                if i < sizingModes.count && sizingModes[i] == .expand {
                    sizes[i] = sizePerExpand
                }
            }
        } else if usedFixedSpace > flexibleSpace {
            // Normalize Fixed items if they exceed space (e.g. due to rounding or Shrink items taking too much)
            // Or if we have no Expand items but Fixed items don't sum to 100% of flexible space (unlikely if ratios sum to 1)
            // Actually, if ratios sum to 1, usedFixedSpace == flexibleSpace.
            // If ratios sum to < 1 (because we ignored Expand items' ratios), then usedFixedSpace < flexibleSpace.
            // And we have no Expand items? (Contradiction: we ignored ratios because they were Expand).
            // Wait, if I have Fixed (0.5) and Shrink.
            // Ratios sum to 1? No, usually ratios sum to 1 for *all* items.
            // If item 2 is Shrink, its ratio is still in the array (e.g. 0.5).
            // But we ignore it for sizing.
            // So Fixed item (0.5) takes 0.5 * flexibleSpace.
            // Shrink item takes fixed size.
            // Remaining 0.5 * flexibleSpace is unused?
            // If we have no Expand items, we should probably distribute the unused space to Fixed items.
            
            // Refined Logic for "No Expand Items":
            // If expandCount == 0:
            // Re-distribute remaining flexible space to Fixed items proportionally to their ratios.
            
            let remainingUnused = flexibleSpace - usedFixedSpace
            if remainingUnused > 0 {
                // Sum of ratios of Fixed items
                var totalFixedRatio: CGFloat = 0
                for i in 0..<count {
                    if i < sizingModes.count && sizingModes[i] == .fixed {
                        totalFixedRatio += (i < ratios.count) ? ratios[i] : 0
                    }
                }
                
                if totalFixedRatio > 0 {
                    for i in 0..<count {
                        if i < sizingModes.count && sizingModes[i] == .fixed {
                            let ratio = (i < ratios.count) ? ratios[i] : 0
                            let extra = remainingUnused * (ratio / totalFixedRatio)
                            sizes[i] += extra
                        }
                    }
                }
            }
        }
        
        return sizes
    }
}
