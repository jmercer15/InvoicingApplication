import Foundation
import Observation

@Observable
@MainActor
public final class ProfileViewModel {
    private enum DefaultsKey {
        static let name = "userName"
        static let email = "userEmail"
        static let phone = "userPhone"
        static let role = "userRole"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var observationTasks: [Task<Void, Never>] = []
    @ObservationIgnored private var isApplyingExternalDefaults = false

    var name: String = "" {
        didSet { write(name, forKey: DefaultsKey.name, oldValue: oldValue) }
    }
    var email: String = "" {
        didSet { write(email, forKey: DefaultsKey.email, oldValue: oldValue) }
    }
    var phone: String = "" {
        didSet { write(phone, forKey: DefaultsKey.phone, oldValue: oldValue) }
    }
    var role: String = "" {
        didSet { write(role, forKey: DefaultsKey.role, oldValue: oldValue) }
    }

    var validationErrors: [String: String] = [:]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        applyExternalDefaults {
            name = defaults.string(forKey: DefaultsKey.name) ?? ""
            email = defaults.string(forKey: DefaultsKey.email) ?? ""
            phone = defaults.string(forKey: DefaultsKey.phone) ?? ""
            role = defaults.string(forKey: DefaultsKey.role) ?? ""
        }
        startObservation()
    }

    public func save() {
        _ = validate()
    }

    public func validate() -> Bool {
        validationErrors = [:]

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationErrors["name"] = "Name cannot be empty"
        }

        if !email.isEmpty {
            let emailPattern = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
            let predicate = NSPredicate(format: "SELF MATCHES %@", emailPattern)
            if !predicate.evaluate(with: email) {
                validationErrors["email"] = "Invalid email format"
            }
        }

        return validationErrors.isEmpty
    }

    private func startObservation() {
        observeString(DefaultsKey.name) { [weak self] value in self?.name = value }
        observeString(DefaultsKey.email) { [weak self] value in self?.email = value }
        observeString(DefaultsKey.phone) { [weak self] value in self?.phone = value }
        observeString(DefaultsKey.role) { [weak self] value in self?.role = value }
    }

    private func observeString(
        _ key: String,
        apply: @escaping @MainActor @Sendable (String) -> Void
    ) {
        observationTasks.append(Task { [weak self, defaults] in
            for await newValue in defaults.observedValue(forKey: key, as: String.self) {
                self?.applyObservedString(newValue ?? "", apply: apply)
            }
        })
    }

    private func applyObservedString(
        _ value: String,
        apply: @escaping @MainActor @Sendable (String) -> Void
    ) {
        applyExternalDefaults {
            apply(value)
        }
    }

    private func write(_ value: String, forKey key: String, oldValue: String) {
        guard !isApplyingExternalDefaults, value != oldValue else { return }
        defaults.set(value, forKey: key)
    }

    private func applyExternalDefaults(_ apply: () -> Void) {
        isApplyingExternalDefaults = true
        apply()
        isApplyingExternalDefaults = false
    }

deinit {
        observationTasks.forEach { $0.cancel() }
    }
}
