import Foundation
import Observation

@Observable
class LSPManager {
    static let shared = LSPManager()
    
    // Lưu trữ cả process và service để quản lý vòng đời
    private var processes: [String: Process] = [:]
    private var services: [String: LanguageClientService] = [:]
    
    private init() {}
    
    /// Khởi chạy hoặc lấy Deno LSP cho dự án.
    func startDenoLSP(projectRoot: URL) -> LanguageClientService? {
        let key = "deno-\(projectRoot.path)"
        
        if let existingService = services[key] {
            return existingService
        }
        
        let process = Process()
        
        // Tìm binary deno trong App Bundle
        if let bundlePath = Bundle.main.path(forResource: "deno", ofType: nil) {
            process.executableURL = URL(fileURLWithPath: bundlePath)
        } else {
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/deno")
        }
        
        process.arguments = ["lsp"]
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
                print("🚨 Deno LSP Error: \(message.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        
        do {
            try process.run()
            processes[key] = process
            
            let service = LanguageClientService(process: process)
            services[key] = service
            
            print("🚀 Deno LSP started for: \(projectRoot.lastPathComponent)")
            return service
        } catch {
            print("❌ Failed to start Deno LSP: \(error)")
            return nil
        }
    }
    
    func stopAllServers() {
        for (key, process) in processes {
            process.terminate()
            print("🛑 Stopped LSP: \(key)")
        }
        processes.removeAll()
        services.removeAll()
    }
}
