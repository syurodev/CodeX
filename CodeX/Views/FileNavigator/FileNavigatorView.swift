import SwiftUI

struct FileNavigatorView: View {
    @Bindable var viewModel: FileNavigatorViewModel
    let gitStatusesByURL: [URL: GitFileStatus]
    var onFileSelected: (FileNode) -> Void

    // MARK: Context menu callbacks
    var onNewFile: (URL) -> Void = { _ in }
    var onNewFolder: (URL) -> Void = { _ in }
    var onRename: (FileNode) -> Void = { _ in }
    var onTrash: (FileNode) -> Void = { _ in }
    var onDuplicate: (FileNode) -> Void = { _ in }
    var onRevealInFinder: (FileNode) -> Void = { _ in }
    var onCopyPath: (FileNode) -> Void = { _ in }
    var onCopyRelativePath: (FileNode) -> Void = { _ in }

    var body: some View {
        FileOutlineView(
            rootNodes: viewModel.rootNodes,
            gitStatusesByURL: gitStatusesByURL,
            selectedNode: $viewModel.selectedNode,
            onFileDoubleClicked: { node in
                onFileSelected(node)
            },
            onNodeExpanded: { node in
                viewModel.loadChildren(for: node)
            },
            onNewFile: onNewFile,
            onNewFolder: onNewFolder,
            onRename: onRename,
            onTrash: onTrash,
            onDuplicate: onDuplicate,
            onRevealInFinder: onRevealInFinder,
            onCopyPath: onCopyPath,
            onCopyRelativePath: onCopyRelativePath
        )
    }
}
