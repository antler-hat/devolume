import Foundation

struct ProcessRule: Hashable {
    let identifier: String
    let displayName: String
}

final class ProcessRuleStore {
    static let didChangeNotification = Notification.Name("ProcessRuleStoreDidChange")

    private let defaults: UserDefaults
    private let storageKey = "ProcessRuleStore.savedRules"
    private let notificationCenter: NotificationCenter

    init(
        defaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default
    ) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
    }

    func allRules() -> [ProcessRule] {
        let dictionary = storedDictionary()
        return dictionary
            .map { ProcessRule(identifier: $0.key, displayName: $0.value) }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    func addRules(for processes: [ProcessInfo]) {
        guard !processes.isEmpty else { return }

        var dictionary = storedDictionary()
        var didChange = false

        for process in processes {
            let displayName = sanitizedDisplayName(from: process.name)
            guard !displayName.isEmpty else { continue }
            let identifier = normalizedIdentifier(from: process.name)
            if dictionary[identifier] == nil {
                dictionary[identifier] = displayName
                didChange = true
            }
        }

        if didChange {
            defaults.set(dictionary, forKey: storageKey)
            notificationCenter.post(name: Self.didChangeNotification, object: self)
        }
    }

    func removeRule(withIdentifier identifier: String) {
        var dictionary = storedDictionary()
        guard dictionary.removeValue(forKey: identifier) != nil else { return }
        defaults.set(dictionary, forKey: storageKey)
        notificationCenter.post(name: Self.didChangeNotification, object: self)
    }

    func removeRules(withIdentifiers identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        var dictionary = storedDictionary()
        var didChange = false
        for identifier in identifiers {
            if dictionary.removeValue(forKey: identifier) != nil {
                didChange = true
            }
        }
        if didChange {
            defaults.set(dictionary, forKey: storageKey)
            notificationCenter.post(name: Self.didChangeNotification, object: self)
        }
    }

    func containsRule(for processName: String) -> Bool {
        let identifier = normalizedIdentifier(from: processName)
        return storedDictionary()[identifier] != nil
    }

    @discardableResult
    func removeRule(for processName: String) -> Bool {
        let identifier = normalizedIdentifier(from: processName)
        var dictionary = storedDictionary()
        guard dictionary.removeValue(forKey: identifier) != nil else { return false }
        defaults.set(dictionary, forKey: storageKey)
        notificationCenter.post(name: Self.didChangeNotification, object: self)
        return true
    }

    private func storedDictionary() -> [String: String] {
        (defaults.dictionary(forKey: storageKey) as? [String: String]) ?? [:]
    }

    private func normalizedIdentifier(from processName: String) -> String {
        processName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func sanitizedDisplayName(from processName: String) -> String {
        processName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
