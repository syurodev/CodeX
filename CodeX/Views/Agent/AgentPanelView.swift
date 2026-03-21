import ACPClient
import Foundation
import SwiftUI

struct AgentSidebarView: View {
    @Bindable var viewModel: AgentPanelViewModel
    @Environment(\.colorScheme) private var colorScheme

    private func rowFill(isActive: Bool) -> Color {
        if isActive {
            return .accentColor.opacity(colorScheme == .dark ? 0.12 : 0.1)
        }

        return .clear
    }

    private func rowBorder(isActive: Bool) -> Color {
        if isActive {
            return .accentColor.opacity(colorScheme == .dark ? 0.18 : 0.14)
        }

        return .clear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Agents")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.showLauncher()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("Create a new agent tab in the panel")
            }

            if viewModel.runtimes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No agents running")
                        .font(.subheadline.weight(.semibold))
                    Text("Open the agent panel and choose which agent to start.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.runtimes) { runtime in
                            Button {
                                viewModel.selectRuntime(id: runtime.id)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: runtime.provider.systemImage)
                                        .foregroundColor(.accentColor)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(runtime.title)
                                            .font(.subheadline.weight(.medium))
                                        Text(runtime.workingDirectoryName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    AgentRuntimeStateBadge(state: runtime.state)
                                }
                                .padding(10)
                                .background {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(rowFill(isActive: viewModel.activeRuntimeID == runtime.id))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .strokeBorder(rowBorder(isActive: viewModel.activeRuntimeID == runtime.id))
                                        }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(12)
    }
}

struct AgentPanelView: View {
    @Bindable var viewModel: AgentPanelViewModel

    var body: some View {
        VStack(spacing: 0) {
            AgentRuntimeTabBarView(viewModel: viewModel)
            Divider()

            if viewModel.isShowingLauncher || viewModel.activeRuntime == nil {
                AgentLauncherView(viewModel: viewModel)
            } else if let runtime = viewModel.activeRuntime {
                AgentRuntimeContentView(viewModel: runtime)
            }
        }
    }
}

struct AgentRuntimeStateBadge: View {
    let state: AgentRuntimeState

    private var tint: Color {
        switch state {
        case .starting: return .orange
        case .ready: return .green
        case .busy: return .blue
        case .stopped: return .secondary
        case .error: return .red
        }
    }

    var body: some View {
        Text(state.label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint.opacity(0.92))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(tint.opacity(0.14))
                    .overlay {
                        Capsule()
                            .strokeBorder(tint.opacity(0.18))
                    }
            }
            .clipShape(Capsule())
    }
}

private struct AgentRuntimeTabBarView: View {
    @Bindable var viewModel: AgentPanelViewModel
    @Environment(\.colorScheme) private var colorScheme

    private func stateColor(_ state: AgentRuntimeState) -> Color {
        switch state {
        case .starting: return .orange
        case .ready:    return .green
        case .busy:     return .blue
        case .stopped:  return .secondary
        case .error:    return .red
        }
    }

    private func tabFill(isActive: Bool) -> Color {
        if isActive {
            return .accentColor.opacity(colorScheme == .dark ? 0.14 : 0.1)
        }

        return colorScheme == .dark
            ? .agentPanelSurface.opacity(0.4)
            : .agentPanelElevatedSurface.opacity(0.96)
    }

    private func tabBorder(isActive: Bool) -> Color {
        if isActive {
            return .accentColor.opacity(colorScheme == .dark ? 0.2 : 0.16)
        }

        return .agentPanelSeparator.opacity(colorScheme == .dark ? 0.28 : 0.42)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(viewModel.runtimes) { runtime in
                    let isActive = viewModel.activeRuntimeID == runtime.id
                    Button {
                        viewModel.selectRuntime(id: runtime.id)
                    } label: {
                        Image(runtime.provider.iconImageName)
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                            .padding(6)
                            .background {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(tabFill(isActive: isActive))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(tabBorder(isActive: isActive))
                                    }
                            }
                    }
                    .buttonStyle(.plain)
                    .help(runtime.title)
                    .overlay(alignment: .bottomTrailing) {
                        AgentStateDotView(state: runtime.state)
                            .offset(x: 3, y: 3)
                    }
                    .overlay(alignment: .topTrailing) {
                        Button {
                            viewModel.closeRuntime(id: runtime.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 6.5, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 13, height: 13)
                                .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
                                .overlay(Circle().strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .offset(x: 4, y: -4)
                        .help("Close \(runtime.title)")
                    }
                }

                Button {
                    viewModel.showLauncher()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 20, height: 20)
                        .padding(7)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(tabFill(isActive: false))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(tabBorder(isActive: false))
                                }
                        }
                }
                .buttonStyle(.plain)
                .help("New Agent")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
    }
}

private struct AgentStateDotView: View {
    let state: AgentRuntimeState
    @State private var pinging = false

    private var color: Color {
        switch state {
        case .starting: return .orange
        case .ready:    return .green
        case .busy:     return .blue
        case .stopped:  return .secondary
        case .error:    return .red
        }
    }

    private var animates: Bool {
        state == .starting || state == .busy
    }

    var body: some View {
        ZStack {
            if animates {
                Circle()
                    .fill(color.opacity(pinging ? 0 : 0.45))
                    .frame(width: 7, height: 7)
                    .scaleEffect(pinging ? 16.0 / 7.0 : 1)
                    .animation(
                        .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                        value: pinging
                    )
            }
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .background(Circle().fill(Color(nsColor: .windowBackgroundColor)).padding(-1.5))
        }
        .frame(width: 7, height: 7)
        .onAppear { if animates { pinging = true } }
        .onChange(of: state) { pinging = animates }
    }
}

private struct AgentLauncherView: View {
    @Bindable var viewModel: AgentPanelViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(CopilotService.self) private var copilotService

    private var providerCardFill: Color {
        colorScheme == .dark
            ? .agentPanelSurface.opacity(0.48)
            : .agentPanelElevatedSurface.opacity(0.96)
    }

