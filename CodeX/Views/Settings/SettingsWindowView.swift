import AppKit
import SwiftUI
import CodeXEditor

private enum SettingsSidebarItem: String, CaseIterable, Hashable, Identifiable {
    case themes
    case editor
    case terminal

    var id: Self { self }

    var title: String {
        switch self {
        case .themes: "Themes"
        case .editor: "Editor"
        case .terminal: "Terminal"
        }
    }

    var systemImage: String {
        switch self {
        case .themes: "paintpalette"
        case .editor: "text.alignleft"
        case .terminal: "terminal"
        }
    }

    var summary: String {
        switch self {
        case .themes: "Editor + terminal appearance"
        case .editor: "Editing behavior and layout"
        case .terminal: "Appearance and launcher"
        }
    }
}

struct SettingsWindowView: View {
    @State private var selection: SettingsSidebarItem = .themes
    @State private var settingsWindow: NSWindow?
    @State private var pendingWindowFrontRetention = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            Group {
                switch selection {
                case .themes:
                    ThemesSettingsView(onSettingMutation: keepSettingsWindowInFront)
                case .editor:
                    EditorSettingsView(onSettingMutation: keepSettingsWindowInFront)
                case .terminal:
                    TerminalSettingsView(onSettingMutation: keepSettingsWindowInFront)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 840, minHeight: 540)
        .background(Color(nsColor: .windowBackgroundColor))
        .background {
            SettingsWindowAccessor { window in
                guard settingsWindow !== window else { return }
                settingsWindow = window
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.title2.weight(.semibold))
                Text("Xcode-style preferences shell")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                ForEach(SettingsSidebarItem.allCases) { item in
                    Button {
                        selection = item
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.systemImage)
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(item.summary)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(background(for: item), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 240)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
    }

    private func background(for item: SettingsSidebarItem) -> AnyShapeStyle {
        selection == item
            ? AnyShapeStyle(Color.accentColor.opacity(0.18))
            : AnyShapeStyle(Color.clear)
    }

    private func keepSettingsWindowInFront() {
        guard !pendingWindowFrontRetention else { return }

        pendingWindowFrontRetention = true

        DispatchQueue.main.async {
            pendingWindowFrontRetention = false

            guard
                let settingsWindow,
                settingsWindow.isVisible,
                NSApp.isActive
            else {
                return
            }

            settingsWindow.makeKeyAndOrderFront(nil)
        }
    }
}

private struct ThemesSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.colorScheme) private var colorScheme
    let onSettingMutation: () -> Void

