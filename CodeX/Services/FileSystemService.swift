import Foundation
import AppKit
// import CodeEditLanguages

struct FileSystemService {
    private let fileManager = FileManager.default

    /// Files/directories that are always hidden regardless of the dotfile setting.
    private static let alwaysHidden: Set<String> = [".DS_Store", ".git", ".svn", ".hg"]

    func buildFileTree(at url: URL) -> [FileNode] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [] // Show dotfiles — they are often project config files
        ) else {
            return []
        }

        return contents.compactMap { childURL -> FileNode? in
            let name = childURL.lastPathComponent
            guard !Self.alwaysHidden.contains(name) else { return nil }
            let isDir = (try? childURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            return FileNode(
                id: UUID(),
                name: name,
                url: childURL,
                isDirectory: isDir,
                children: nil
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

    // MARK: - File / Folder creation

    /// Tạo file rỗng tại `directory` với tên `name`.
    /// Nếu đã tồn tại file cùng tên thì thêm suffix số: `name 2.ext`, `name 3.ext`…
    /// - Returns: URL của file vừa được tạo.
    @discardableResult
    func createFile(named name: String, in directory: URL) throws -> URL {
        let url = uniqueURL(for: name, in: directory)
        guard fileManager.createFile(atPath: url.path, contents: nil) else {
            throw FileSystemError.creationFailed(url)
        }
        return url
    }

    /// Tạo thư mục tại `directory` với tên `name`.
    /// Nếu đã tồn tại thư mục cùng tên thì thêm suffix số.
    /// - Returns: URL của thư mục vừa được tạo.
    @discardableResult
    func createFolder(named name: String, in directory: URL) throws -> URL {
        let url = uniqueURL(for: name, in: directory)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Rename

    /// Đổi tên item (file hoặc folder) tại `url` thành `newName`.
    /// - Returns: URL mới sau khi đổi tên.
    @discardableResult
    func renameItem(at url: URL, to newName: String) throws -> URL {
        let destination = url.deletingLastPathComponent().appendingPathComponent(newName)
        try fileManager.moveItem(at: url, to: destination)
        return destination
    }

    // MARK: - Trash

    /// Di chuyển item vào Trash (có thể undo qua Finder).
    func trashItem(at url: URL) throws {
        try fileManager.trashItem(at: url, resultingItemURL: nil)
    }

    // MARK: - Duplicate

    /// Tạo bản sao của `url` trong cùng thư mục.
    /// Tên bản sao: `{stem} copy.{ext}` (hoặc thêm số nếu đã tồn tại).
    /// - Returns: URL của bản sao vừa tạo.
    @discardableResult
    func duplicateFile(at url: URL) throws -> URL {
        let directory = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        let baseName = ext.isEmpty ? "\(stem) copy" : "\(stem) copy.\(ext)"
        let destination = uniqueURL(for: baseName, in: directory)
        try fileManager.copyItem(at: url, to: destination)
        return destination
    }

    // MARK: - Reveal in Finder

    func revealInFinder(_ url: URL) {
        if url.hasDirectoryPath {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        }
    }

    // MARK: - Helpers

    /// Sinh URL không bị trùng trong `directory`.
    /// Nếu `name` đã tồn tại thì thử `{stem} 2.{ext}`, `{stem} 3.{ext}`…
    private func uniqueURL(for name: String, in directory: URL) -> URL {
        let base = directory.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: base.path) else { return base }

        let url = URL(fileURLWithPath: name)
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        var counter = 2
        while true {
            let candidate = ext.isEmpty
                ? "\(stem) \(counter)"
                : "\(stem) \(counter).\(ext)"
            let candidateURL = directory.appendingPathComponent(candidate)
            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            counter += 1
        }
    }

    // MARK: - Language detection

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

// MARK: - Errors

enum FileSystemError: LocalizedError {
    case creationFailed(URL)

    var errorDescription: String? {
        switch self {
        case .creationFailed(let url):
            return "Không thể tạo file tại: \(url.path)"
        }
    }
}