    /// Copilot đã sẵn sàng khởi chạy agent chưa
    private var copilotReady: Bool {
        if case .ready = copilotService.installState { return true }
        return false
    }

    /// Nút Start Agent có thể bấm không
    private var canStart: Bool {
        switch viewModel.selectedLaunchProviderID {
        case .claudeCode: return true
        case .githubCopilot: return copilotReady
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Start an agent")
                .font(.title3.weight(.semibold))

            Text("Opening the panel does not auto-start Claude. Choose a provider first, then create a runtime tab.")
                .foregroundColor(.secondary)

            Picker("Agent", selection: $viewModel.selectedLaunchProviderID) {
                ForEach(viewModel.availableProviders) { provider in
                    Text(provider.displayName).tag(provider.id)
                }
            }
            .pickerStyle(.menu)

            if let provider = viewModel.selectedLaunchProvider {
                VStack(alignment: .leading, spacing: 6) {
                    Label(provider.displayName, systemImage: provider.systemImage)
                        .font(.headline)
                    Text(provider.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Workspace: \(viewModel.workspaceDisplayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(providerCardFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.agentPanelSeparator.opacity(colorScheme == .dark ? 0.3 : 0.4))
                        }
                }
            }

            // Copilot installation gate — chỉ hiện khi provider là Copilot
            if viewModel.selectedLaunchProviderID == .githubCopilot {
                CopilotInstallGateView(copilotService: copilotService)
            }

            Button {
                viewModel.startSelectedProvider()
            } label: {
                Label("Start Agent", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canStart)

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - CopilotInstallGateView

private struct CopilotInstallGateView: View {
    @Bindable var copilotService: CopilotService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            switch copilotService.installState {
            case .unknown:
                EmptyView()
                    .task { await copilotService.check() }

            case .checking:
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.75)
                    Text("Checking Copilot installation…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(gateFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            case .notInstalled:
                VStack(alignment: .leading, spacing: 10) {
                    Label("Copilot CLI not found", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text("Install Copilot CLI to use GitHub Copilot as an agent. Homebrew is not available on this machine.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    installInstructions
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(gateFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            case .brewAvailable:
                VStack(alignment: .leading, spacing: 10) {
                    Label("Copilot CLI not installed", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text("Copilot CLI is required to use GitHub Copilot as an agent. You can install it automatically via Homebrew.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await copilotService.installViaBrew() }
                    } label: {
                        Label("Install via Homebrew", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(gateFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            case .installing(let log):
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.75)
                        Text("Installing Copilot CLI…")
                            .font(.subheadline.weight(.semibold))
                    }
                    ScrollView(.vertical) {
                        Text(log)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 100)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(gateFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            case .authRequired:
                VStack(alignment: .leading, spacing: 10) {
                    Label("Authentication required", systemImage: "person.badge.key.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.yellow)
                    Text("Copilot CLI is installed but not signed in. Open Terminal to authenticate, then click Recheck.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Button {
                            copilotService.openTerminalForAuth()
                        } label: {
                            Label("Sign In", systemImage: "terminal")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            Task { await copilotService.recheckAfterAuth() }
                        } label: {
                            Label("Recheck", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(gateFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            case .ready:
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Copilot CLI is ready")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(gateFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            case .error(let msg):
                VStack(alignment: .leading, spacing: 8) {
                    Label("Error", systemImage: "xmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await copilotService.check() }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(gateFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    // MARK: - Helpers

    private var gateFill: AnyShapeStyle {
        AnyShapeStyle(.ultraThinMaterial)
    }

    @ViewBuilder
    private var installInstructions: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Manual installation options:")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("npm install -g @github/copilot")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("curl -fsSL https://gh.io/copilot-install | bash")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            Button {
                Task { await copilotService.check() }
            } label: {
                Label("Recheck after installing", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 4)
        }
    }
}

private struct AgentRuntimeContentView: View {
    @Bindable var viewModel: AgentRuntimeViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(CopilotService.self) private var copilotService
    @State private var composerText: String = ""
    @State private var activeAtQuery: String? = nil
    private let composerRef = AgentRichComposerRef()
    @State private var isPinnedToBottom = true
    @State private var unreadTranscriptCount = 0

    private let transcriptBottomID = "agent-transcript-bottom"
    private let transcriptAutoScrollThreshold: CGFloat = 72
    private let composerOuterPadding: CGFloat = 16

    private var transcriptChangeToken: String {
        viewModel.transcriptSections.map(\.changeToken).joined(separator: "||")
    }

    private var canSendDraft: Bool {
        let hasText = !composerText
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        let hasMentions = composerText.contains("\u{FFFC}")
        return (hasText || hasMentions) && viewModel.state != .busy
    }

    private var transcriptSections: [AgentTranscriptSection] {
        viewModel.transcriptSections
    }

    private var activeAssistantMessageID: AgentMessage.ID? {
        viewModel.messages.last(where: { $0.role == .assistant })?.id
    }

    private var transcriptBottomClearance: CGFloat {
        AgentTranscriptLayout.bottomClearance(
            composerHeight: composerHeight,
            composerOuterPadding: composerOuterPadding
        )
    }

    private var jumpToLatestBottomPadding: CGFloat {
        transcriptBottomClearance + 12
    }

    @State private var composerHeight: CGFloat = 72
    @State private var fileMentionResults: [URL] = []
    @State private var fileMentionTask: Task<Void, Never>? = nil
    @State private var fileMentionSelectedIndex: Int = 0

    private var commandSuggestions: [AgentSlashCommand] {
        let trimmed = composerText
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return [] }
        let query = String(trimmed.dropFirst()).lowercased()
        let commands = viewModel.slashCommands
        if query.isEmpty { return commands }
        return commands.filter {
            $0.name.lowercased().hasPrefix(query) ||
            $0.description.lowercased().contains(query)
        }
    }

    private func selectCommand(_ command: AgentSlashCommand) {
        composerRef.replaceAll(with: "/\(command.name) ")
    }

    private func searchFiles(query: String) {
        fileMentionTask?.cancel()
        guard let workDir = viewModel.workingDirectory else {
            fileMentionResults = []
            return
        }
        fileMentionTask = Task {
            let results = await Task.detached(priority: .userInitiated) {
                AgentFileSearcher.search(query: query, in: workDir)
            }.value
            guard !Task.isCancelled else { return }
            fileMentionResults = results
        }
    }

    private func selectFileMention(_ url: URL) {
        composerRef.insertMention(url: url)
        fileMentionResults = []
        fileMentionTask?.cancel()
    }

    private func handlePickerKeyDown(_ event: NSEvent) -> Bool {
        guard !fileMentionResults.isEmpty else { return false }
        switch event.keyCode {
        case 126: // up arrow
            fileMentionSelectedIndex = max(0, fileMentionSelectedIndex - 1)
            return true
        case 125: // down arrow
            fileMentionSelectedIndex = min(fileMentionResults.count - 1, fileMentionSelectedIndex + 1)
            return true
        case 36: // return
            selectFileMention(fileMentionResults[fileMentionSelectedIndex])
            return true
        case 53: // escape
            fileMentionResults = []
            fileMentionTask?.cancel()
            return true
        default:
            return false
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                transcriptScrollView(proxy: proxy)
            }

            // Auth required banner — chỉ hiện khi Copilot chưa đăng nhập
            if viewModel.requiresAuthentication {
                copilotAuthBanner
            }

            if !commandSuggestions.isEmpty {
                AgentCommandPickerView(
                    suggestions: commandSuggestions,
                    onSelect: { command in selectCommand(command) }
                )
                .padding(.horizontal, composerOuterPadding)
                .padding(.bottom, composerHeight + composerOuterPadding + 6)
                .transition(.opacity.animation(.easeInOut(duration: 0.15)))
            }

            if !fileMentionResults.isEmpty {
                AgentFileMentionPickerView(
                    results: fileMentionResults,
                    selectedIndex: fileMentionSelectedIndex,
                    workingDirectory: viewModel.workingDirectory,
                    onSelect: selectFileMention
                )
                .padding(.horizontal, composerOuterPadding)
                .padding(.bottom, composerHeight + composerOuterPadding + 6)
                .transition(.opacity.animation(.easeInOut(duration: 0.15)))
            }

            AgentPromptComposerView(
                ref: composerRef,
                state: viewModel.state,
                statusText: viewModel.footerText,
                agentName: viewModel.provider.displayName,
                canSend: canSendDraft,
                onTextChange: { composerText = $0 },
                onAtQuery: { activeAtQuery = $0 },
                onAtDismiss: { activeAtQuery = nil },
                onSubmit: submitDraft,
                onStopResponding: viewModel.stopResponding,
                onPickerKeyDown: handlePickerKeyDown
            )
            .background {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ComposerHeightPreferenceKey.self,
                        value: geo.size.height
                    )
                }
            }
            .onPreferenceChange(ComposerHeightPreferenceKey.self) { value in
                composerHeight = value
            }
            .padding(composerOuterPadding)
        }
        .onChange(of: activeAtQuery) { _, newQuery in
            if let query = newQuery {
                searchFiles(query: query)
            } else {
                fileMentionTask?.cancel()
                if !fileMentionResults.isEmpty { fileMentionResults = [] }
            }
        }
        .onChange(of: fileMentionResults) { _, _ in
            fileMentionSelectedIndex = 0
        }
    }

    private func submitDraft() {
        guard canSendDraft else { return }
        let prompt = composerRef.buildPrompt(workingDirectory: viewModel.workingDirectory)
        guard !prompt.isEmpty else { return }
        composerRef.clearAll()
        composerText = ""
        activeAtQuery = nil
        fileMentionResults = []
        viewModel.submitPrompt(prompt)
    }

    @ViewBuilder
    private func transcriptScrollView(proxy: ScrollViewProxy) -> some View {
        let baseScrollView = ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !transcriptSections.isEmpty {
                    AgentTranscriptSectionsView(
                        sections: transcriptSections,
                        activeMessageID: activeAssistantMessageID,
                        isBusy: viewModel.state == .busy,
                        pendingPermissionRequests: viewModel.pendingPermissionRequests,
                        provider: viewModel.provider
                    )
                }

                Color.clear
                    .frame(height: transcriptBottomClearance)
                    .id(transcriptBottomID)
            }
            .padding(16)
        }
        .onAppear {
            isPinnedToBottom = true
            proxy.scrollTo(transcriptBottomID, anchor: .bottom)
        }
        .onChange(of: transcriptChangeToken) { _, _ in
            if isPinnedToBottom {
                unreadTranscriptCount = 0
                scrollTranscriptToBottom(using: proxy, animated: viewModel.state != .busy)
            } else {
                unreadTranscriptCount = AgentTranscriptUnreadState.nextUnreadCount(
                    currentCount: unreadTranscriptCount,
                    isPinnedToBottom: isPinnedToBottom
                )
            }
        }
        .onChange(of: isPinnedToBottom) { _, newValue in
            if newValue {
                unreadTranscriptCount = 0
            }
        }
        .onChange(of: composerHeight) { _, _ in
            guard isPinnedToBottom else { return }
            scrollTranscriptToBottom(using: proxy, animated: false)
        }

        ZStack(alignment: .bottomTrailing) {
            if #available(macOS 15.0, *) {
                baseScrollView
                    .onScrollGeometryChange(for: AgentTranscriptScrollMetrics.self) { geometry in
                        AgentTranscriptScrollMetrics(
                            contentOffsetY: geometry.contentOffset.y,
                            contentHeight: geometry.contentSize.height,
                            containerHeight: geometry.containerSize.height
                        )
                    } action: { previousMetrics, newMetrics in
                        isPinnedToBottom = AgentTranscriptAutoScrollState.nextPinnedState(
                            currentPinned: isPinnedToBottom,
                            previousMetrics: previousMetrics,
                            newMetrics: newMetrics,
                            threshold: transcriptAutoScrollThreshold
                        )
                        // Auto-scroll when pinned and layout actually grew.
                        // This handles the debounced text view case: the
                        // transcriptChangeToken fires immediately on content change,
                        // but the layout only grows 160ms later when the text view
                        // flushes. We catch that layout growth here and scroll then.
                        if isPinnedToBottom && newMetrics.contentHeight > previousMetrics.contentHeight + 1 {
                            scrollTranscriptToBottom(using: proxy, animated: false)
                        }
                    }
            } else {
                baseScrollView
            }

            if !isPinnedToBottom {
                AgentTranscriptJumpToLatestButton(unreadCount: unreadTranscriptCount) {
                    jumpToLatest(using: proxy)
                }
                .padding(.trailing, 16)
                .padding(.bottom, jumpToLatestBottomPadding)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.26, bounce: 0.08), value: isPinnedToBottom)
        .animation(.spring(duration: 0.24, bounce: 0.1), value: unreadTranscriptCount)
    }

    private func scrollTranscriptToBottom(using proxy: ScrollViewProxy, animated: Bool) {
        // animated=true  → user-triggered (jump to latest): smooth 0.22s
        // animated=false → auto-follow during streaming: fast 0.14s (smooth but keeps up)
        let animation: Animation = animated ? .easeOut(duration: 0.22) : .easeOut(duration: 0.5)
        withAnimation(animation) {
            proxy.scrollTo(transcriptBottomID, anchor: .bottom)
        }
        // Second pass catches layout that settles after content change
        DispatchQueue.main.async {
            withAnimation(animation) {
                proxy.scrollTo(transcriptBottomID, anchor: .bottom)
            }
        }
    }

    private func jumpToLatest(using proxy: ScrollViewProxy) {
        unreadTranscriptCount = 0
        isPinnedToBottom = true
        scrollTranscriptToBottom(using: proxy, animated: true)
    }

    // MARK: - Copilot Auth Banner

    @ViewBuilder
    private var copilotAuthBanner: some View {
        VStack(spacing: 12) {
            Label("Authentication Required", systemImage: "person.badge.key.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text("GitHub Copilot requires you to sign in before starting a session.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Button {
                    copilotService.openTerminalForAuth()
                } label: {
                    Label("Sign In", systemImage: "terminal")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    viewModel.retryAfterAuthentication()
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, composerOuterPadding)
        .padding(.bottom, transcriptBottomClearance + composerOuterPadding)
    }
}

struct AgentStreamingTextChange: Equatable {
    let stablePrefix: String
    let animatedSuffix: String

    init(previous: String, current: String) {
        if previous.isEmpty {
            self.stablePrefix = ""
            self.animatedSuffix = current
        } else if current.hasPrefix(previous) {
            self.stablePrefix = previous
            self.animatedSuffix = String(current.dropFirst(previous.count))
        } else {
            self.stablePrefix = current
            self.animatedSuffix = ""
        }
    }
}

private struct ComposerHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 72
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct AgentPromptComposerView: View {
    let ref: AgentRichComposerRef
    let state: AgentRuntimeState
    let statusText: String
    let agentName: String
    let canSend: Bool
    let onTextChange: (String) -> Void
    let onAtQuery: (String) -> Void
    let onAtDismiss: () -> Void
    let onSubmit: () -> Void
    let onStopResponding: () -> Void
    var onPickerKeyDown: ((NSEvent) -> Bool)? = nil
    @Environment(\.colorScheme) private var colorScheme
    @State private var richComposerHeight: CGFloat = 22

    private let cornerRadius: CGFloat = 24

    private var showsAnimatedStatus: Bool {
        state == .starting || state == .busy
    }

    private var showsStopButton: Bool {
        state == .busy
    }

    private var promptLabel: String {
        "Message \(agentName)"
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            AgentRichComposerView(
                ref: ref,
                placeholder: promptLabel,
                isEnabled: true,
                contentHeight: $richComposerHeight,
                onTextChange: onTextChange,
                onAtQuery: onAtQuery,
                onAtDismiss: onAtDismiss,
                onSubmit: onSubmit,
                onPickerKeyDown: onPickerKeyDown
            )
            .frame(height: richComposerHeight)
            .opacity(showsAnimatedStatus ? 0.82 : 1.0)

            Button(action: showsStopButton ? onStopResponding : onSubmit) {
                Circle()
                    .fill(buttonBackground)
                    .frame(width: 26, height: 26)
                    .overlay {
                        Image(systemName: showsStopButton ? "stop.fill" : "arrow.up")
                            .font(.system(size: showsStopButton ? 10 : 11, weight: .bold))
                            .foregroundStyle(buttonForeground)
                    }
            }
            .buttonStyle(.plain)
            .disabled(showsStopButton ? false : !canSend)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background {
            if #available(macOS 26.0, *) {
                Color.clear
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark ? Color.agentPanelBackground.opacity(0.9) : Color.agentPanelElevatedSurface.opacity(0.96))
                    .background {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
            }
        }
        .modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.1), radius: colorScheme == .dark ? 20 : 14, y: colorScheme == .dark ? 10 : 6)
        .animation(.easeInOut(duration: 0.2), value: showsAnimatedStatus)
    }

    private var buttonBackground: Color {
        if showsStopButton {
            return .red.opacity(0.18)
        }

        return canSend
            ? .accentColor.opacity(colorScheme == .dark ? 0.14 : 0.12)
            : .agentPanelSurface.opacity(colorScheme == .dark ? 0.6 : 0.82)
    }

    private var buttonForeground: Color {
        if showsStopButton {
            return .red.opacity(0.92)
        }

        return canSend
            ? .accentColor.opacity(0.96)
            : .secondary.opacity(0.65)
    }
}

private struct LiquidGlassModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.agentPanelSeparator.opacity(0.45))
                }
        }
    }
}

// MARK: - Command Picker

private struct AgentCommandPickerView: View {
    let suggestions: [AgentSlashCommand]
    let onSelect: (AgentSlashCommand) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(suggestions.prefix(10)) { command in
                    AgentCommandRowView(command: command, onSelect: onSelect)
                }
            }
            .padding(6)
        }
        .frame(maxHeight: 260)
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.agentPanelSeparator.opacity(0.4))
        }
        .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
    }
}

private struct AgentCommandRowView: View {
    let command: AgentSlashCommand
    let onSelect: (AgentSlashCommand) -> Void
    @State private var isHovered = false

