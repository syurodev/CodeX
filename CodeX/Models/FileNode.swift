import Foundation

final class FileNode: NSObject, Identifiable {
    let id: UUID
    let name: String
    let url: URL
    let isDirectory: Bool
    var children: [FileNode]?

    init(id: UUID = UUID(), name: String, url: URL, isDirectory: Bool, children: [FileNode]? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
    }

    override var hash: Int {
        return id.hashValue
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? FileNode else { return false }
        return id == other.id
    }
}

extension FileNode: Comparable {
    static func < (lhs: FileNode, rhs: FileNode) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
