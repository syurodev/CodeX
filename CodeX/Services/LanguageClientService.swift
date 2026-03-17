import Foundation
import SwiftUI

// Actor quản lý pending requests - thread-safe không gây deadlock với Swift concurrency
private actor RequestStore {
    var pending: [Int: CheckedContinuation<Any?, Never>] = [:]
    var nextId: Int = 1
    
    func allocateId() -> Int {
        let id = nextId
        nextId += 1
        return id
    }
    
    func register(id: Int, continuation: CheckedContinuation<Any?, Never>) {
        pending[id] = continuation
    }
    
    func resolve(id: Int, result: Any?) {
        guard let continuation = pending.removeValue(forKey: id) else {
            print("⚠️ No pending request for id=\(id). Known IDs: \(Array(pending.keys))")
            return
        }
        continuation.resume(returning: result)
    }
    
    func pendingCount() -> Int { pending.count }
}

// Actor bảo vệ buffer LSP khỏi data race do readabilityHandler tạo nhiều concurrent Task
private actor LSPBuffer {
    private var buffer = Data()

    func append(_ data: Data) {
        buffer.append(data)
    }

    /// Xử lý buffer và trả về các body message hoàn chỉnh
    func drainMessages() -> [Data] {
        var results: [Data] = []
        let headerTag = Data("Content-Length:".utf8)

        while !buffer.isEmpty {
            // Bỏ garbage trước "Content-Length:"
            if let tagRange = buffer.range(of: headerTag) {
                if tagRange.lowerBound > 0 {
                    buffer.removeSubrange(0..<tagRange.lowerBound)
                }
            } else {
                if buffer.count > 8192 { buffer.removeAll() }
                break
            }

            guard let separatorRange = buffer.range(of: Data("\r\n\r\n".utf8)) else { break }

            let headerPart = buffer.subdata(in: 0..<separatorRange.lowerBound)
            guard let headerString = String(data: headerPart, encoding: .utf8) else {
                buffer.removeSubrange(0..<separatorRange.upperBound)
                continue
            }

            var contentLength: Int?
            for line in headerString.components(separatedBy: "\r\n") {
                let low = line.lowercased().trimmingCharacters(in: .whitespaces)
                if low.hasPrefix("content-length:") {
                    contentLength = Int(low.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces))
                }
            }

            guard let length = contentLength, length > 0 else {
                buffer.removeSubrange(0..<separatorRange.upperBound)
                continue
            }

            let bodyStart = separatorRange.upperBound
            let bodyEnd = bodyStart + length
            guard buffer.count >= bodyEnd else { break }

            results.append(buffer.subdata(in: bodyStart..<bodyEnd))
            buffer.removeSubrange(0..<bodyEnd)
        }
        return results
    }
}

/// LanguageClientService xử lý việc gửi và nhận các thông điệp JSON-RPC chuẩn LSP.
class LanguageClientService {
    private let process: Process
    private let inputPipe: Pipe
    private let outputPipe: Pipe

    private let store = RequestStore()
    private let lspBuffer = LSPBuffer()

    var isInitialized = false

    init(process: Process) {
        self.process = process
        self.inputPipe = process.standardInput as! Pipe
        self.outputPipe = process.standardOutput as! Pipe
        setupOutputListener()
    }
    
    // MARK: - Initialization
    
    func initialize(params: [String: Any]) async -> Any? {
        guard !isInitialized else { return nil }
        let response = await sendRequest(method: "initialize", params: params)
        sendNotification(method: "initialized", params: [:])
        isInitialized = true
        return response
    }
    
    // MARK: - Request / Notification
    
    func sendRequest(method: String, params: [String: Any]) async -> Any? {
        let requestId = await store.allocateId()
        
        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": requestId,
            "method": method,
            "params": params
        ]
        
        return await withCheckedContinuation { continuation in
            Task {
                await store.register(id: requestId, continuation: continuation)
                self.send(data: request)
            }
        }
    }
    
    func sendNotification(method: String, params: [String: Any]) {
        let notification: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method,
            "params": params
        ]
        send(data: notification)
    }

    // MARK: - Document Symbols
    
    func fetchDocumentSymbols(fileURL: URL) async -> [DocumentSymbol]? {
        let params: [String: Any] = [
            "textDocument": [
                "uri": fileURL.absoluteString
            ]
        ]
        
        let response = await sendRequest(method: "textDocument/documentSymbol", params: params)
        
        guard let arrayMap = response as? [[String: Any]] else {
            return nil
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: arrayMap)
            let decoder = JSONDecoder()
            let symbols = try decoder.decode([DocumentSymbol].self, from: jsonData)
            return symbols
        } catch {
            print("❌ Failed to decode DocumentSymbol: \(error)")
            return nil
        }
    }
    
    // MARK: - Low-level send
    
    private func send(data: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data) else {
            print("❌ Failed to serialize request")
            return
        }
        let header = "Content-Length: \(jsonData.count)\r\n\r\n"
        guard let headerData = header.data(using: .utf8) else { return }
        var fullData = Data()
        fullData.append(headerData)
        fullData.append(jsonData)
        try? inputPipe.fileHandleForWriting.write(contentsOf: fullData)
    }
    
    // MARK: - Reading

    private func setupOutputListener() {
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task {
                await self.lspBuffer.append(data)
                let messages = await self.lspBuffer.drainMessages()
                for body in messages {
                    await self.handleMessage(body)
                }
            }
        }
    }

    private func handleMessage(_ data: Data) async {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ Cannot parse LSP message as JSON object")
            if let str = String(data: data, encoding: .utf8) {
                print("   Raw: \(str.prefix(200))")
            }
            return
        }
        
        // LSP spec: nếu có "id" → đây là response (hoặc server-initiated request)
        // id có thể là Int hoặc Double tùy JSONSerialization
        let idValue: Int?
        if let id = json["id"] as? Int { idValue = id }
        else if let id = json["id"] as? Double { idValue = Int(id) }
        else { idValue = nil }
        
        if let id = idValue {
            if let method = json["method"] as? String {
                // Server-initiated request (ví dụ: workspace/configuration)
                let params = json["params"] as? [String: Any] ?? [:]
                sendServerRequestReply(id: id, method: method, params: params)
            } else {
                // Đây là response cho request của client
                await store.resolve(id: id, result: json["result"])
            }
        } else if let _ = json["method"] as? String {
            // Notification (không có id)
            // print("📩 LSP notification: \(method)")
        }
    }
    
    /// Trả lời các request mà server gửi tới client (ví dụ workspace/configuration)
    private func sendServerRequestReply(id: Int, method: String, params: [String: Any]) {
        var result: Any = NSNull()
        
        if method == "workspace/configuration" {
            // typescript-language-server sends workspace/configuration requests.
            // Return null for each item — the server will use its defaults.
            let items = (params["items"] as? [[String: Any]]) ?? []
            result = items.map { _ in NSNull() }
        }
        
        let reply: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "result": result
        ]
        send(data: reply)
    }
}
