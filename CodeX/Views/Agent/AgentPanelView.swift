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
            HStack(spacing: 8) {
                ForEach(viewModel.runtimes) { runtime in
                    HStack(spacing: 6) {
                        Button {
                            viewModel.selectRuntime(id: runtime.id)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: runtime.provider.systemImage)
                                Text(runtime.title)
                                    .lineLimit(1)
                                AgentRuntimeStateBadge(state: runtime.state)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(tabFill(isActive: viewModel.activeRuntimeID == runtime.id))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(tabBorder(isActive: viewModel.activeRuntimeID == runtime.id))
                                    }
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.closeRuntime(id: runtime.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Close \(runtime.title)")
                    }
                }

                Button {
                    viewModel.showLauncher()
                } label: {
                    Label("New Agent", systemImage: "plus")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
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
            }
            .padding(12)
        }
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
    @State private var draft = ""
    @State private var isPinnedToBottom = true
    @State private var unreadTranscriptCount = 0

    private let transcriptBottomID = "agent-transcript-bottom"
    private let transcriptAutoScrollThreshold: CGFloat = 72
    private let composerOuterPadding: CGFloat = 16

    private var transcriptChangeToken: String {
        viewModel.transcriptSections.map(\.changeToken).joined(separator: "||")
    }

    private var canSendDraft: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && viewModel.state != .busy
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

    private var runtimeBackgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                .agentPanelBackground,
                .agentPanelSecondaryBackground,
                .agentPanelBackground.opacity(0.96)
            ]
        }

        return [
            .agentPanelElevatedSurface,
            .agentPanelSurface,
            .agentPanelElevatedSurface
        ]
    }

    @State private var composerHeight: CGFloat = 72

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                transcriptScrollView(proxy: proxy)
            }

            // Auth required banner — chỉ hiện khi Copilot chưa đăng nhập
            if viewModel.requiresAuthentication {
                copilotAuthBanner
            }

            AgentPromptComposerView(
                text: $draft,
                state: viewModel.state,
                statusText: viewModel.footerText,
                canSend: canSendDraft,
                onSubmit: submitDraft,
                onStopResponding: viewModel.stopResponding
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
        .background {
            LinearGradient(
                colors: runtimeBackgroundColors,
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func submitDraft() {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, viewModel.state != .busy else { return }
        draft = ""
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
                        isBusy: viewModel.state == .busy
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
            scrollTranscriptToBottom(using: proxy, animated: false)
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
        let action = {
            proxy.scrollTo(transcriptBottomID, anchor: .bottom)
        }

        let performScroll = {
            if animated {
                withAnimation(.easeOut(duration: 0.18), action)
            } else {
                action()
            }
        }

        performScroll()

        DispatchQueue.main.async {
            performScroll()
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
    @Binding var text: String
    let state: AgentRuntimeState
    let statusText: String
    let canSend: Bool
    let onSubmit: () -> Void
    let onStopResponding: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private let cornerRadius: CGFloat = 24

    private var showsAnimatedStatus: Bool {
        state == .starting || state == .busy
    }

    private var showsStopButton: Bool {
        state == .busy
    }

    private var promptLabel: String {
        switch state {
        case .ready:
            return "Message Codex"
        case .starting, .busy, .stopped, .error:
            return statusText
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            TextField(
                "",
                text: $text,
                prompt: Text(promptLabel)
                    .foregroundStyle(Color.secondary.opacity(showsAnimatedStatus ? 0.92 : 0.72))
            )
            .textFieldStyle(.plain)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary.opacity(showsAnimatedStatus ? 0.82 : 0.96))
            .onSubmit(onSubmit)

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

private struct AgentMessageRowView: View {
    let message: AgentMessage
    let isStreaming: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var roleLabel: String {
        switch message.role {
        case .assistant:
            return "Assistant"
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
            HStack(spacing: 8) {
                Circle()
                    .fill(roleTint.opacity(0.85))
                    .frame(width: 7, height: 7)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(sections) { section in
                switch section.content {
                case let .message(message):
                    AgentMessageRowView(
                        message: message,
                        isStreaming: isBusy
                            && message.role == .assistant
                            && message.id == activeMessageID
                    )
                case let .activityGroup(activities):
                    AgentActivityGroupView(activities: activities)
                }
            }
        }
    }
}

private struct AgentActivityGroupView: View {
    let activities: [AgentActivity]
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme

    private var hasRunningActivity: Bool {
        activities.contains { $0.status == .running }
    }

    private var summaryText: String {
        if let running = activities.last(where: { $0.status == .running }) {
            return running.title
        }
        let count = activities.count
        return "\(count) tool\(count == 1 ? "" : "s") called"
    }

    private var summaryTint: Color {
        if hasRunningActivity { return .blue }
        if activities.contains(where: { $0.status == .failed }) { return .red }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: hasRunningActivity ? "circle.dotted" : "hammer")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(summaryTint.opacity(0.8))
                        .frame(width: 20, height: 20)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(summaryTint.opacity(0.1))
                        }

                    Text(summaryText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentTransition(.numericText())

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(activities) { activity in
                        AgentActivityRowView(activity: activity)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .blurReplace))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(colorScheme == .dark ? Color.agentPanelSurface.opacity(0.55) : Color.agentPanelElevatedSurface.opacity(0.95))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.agentPanelSeparator.opacity(colorScheme == .dark ? 0.35 : 0.42))
                }
        }
        .animation(.easeInOut(duration: 0.28), value: summaryText)
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
    private let animDuration: Double = 0.5

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
        let progress = visualProgress(at: date)
        let easedProgress = easedVisualProgress(at: date)

        ZStack(alignment: .topLeading) {
            Text(stableLayerAttributedString())

            Text(animatedLayerAttributedString())
                .compositingGroup()
                .blur(radius: blurRadius(for: progress))
                .opacity(animatedLayerOpacity(for: easedProgress))
                .offset(y: verticalLiftOffset(for: easedProgress))
        }
    }

    private func visualProgress(at date: Date) -> Double {
        guard isAnimatingBatch, !animatedSuffix.isEmpty, let animationStartedAt else {
            return 1
        }

        let elapsed = date.timeIntervalSince(animationStartedAt)
        return max(0, min(1, elapsed / animDuration))
    }

    private func easedVisualProgress(at date: Date) -> Double {
        let progress = visualProgress(at: date)
        return 1 - pow(1 - progress, 3)
    }

    private func stableLayerAttributedString() -> AttributedString {
        var result = AttributedString(stableContent)
        guard !animatedSuffix.isEmpty else { return result }

        var hiddenSuffix = AttributedString(animatedSuffix)
        hiddenSuffix.foregroundColor = .clear
        result.append(hiddenSuffix)
        return result
    }

    private func animatedLayerAttributedString() -> AttributedString {
        var hiddenStable = AttributedString(stableContent)
        hiddenStable.foregroundColor = .clear

        var visibleSuffix = AttributedString(animatedSuffix)
        visibleSuffix.foregroundColor = .primary
        hiddenStable.append(visibleSuffix)
        return hiddenStable
    }

    private func blurRadius(for progress: Double) -> CGFloat {
        CGFloat(8 * (1 - max(0, min(1, progress))))
    }

    private func animatedLayerOpacity(for easedProgress: Double) -> Double {
        0.1 + (0.9 * max(0, min(1, easedProgress)))
    }

    private func verticalLiftOffset(for easedProgress: Double) -> CGFloat {
        CGFloat(6 * (1 - max(0, min(1, easedProgress))))
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
        isAnimatingBatch = true
        animationStartedAt = Date()
        scheduleAnimationCompletion()
    }

    private func scheduleAnimationCompletion() {
        animationCompletionTask?.cancel()
        animationCompletionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(animDuration * 1_000_000_000))
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

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: activity.kind.systemImage)
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

            AgentInfoBadge(title: activity.status.label, tint: statusTint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private var statusTint: Color {
        switch activity.status {
        case .running:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .info:
            return .secondary
        }
    }
}