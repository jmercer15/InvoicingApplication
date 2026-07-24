import Foundation

/// Cross-layer portion of persisted invoice-editor state.
///
/// Editor owns richer presentation fields. Core and Data only decode semantic
/// fields needed by invoice calculations and creation workflows. Codable
/// ignores unknown editor-owned keys, preserving package dependency direction.
public struct InvoiceEditorConfiguration: Codable, Equatable, Sendable {
    public static let currentVersion = 4

    public var version: Int
    public var title: String
    public var billParticipantDirectly: Bool
    public var billToPhone: String
    public var discountAmount: Decimal
    public var showsTaxSummary: Bool

    public init(
        version: Int = currentVersion,
        title: String = "Tax Invoice",
        billParticipantDirectly: Bool = true,
        billToPhone: String = "",
        discountAmount: Decimal = 0,
        showsTaxSummary: Bool = true
    ) {
        self.version = version
        self.title = title
        self.billParticipantDirectly = billParticipantDirectly
        self.billToPhone = billToPhone
        self.discountAmount = max(0, discountAmount)
        self.showsTaxSummary = showsTaxSummary
    }

    public init(data: Data?) {
        guard let data,
              let decoded = try? JSONDecoder().decode(Self.self, from: data)
        else {
            self.init()
            return
        }
        self = decoded
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case title
        case billParticipantDirectly
        case billToPhone
        case discountAmount
        case showsTaxSummary
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            version: try container.decodeIfPresent(Int.self, forKey: .version) ?? 1,
            title: try container.decodeIfPresent(String.self, forKey: .title) ?? "Tax Invoice",
            billParticipantDirectly: try container.decodeIfPresent(
                Bool.self,
                forKey: .billParticipantDirectly
            ) ?? true,
            billToPhone: try container.decodeIfPresent(String.self, forKey: .billToPhone) ?? "",
            discountAmount: try container.decodeIfPresent(Decimal.self, forKey: .discountAmount) ?? 0,
            showsTaxSummary: try container.decodeIfPresent(Bool.self, forKey: .showsTaxSummary) ?? true
        )
    }
}