    var body: some View {
        let settings = settingsStore.settings

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Themes")
                            .font(.largeTitle.weight(.semibold))
                        Text("Choose the editor appearance and use this page as a quick visual overview for themed surfaces across the app.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 16)

                    Button("Restore Defaults") {
                        settingsStore.reset()
                        onSettingMutation()
                    }
                }

                SettingsCard(
                    title: "Theme Selection",
                    description: "Editor appearance persists immediately. Terminal appearance now lives on the dedicated Terminal page."
                ) {
                    SettingsControlRow(
                        title: "Editor theme",
                        description: "Pick a fixed Xcode palette or follow the current macOS appearance."
                    ) {
                        Picker("Editor Theme", selection: editorThemeBinding) {
                            ForEach(EditorThemePreference.allCases, id: \.self) { preference in
                                Text(preference.displayName).tag(preference)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        editorPreviewCard(settings: settings.editor)
                        terminalPreviewCard()
                    }

                    VStack(spacing: 20) {
                        editorPreviewCard(settings: settings.editor)
                        terminalPreviewCard()
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 920, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var editorThemeBinding: Binding<EditorThemePreference> {
        Binding(
            get: { settingsStore.settings.editorTheme },
            set: {
                settingsStore.setEditorTheme($0)
                onSettingMutation()
            }
        )
    }

    private func editorPreviewCard(settings: EditorSettings) -> some View {
        SettingsCard(title: "Editor Preview") {
            EditorThemePreview(
                theme: settingsStore.settings.editorTheme.resolvedTheme(for: colorScheme),
                settings: settings
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func terminalPreviewCard() -> some View {
        SettingsCard(title: "Terminal Preview") {
            TerminalThemePreview(
                colors: settingsStore.settings.terminal.theme.resolvedTheme(for: colorScheme),
                settings: settingsStore.settings.terminal
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct EditorSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.colorScheme) private var colorScheme
    let onSettingMutation: () -> Void

    var body: some View {
        let settings = settingsStore.settings

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Editor")
                            .font(.largeTitle.weight(.semibold))
                        Text("Tune the shared editor runtime. Every control on this page already maps to live configuration used by open editors.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 16)

                    Button("Reset Editor Defaults") {
                        updateEditor { $0 = EditorSettings() }
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        typographyCard
                        previewCard(settings: settings.editor)
                    }

                    VStack(spacing: 20) {
                        typographyCard
                        previewCard(settings: settings.editor)
                    }
                }

                SettingsCard(
                    title: "Layout & Behavior",
                    description: "These controls affect code layout, wrapping, and peripheral chrome in the current editor surface."
                ) {
                    SettingsControlRow(
                        title: "Tab width",
                        description: "Controls indentation width for the shared editor runtime."
                    ) {
                        Stepper(value: tabWidthBinding, in: 2...8) {
                            Text("\(tabWidthBinding.wrappedValue) spaces")
                                .font(.system(.body, design: .monospaced))
                        }
                        .frame(width: 160, alignment: .trailing)
                    }

                    Divider()

                    SettingsControlRow(
                        title: "Wrap lines",
                        description: "Soft-wrap long lines in the current editor."
                    ) {
                        Toggle("Wrap lines", isOn: wrapLinesBinding)
                            .labelsHidden()
                    }

                    Divider()

                    SettingsControlRow(
                        title: "Show line numbers",
                        description: "Toggle the gutter numbering in the current editor surface."
                    ) {
                        Toggle("Show line numbers", isOn: showLineNumbersBinding)
                            .labelsHidden()
                    }

                    Divider()

                    SettingsControlRow(
                        title: "Show minimap",
                        description: "Show a compressed code overview rail on the trailing edge of each editor."
                    ) {
                        Toggle("Show minimap", isOn: showMinimapBinding)
                            .labelsHidden()
                    }

                    Divider()

                    SettingsControlRow(
                        title: "Use system cursor",
                        description: "Use AppKit-default insertion caret styling instead of the theme cursor accent."
                    ) {
                        Toggle("Use system cursor", isOn: useSystemCursorBinding)
                            .labelsHidden()
                    }

                    Divider()

                    SettingsControlRow(
                        title: "Use theme background",
                        description: "Apply the selected theme background instead of the system text background color."
                    ) {
                        Toggle("Use theme background", isOn: useThemeBackgroundBinding)
                            .labelsHidden()
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 920, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var typographyCard: some View {
        SettingsCard(
            title: "Typography",
            description: "Font metrics are applied through the shared editor configuration and update open documents immediately."
        ) {
            SettingsControlRow(
                title: "Font family",
                description: "Current monospaced family resolved by the editor runtime. Font selection can be expanded in a later pass."
            ) {
                Text(settingsStore.settings.editor.font_name)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 200, alignment: .trailing)
            }

            Divider()

            SettingsControlRow(
                title: "Font size",
                description: "Base point size used by the shared editor configuration."
            ) {
                HStack(spacing: 10) {
                    Slider(value: fontSizeBinding, in: 11...24, step: 1)
                    Text("\(Int(fontSizeBinding.wrappedValue)) pt")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
                .frame(width: 240)
            }

            Divider()

            SettingsControlRow(
                title: "Line height",
                description: "Adjust vertical density without changing the font family."
            ) {
                HStack(spacing: 10) {
                    Slider(value: lineHeightBinding, in: 1.1...1.8, step: 0.05)
                    Text(String(format: "%.2f×", lineHeightBinding.wrappedValue))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
                .frame(width: 240)
            }

            Divider()

            SettingsControlRow(
                title: "Letter spacing",
                description: "Increase or tighten character spacing using the same multiplier the runtime editor already applies."
            ) {
                HStack(spacing: 10) {
                    Slider(value: letterSpacingBinding, in: 0.8...1.4, step: 0.05)
                    Text(String(format: "%.2f×", letterSpacingBinding.wrappedValue))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
                .frame(width: 240)
            }
        }
    }

    private var fontSizeBinding: Binding<Double> {
        Binding(
            get: { Double(settingsStore.settings.editor.font_size) },
            set: { value in
                updateEditor { $0.font_size = CGFloat(value) }
            }
        )
    }

    private var lineHeightBinding: Binding<Double> {
        Binding(
            get: { settingsStore.settings.editor.line_height_multiple },
            set: { value in
                updateEditor { $0.line_height_multiple = value }
            }
        )
    }

    private var letterSpacingBinding: Binding<Double> {
        Binding(
            get: { settingsStore.settings.editor.letter_spacing },
            set: { value in
                updateEditor { $0.letter_spacing = value }
            }
        )
    }

    private var tabWidthBinding: Binding<Int> {
        Binding(
            get: { settingsStore.settings.editor.tab_width },
            set: { value in
                updateEditor { $0.tab_width = value }
            }
        )
    }

    private var wrapLinesBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.editor.wrap_lines },
            set: { value in
                updateEditor { $0.wrap_lines = value }
            }
        )
    }

    private var showLineNumbersBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.editor.show_line_numbers },
            set: { value in
                updateEditor { $0.show_line_numbers = value }
            }
        )
    }

    private var showMinimapBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.editor.show_minimap },
            set: { value in
                updateEditor { $0.show_minimap = value }
            }
        )
    }

    private var useSystemCursorBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.editor.use_system_cursor },
            set: { value in
                updateEditor { $0.use_system_cursor = value }
            }
        )
    }

    private var useThemeBackgroundBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.editor.use_theme_background },
            set: { value in
                updateEditor { $0.use_theme_background = value }
            }
        )
    }

