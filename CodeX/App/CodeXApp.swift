import AppKit
import SwiftUI

@main
struct CodeXApp: App {
    @State private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(appViewModel)
                .environment(appViewModel.settingsStore)
                .onDisappear {
                    appViewModel.shutdownAgentRuntimes()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    appViewModel.shutdownAgentRuntimes()
                }
        }
        .defaultSize(width: 1200, height: 800)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Project...") {
                    appViewModel.openFolderPanel()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    // Cần link với save logic sau này
                }
                .keyboardShortcut("s", modifiers: .command)
            }

            CommandMenu("Terminal") {
                Button("Toggle Terminal") {
                    appViewModel.toggleTerminalPanel()
                }
                .keyboardShortcut("`", modifiers: .control)

                Divider()

                Button("New Terminal Session") {
                    appViewModel.terminalPanelViewModel.newSession(workingDirectory: appViewModel.project?.rootURL)
                    if !appViewModel.isTerminalPanelPresented {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appViewModel.isTerminalPanelPresented = true
                        }
                    }
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Button("New Terminal at Current File") {
                    let fileURL = appViewModel.editorViewModel.currentDocument?.url
                    appViewModel.terminalPanelViewModel.newSessionAtCurrentFile(
                        fileURL: fileURL,
                        projectRoot: appViewModel.project?.rootURL
                    )
                    if !appViewModel.isTerminalPanelPresented {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appViewModel.isTerminalPanelPresented = true
                        }
                    }
                }
            }

            CommandMenu("Editor") {
                Button("Close Tab") {
                    if let currentID = appViewModel.editorViewModel.currentDocumentID {
                        appViewModel.editorViewModel.closeDocument(id: currentID)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)

                Button("Close All Tabs") {
                    appViewModel.editorViewModel.closeAllDocuments()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsWindowView()
                .environment(appViewModel.settingsStore)
                .containerBackground(.thinMaterial, for: .window)
        }
        .defaultSize(width: 880, height: 560)
    }
}
