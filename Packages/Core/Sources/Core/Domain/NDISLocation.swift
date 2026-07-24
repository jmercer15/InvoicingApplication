import Foundation

public struct NDISLocation: Sendable {
    public let postcode: String
    public let suburb: String?
    public let state: String?
    public let latitude: Double?
    public let longitude: Double?

    public init(
        postcode: String,
        suburb: String? = nil,
        state: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.postcode = postcode
        self.suburb = suburb
        self.state = state
        self.latitude = latitude
        self.longitude = longitude
    }
}