    var body: some View {
        Button { onSelect(command) } label: {
            HStack(spacing: 8) {
                Text("/\(command.name)")
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                if !command.description.isEmpty {
                    Text(command.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                if isHovered {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.accentColor.opacity(0.1))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct AgentFileMentionPickerView: View {
    let results: [URL]
    let selectedIndex: Int
    let workingDirectory: URL?
    let onSelect: (URL) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(results.enumerated()), id: \.element.path) { index, url in
                        AgentFileMentionRowView(
                            url: url,
                            workingDirectory: workingDirectory,
                            isSelected: index == selectedIndex,
                            onSelect: onSelect
                        )
                        .id(index)
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: 240)
            .fixedSize(horizontal: false, vertical: true)
            .onChange(of: selectedIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.agentPanelSeparator.opacity(0.4))
        }
        .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
    }
}

private struct AgentFileMentionRowView: View {
    let url: URL
    let workingDirectory: URL?
    let isSelected: Bool
    let onSelect: (URL) -> Void
    @State private var isHovered = false

    private var isDirectory: Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    private var displayName: String { url.lastPathComponent }

    private var relativePath: String {
        guard let workDir = workingDirectory,
              url.path.hasPrefix(workDir.path) else { return url.lastPathComponent }
        return String(url.path.dropFirst(workDir.path.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private var isHighlighted: Bool { isSelected || isHovered }

    var body: some View {
        Button { onSelect(url) } label: {
            HStack(spacing: 8) {
                Image(systemName: isDirectory ? "folder.fill" : "doc.text")
                    .font(.system(size: 11))
                    .foregroundStyle(isHighlighted ? Color.accentColor : .secondary)
                    .frame(width: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.primary)
                    let rel = relativePath
                    if rel != displayName {
                        Text(rel)
                            .font(.caption2)
                            .foregroundStyle(isHighlighted ? Color.accentColor.opacity(0.8) : .secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected
                            ? Color.accentColor.opacity(0.15)
                            : Color.accentColor.opacity(0.08))
                }
            }
            .animation(.easeInOut(duration: 0.1), value: isHighlighted)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct AgentMessageRowView: View {
    let message: AgentMessage
    let isStreaming: Bool
    let provider: AgentProvider
    @Environment(\.colorScheme) private var colorScheme

    private var roleLabel: String {
        switch message.role {
        case .assistant:
            return provider.displayName
        case .user:
            return "You"
        case .system:
            return "Status"
        }
    }

    private var roleTint: Color {
        switch message.role {
        case .assistant:
            return .primary
        case .user:
            return .accentColor
        case .system:
            return .orange
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(backgroundFill)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(borderFill)
            }
    }

    private var backgroundFill: Color {
        switch message.role {
        case .assistant:
            return colorScheme == .dark
                ? .agentPanelSurface.opacity(0.72)
                : .agentPanelElevatedSurface.opacity(0.96)
        case .user:
            return .accentColor.opacity(colorScheme == .dark ? 0.12 : 0.1)
        case .system:
            return .orange.opacity(colorScheme == .dark ? 0.1 : 0.08)
        }
    }

    private var borderFill: Color {
        switch message.role {
        case .assistant:
            return .agentPanelSeparator.opacity(colorScheme == .dark ? 0.45 : 0.32)
        case .user:
            return .accentColor.opacity(colorScheme == .dark ? 0.18 : 0.16)
        case .system:
            return .orange.opacity(colorScheme == .dark ? 0.18 : 0.14)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if message.role == .assistant {
                    Image(provider.iconImageName)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(.secondary)
                } else {
                    Circle()
                        .fill(roleTint.opacity(0.85))
                        .frame(width: 7, height: 7)
                }
                Text(roleLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if message.role == .assistant {
                AgentStreamingAssistantTextView(
                    content: message.content,
                    isStreaming: isStreaming
                )
            } else {
                Text(message.content)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .textSelection(.enabled)
        .padding(14)
        .background(rowBackground)
    }
}

private struct AgentTranscriptSectionsView: View {
    let sections: [AgentTranscriptSection]
    let activeMessageID: AgentMessage.ID?
    let isBusy: Bool
    let pendingPermissionRequests: [AgentPermissionRequest]
    let provider: AgentProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                switch section.content {
                case let .message(message):
                    AgentMessageRowView(
                        message: message,
                        isStreaming: isBusy
                            && message.role == .assistant
                            && message.id == activeMessageID,
                        provider: provider
                    )
                    .transition(.opacity.animation(.easeIn(duration: 0.22)))
                case let .activityGroup(activities):
                    let isLast = index == sections.indices.last
                    AgentActivityListView(
                        activities: activities,
                        pendingPermissionRequests: isLast ? pendingPermissionRequests : []
                    )
                    .transition(.opacity.animation(.easeIn(duration: 0.22)))
                }
            }

            if case .message = sections.last?.content,
               let request = pendingPermissionRequests.first {
                AgentPermissionRequestView(request: request)
                    .transition(.opacity.animation(.easeIn(duration: 0.22)))
            }
        }
        .animation(.default, value: sections.map(\.id))
    }
}

private struct AgentActivityListView: View {
    let activities: [AgentActivity]
    let pendingPermissionRequests: [AgentPermissionRequest]
    @Environment(\.colorScheme) private var colorScheme

    private func permissionRequest(for activity: AgentActivity) -> AgentPermissionRequest? {
        if let title = pendingPermissionRequests.first(where: { $0.toolCallTitle == activity.title }) {
            return title
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(activities) { activity in
                AgentActivityRowView(
                    activity: activity,
                    pendingPermission: permissionRequest(for: activity)
                )
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(colorScheme == .dark
                            ? Color.agentPanelSurface.opacity(0.5)
                            : Color.agentPanelElevatedSurface.opacity(0.92))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.agentPanelSeparator.opacity(
                                    colorScheme == .dark ? 0.28 : 0.36
                                ))
                        }
                }
                .transition(.opacity.animation(.easeIn(duration: 0.20)))
            }
        }
        .animation(.default, value: activities.map(\.id))
        .animation(.spring(duration: 0.28, bounce: 0.1), value: pendingPermissionRequests.map(\.id))
    }
}

private struct AgentPermissionRequestView: View {
    let request: AgentPermissionRequest
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange.opacity(0.9))
                    .frame(width: 20, height: 20)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.orange.opacity(0.12))
                    }
                Text("Permission Required")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            if let message = request.message, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach(request.options, id: \.id) { option in
                    Button(option.name) {
                        request.resolve(.select(optionID: option.id))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Button("Cancel") {
                    request.resolve(.cancel)
                }
                .buttonStyle(.plain)
                .controlSize(.small)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.orange.opacity(colorScheme == .dark ? 0.08 : 0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.orange.opacity(colorScheme == .dark ? 0.22 : 0.18))
                }
        }
    }
}

/// Streams assistant text with a blur-in effect on ONLY the newly arrived
/// delta. Previously stable text is drawn without any animation, so there is
/// no full-message flicker on every update.
private struct AgentStreamingAssistantTextView: View {
    let content: String
    let isStreaming: Bool

    /// Text already committed to the screen — drawn with no animation.
    @State private var stableContent = ""
    /// The newest delta currently animating in.
    @State private var animatedSuffix = ""
    @State private var debounceTask: Task<Void, Never>?
    @State private var animationCompletionTask: Task<Void, Never>?
    @State private var targetContent = ""
    @State private var isAnimatingBatch = false
    @State private var animationStartedAt: Date?

    private let debounceNs: UInt64 = 70_000_000  // 70 ms
    private let charFadeDuration: Double = 0.35
    private let maxStaggerGap: Double = 0.05     // max delay between consecutive chars
    private let maxStaggerSpread: Double = 0.40  // total stagger never exceeds this
    @State private var currentBatchDuration: Double = 0.5

    var body: some View {
        Group {
            if isAnimatingBatch {
                TimelineView(.animation) { timeline in
                    animatedBlurText(at: timeline.date)
                }
            } else {
                Text(stableContent + animatedSuffix)
            }
        }
        .foregroundStyle(.primary.opacity(0.96))
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            targetContent = content
            if isStreaming && !content.isEmpty {
                // Chunks may have all arrived before this view's first render
                // (rapid burst delivery). Schedule instead of committing as stable
                // so the blur-in animation still triggers.
                schedule(content)
            } else {
                commitImmediately(content)
            }
        }
        .onDisappear {
            debounceTask?.cancel()
            debounceTask = nil
            animationCompletionTask?.cancel()
            animationCompletionTask = nil
        }
        .onChange(of: content) { _, new in
            targetContent = new
            schedule(new)
        }
        .onChange(of: isStreaming) { _, streaming in
            if !streaming {
                debounceTask?.cancel()
                debounceTask = nil
                if !isAnimatingBatch {
                    startNextBatchIfNeeded()
                }
            }
        }
    }

    @ViewBuilder
    private func animatedBlurText(at date: Date) -> some View {
        if let animationStartedAt {
            let elapsed = date.timeIntervalSince(animationStartedAt)
            // Quick global blur that fades out in the first 0.15s for a soft appearance.
            let blur = CGFloat(5 * max(0, 1 - elapsed / 0.15))
            // Overall lift offset follows the full batch progress.
            let overallProgress = min(1.0, elapsed / currentBatchDuration)
            let easedOverall = 1 - pow(1 - overallProgress, 3)
            let lift = CGFloat(5 * (1 - easedOverall))

            ZStack(alignment: .topLeading) {
                // Layer 1: stable text visible, suffix as transparent placeholder for layout.
                Text(stableLayerAttributedString())

                // Layer 2: stable hidden, suffix with per-character staggered opacity.
                Text(staggeredSuffixAttributedString(elapsed: elapsed))
                    .blur(radius: blur)
                    .offset(y: lift)
            }
        } else {
            Text(stableContent + animatedSuffix)
        }
    }

    private func staggeredSuffixAttributedString(elapsed: Double) -> AttributedString {
        var result = AttributedString(stableContent)
        result.foregroundColor = .clear

        let chars = Array(animatedSuffix)
        let gap = staggerGap(for: chars.count)

        for (i, char) in chars.enumerated() {
            let charElapsed = max(0, elapsed - Double(i) * gap)
            let rawProgress = min(1.0, charElapsed / charFadeDuration)
            let easedProgress = 1 - pow(1 - rawProgress, 3)

            var attr = AttributedString(String(char))
            attr.foregroundColor = Color.primary.opacity(0.96 * easedProgress)
            result.append(attr)
        }

        return result
    }

    private func stableLayerAttributedString() -> AttributedString {
        var result = AttributedString(stableContent)
        guard !animatedSuffix.isEmpty else { return result }
        var hiddenSuffix = AttributedString(animatedSuffix)
        hiddenSuffix.foregroundColor = .clear
        result.append(hiddenSuffix)
        return result
    }

    private func staggerGap(for count: Int) -> Double {
        guard count > 1 else { return 0 }
        return min(maxStaggerGap, maxStaggerSpread / Double(count - 1))
    }

    private func totalBatchDuration(for count: Int) -> Double {
        let spread = staggerGap(for: count) * Double(max(0, count - 1))
        return spread + charFadeDuration
    }

    private func schedule(_ new: String) {
        let displayed = stableContent + animatedSuffix
        guard displayed.isEmpty || new.hasPrefix(displayed) else {
            commitImmediately(new)
            return
        }

        guard isStreaming else {
            if !isAnimatingBatch {
                startNextBatchIfNeeded()
            }
            return
        }

        guard !isAnimatingBatch else { return }

        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: debounceNs)
            guard !Task.isCancelled else { return }
            startNextBatchIfNeeded()
        }
    }

