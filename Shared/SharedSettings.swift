import Foundation

/// Settings the app writes and the widget extension reads, stored in the shared App Group container.
enum SharedSettings {
    /// Team-prefixed App Group (macOS accepts these without registering a `group.` identifier).
    static let appGroup = "VBTQQJK27C.com.camosec.openbell"
    static let store = UserDefaults(suiteName: appGroup) ?? .standard

    static let showDialCardsKey = "showDialCards"
    /// Widget kind of the large dial widget, so the app can reload it when the setting changes.
    static let dialWidgetKind = "SessionsDial"

    static var showDialCards: Bool {
        store.object(forKey: showDialCardsKey) as? Bool ?? true
    }

    /// One-time copy of the value saved before the setting moved to the App Group.
    static func migrateFromStandardDefaults() {
        let old = UserDefaults.standard
        guard store.object(forKey: showDialCardsKey) == nil,
              let value = old.object(forKey: showDialCardsKey) as? Bool else { return }
        store.set(value, forKey: showDialCardsKey)
        old.removeObject(forKey: showDialCardsKey)
    }
}
