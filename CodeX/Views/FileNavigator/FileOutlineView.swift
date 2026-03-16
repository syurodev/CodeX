import SwiftUI
import AppKit

struct FileOutlineView: NSViewControllerRepresentable {
    let rootNodes: [FileNode]
    let gitStatusesByURL: [URL: GitFileStatus]
    @Binding var selectedNode: FileNode?
    var onFileDoubleClicked: (FileNode) -> Void
    var onNodeExpanded: (FileNode) -> Void

    // MARK: Context menu callbacks
    var onNewFile: (URL) -> Void
    var onNewFolder: (URL) -> Void
    var onRename: (FileNode) -> Void
    var onTrash: (FileNode) -> Void
    var onDuplicate: (FileNode) -> Void
    var onRevealInFinder: (FileNode) -> Void
    var onCopyPath: (FileNode) -> Void
    var onCopyRelativePath: (FileNode) -> Void
    
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

        // MARK: Context menu delegate

        func fileOutlineViewController(_ vc: FileOutlineViewController, didRequestNewFileIn directory: URL) {
            DispatchQueue.main.async { self.parent.onNewFile(directory) }
        }

        func fileOutlineViewController(_ vc: FileOutlineViewController, didRequestNewFolderIn directory: URL) {
            DispatchQueue.main.async { self.parent.onNewFolder(directory) }
        }

        func fileOutlineViewController(_ vc: FileOutlineViewController, didRequestRename node: FileNode) {
            DispatchQueue.main.async { self.parent.onRename(node) }
        }

        func fileOutlineViewController(_ vc: FileOutlineViewController, didRequestTrash node: FileNode) {
            DispatchQueue.main.async { self.parent.onTrash(node) }
        }

        func fileOutlineViewController(_ vc: FileOutlineViewController, didRequestDuplicate node: FileNode) {
            DispatchQueue.main.async { self.parent.onDuplicate(node) }
        }

        func fileOutlineViewController(_ vc: FileOutlineViewController, didRequestRevealInFinder node: FileNode) {
            DispatchQueue.main.async { self.parent.onRevealInFinder(node) }
        }

        func fileOutlineViewController(_ vc: FileOutlineViewController, didRequestCopyPath node: FileNode) {
            DispatchQueue.main.async { self.parent.onCopyPath(node) }
        }

        func fileOutlineViewController(_ vc: FileOutlineViewController, didRequestCopyRelativePath node: FileNode) {
            DispatchQueue.main.async { self.parent.onCopyRelativePath(node) }
        }
    }
}

protocol FileOutlineViewControllerDelegate: AnyObject {
    // MARK: Navigation
    func fileOutlineViewController(_ vc: FileOutlineViewController, didSelect node: FileNode?)
    func fileOutlineViewController(_ vc: FileOutlineViewController, didDoubleClick node: FileNode)
    func fileOutlineViewController(_ vc: FileOutlineViewController, didExpand node: FileNode)

    // MARK: Context menu
    func fileOutlineViewController(_ vc: FileOutlineViewController, didRequestNewFileIn directory: URL)
    func fileOutlineViewController(_ vc: FileOutlineViewController, didRequestNewFolderIn directory: URL)
    func fileOutlineViewController(_ vc: FileOutlineViewController, didRequestRename node: FileNode)
    func fileOutlineViewController(_ vc: FileOutlineViewController, didRequestTrash node: FileNode)
    func fileOutlineViewController(_ vc: FileOutlineViewController, didRequestDuplicate node: FileNode)
    func fileOutlineViewController(_ vc: FileOutlineViewController, didRequestRevealInFinder node: FileNode)
    func fileOutlineViewController(_ vc: FileOutlineViewController, didRequestCopyPath node: FileNode)
    func fileOutlineViewController(_ vc: FileOutlineViewController, didRequestCopyRelativePath node: FileNode)
}

class FileOutlineViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
    weak var delegate: FileOutlineViewControllerDelegate?

    private var outlineView: NSOutlineView!
    private var scrollView: NSScrollView!
    private var rootNodes: [FileNode] = []
    private var gitStatusesByURL: [URL: GitFileStatus] = [:]
    private var directoryStatusesByURL: [URL: GitFileStatus] = [:]

    /// Node được right-click gần nhất — lưu trong `menuNeedsUpdate` để các @objc action dùng lại.
    private var clickedNodeForMenu: FileNode?
    
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

        setupContextMenu()
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

// MARK: - Context Menu

extension FileOutlineViewController: NSMenuDelegate {

    func setupContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        outlineView.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let row = outlineView.clickedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? FileNode else { return }
        clickedNodeForMenu = node

        // --- New File / New Folder ---
        menu.addItem(makeMenuItem("New File", action: #selector(menuNewFile), image: "doc.badge.plus"))
        menu.addItem(makeMenuItem("New Folder", action: #selector(menuNewFolder), image: "folder.badge.plus"))
        menu.addItem(.separator())

        // --- Rename ---
        menu.addItem(makeMenuItem("Rename", action: #selector(menuRename), image: "pencil"))

        // --- Duplicate (chỉ cho file) ---
        if !node.isDirectory {
            menu.addItem(makeMenuItem("Duplicate", action: #selector(menuDuplicate), image: "doc.on.doc"))
        }

        // --- Move to Trash ---
        menu.addItem(makeMenuItem("Move to Trash", action: #selector(menuTrash), image: "trash"))
        menu.addItem(.separator())

        // --- Reveal / Copy ---
        menu.addItem(makeMenuItem("Reveal in Finder", action: #selector(menuRevealInFinder), image: "folder"))
        menu.addItem(makeMenuItem("Copy Path", action: #selector(menuCopyPath), image: "doc.on.clipboard"))
        menu.addItem(makeMenuItem("Copy Relative Path", action: #selector(menuCopyRelativePath), image: "link"))
    }

    private func makeMenuItem(_ title: String, action: Selector, image: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: image, accessibilityDescription: nil)
        return item
    }

    // MARK: @objc Actions

    @objc private func menuNewFile() {
        guard let node = clickedNodeForMenu else { return }
        let dir = node.isDirectory ? node.url : node.url.deletingLastPathComponent()
        delegate?.fileOutlineViewController(self, didRequestNewFileIn: dir)
    }

    @objc private func menuNewFolder() {
        guard let node = clickedNodeForMenu else { return }
        let dir = node.isDirectory ? node.url : node.url.deletingLastPathComponent()
        delegate?.fileOutlineViewController(self, didRequestNewFolderIn: dir)
    }

    @objc private func menuRename() {
        guard let node = clickedNodeForMenu else { return }
        delegate?.fileOutlineViewController(self, didRequestRename: node)
    }

    @objc private func menuDuplicate() {
        guard let node = clickedNodeForMenu else { return }
        delegate?.fileOutlineViewController(self, didRequestDuplicate: node)
    }

    @objc private func menuTrash() {
        guard let node = clickedNodeForMenu else { return }
        delegate?.fileOutlineViewController(self, didRequestTrash: node)
    }

    @objc private func menuRevealInFinder() {
        guard let node = clickedNodeForMenu else { return }
        delegate?.fileOutlineViewController(self, didRequestRevealInFinder: node)
    }

    @objc private func menuCopyPath() {
        guard let node = clickedNodeForMenu else { return }
        delegate?.fileOutlineViewController(self, didRequestCopyPath: node)
    }

    @objc private func menuCopyRelativePath() {
        guard let node = clickedNodeForMenu else { return }
        delegate?.fileOutlineViewController(self, didRequestCopyRelativePath: node)
    }
}
