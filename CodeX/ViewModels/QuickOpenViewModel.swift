import Foundation
import AppKit

@Observable
@MainActor
final class QuickOpenViewModel {

    struct FileResult: Identifiable {
        let id = UUID()
        let url: URL
        let name: String
        let displayPath: String  // parent path only (for subtitle)
        let relativePath: String // full path from project root
    }

    var searchText: String = "" {
        didSet { updateResults() }
    }
    var results: [FileResult] = []
    var selectedIndex: Int = 0
    var isLoading: Bool = false

    private var allFiles: [FileResult] = []
    private var scanTask: Task<Void, Never>?

    // MARK: - Load

    func load(projectRoot: URL) {
        scanTask?.cancel()
        isLoading = true
        allFiles = []
        results = []

        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            let files = Self.scanFiles(at: projectRoot)
            await MainActor.run { [weak self] in
                guard let self, !Task.isCancelled else { return }
                self.allFiles = files
                self.isLoading = false
                self.updateResults()
            }
        }
    }

    // MARK: - Search

    func updateResults() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            results = Array(allFiles.prefix(50))
            selectedIndex = 0
            return
        }

        let lower = query.lowercased()

        let scored: [(FileResult, Int)] = allFiles.compactMap { file in
            let name = file.name.lowercased()
            let path = file.relativePath.lowercased()

            if name == lower                { return (file, 100) }
            if name.hasPrefix(lower)        { return (file, 80) }
            if name.contains(lower)         { return (file, 60) }
            if path.contains(lower)         { return (file, 40) }
            return nil
        }

        results = scored
            .sorted { $0.1 > $1.1 }
            .prefix(50)
            .map(\.0)

        selectedIndex = 0
    }

    // MARK: - Keyboard navigation

    func selectNext() {
        guard !results.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, results.count - 1)
    }

    func selectPrevious() {
        guard !results.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
    }

    var selectedResult: FileResult? {
        guard results.indices.contains(selectedIndex) else { return nil }
        return results[selectedIndex]
    }

    // MARK: - Reset

    func reset() {
        searchText = ""
        results = Array(allFiles.prefix(50))
        selectedIndex = 0
    }

    // MARK: - Private file scan

    private nonisolated static let ignoredNames: Set<String> = [
        ".DS_Store", ".git", ".svn", ".hg",
        "node_modules", ".build", ".swiftpm", ".derivedData",
        "DerivedData", ".Trash", "__pycache__", ".venv",
        "dist", "build", ".next", ".nuxt"
    ]

    private nonisolated static func scanFiles(at root: URL) -> [FileResult] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var files: [FileResult] = []
        let rootPath = root.path

        for case let fileURL as URL in enumerator {
            if Task.isCancelled { break }

            let name = fileURL.lastPathComponent
            guard !ignoredNames.contains(name) else {
                enumerator.skipDescendants()
                continue
            }

            let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard !isDir else { continue }

            var relativePath = fileURL.path
            if relativePath.hasPrefix(rootPath) {
                relativePath = String(relativePath.dropFirst(rootPath.count))
                if relativePath.hasPrefix("/") { relativePath = String(relativePath.dropFirst()) }
            }

            let displayPath = (relativePath as NSString).deletingLastPathComponent

            files.append(FileResult(
                url: fileURL,
                name: name,
                displayPath: displayPath,
                relativePath: relativePath
            ))
        }

        return files
    }
}
