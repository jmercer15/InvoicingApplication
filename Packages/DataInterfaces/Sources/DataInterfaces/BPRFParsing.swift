import Core
import Foundation

/// Parses NDIA BPRF (feedback) files into normalized result lines.
public protocol BPRFParsing: Sendable {
    func parse(data: Data) throws -> [BPRFResultLine]
}
