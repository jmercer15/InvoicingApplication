import Foundation

public enum EventURLTokenCodec {
    public struct DecodedPayload: Equatable, Sendable {
        public let token: String
        public let userURL: URL?

        public init(token: String, userURL: URL?) {
            self.token = token
            self.userURL = userURL
        }
    }

    public static let scheme = "invoicing"
    public static let host = "ek-token"
    public static let version = "1"

    public static func encode(token: String, userURL: URL?) -> URL? {
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedToken.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "v", value: version),
            URLQueryItem(name: "t", value: normalizedToken)
        ]
        if let userURL {
            queryItems.append(URLQueryItem(name: "u", value: userURL.absoluteString))
        }
        components.queryItems = queryItems
        return components.url
    }

    public static func decode(_ url: URL?) -> DecodedPayload? {
        guard let url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == scheme,
              components.host == host else {
            return nil
        }

        let queryItems = components.queryItems ?? []
        guard let parsedVersion = queryItems.first(where: { $0.name == "v" })?.value,
              parsedVersion == version else {
            return nil
        }

        guard let token = queryItems.first(where: { $0.name == "t" })?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !token.isEmpty else {
            return nil
        }

        let userURLString = queryItems.first(where: { $0.name == "u" })?.value
        let userURL = userURLString.flatMap(URL.init(string:))
        return DecodedPayload(token: token, userURL: userURL)
    }

    public static func split(_ url: URL?) -> (token: String?, userURL: URL?) {
        if let decoded = decode(url) {
            return (decoded.token, decoded.userURL)
        }
        return (nil, url)
    }

    public static func merge(token: String?, existingURL: URL?) -> URL? {
        guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return split(existingURL).userURL
        }
        let userURL = split(existingURL).userURL
        return encode(token: token, userURL: userURL)
    }
}
