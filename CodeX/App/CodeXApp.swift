import AppKit
import SwiftUI

@main
struct CodeXApp: App {
    @State private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(appViewModel)
                .containerBackground(.thinMaterial, for: .window)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
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
            
            // Xử lý phím tắt đóng Window và Tab
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
    }
}
