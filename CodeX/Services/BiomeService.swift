import Foundation

/// BiomeService xử lý việc chạy Biome để lint và format code JS/TS.
class BiomeService {
    static let shared = BiomeService()
    
    private init() {}
    
    /// Chạy linter cho một file cụ thể.
    func lint(fileURL: URL) async -> String? {
        let process = Process()
        
        // Tìm binary biome trong App Bundle (Bundling strategy)
        if let bundlePath = Bundle.main.path(forResource: "biome", ofType: nil) {
            process.executableURL = URL(fileURLWithPath: bundlePath)
        } else {
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/biome")
        }
        
        process.arguments = ["lint", fileURL.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            print("❌ Biome lint failed: \(error)")
            return nil
        }
    }
    
    /// Chạy formatter và trả về kết quả code đã được format.
    func format(text: String, fileName: String) async -> String? {
        let process = Process()
        
        if let bundlePath = Bundle.main.path(forResource: "biome", ofType: nil) {
            process.executableURL = URL(fileURLWithPath: bundlePath)
        } else {
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/biome")
        }
        
        process.arguments = ["format", "--stdin-file-path", fileName]
        
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        
        do {
            try process.run()
            try inputPipe.fileHandleForWriting.write(contentsOf: text.data(using: .utf8)!)
            inputPipe.fileHandleForWriting.closeFile()
            
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            print("❌ Biome format failed: \(error)")
            return nil
        }
    }
}
