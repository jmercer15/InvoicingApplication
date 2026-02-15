import SwiftUI

struct IsMeasuringIdealSizeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isMeasuringIdealSize: Bool {
        get { self[IsMeasuringIdealSizeKey.self] }
        set { self[IsMeasuringIdealSizeKey.self] = newValue }
    }
}
