import SwiftUI
import Testing

import SwiftTerm
@testable import CodeX

struct SettingsStoreTests {

    @MainActor
    @Test func settingsStorePersistsEditorThemeAndTerminalRuntimePreferences() {
        let (defaults, key) = makeIsolatedDefaults()

        let store = SettingsStore(userDefaults: defaults, storageKey: key)
        store.updateEditor {
            $0.font_size = 15
            $0.wrap_lines = true
            $0.show_line_numbers = false
            $0.use_system_cursor = false
            $0.show_minimap = true
        }
        store.updateTerminal {
            $0.theme = .dark
            $0.font = .menlo
            $0.font_size = 15
            $0.cursor_style = .steadyBar
        }
        store.setEditorTheme(.xcodeLight)

        let reloaded = SettingsStore(userDefaults: defaults, storageKey: key)
        #expect(reloaded.settings.editor.font_size == 15)
        #expect(reloaded.settings.editor.wrap_lines)
        #expect(reloaded.settings.editor.show_line_numbers == false)
        #expect(reloaded.settings.editor.use_system_cursor == false)
        #expect(reloaded.settings.editor.show_minimap)
        #expect(reloaded.settings.editorTheme == .xcodeLight)
        #expect(reloaded.settings.terminal.theme == .dark)
        #expect(reloaded.settings.terminal.font == .menlo)
        #expect(reloaded.settings.terminal.font_size == 15)
        #expect(reloaded.settings.terminal.cursor_style == .steadyBar)
        #expect(reloaded.settings.terminal.resolved_font.pointSize == 15)
        #expect(reloaded.settings.terminal.resolved_cursor_style == .steadyBar)
    }

    @Test func terminalSettingsDecodeLegacyPayloadUsingDefaults() throws {
        let legacyPayload = Data(#"{"theme":"dark"}"#.utf8)

        let decoded = try JSONDecoder().decode(TerminalSettings.self, from: legacyPayload)

        #expect(decoded.theme == .dark)
        #expect(decoded.font == .systemMonospaced)
        #expect(decoded.font_size == NSFont.systemFontSize)
        #expect(decoded.cursor_style == .blinkBlock)
        #expect(decoded.resolved_cursor_style == .blinkBlock)
    }

    @MainActor
    @Test func editorViewModelBuildsConfigurationFromSharedSettingsStore() {
        let store = SettingsStore(userDefaults: UserDefaults(), storageKey: UUID().uuidString)
        let viewModel = EditorViewModel(settingsStore: store)

        store.updateEditor {
            $0.font_size = 16
            $0.tab_width = 2
            $0.wrap_lines = true
            $0.show_line_numbers = false
            $0.use_system_cursor = false
            $0.show_minimap = true
        }

        let darkConfig = viewModel.editorConfiguration(for: .dark)
        #expect(darkConfig.font.pointSize == 16)
        #expect(darkConfig.tabWidth == 2)
        #expect(darkConfig.wrapLines)
        #expect(darkConfig.showLineNumbers == false)
        #expect(darkConfig.useSystemCursor == false)
        #expect(darkConfig.showMinimap)
        #expect(darkConfig.theme == .dark)

        store.setEditorTheme(.xcodeLight)
        let lightConfig = viewModel.editorConfiguration(for: .dark)
        #expect(lightConfig.theme == .light)
    }

    @MainActor
    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, UUID().uuidString)
    }
}