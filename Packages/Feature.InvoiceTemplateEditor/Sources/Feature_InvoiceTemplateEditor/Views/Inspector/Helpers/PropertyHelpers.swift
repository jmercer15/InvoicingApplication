import Foundation

// MARK: - Property Helper Functions

/// Sanitizes a hex color string by removing the '#' prefix and converting to uppercase
/// - Parameter hex: The hex color string (with or without '#')
/// - Returns: Cleaned hex string in uppercase without '#'
func sanitizedHex(_ hex: String) -> String {
    let cleaned = hex.replacingOccurrences(of: "#", with: "").uppercased()
    return cleaned
}

