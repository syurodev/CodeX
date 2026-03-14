import Foundation
import CodeEditLanguages

struct FileSystemService {
    private let fileManager = FileManager.default

    func buildFileTree(at url: URL) -> [FileNode] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { childURL in
            let isDir = (try? childURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            return FileNode(
                id: UUID(),
                name: childURL.lastPathComponent,
                url: childURL,
                isDirectory: isDir,
                children: nil // Do not recursively load children yet
            )
        }.sorted(by: <)
    }

    func loadChildren(for node: FileNode) {
        if node.isDirectory && node.children == nil {
            node.children = buildFileTree(at: node.url)
        }
    }

    func readFileContents(at url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    func writeFile(text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func detectLanguage(for url: URL) -> CodeLanguage {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "js", "jsx":
            return .javascript
        case "ts", "tsx":
            return .typescript
        default:
            return .javascript
        }
    }
}