    private func startNextBatchIfNeeded() {
        debounceTask?.cancel()
        debounceTask = nil

        guard !isAnimatingBatch else { return }

        guard targetContent.hasPrefix(stableContent) || stableContent.isEmpty else {
            commitImmediately(targetContent)
            return
        }

        let remaining = targetContent.hasPrefix(stableContent)
            ? String(targetContent.dropFirst(stableContent.count))
            : ""

        guard !remaining.isEmpty else {
            if !isStreaming {
                stableContent = targetContent
                animatedSuffix = ""
            }
            return
        }

        guard let batch = AgentStreamingTextBatching.batches(for: remaining).first else {
            commitImmediately(targetContent)
            return
        }

        animatedSuffix = batch.text
        currentBatchDuration = totalBatchDuration(for: batch.text.count)
        isAnimatingBatch = true
        animationStartedAt = Date()
        scheduleAnimationCompletion()
    }

    private func scheduleAnimationCompletion() {
        animationCompletionTask?.cancel()
        animationCompletionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(currentBatchDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            completeCurrentAnimation()
        }
    }

    private func completeCurrentAnimation() {
        animationCompletionTask?.cancel()
        animationCompletionTask = nil

        guard !animatedSuffix.isEmpty else {
            isAnimatingBatch = false
            return
        }

        stableContent += animatedSuffix
        animatedSuffix = ""
        isAnimatingBatch = false
        animationStartedAt = nil

        guard targetContent != stableContent else {
            if !isStreaming {
                stableContent = targetContent
            }
            return
        }

        guard targetContent.hasPrefix(stableContent) else {
            commitImmediately(targetContent)
            return
        }

        startNextBatchIfNeeded()
    }

