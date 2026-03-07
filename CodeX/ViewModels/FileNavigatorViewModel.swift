import Foundation

@Observable
class FileNavigatorViewModel {
    var rootNodes: [FileNode] = []
    var selectedNode: FileNode?
    var expandedURLs: Set<URL> = []
    var gitStatusesByURL: [URL: GitFileStatus] = [:]

    func loadDirectory(at url: URL, using service: FileSystemService) {
        selectedNode = nil
        expandedURLs.removeAll()
        rootNodes = service.buildFileTree(at: url)
    }

    func toggleExpansion(of node: FileNode) {
        if expandedURLs.contains(node.url) {
            expandedURLs.remove(node.url)
        } else {
            expandedURLs.insert(node.url)
        }
    }

    func isExpanded(_ node: FileNode) -> Bool {
        expandedURLs.contains(node.url)
    }

    func refresh(at url: URL, using service: FileSystemService) {
        rootNodes = service.buildFileTree(at: url)
    }

    func loadChildren(for node: FileNode) {
        let service = FileSystemService()
        service.loadChildren(for: node)
    }

    func updateGitStatuses(_ statuses: [URL: GitFileStatus]) {
        gitStatusesByURL = statuses
    }
}
