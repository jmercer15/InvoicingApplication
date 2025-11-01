import Foundation

public extension Bundle {
    /// Bundle that contains assets and resources for the SharedUI module.
    static var sharedUI: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }
}