    private func commitImmediately(_ new: String) {
        debounceTask?.cancel()
        debounceTask = nil
        animationCompletionTask?.cancel()
        animationCompletionTask = nil

        stableContent = new
        animatedSuffix = ""
        targetContent = new
        isAnimatingBatch = false
        animationStartedAt = nil
    }
}

private enum AgentFileSearcher {
    static let ignoredDirectories: Set<String> = [
        "node_modules", ".git", ".build", "DerivedData", "Pods", ".hg", ".svn",
        "__pycache__", ".mypy_cache", "dist", "build", ".next", ".nuxt"
    ]

    nonisolated static func search(query: String, in directory: URL, limit: Int = 10) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        let q = query.lowercased()
        var results: [URL] = []

        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if ignoredDirectories.contains(name) {
                enumerator.skipDescendants()
                continue
            }
            if q.isEmpty || name.lowercased().contains(q) || url.path.lowercased().contains(q) {
                results.append(url)
                if results.count >= limit { break }
            }
        }
        return results
    }
}

struct AgentTranscriptScrollMetrics: Equatable {
    let contentOffsetY: CGFloat
    let contentHeight: CGFloat
    let containerHeight: CGFloat
}

enum AgentTranscriptLayout {
    static func bottomClearance(composerHeight: CGFloat, composerOuterPadding: CGFloat) -> CGFloat {
        max(1, composerHeight + max(0, composerOuterPadding))
    }
}