    private func updateEditor(_ mutate: (inout EditorSettings) -> Void) {
        settingsStore.updateEditor(mutate)
        onSettingMutation()
    }

    private func previewCard(settings: EditorSettings) -> some View {
        SettingsCard(title: "Editor Preview") {
            EditorThemePreview(
                theme: settingsStore.settings.editorTheme.resolvedTheme(for: colorScheme),
                settings: settings
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct TerminalSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.colorScheme) private var colorScheme
    let onSettingMutation: () -> Void

    var body: some View {
        let settings = settingsStore.settings
        let startupConfig = TerminalService().makeConfig(workingDirectory: nil)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Terminal")
                            .font(.largeTitle.weight(.semibold))
                        Text("Shape the terminal surface CodeX already ships today. Theme, font, and cursor defaults are runtime-backed for live terminal surfaces, while launcher details stay read-only until session defaults become configurable.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 16)

                    Button("Reset Terminal Defaults") {
                        updateTerminal { $0 = TerminalSettings() }
                    }
                }

                scopeSummaryCard(config: startupConfig, settings: settings.terminal)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        appearanceCard
                        previewCard(settings: settings.terminal)
                    }

                    VStack(spacing: 20) {
                        appearanceCard
                        previewCard(settings: settings.terminal)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        sessionCard(config: startupConfig)
                        environmentCard(config: startupConfig)
                    }

                    VStack(spacing: 20) {
                        sessionCard(config: startupConfig)
                        environmentCard(config: startupConfig)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 920, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func scopeSummaryCard(config: TerminalSessionConfig, settings: TerminalSettings) -> some View {
        SettingsCard(
            title: "Current Scope",
            description: "A quick snapshot of what the Terminal page controls today versus what is still inherited from the current environment."
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    summaryPill(
                        icon: "paintpalette",
                        title: "Live palette",
                        value: settings.theme.displayName,
                        tint: .accentColor
                    )
                    summaryPill(
                        icon: "textformat",
                        title: "Typography",
                        value: terminalFontSummary(settings),
                        tint: Color(nsColor: .systemBlue)
                    )
                    summaryPill(
                        icon: "text.cursor",
                        title: "Cursor",
                        value: settings.cursor_style.shortDisplayName,
                        tint: Color(nsColor: .systemPurple)
                    )
                    summaryPill(
                        icon: "terminal",
                        title: "Default shell",
                        value: compactShellName(for: config.shell),
                        tint: Color(nsColor: .systemGreen)
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    summaryPill(
                        icon: "paintpalette",
                        title: "Live palette",
                        value: settings.theme.displayName,
                        tint: .accentColor
                    )
                    summaryPill(
                        icon: "textformat",
                        title: "Typography",
                        value: terminalFontSummary(settings),
                        tint: Color(nsColor: .systemBlue)
                    )
                    summaryPill(
                        icon: "text.cursor",
                        title: "Cursor",
                        value: settings.cursor_style.shortDisplayName,
                        tint: Color(nsColor: .systemPurple)
                    )
                    summaryPill(
                        icon: "terminal",
                        title: "Default shell",
                        value: compactShellName(for: config.shell),
                        tint: Color(nsColor: .systemGreen)
                    )
                }
            }
        }
    }

    private var appearanceCard: some View {
        SettingsCard(
            title: "Appearance",
            description: "These controls are already wired into TerminalSessionView and update the SwiftTerm appearance used by open terminal surfaces."
        ) {
            SettingsControlRow(
                title: "Terminal theme",
                description: "Follow the current macOS appearance or force a dedicated light/dark terminal palette."
            ) {
                Picker("Terminal Theme", selection: terminalThemeBinding) {
                    ForEach(TerminalThemePreference.allCases, id: \.self) { preference in
                        Text(preference.displayName).tag(preference)
                    }
                }
                .labelsHidden()
                .frame(width: 220)
            }

            Divider()

            SettingsControlRow(
                title: "Terminal font",
                description: "Choose the monospaced font family used by live terminal surfaces."
            ) {
                Picker("Terminal Font", selection: terminalFontBinding) {
                    ForEach(TerminalFontPreference.allCases, id: \.self) { preference in
                        Text(preference.displayName).tag(preference)
                    }
                }
                .labelsHidden()
                .frame(width: 220)
            }

            Divider()

            SettingsControlRow(
                title: "Font size",
                description: "Update terminal typography live without recreating the current session surface."
            ) {
                Stepper(value: terminalFontSizeBinding, in: 10...24, step: 1) {
                    Text("\(Int(terminalFontSizeBinding.wrappedValue)) pt")
                        .font(.system(.body, design: .monospaced))
                }
                .frame(width: 220, alignment: .trailing)
            }

            Divider()

            SettingsControlRow(
                title: "Cursor style",
                description: "Set the default cursor shape used by CodeX terminal surfaces. Shell apps can still request their own style through standard terminal escape sequences."
            ) {
                Picker("Cursor Style", selection: terminalCursorStyleBinding) {
                    ForEach(TerminalCursorStylePreference.allCases, id: \.self) { preference in
                        Text(preference.displayName).tag(preference)
                    }
                }
                .labelsHidden()
                .frame(width: 220)
            }

            Divider()

            SettingsControlRow(
                title: "Runtime scope",
                description: "Theme, font, and default cursor style now update live on terminal surfaces. Shell, environment, and startup behavior remain inherited from the launcher path below."
            ) {
                valueLabel("Theme, font, cursor")
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func sessionCard(config: TerminalSessionConfig) -> some View {
        SettingsCard(
            title: "Session Launcher",
            description: "These values reflect the current launcher path already used when creating a new terminal session. They remain read-only until session defaults become configurable."
        ) {
            SettingsControlRow(
                title: "Shell executable",
                description: "Resolved from the user environment and used for new sessions."
            ) {
                valueLabel(config.shell)
            }

            Divider()

            SettingsControlRow(
                title: "Launch arguments",
                description: "Arguments passed to the shell when a session starts."
            ) {
                valueLabel(config.arguments.joined(separator: " "))
            }

            Divider()

            SettingsControlRow(
                title: "Startup directory",
                description: "Fallback working directory when a session is opened without a file-specific location."
            ) {
                valueLabel(config.initialWorkingDirectory.path)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func environmentCard(config: TerminalSessionConfig) -> some View {
        SettingsCard(
            title: "Session Environment",
            description: "Environment keys injected by TerminalService for new sessions. They help define terminal capabilities without introducing additional app-level preferences yet."
        ) {
            SettingsControlRow(
                title: "TERM",
                description: "Terminal type exposed to child processes."
            ) {
                valueLabel(environmentValue(named: "TERM", in: config.environment) ?? "xterm-256color")
            }

            Divider()

            SettingsControlRow(
                title: "COLORTERM",
                description: "Color capability hint injected into the terminal environment."
            ) {
                valueLabel(environmentValue(named: "COLORTERM", in: config.environment) ?? "truecolor")
            }

            Divider()

            SettingsControlRow(
                title: "LANG",
                description: "Locale fallback provided when the inherited environment does not already specify one."
            ) {
                valueLabel(environmentValue(named: "LANG", in: config.environment) ?? "en_US.UTF-8")
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var terminalThemeBinding: Binding<TerminalThemePreference> {
        Binding(
            get: { settingsStore.settings.terminal.theme },
            set: { preference in
                updateTerminal { $0.theme = preference }
            }
        )
    }

    private var terminalFontBinding: Binding<TerminalFontPreference> {
        Binding(
            get: { settingsStore.settings.terminal.font },
            set: { preference in
                updateTerminal { $0.font = preference }
            }
        )
    }

    private var terminalFontSizeBinding: Binding<Double> {
        Binding(
            get: { Double(settingsStore.settings.terminal.font_size) },
            set: { value in
                updateTerminal { $0.font_size = CGFloat(value) }
            }
        )
    }

    private var terminalCursorStyleBinding: Binding<TerminalCursorStylePreference> {
        Binding(
            get: { settingsStore.settings.terminal.cursor_style },
            set: { preference in
                updateTerminal { $0.cursor_style = preference }
            }
        )
    }

    private func updateTerminal(_ mutate: (inout TerminalSettings) -> Void) {
        settingsStore.updateTerminal(mutate)
        onSettingMutation()
    }

    private func previewCard(settings: TerminalSettings) -> some View {
        SettingsCard(
            title: "Live Preview",
            description: "A compact preview of the palette, typography, and cursor defaults currently resolved for terminal surfaces in CodeX."
        ) {
            TerminalThemePreview(
                colors: settings.theme.resolvedTheme(for: colorScheme),
                settings: settings
            )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func environmentValue(named key: String, in environment: [String]) -> String? {
        let prefix = "\(key)="
        guard let entry = environment.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        return String(entry.dropFirst(prefix.count))
    }

    private func compactShellName(for shell: String) -> String {
        URL(fileURLWithPath: shell).lastPathComponent
    }

    private func terminalFontSummary(_ settings: TerminalSettings) -> String {
        "\(settings.font.displayName) \(Int(settings.font_size)) pt"
    }

    private func summaryPill(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func valueLabel(_ value: String) -> some View {
        Text(value)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.trailing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 320, alignment: .trailing)
            .textSelection(.enabled)
    }
}

private struct SettingsPlaceholderView: View {
    let item: SettingsSidebarItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.title)
                    .font(.largeTitle.weight(.semibold))
                Text("This section is intentionally left as a shell for the next phase. The window structure is now in place, and the first fully working page is Themes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                SettingsCard(title: "Planned next") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Move the remaining editor controls out of ad-hoc state", systemImage: "checkmark.circle")
                        Label("Add terminal session defaults and shell preferences", systemImage: "checkmark.circle")
                        Label("Match Xcode-style grouping more closely", systemImage: "checkmark.circle")
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(28)
            .frame(maxWidth: 920, alignment: .leading)
        }
    }
}

private struct SettingsWindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.window)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    var description: String?
    let content: Content

    init(
        title: String,
        description: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.description = description
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if let description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct SettingsControlRow<Control: View>: View {
    let title: String
    let description: String
    let control: Control

    init(
        title: String,
        description: String,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.description = description
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 20)

            control
        }
    }
}

private struct EditorThemePreview: View {
    let theme: EditorTheme
    let settings: EditorSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(settings.font_name)
                Spacer(minLength: 8)
                Text("\(Int(settings.font_size)) pt")
            }
            .font(.caption)
            .foregroundStyle(Color(nsColor: theme.gutterForeground))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(nsColor: theme.gutterBackground))

            VStack(alignment: .leading, spacing: 8) {
                EditorPreviewLine(
                    number: 1,
                    showNumber: settings.show_line_numbers,
                    tokens: [
                        ("struct ", Color(nsColor: theme.keyword.color)),
                        ("ThemePanel", Color(nsColor: theme.type.color)),
                        (" {", Color(nsColor: theme.text))
                    ]
                )
                EditorPreviewLine(
                    number: 2,
                    showNumber: settings.show_line_numbers,
                    tokens: [
                        ("    let ", Color(nsColor: theme.keyword.color)),
                        ("name", Color(nsColor: theme.variable.color)),
                        (" = ", Color(nsColor: theme.operator_.color)),
                        ("\"Xcode Dark\"", Color(nsColor: theme.string.color))
                    ]
                )
                EditorPreviewLine(
                    number: 3,
                    showNumber: settings.show_line_numbers,
                    tokens: [
                        ("    var ", Color(nsColor: theme.keyword.color)),
                        ("tabWidth", Color(nsColor: theme.variable.color)),
                        (" = ", Color(nsColor: theme.operator_.color)),
                        ("\(settings.tab_width)", Color(nsColor: theme.number.color))
                    ]
                )
                EditorPreviewLine(
                    number: 4,
                    showNumber: settings.show_line_numbers,
                    tokens: [
                        ("}", Color(nsColor: theme.text))
                    ]
                )
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: theme.lineHighlight), lineWidth: 1)
        }
    }

    private var backgroundColor: Color {
        settings.use_theme_background
            ? Color(nsColor: theme.background)
            : Color(nsColor: .textBackgroundColor)
    }
}

private struct EditorPreviewLine: View {
    let number: Int
    let showNumber: Bool
    let tokens: [(String, Color)]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if showNumber {
                Text("\(number)")
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .trailing)
            }

            HStack(spacing: 0) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { item in
                    Text(item.element.0)
                        .foregroundStyle(item.element.1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 12, design: .monospaced))
    }
}

private struct TerminalThemePreview: View {
    let colors: TerminalColors
    var settings: TerminalSettings = TerminalSettings()

