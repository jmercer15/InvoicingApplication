import Foundation

/// Parses Hub duration text fields into total minutes.
/// Supports `"1h 30m"`, `"90m"`, `"1.5h"`, `"1:30"`, and bare minute values (`"90"`).
public enum BillingHubDurationParser {
    public static func totalMinutes(from string: String) -> Int? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let hours = Int(parts[0]),
                  let minutes = Int(parts[1]),
                  hours >= 0,
                  minutes >= 0,
                  minutes < 60
            else { return nil }
            return hours * 60 + minutes
        }

        var hours: Double = 0
        var minutes: Double = 0
        var matchedUnit = false
        let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)

        if let hourRegex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*h"#),
           let match = hourRegex.firstMatch(in: trimmed, range: nsRange),
           let range = Range(match.range(at: 1), in: trimmed),
           let value = Double(trimmed[range]) {
            hours = value
            matchedUnit = true
        }

        if let minuteRegex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*m"#),
           let match = minuteRegex.firstMatch(in: trimmed, range: nsRange),
           let range = Range(match.range(at: 1), in: trimmed),
           let value = Double(trimmed[range]) {
            minutes = value
            matchedUnit = true
        }

        if matchedUnit {
            let total = Int((hours * 60 + minutes).rounded())
            return total > 0 ? total : nil
        }

        if let plain = Double(trimmed.replacingOccurrences(of: ",", with: ".")) {
            let total = Int(plain.rounded())
            return total > 0 ? total : nil
        }

        return nil
    }
}