enum AgentTranscriptAutoScrollState {
    static func isNearBottom(
        metrics: AgentTranscriptScrollMetrics,
        threshold: CGFloat
    ) -> Bool {
        isNearBottom(
            contentOffsetY: metrics.contentOffsetY,
            contentHeight: metrics.contentHeight,
            containerHeight: metrics.containerHeight,
            threshold: threshold
        )
    }

    static func isNearBottom(
        contentOffsetY: CGFloat,
        contentHeight: CGFloat,
        containerHeight: CGFloat,
        threshold: CGFloat
    ) -> Bool {
        guard contentHeight > 0, containerHeight > 0 else {
            return true
        }

        let viewportBottom = contentOffsetY + containerHeight
        let distanceFromBottom = max(0, contentHeight - viewportBottom)
        return distanceFromBottom <= max(0, threshold)
    }

    static func nextPinnedState(
        currentPinned: Bool,
        previousMetrics: AgentTranscriptScrollMetrics,
        newMetrics: AgentTranscriptScrollMetrics,
        threshold: CGFloat
    ) -> Bool {
        if isNearBottom(metrics: newMetrics, threshold: threshold) {
            return true
        }

        guard currentPinned else {
            return false
        }

        let movedUpward = newMetrics.contentOffsetY < (previousMetrics.contentOffsetY - 1)
        return !movedUpward
    }
}

