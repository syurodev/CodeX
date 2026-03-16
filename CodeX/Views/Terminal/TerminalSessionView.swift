import SwiftUI
import SwiftTerm

struct TerminalSessionView: NSViewRepresentable {
    let session: TerminalSessionViewModel
    /// When `false` the underlying NSView is hidden so the process stays alive
    /// but the view is invisible and cannot receive keyboard input.
    var isActive: Bool = true
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.colorScheme) private var colorScheme

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let view = LocalProcessTerminalView(frame: .zero)
        view.processDelegate = context.coordinator
        applyRuntimeAppearance(to: view)
        view.startProcess(
            executable: session.config.shell,
            args: session.config.arguments,
            environment: session.config.environment,
            execName: URL(fileURLWithPath: session.config.shell).lastPathComponent,
            currentDirectory: session.config.initialWorkingDirectory.path
        )
        return view
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        applyRuntimeAppearance(to: nsView)
        let wasHidden = nsView.isHidden
        nsView.isHidden = !isActive
        // Restore keyboard focus when this tab becomes active again
        if wasHidden && isActive {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    private func applyRuntimeAppearance(to view: LocalProcessTerminalView) {
        let terminalSettings = settingsStore.settings.terminal
        let theme = terminalSettings.theme.resolvedTheme(for: colorScheme)
        theme.apply(to: view)
        view.font = terminalSettings.resolved_font
        view.getTerminal().setCursorStyle(terminalSettings.resolved_cursor_style)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    @MainActor
    final class Coordinator: LocalProcessTerminalViewDelegate {
        weak var session: TerminalSessionViewModel?

        init(session: TerminalSessionViewModel) {
            self.session = session
        }

        nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            guard !title.isEmpty else { return }
            Task { @MainActor in
                self.session?.title = title
            }
        }

        nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            guard let directory,
                  let url = URL(string: directory) else { return }
            Task { @MainActor in
                self.session?.workingDirectory = url
            }
        }

        nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
            Task { @MainActor in
                self.session?.isAlive = false
            }
        }
    }
}
