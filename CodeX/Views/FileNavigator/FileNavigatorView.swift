import SwiftUI

struct FileNavigatorView: View {
    @Bindable var viewModel: FileNavigatorViewModel
    let gitStatusesByURL: [URL: GitFileStatus]
    var onFileSelected: (FileNode) -> Void

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
            }
        )
    }
}