struct AgentStreamingTextBatch: Equatable {
    let text: String
    let index: Int
    let totalCount: Int
}

enum AgentStreamingTextBatching {
    private static let minimumCharactersPerBatch = 28
    private static let maximumCharactersPerBatch = 70

    static func batches(for text: String) -> [AgentStreamingTextBatch] {
        let characters = Array(text)
        guard !characters.isEmpty else { return [] }

        var ranges: [Range<Int>] = []
        var startIndex = 0

        while startIndex < characters.count {
            let remaining = characters.count - startIndex
            if remaining <= maximumCharactersPerBatch {
                ranges.append(startIndex..<characters.count)
                break
            }

            let preferredUpperBound = min(startIndex + maximumCharactersPerBatch, characters.count)
            let preferredLowerBound = min(startIndex + minimumCharactersPerBatch, preferredUpperBound)
            let splitIndex = preferredSplitIndex(
                in: characters,
                lowerBound: preferredLowerBound,
                upperBound: preferredUpperBound
            )

            ranges.append(startIndex..<splitIndex)
            startIndex = splitIndex
        }

        return ranges.enumerated().map { index, range in
            AgentStreamingTextBatch(
                text: String(characters[range]),
                index: index,
                totalCount: ranges.count
            )
        }
    }

    private static func preferredSplitIndex(
        in characters: [Character],
        lowerBound: Int,
        upperBound: Int
    ) -> Int {
        guard lowerBound < upperBound else { return upperBound }

        for index in stride(from: upperBound - 1, through: lowerBound, by: -1) {
            if isWhitespaceOrBoundary(characters[index]) {
                return index + 1
            }
        }

        return upperBound
    }

