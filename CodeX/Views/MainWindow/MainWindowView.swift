import SwiftUI

struct MainWindowView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        @Bindable var appVM = appViewModel

        NavigationSplitView(columnVisibility: $appVM.splitViewVisibility) {
            VStack(spacing: 0) {
                SidebarToolbarView(viewModel: appVM)

                Divider()

                if appVM.selectedSidebarTab == .explorer {
                    FileNavigatorView(
                        viewModel: appVM.fileNavigatorViewModel,
                        gitStatusesByURL: appVM.fileNavigatorViewModel.gitStatusesByURL,
                        onFileSelected: { node in
                            appVM.openFile(node)
                        },
                        onNewFile: { url in appVM.fileNavigator_newFile(in: url) },
                        onNewFolder: { url in appVM.fileNavigator_newFolder(in: url) },
                        onRename: { node in appVM.fileNavigator_rename(node) },
                        onTrash: { node in appVM.fileNavigator_trash(node) },
                        onDuplicate: { node in appVM.fileNavigator_duplicate(node) },
                        onRevealInFinder: { node in appVM.fileNavigator_revealInFinder(node) },
                        onCopyPath: { node in appVM.fileNavigator_copyPath(node) },
                        onCopyRelativePath: { node in appVM.fileNavigator_copyRelativePath(node) }
                    )
                } else if appVM.selectedSidebarTab == .spray {
                    AgentSidebarView(viewModel: appVM.agentPanelViewModel)
                } else {
                    VStack {
                        Spacer()
                        Text("Not implemented yet")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 400)
        } detail: {
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    CodeEditorView(
                        viewModel: appVM.editorViewModel,
                        topContentInset: appVM.editorViewModel.openDocuments.isEmpty ? 0 : EditorTabBarView.height + EditorJumpBarView.height,
                        bottomContentInset: appVM.isTerminalPanelPresented ? 0 : StatusBarView.height
                    )
                    .overlay(alignment: .bottom) {
                        if !appVM.isTerminalPanelPresented {
                            StatusBarView(
                                document: appVM.editorViewModel.currentDocument,
                                cursorPosition: appVM.editorViewModel.cursorPosition
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if !appVM.editorViewModel.openDocuments.isEmpty {
                        EditorTopChromeView {
                            VStack(spacing: 0) {
                                EditorTabBarView(viewModel: appVM.editorViewModel)

                                if let currentDocument = appVM.editorViewModel.currentDocument {
                                    EditorJumpBarView(document: currentDocument)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if appVM.isTerminalPanelPresented {
                    TerminalPanelView(
                        viewModel: appVM.terminalPanelViewModel,
                        height: $appVM.terminalPanelHeight,
                        runViewModel: appVM.projectRunViewModel,
                        onNewSession: {
                            appVM.terminalPanelViewModel.newSession(workingDirectory: appVM.project?.rootURL)
                        },
                        onClose: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                appVM.isTerminalPanelPresented = false
                            }
                        }
                    )

                    StatusBarView(
                        document: appVM.editorViewModel.currentDocument,
                        cursorPosition: appVM.editorViewModel.cursorPosition
                    )
                }
            }
        }
        .inspector(isPresented: $appVM.isAgentInspectorPresented) {
            AgentPanelView(viewModel: appVM.agentPanelViewModel)
                .inspectorColumnWidth(min: 260, ideal: 320, max: 700)
                .toolbar {
                    if appVM.isAgentInspectorPresented {
                        AgentInspectorToolbarContent(appViewModel: appVM)
                    }
                }
        }
        .frame(minWidth: 800, minHeight: 500)
        .background {
            WindowTitlebarContent(id: "MainWindowTitlebarConfigurator") {
                EmptyView()
            }
        }
        .navigationTitle(windowTitle(for: appVM))
        .navigationSubtitle(windowSubtitle(for: appVM))
        .toolbar {
            MainWindowToolbarContent(appViewModel: appVM)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CodeX.OpenAndJump"))) { notification in
            print("📣 Received CodeX.OpenAndJump notification")
            guard let userInfo = notification.userInfo,
                  let url = userInfo["url"] as? URL,
                  let line = userInfo["line"] as? Int,
                  let column = userInfo["column"] as? Int else {
                print("⚠️ Invalid notification userInfo: \(String(describing: notification.userInfo))")
                return
            }
            print("➡️ Jumping to \(url.lastPathComponent):\(line):\(column)")
            appViewModel.openFile(at: url, line: line, column: column)
        }
    }
}

// Background + bottom border for EditorTabBarView and EditorJumpBarView
private struct EditorTopChromeView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content
            .background(.bar)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill((colorScheme == .dark ? Color.white : Color.black).opacity(colorScheme == .dark ? 0.085 : 0.10))
                    .frame(height: 1)
            }
    }
}

private extension MainWindowView {
    func windowTitle(for appViewModel: AppViewModel) -> String {
        appViewModel.editorViewModel.currentDocument?.fileName ?? appViewModel.projectName
    }

    func windowSubtitle(for appViewModel: AppViewModel) -> String {
        if let document = appViewModel.editorViewModel.currentDocument {
            let filePath = document.url.deletingLastPathComponent().path

            if let rootPath = appViewModel.project?.rootURL.path,
               filePath.hasPrefix(rootPath) {
                let suffix = String(filePath.dropFirst(rootPath.count))
                return suffix.isEmpty ? appViewModel.projectName : appViewModel.projectName + suffix
            }

            return document.url.deletingLastPathComponent().lastPathComponent
        }

        if appViewModel.gitViewModel.is_git_repo {
            return appViewModel.gitViewModel.current_branch
        }

        return ""
    }
}

#Preview {
    let appViewModel = AppViewModel()

    MainWindowView()
        .environment(appViewModel)
        .environment(appViewModel.settingsStore)
}
