import SwiftUI

struct MainWindowView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var titlebarDetailLeadingInset: CGFloat = 78
    @State private var titlebarNativeLeadingInset: CGFloat = 140

    var body: some View {
        @Bindable var appVM = appViewModel

        VStack(spacing: 0) {
            HSplitView {
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
                                }
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
                    CodeEditorView(viewModel: appVM.editorViewModel)
                        .ignoresSafeArea(.container, edges: .top)
                        .safeAreaInset(edge: .top, spacing: 0) {
                            if !appVM.editorViewModel.openDocuments.isEmpty {
                                EditorTabBarView(viewModel: appVM.editorViewModel)
                            }
                        }
                        .background {
                            TitlebarLayoutProbe(region: .detail)
                        }
                }
                .toolbarBackground(.hidden, for: .windowToolbar)
                .frame(minWidth: 500)

                if appVM.isAgentInspectorPresented {
                    AgentPanelView(viewModel: appVM.agentPanelViewModel)
                    .frame(minWidth: 260, idealWidth: 320, maxWidth: 700)
                    .background(Color(nsColor: .windowBackgroundColor))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: appVM.isAgentInspectorPresented)

            StatusBarView(
                document: appVM.editorViewModel.currentDocument,
                cursorPosition: appVM.editorViewModel.cursorPosition
            )
        }
        .background {
            TitlebarLayoutProbe(region: .root)

            WindowTitlebarContent(
                id: "main-window-titlebar",
                onLeadingSafeAreaChange: { leadingInset in
                    guard abs(leadingInset - titlebarNativeLeadingInset) > 0.5 else {
                        return
                    }

                    titlebarNativeLeadingInset = leadingInset
                }
            ) {
                MainWindowTitlebarContent(
                    appViewModel: appVM,
                    leadingInset: max(titlebarDetailLeadingInset, titlebarNativeLeadingInset)
                )
            }
            .frame(width: 0, height: 0)
        }
        .frame(minWidth: 800, minHeight: 500)
        .onPreferenceChange(TitlebarFramePreferenceKey.self) { frames in
            guard
                let rootFrame = frames[.root],
                let detailFrame = frames[.detail]
            else {
                return
            }

            let computedInset = max(78, detailFrame.minX - rootFrame.minX + 12)
            guard abs(computedInset - titlebarDetailLeadingInset) > 0.5 else {
                return
            }

            titlebarDetailLeadingInset = computedInset
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

private struct MainWindowTitlebarContent: View {
    @Bindable var appViewModel: AppViewModel
    let leadingInset: CGFloat

    var body: some View {
        GlassEffectContainer(spacing: 12.0) {
            ZStack {
                HStack(spacing: 12) {
                    ToolbarGitBranchButton(appViewModel: appViewModel)

                    Spacer(minLength: 12)

                    AgentInspectorTitlebarButton(appViewModel: appViewModel)
                }
                .padding(.leading, leadingInset)
                .padding(.trailing, 12)

                ToolbarProjectStatusView(projectName: appViewModel.projectName)
                    .padding(.horizontal, 170)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private enum TitlebarLayoutRegion: Hashable {
    case root
    case detail
}

private struct TitlebarFramePreferenceKey: PreferenceKey {
    static var defaultValue: [TitlebarLayoutRegion: CGRect] = [:]

    static func reduce(
        value: inout [TitlebarLayoutRegion: CGRect],
        nextValue: () -> [TitlebarLayoutRegion: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct TitlebarLayoutProbe: View {
    let region: TitlebarLayoutRegion

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: TitlebarFramePreferenceKey.self,
                    value: [region: proxy.frame(in: .global)]
                )
        }
    }
}

private struct AgentInspectorTitlebarButton: View {
    @Bindable var appViewModel: AppViewModel

    var body: some View {
        Button(action: {
            appViewModel.openAgentPanel()
        }) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .glassEffect(glassStyle, in: Capsule())
        .help("Toggle Agent panel")
        .accessibilityLabel("Toggle Agent panel")
    }

    private var glassStyle: Glass {
        appViewModel.isAgentInspectorPresented
            ? .clear.tint(.accentColor).interactive()
            : .clear.interactive()
    }
}

#Preview {
    MainWindowView()
        .environment(AppViewModel())
}
