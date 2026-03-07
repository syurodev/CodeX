import SwiftUI
import AppKit

struct FileOutlineView: NSViewControllerRepresentable {
    let rootNodes: [FileNode]
    let gitStatusesByURL: [URL: GitFileStatus]
    @Binding var selectedNode: FileNode?
    var onFileDoubleClicked: (FileNode) -> Void
    var onNodeExpanded: (FileNode) -> Void
    
    func makeNSViewController(context: Context) -> FileOutlineViewController {
        let vc = FileOutlineViewController()
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateNSViewController(_ nsViewController: FileOutlineViewController, context: Context) {
        nsViewController.update(with: rootNodes, gitStatusesByURL: gitStatusesByURL)
        nsViewController.selectNode(selectedNode)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, FileOutlineViewControllerDelegate {
        var parent: FileOutlineView
        
        init(_ parent: FileOutlineView) {
            self.parent = parent
        }
        
        func fileOutlineViewController(_ vc: FileOutlineViewController, didSelect node: FileNode?) {
            DispatchQueue.main.async {
                self.parent.selectedNode = node
            }
        }
        
        func fileOutlineViewController(_ vc: FileOutlineViewController, didDoubleClick node: FileNode) {
            if !node.isDirectory {
                DispatchQueue.main.async {
                    self.parent.onFileDoubleClicked(node)
                }
            }
        }
        
        func fileOutlineViewController(_ vc: FileOutlineViewController, didExpand node: FileNode) {
            self.parent.onNodeExpanded(node)
        }
    }
}

protocol FileOutlineViewControllerDelegate: AnyObject {
    func fileOutlineViewController(_ vc: FileOutlineViewController, didSelect node: FileNode?)
    func fileOutlineViewController(_ vc: FileOutlineViewController, didDoubleClick node: FileNode)
    func fileOutlineViewController(_ vc: FileOutlineViewController, didExpand node: FileNode)
}

class FileOutlineViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
    weak var delegate: FileOutlineViewControllerDelegate?
    
    private var outlineView: NSOutlineView!
    private var scrollView: NSScrollView!
    private var rootNodes: [FileNode] = []
    private var gitStatusesByURL: [URL: GitFileStatus] = [:]
    private var directoryStatusesByURL: [URL: GitFileStatus] = [:]
    
    override func loadView() {
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        
        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.rowHeight = 24
        outlineView.style = .sourceList
        outlineView.allowsMultipleSelection = false
        outlineView.backgroundColor = .clear
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FileColumn"))
        column.title = "Files"
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        
        outlineView.dataSource = self
        outlineView.delegate = self
        
        scrollView.documentView = outlineView
        self.view = scrollView
        
        outlineView.target = self
        outlineView.doubleAction = #selector(onDoubleClick(_:))
    }
    
    func update(with nodes: [FileNode], gitStatusesByURL: [URL: GitFileStatus]) {
        let currentIDs = rootNodes.map(\.id)
        let newIDs = nodes.map(\.id)
        let nodesDidChange = currentIDs != newIDs
        let statusesDidChange = self.gitStatusesByURL != gitStatusesByURL

        guard nodesDidChange || statusesDidChange else { return }

        if nodesDidChange {
            self.rootNodes = nodes
        }

        if statusesDidChange {
            self.gitStatusesByURL = gitStatusesByURL
            self.directoryStatusesByURL = buildDirectoryStatuses(from: gitStatusesByURL)
        }

        outlineView.reloadData()
    }
    
    func selectNode(_ node: FileNode?) {
        guard let node = node else {
            if outlineView.selectedRow != -1 {
                outlineView.deselectAll(nil)
            }
            return
        }
        
        let row = outlineView.row(forItem: node)
        if row >= 0 && outlineView.selectedRow != row {
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            outlineView.scrollRowToVisible(row)
        }
    }
    
    @objc private func onDoubleClick(_ sender: Any) {
        let row = outlineView.clickedRow
        guard row >= 0, let item = outlineView.item(atRow: row) as? FileNode else { return }
        
        if item.isDirectory {
            if outlineView.isItemExpanded(item) {
                outlineView.collapseItem(item)
            } else {
                outlineView.expandItem(item)
            }
        } else {
            delegate?.fileOutlineViewController(self, didDoubleClick: item)
        }
    }
    
    // MARK: - NSOutlineViewDataSource
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return rootNodes.count
        }
        guard let node = item as? FileNode else { return 0 }
        return node.children?.count ?? 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return rootNodes[index]
        }
        let node = item as! FileNode
        return node.children![index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? FileNode else { return false }
        return node.isDirectory
    }
    
    // MARK: - NSOutlineViewDelegate
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outlineView.selectedRow
        if row >= 0 {
            let item = outlineView.item(atRow: row) as? FileNode
            delegate?.fileOutlineViewController(self, didSelect: item)
        } else {
            delegate?.fileOutlineViewController(self, didSelect: nil)
        }
    }
    
    func outlineViewItemWillExpand(_ notification: Notification) {
        if let node = notification.userInfo?["NSObject"] as? FileNode {
            delegate?.fileOutlineViewController(self, didExpand: node)
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? FileNode else { return nil }
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("FileCell")
        var cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellIdentifier
            
            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyUpOrDown
            
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.font = .systemFont(ofSize: 13)
            textField.lineBreakMode = .byTruncatingTail
            textField.isBordered = false
            textField.drawsBackground = false
            textField.isEditable = false

            let statusField = NSTextField(labelWithString: "")
            statusField.translatesAutoresizingMaskIntoConstraints = false
            statusField.font = .systemFont(ofSize: 11, weight: .semibold)
            statusField.alignment = .right
            statusField.isHidden = true
            statusField.setContentHuggingPriority(.required, for: .horizontal)
            statusField.setContentCompressionResistancePriority(.required, for: .horizontal)
            
            cell?.addSubview(imageView)
            cell?.addSubview(textField)
            cell?.addSubview(statusField)
            cell?.imageView = imageView
            cell?.textField = textField
            statusField.identifier = NSUserInterfaceItemIdentifier("GitStatusField")
            
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                imageView.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),
                
                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.trailingAnchor.constraint(lessThanOrEqualTo: statusField.leadingAnchor, constant: -6),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),

                statusField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -6),
                statusField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                statusField.widthAnchor.constraint(greaterThanOrEqualToConstant: 10)
            ])
        }
        
        cell?.textField?.stringValue = node.name
        
        if node.isDirectory {
            cell?.imageView?.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
            cell?.imageView?.contentTintColor = .systemBlue
        } else {
            let iconName = FileIcon.iconName(for: node.name)
            let color = FileIcon.iconColor(for: node.name)
            cell?.imageView?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            cell?.imageView?.contentTintColor = NSColor(color)
        }

        if let statusField = cell?.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("GitStatusField") }) as? NSTextField {
            if let status = gitStatus(for: node) {
                statusField.stringValue = status.badgeText
                statusField.textColor = colorForGitStatus(status)
                statusField.isHidden = false
            } else {
                statusField.stringValue = ""
                statusField.isHidden = true
            }
        }
        
        return cell
    }

    private func colorForGitStatus(_ status: GitFileStatus) -> NSColor {
        switch status {
        case .modified:
            return .systemYellow
        case .added:
            return .systemGreen
        case .deleted:
            return .systemRed
        case .renamed, .copied:
            return .systemBlue
        case .untracked:
            return .systemGray
        case .conflicted:
            return .systemOrange
        }
    }

    private func gitStatus(for node: FileNode) -> GitFileStatus? {
        let nodeURL = node.url.standardizedFileURL
        if node.isDirectory {
            return directoryStatusesByURL[nodeURL]
        }
        return gitStatusesByURL[nodeURL]
    }

    private func buildDirectoryStatuses(from fileStatuses: [URL: GitFileStatus]) -> [URL: GitFileStatus] {
        var statuses: [URL: GitFileStatus] = [:]
        for (fileURL, status) in fileStatuses {
            var directoryURL = fileURL.deletingLastPathComponent().standardizedFileURL
            while directoryURL.path != "/" {
                merge(status, into: &statuses, for: directoryURL)
                let parentURL = directoryURL.deletingLastPathComponent().standardizedFileURL
                if parentURL == directoryURL {
                    break
                }
                directoryURL = parentURL
            }
        }
        return statuses
    }

    private func merge(_ newStatus: GitFileStatus, into statuses: inout [URL: GitFileStatus], for directoryURL: URL) {
        guard let current = statuses[directoryURL] else {
            statuses[directoryURL] = newStatus
            return
        }
        if newStatus.priority > current.priority {
            statuses[directoryURL] = newStatus
        }
    }
}