    private static func isWhitespaceOrBoundary(_ character: Character) -> Bool {
        if character.unicodeScalars.allSatisfy({ $0.properties.isWhitespace }) {
            return true
        }

        return ",.;:!?)]}".contains(character)
    }
}

enum AgentTranscriptUnreadState {
    static func nextUnreadCount(currentCount: Int, isPinnedToBottom: Bool) -> Int {
        guard !isPinnedToBottom else { return 0 }
        return min(currentCount + 1, 99)
    }

    static func badgeText(for unreadCount: Int) -> String {
        unreadCount > 99 ? "99+" : "\(unreadCount)"
    }
}

private struct AgentTranscriptJumpToLatestButton: View {
    let unreadCount: Int
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.accentColor)

                Text("Jump to latest")
                    .font(.subheadline.weight(.semibold))

                if unreadCount > 0 {
                    Text(AgentTranscriptUnreadState.badgeText(for: unreadCount))
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.accentColor, in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.agentPanelSeparator.opacity(colorScheme == .dark ? 0.26 : 0.4))
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.12 : 0.06), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .help(unreadCount > 0 ? "Scroll to the latest response (\(unreadCount) new updates)" : "Scroll to the latest response")
    }
}

@available(macOS 15.0, *)
private extension Text.Layout {
    var flattenedRuns: some RandomAccessCollection<Text.Layout.Run> {
        flatMap { line in
            line
        }
    }
}

private struct AgentInfoBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(tint.opacity(0.12))
                    .overlay {
                        Capsule()
                            .strokeBorder(tint.opacity(0.14))
                    }
            }
    }
}

private struct AgentActivityRowView: View {
    let activity: AgentActivity
    var pendingPermission: AgentPermissionRequest? = nil

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.30, bounce: 0.06)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: activityIcon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(statusTint)
                        .frame(width: 20, height: 20)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(statusTint.opacity(0.12))
                        }

                    Text(activity.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary.opacity(0.82))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(duration: 0.24, bounce: 0.1), value: isExpanded)

                    AgentInfoBadge(title: activity.status.label, tint: statusTint)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .padding(.horizontal, 10)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: 0.14).delay(0.18)),
                        removal: .opacity.animation(.easeOut(duration: 0.10))
                    ))
                AgentActivityDetailView(activity: activity)
                    .padding(10)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: 0.18).delay(0.20)),
                        removal: .opacity.animation(.easeOut(duration: 0.12))
                    ))
            }

            if let request = pendingPermission {
                Divider()
                    .padding(.horizontal, 10)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: 0.16).delay(0.20)),
                        removal: .opacity.animation(.easeOut(duration: 0.12))
                    ))
                AgentPermissionInlineView(request: request)
                    .padding(10)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: 0.20).delay(0.22)),
                        removal: .opacity.animation(.easeOut(duration: 0.14))
                    ))
            }
        }
        .animation(.spring(duration: 0.30, bounce: 0.06), value: pendingPermission?.id)
    }

    private var activityIcon: String {
        if activity.kind != .tool {
            return activity.kind.systemImage
        }
        switch activity.toolKind {
        case "read":             return "doc.text"
        case "edit":             return "pencil"
        case "delete":           return "trash"
        case "move":             return "arrow.right.doc.on.clipboard"
        case "search":           return "magnifyingglass"
        case "execute":          return "terminal"
        case "think":            return "brain"
        case "fetch":            return "arrow.down.circle"
        case "switch_mode":      return "arrow.left.arrow.right"
        case "plan":             return "list.bullet.clipboard"
        case "exit_plan_mode":   return "checkmark.circle"
        default:                 return "wrench.and.screwdriver"
        }
    }

    private var statusTint: Color {
        switch activity.status {
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        case .info: return .secondary
        }
    }
}

private struct AgentActivityDetailView: View {
    let activity: AgentActivity
    @Environment(\.colorScheme) private var colorScheme

    private var hasAnyDetail: Bool {
        activity.command != nil || activity.output != nil || (activity.detail != nil && !activity.detail!.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let command = activity.command {
                detailSection(label: "Command") {
                    Text(command)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.85))
                        .textSelection(.enabled)
                        .lineLimit(6)
                }
            }

            if let output = activity.output, !output.isEmpty {
                detailSection(label: "Output") {
                    ScrollView(.vertical) {
                        Text(output)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.82))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(colorScheme == .dark
                                ? Color.black.opacity(0.25)
                                : Color.black.opacity(0.04))
                    }
                }
            }

            if let detail = activity.detail, !detail.isEmpty {
                detailSection(label: "Info") {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !hasAnyDetail {
                Text("No additional details available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func detailSection(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }
}

private struct AgentPermissionInlineView: View {
    let request: AgentPermissionRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.orange.opacity(0.9))
                Text("Permission Required")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange.opacity(0.9))
            }

            if let message = request.message, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach(request.options, id: \.id) { option in
                    Button(option.name) {
                        request.resolve(.select(optionID: option.id))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Button("Cancel") {
                    request.resolve(.cancel)
                }
                .buttonStyle(.plain)
                .controlSize(.small)
                .foregroundStyle(.secondary)
            }
        }
    }
}