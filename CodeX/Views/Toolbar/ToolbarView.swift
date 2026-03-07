import SwiftUI

struct ToolbarGitBranchButton: View {
    @Bindable var appViewModel: AppViewModel

    var body: some View {
        Button(action: {
            appViewModel.gitViewModel.is_popover_presented.toggle()
        }) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 13, weight: .medium))

                Text(appViewModel.gitViewModel.current_branch)
                    .font(.system(size: 13, weight: .semibold))

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .glassEffect(.clear.interactive(), in: Capsule())
        .disabled(!appViewModel.gitViewModel.is_git_repo)
        .popover(isPresented: $appViewModel.gitViewModel.is_popover_presented, arrowEdge: .bottom) {
            BranchPopoverView(appViewModel: appViewModel)
        }
        .alert("Rename Branch", isPresented: $appViewModel.gitViewModel.isShowingRenameAlert) {
            TextField("New branch name", text: $appViewModel.gitViewModel.branchNameInput)
            Button("Rename") {
                let oldName = appViewModel.gitViewModel.targetBranchForAction
                let newName = appViewModel.gitViewModel.branchNameInput.trimmingCharacters(in: .whitespaces)
                if !newName.isEmpty && newName != oldName {
                    appViewModel.rename_branch(oldName: oldName, newName: newName)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter a new name for branch '\(appViewModel.gitViewModel.targetBranchForAction)'.")
        }
        .sheet(isPresented: $appViewModel.gitViewModel.isShowingNewBranchAlert) {
            NewBranchSheetView(appViewModel: appViewModel)
        }
    }
}

struct ToolbarProjectStatusView: View {
    let projectName: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            fullContent
            compactContent
            titleOnlyContent
            iconOnlyContent
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(minWidth: 32, idealWidth: 280, maxWidth: 420)
        .glassEffect(.clear, in: Capsule())
    }

    private var fullContent: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "macwindow")
                    .font(.system(size: 11))
                Text(projectName)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 11))
                Text("My Mac")
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            .foregroundColor(.secondary)

            Text("Running \(projectName)")
                .font(.system(size: 11))
                .foregroundColor(.primary.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .allowsTightening(true)
    }

    private var compactContent: some View {
        HStack(spacing: 6) {
            Image(systemName: "macwindow")
                .font(.system(size: 11))
            Text(projectName)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)
            Image(systemName: "laptopcomputer")
                .font(.system(size: 11))
        }
        .foregroundColor(.secondary)
        .allowsTightening(true)
    }

    private var titleOnlyContent: some View {
        Text(projectName)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .allowsTightening(true)
    }

    private var iconOnlyContent: some View {
        Image(systemName: "macwindow")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
    }
}

