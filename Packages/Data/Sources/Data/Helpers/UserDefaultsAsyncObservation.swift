import Foundation

extension UserDefaults: @retroactive @unchecked Sendable {}

public extension UserDefaults {
    func observedValue<Value: Sendable>(
        forKey key: String,
        as type: Value.Type
    ) -> AsyncStream<Value?> {
        let (stream, continuation) = AsyncStream.makeStream(of: Value?.self)
        let observer = UserDefaultsKeyObserver<Value> { value in
            continuation.yield(value)
        }

        addObserver(observer, forKeyPath: key, options: [.initial, .new], context: nil)
        continuation.onTermination = { [weak self, observer] _ in
            self?.removeObserver(observer, forKeyPath: key)
        }

        return stream
    }
}

private final class UserDefaultsKeyObserver<Value: Sendable>: NSObject, @unchecked Sendable {
    private let onUpdate: @Sendable (Value?) -> Void

    init(onUpdate: @escaping @Sendable (Value?) -> Void) {
        self.onUpdate = onUpdate
        super.init()
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard let rawValue = change?[.newKey], !(rawValue is NSNull) else {
            onUpdate(nil)
            return
        }

        if let value = rawValue as? Value {
            onUpdate(value)
            return
        }

        if Value.self == Double.self, let number = rawValue as? NSNumber {
            onUpdate(number.doubleValue as? Value)
            return
        }

        if Value.self == Bool.self, let number = rawValue as? NSNumber {
            onUpdate(number.boolValue as? Value)
            return
        }

        if Value.self == Int.self, let number = rawValue as? NSNumber {
            onUpdate(number.intValue as? Value)
            return
        }

        onUpdate(nil)
    }
}
