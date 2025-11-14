//
//  ResizeHelpers.swift
//  Feature.InvoiceTemplateEditor
//
//  Shared helper functions for safe resize calculations
//

import SwiftUI

/// Safely calculates new ratios for resize operations, handling edge cases
/// - Parameters:
///   - delta: The drag delta (in points)
///   - containerSize: The container size dimension (width for horizontal, height for vertical)
///   - currentRatio: The current ratio of the section being expanded
///   - nextRatio: The current ratio of the adjacent section being compressed
///   - minRatio: Minimum allowed ratio (default: 0.05)
///   - maxRatio: Maximum allowed ratio (default: 0.95)
/// - Returns: Tuple of (newCurrentRatio, newNextRatio) normalized to sum to currentRatio + nextRatio
func safeResizeRatios(
    delta: CGFloat,
    containerSize: CGFloat,
    currentRatio: CGFloat,
    nextRatio: CGFloat,
    minRatio: CGFloat = 0.05,
    maxRatio: CGFloat = 0.95
) -> (current: CGFloat, next: CGFloat) {
        // Edge case: Zero or negative container size
        guard containerSize > 0 else {
            return (current: currentRatio, next: nextRatio)
        }
        
        // Calculate ratio change, but clamp it to prevent extreme values
        let rawRatioChange = delta / containerSize
        let maxRatioChange = min(abs(rawRatioChange), 0.5) // Prevent more than 50% change in one drag
        let ratioChange = rawRatioChange > 0 ? maxRatioChange : -maxRatioChange
        
        // Calculate new ratios before clamping
        let newCurrentRatioRaw = currentRatio + ratioChange
        let newNextRatioRaw = nextRatio - ratioChange
        
        // Clamp ratios to valid range
        let newCurrentRatioClamped = max(minRatio, min(maxRatio, newCurrentRatioRaw))
        let newNextRatioClamped = max(minRatio, min(maxRatio, newNextRatioRaw))
        
        // Calculate how much we actually changed (after clamping)
        let actualCurrentChange = newCurrentRatioClamped - currentRatio
        let actualNextChange = newNextRatioClamped - nextRatio
        
        // If one ratio hit a boundary, adjust the other proportionally
        let totalRatio = currentRatio + nextRatio
        let newCurrentRatio: CGFloat
        let newNextRatio: CGFloat
        
        if abs(actualCurrentChange) < abs(ratioChange) {
            // Current ratio hit a boundary, adjust next ratio to maintain total
            newCurrentRatio = newCurrentRatioClamped
            newNextRatio = max(minRatio, min(maxRatio, totalRatio - newCurrentRatio))
        } else if abs(actualNextChange) < abs(ratioChange) {
            // Next ratio hit a boundary, adjust current ratio to maintain total
            newNextRatio = newNextRatioClamped
            newCurrentRatio = max(minRatio, min(maxRatio, totalRatio - newNextRatio))
        } else {
            // Both ratios within bounds, use clamped values
            newCurrentRatio = newCurrentRatioClamped
            newNextRatio = newNextRatioClamped
        }
        
        // Final normalization: ensure ratios sum to original total (handles floating point errors)
        let finalTotal = newCurrentRatio + newNextRatio
        let scaleFactor = totalRatio / finalTotal
        
        return (
            current: newCurrentRatio * scaleFactor,
            next: newNextRatio * scaleFactor
        )
    }