    private enum CursorPreviewShape {
        case block
        case underline
        case bar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(promptColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Terminal")
                        .font(.caption.weight(.semibold))
                    Text("xterm-256color • \(settings.cursor_style.shortDisplayName)")
                        .font(.caption2)
                        .foregroundStyle(chromeSecondaryColor)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(settings.font.displayName) \(Int(settings.font_size)) pt")
                        .font(.caption.weight(.medium))
                    Text("login shell")
                        .font(.caption2)
                        .foregroundStyle(chromeSecondaryColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .foregroundStyle(Color(nsColor: colors.foreground))
            .background(chromeBackgroundColor)

            Rectangle()
                .fill(Color(nsColor: colors.caret).opacity(0.14))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 0) {
                terminalRow {
                    terminalLine(prompt: "codex@macbook", path: "~/CodeX", command: "git status --short")
                }
                terminalRow {
                    gitStatusLine(symbol: "M", path: "CodeX/Views/Settings/SettingsWindowView.swift", symbolColor: warningColor)
                }
                terminalRow {
                    gitStatusLine(symbol: "A", path: "CodeXTests/SettingsStoreTests.swift", symbolColor: successColor)
                }
                terminalRow {
                    terminalLine(prompt: "codex@macbook", path: "~/CodeX", command: "swift test --filter SettingsStoreTests")
                }
                terminalRow {
                    terminalOutput("✓  3 tests passed", color: successColor)
                }
                terminalRow {
                    terminalLine(prompt: "codex@macbook", path: "~/CodeX", command: "echo $TERM")
                }
                terminalRow {
                    terminalOutput("xterm-256color", color: infoColor)
                }
                terminalRow {
                    cursorPreviewLine(prompt: "codex@macbook", path: "~/CodeX")
                }
            }
            .font(.custom(settings.resolved_font.fontName, size: settings.font_size))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: colors.background), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: colors.caret).opacity(0.2), lineWidth: 1)
        }
    }

    private func terminalRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, minHeight: lineHeight, alignment: .leading)
    }

    private func terminalLine(prompt: String, path: String, command: String) -> some View {
        HStack(spacing: 0) {
            promptPrefix(prompt: prompt, path: path)
            Text(command)
                .foregroundStyle(Color(nsColor: colors.foreground))
        }
    }

    private func gitStatusLine(symbol: String, path: String, symbolColor: Color) -> some View {
        HStack(spacing: 0) {
            Text(symbol)
                .foregroundStyle(symbolColor)
            Text("  ")
                .foregroundStyle(chromeSecondaryColor)
            Text(path)
                .foregroundStyle(Color(nsColor: colors.foreground).opacity(0.92))
        }
    }

    private func cursorPreviewLine(prompt: String, path: String) -> some View {
        TimelineView(.periodic(from: .now, by: 0.6)) { context in
            HStack(spacing: 0) {
                promptPrefix(prompt: prompt, path: path)
                terminalCursor(opacity: cursorOpacity(at: context.date))
            }
        }
    }

    private func promptPrefix(prompt: String, path: String) -> some View {
        HStack(spacing: 0) {
            Text(prompt)
                .foregroundStyle(promptColor)
            Text(" ")
                .foregroundStyle(chromeSecondaryColor)
            Text(path)
                .foregroundStyle(pathColor)
            Text(" % ")
                .foregroundStyle(chromeSecondaryColor)
        }
    }

    @ViewBuilder
    private func terminalCursor(opacity: Double) -> some View {
        switch cursorPreviewShape {
        case .block:
            Text(" ")
                .frame(width: cursorCellWidth, height: cursorCellHeight)
                .background(Color(nsColor: colors.caret).opacity(opacity), in: RoundedRectangle(cornerRadius: 2, style: .continuous))
        case .underline:
            Color.clear
                .frame(width: cursorCellWidth, height: cursorCellHeight)
                .overlay(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Color(nsColor: colors.caret).opacity(opacity))
                        .frame(width: cursorCellWidth, height: 2)
                }
        case .bar:
            Color.clear
                .frame(width: cursorCellWidth, height: cursorCellHeight)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Color(nsColor: colors.caret).opacity(opacity))
                        .frame(width: 2, height: cursorCellHeight)
                }
        }
    }

    private var cursorPreviewShape: CursorPreviewShape {
        switch settings.cursor_style {
        case .blinkBlock, .steadyBlock:
            .block
        case .blinkUnderline, .steadyUnderline:
            .underline
        case .blinkBar, .steadyBar:
            .bar
        }
    }

    private var cursorIsBlinking: Bool {
        switch settings.cursor_style {
        case .blinkBlock, .blinkUnderline, .blinkBar:
            true
        case .steadyBlock, .steadyUnderline, .steadyBar:
            false
        }
    }

    private var cursorCellWidth: CGFloat {
        max(settings.font_size * 0.62, 8)
    }

    private var cursorCellHeight: CGFloat {
        max(settings.font_size * 1.15, 14)
    }

    private var lineHeight: CGFloat {
        max(cursorCellHeight * 1.06, settings.font_size * 1.42)
    }

    private var chromeBackgroundColor: Color {
        Color(nsColor: colors.foreground).opacity(0.06)
    }

    private var chromeSecondaryColor: Color {
        Color(nsColor: colors.foreground).opacity(0.62)
    }

    private var promptColor: Color {
        ansiPreviewColor(at: 10, fallback: Color(nsColor: .systemGreen).opacity(0.92))
    }

    private var pathColor: Color {
        ansiPreviewColor(at: 12, fallback: Color(nsColor: .systemBlue).opacity(0.88))
    }

    private var successColor: Color {
        ansiPreviewColor(at: 10, fallback: Color(nsColor: .systemGreen).opacity(0.94))
    }

    private var warningColor: Color {
        ansiPreviewColor(at: 11, fallback: Color(nsColor: .systemYellow).opacity(0.95))
    }

    private var infoColor: Color {
        ansiPreviewColor(at: 14, fallback: Color(nsColor: colors.foreground).opacity(0.92))
    }

    private func ansiPreviewColor(at index: Int, fallback: Color) -> Color {
        guard let ansi = colors.ansiNSColor(at: index) else { return fallback }
        return Color(nsColor: ansi)
    }

    private func cursorOpacity(at date: Date) -> Double {
        guard cursorIsBlinking else { return 1 }
        let phase = Int(date.timeIntervalSinceReferenceDate / 0.6)
        return phase.isMultiple(of: 2) ? 1 : 0.18
    }

    private func terminalOutput(_ text: String, color: Color) -> some View {
        Text(text)
            .foregroundStyle(color)
    }
}
