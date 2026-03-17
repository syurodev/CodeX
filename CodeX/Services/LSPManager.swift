import Foundation
import Observation

@Observable
class LSPManager {
    static let shared = LSPManager()
    
    // Lưu trữ cả process và service để quản lý vòng đời
    private var processes: [String: Process] = [:]
    private var services: [String: LanguageClientService] = [:]
    
    // Lưu lịch sử log 50 dòng cuối của mỗi server
    var serverLogs: [String: [String]] = [:]
    
    private init() {}
    
    /// Khởi chạy hoặc lấy vtsls (hoặc typescript-language-server) cho dự án.
    /// Chạy qua login shell để tự resolve PATH từ .zshrc/.zprofile của user
    /// (hỗ trợ NVM, Homebrew, volta, etc.).
    func startTypeScriptLSP(projectRoot: URL) -> LanguageClientService? {
        let key = "tsls-\(projectRoot.path)"

        if let existingService = services[key] {
            return existingService
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")

        // Augment PATH với các location phổ biến: Zed vtsls, Homebrew, npm global, NVM.
        // Dùng login shell (-l) để user's .zprofile/.zshrc cũng được load.
        let home = NSHomeDirectory()
        let extraPaths = [
            "\(home)/Library/Application Support/Zed/languages/vtsls/node_modules/.bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.nvm/versions/node/current/bin",
            "\(home)/.volta/bin",
        ].joined(separator: ":")
        let currentPath = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "\(extraPaths):\(currentPath)"
        process.environment = env

        // Source NVM nếu có (.zshrc không được load trong non-interactive login shell).
        // Sau đó exec LSP server: thử vtsls trước, fallback typescript-language-server.
        process.arguments = ["-l", "-c", """
            [ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh" 2>/dev/null
            [ -s "$HOME/.volta/load.sh" ] && source "$HOME/.volta/load.sh" 2>/dev/null
            if command -v vtsls >/dev/null 2>&1; then
                exec vtsls --stdio
            elif command -v typescript-language-server >/dev/null 2>&1; then
                exec typescript-language-server --stdio
            else
                echo "No TypeScript LSP found (vtsls or typescript-language-server)" >&2
                exit 1
            fi
            """]
        process.currentDirectoryURL = projectRoot
        
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe() // Tách riêng stderr
        
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Theo dõi stderr để log lỗi mà không làm bẩn stream chính
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let message = String(data: data, encoding: .utf8) {
                let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
                Task { @MainActor in
                    var logs = LSPManager.shared.serverLogs[key] ?? []
                    logs.append(text)
                    if logs.count > 50 { logs.removeFirst(logs.count - 50) }
                    LSPManager.shared.serverLogs[key] = logs
                }
            }
        }
        
        do {
            try process.run()
            processes[key] = process
            
            let service = LanguageClientService(process: process)
            services[key] = service
            
            return service
        } catch {
            return nil
        }
    }
    
    func stopAllServers() {
        for (key, process) in processes {
            process.terminate()
        }
        processes.removeAll()
        services.removeAll()
    }
}
