import Foundation
import AppKit

public struct RichTextContent: Codable, Equatable, @unchecked Sendable {
    public var storage: NSAttributedString
    
    public init(string: String = "") {
        self.storage = NSAttributedString(string: string)
    }
    
    public init(storage: NSAttributedString) {
        self.storage = storage
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case rtf
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try container.decode(Data.self, forKey: .rtf)
        if let attributedString = NSAttributedString(rtf: data, documentAttributes: nil) {
            self.storage = attributedString
        } else {
            self.storage = NSAttributedString()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let data = storage.rtf(from: NSRange(location: 0, length: storage.length), documentAttributes: [:])
        try container.encode(data, forKey: .rtf)
    }
    
    // MARK: - Equatable
    public static func == (lhs: RichTextContent, rhs: RichTextContent) -> Bool {
        lhs.storage.isEqual(to: rhs.storage)
    }
    
    public mutating func append(_ other: RichTextContent) {
        let mutable = NSMutableAttributedString(attributedString: storage)
        if mutable.length > 0 && other.storage.length > 0 {
            mutable.append(NSAttributedString(string: "\n"))
        }
        mutable.append(other.storage)
        self.storage = mutable
    }
}
