import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    private let userDefaults: UserDefaults
    private let storageKey: String

    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            persist()
        }
    }

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "CodeX.appSettings"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.settings = Self.load(from: userDefaults, storageKey: storageKey)
    }

    func update(_ mutate: (inout AppSettings) -> Void) {
        var draft = settings
        mutate(&draft)
        settings = draft
    }

    func updateEditor(_ mutate: (inout EditorSettings) -> Void) {
        update { mutate(&$0.editor) }
    }

    func updateTerminal(_ mutate: (inout TerminalSettings) -> Void) {
        update { mutate(&$0.terminal) }
    }

    func setEditorTheme(_ preference: EditorThemePreference) {
        update { $0.editorTheme = preference }
    }

    func reset() {
        settings = AppSettings()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to persist app settings: \(error)")
        }
    }

    private static func load(from userDefaults: UserDefaults, storageKey: String) -> AppSettings {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return AppSettings()
        }

        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            assertionFailure("Failed to decode app settings, falling back to defaults: \(error)")
            return AppSettings()
        }
    }
}