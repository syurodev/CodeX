import SwiftUI

struct RunScriptPopoverView: View {
    let appViewModel: AppViewModel
    @Binding var isPresented: Bool

    private var vm: ProjectRunViewModel { appViewModel.projectRunViewModel }

    var body: some View {
        VStack(spacing: 0) {
            scriptList
            if vm.hasAnyRunning {
                Divider()
                stopAllFooter
            }
        }
        .frame(width: 300)
    }

    // MARK: - Script list

    private var scriptList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                if vm.scriptGroups.count == 1 {
                    // Single package: flat list, no header
                    ForEach(vm.scriptGroups[0].scripts) { script in
                        scriptRow(script, groupName: vm.scriptGroups[0].name)
                    }
                    .padding(.vertical, 6)
                } else {
                    // Monorepo: grouped with headers
                    ForEach(vm.scriptGroups) { group in
                        groupSection(group)
                    }
                }
            }
        }
        .frame(maxHeight: 420)
    }

    // MARK: - Group section

    private func groupSection(_ group: RunScriptGroup) -> some View {
        let groupHasRunning = group.scripts.contains { vm.isRunning($0) }
        return VStack(alignment: .leading, spacing: 0) {
            // Group header
            HStack {
                Text(group.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if groupHasRunning {
                    Button {
                        for script in group.scripts where vm.isRunning(script) {
                            appViewModel.stopScript(script)
                        }
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Stop all in \(group.name)")
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 3)

            ForEach(group.scripts) { script in
                scriptRow(script, groupName: group.name)
            }
        }
    }

    // MARK: - Script row

    private func scriptRow(_ script: RunScript, groupName: String) -> some View {
        let running = vm.isRunning(script)
        let state = vm.runState(for: script)

        return HStack(spacing: 8) {
            // Running indicator dot
            Circle()
                .fill(running ? Color.green : Color.clear)
                .frame(width: 6, height: 6)
                .overlay(
                    Circle()
                        .stroke(Color.secondary.opacity(running ? 0 : 0.3), lineWidth: 1)
                )

            // Script info
            VStack(alignment: .leading, spacing: 1) {
                Text(script.name)
                    .font(.system(size: 13, weight: running ? .semibold : .regular))
                    .foregroundStyle(.primary)

                Group {
                    if case .error(let msg) = state {
                        Text(msg)
                            .foregroundStyle(.red)
                    } else if case .running(_, let port) = state, let port {
                        Text(":\(port)")
                            .foregroundStyle(.green)
                    } else {
                        Text(script.command)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)
            }

            Spacer()

            // Stop button (if running) or starting indicator
            if case .starting = state {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 16, height: 16)
            } else if running {
                Button {
                    appViewModel.stopScript(script)
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: 22, height: 22)
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("Stop \(script.name)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            running
                ? Color.green.opacity(0.08)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            guard !running else { return }
            appViewModel.run(script: script, groupName: groupName)
            isPresented = false
        }
        .padding(.horizontal, 6)
        .animation(.easeInOut(duration: 0.15), value: running)
    }

    // MARK: - Stop all footer

    private var stopAllFooter: some View {
        HStack {
            Spacer()
            Button {
                appViewModel.stopAllScripts()
            } label: {
                Label("Stop All", systemImage: "stop.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }
}
