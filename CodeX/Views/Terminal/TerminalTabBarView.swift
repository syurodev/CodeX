import SwiftUI

struct TerminalTabBarView: View {
    @Bindable var viewModel: TerminalPanelViewModel
    let onNewSession: () -> Void
    let onClose: () -> Void

    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 0) {
            // Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 6.0) {
                    HStack(spacing: 2) {
                        // ── Run output tabs (always first) ────────────────────
                        ForEach(viewModel.runOutputItems) { runItem in
                            RunOutputTabItemView(
                                item: runItem,
                                isSelected: viewModel.activeRunTabID == runItem.id,
                                onSelect: { viewModel.selectRunTab(id: runItem.id) },
                                onClose:  { viewModel.closeRunTab(id: runItem.id) }
                            )
                            .glassEffectID(runItem.id, in: tabNamespace)
                            .glassEffectTransition(.matchedGeometry)
                        }

                        // ── Terminal sessions ──────────────────────────────────
                        ForEach(viewModel.sessions) { session in
                            TerminalTabItemView(
                                session: session,
                                isSelected: !viewModel.isRunTabActive && session.id == viewModel.activeSessionID,
                                onSelect: { viewModel.selectSession(id: session.id) },
                                onClose:  { viewModel.closeSession(id: session.id) }
                            )
                            .glassEffectID(session.id, in: tabNamespace)
                            .glassEffectTransition(.matchedGeometry)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }

            Spacer(minLength: 8)

            // Trailing actions
            GlassEffectContainer(spacing: 8.0) {
                HStack(spacing: 4) {
                    Button(action: onNewSession) {
                        Image(systemName: "plus")
                            .frame(width: 24, height: 20)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive())
                    .help("New Terminal")

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .frame(width: 24, height: 20)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive())
                    .help("Close Terminal Panel")
                }
                .foregroundStyle(.secondary)
                .font(.system(size: 11, weight: .medium))
            }
            .padding(.trailing, 12)
        }
        .frame(height: 36)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Run output tab item

private struct RunOutputTabItemView: View {
    let item: RunOutputTabModel
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                if item.isAlive {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                } else {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Text(item.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)

                if isSelected || isHovering {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12, height: 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovering ? 1.0 : 0.6)
                } else {
                    Spacer().frame(width: 12)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .opacity(isSelected ? 1.0 : (isHovering ? 0.85 : 0.5))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Terminal session tab item

private struct TerminalTabItemView: View {
    let session: TerminalSessionViewModel
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Image(systemName: session.isAlive ? "terminal" : "terminal.fill")
                    .foregroundStyle(session.isAlive ? .secondary : .tertiary)
                    .font(.system(size: 11))

                Text(session.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)

                if isSelected || isHovering {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12, height: 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovering ? 1.0 : 0.6)
                } else {
                    Spacer().frame(width: 12)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .opacity(isSelected ? 1.0 : (isHovering ? 0.85 : 0.5))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}
