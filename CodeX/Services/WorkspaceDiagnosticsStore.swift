import Foundation
import Observation

/// Single source of truth cho diagnostics của toàn bộ workspace.
/// - Background index chạy khi mở project (Biome check toàn folder).
/// - Per-file update ghi đè khi user edit file đó (luôn ưu tiên hơn index).
@MainActor
@Observable
class WorkspaceDiagnosticsStore {

    // MARK: - State

    private(set) var diagnostics: [URL: [Diagnostic]] = [:]
    private(set) var isIndexing = false

    // MARK: - Computed totals

    var totalErrors: Int {
        diagnostics.values.reduce(0) { $0 + $1.filter { $0.severity == .error }.count }
    }

    var totalWarnings: Int {
        diagnostics.values.reduce(0) { $0 + $1.filter { $0.severity == .warning }.count }
    }

    // MARK: - Per-file update (từ scheduleBiomeCheck)

    /// Ghi đè diagnostics cho một file cụ thể. Được gọi sau khi per-file Biome check hoàn thành.
    func update(url: URL, diagnostics: [Diagnostic]) {
        self.diagnostics[url] = diagnostics
        manuallyUpdatedURLs.insert(url)
    }

    // MARK: - Workspace index

    private var indexTask: Task<Void, Never>?
    /// URLs đã được update bởi per-file check trong lúc index đang chạy.
    /// Khi index hoàn thành, những file này không bị ghi đè bởi kết quả cũ hơn.
    private var manuallyUpdatedURLs: Set<URL> = []

    func startIndex(root: URL, formatConfig: DefaultFormatConfig) {
        indexTask?.cancel()
        manuallyUpdatedURLs = []
        isIndexing = true

        indexTask = Task.detached(priority: .utility) { [weak self] in
            let result = await BiomeService.shared.checkWorkspace(root: root, formatConfig: formatConfig)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                for (url, diags) in result {
                    // Không ghi đè file đã được per-file check update trong lúc index chạy
                    if !self.manuallyUpdatedURLs.contains(url) {
                        self.diagnostics[url] = diags
                    }
                }
                self.isIndexing = false
                print("📊 [WorkspaceIndex] Hoàn thành: \(result.count) files, \(self.totalErrors) errors, \(self.totalWarnings) warnings")
            }
        }
    }

    func clear() {
        indexTask?.cancel()
        diagnostics = [:]
        isIndexing = false
        manuallyUpdatedURLs = []
    }
}
