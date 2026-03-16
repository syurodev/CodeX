import Foundation
import MLXLLM
import MLXLMCommon

// MARK: - State

enum LocalLLMState: Equatable {
    case idle
    case downloading(progress: Double)
    case loading(progress: Double)
    case ready
    case generating
    case error(String)
}

// MARK: - Service

/// Service để load và chạy model LLM cục bộ (Qwen2.5-Coder) bằng MLX
@MainActor
@Observable
final class LocalLLMService {

    // MARK: - Shared

    static let shared = LocalLLMService()

    // MARK: - Observable State

    var state: LocalLLMState = .idle
    var downloadProgress: Double = 0
    var loadingProgress: Double = 0

    // MARK: - Constants

    private static let modelFolderName = "Qwen2.5-Coder-1.5B-Instruct-8bit"

    /// Các file cần thiết để model hoạt động
    private static let requiredFiles = [
        "model.safetensors",
        "config.json",
        "tokenizer.json",
        "tokenizer_config.json",
    ]

    /// Base URL trên HuggingFace để tải model
    private static let hfBaseURL = "https://huggingface.co/mlx-community/Qwen2.5-Coder-1.5B-Instruct-8bit/resolve/main"

    /// Mapping tên file local → tên file trên HuggingFace
    private static let hfFileNames: [String: String] = [
        "model.safetensors": "model.safetensors",
        "config.json": "config.json",
        "tokenizer.json": "tokenizer.json",
        "tokenizer_config.json": "tokenizer_config.json",
        "generation_config.json": "generation_config.json",
        "special_tokens_map.json": "special_tokens_map.json",
    ]

    // MARK: - Private

    private var modelContainer: ModelContainer?

    // MARK: - Model Directory

    /// Thư mục lưu model trong Application Support
    var modelDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("CodeX/Models/\(Self.modelFolderName)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Kiểm tra xem model đã có đủ file chưa
    var isModelAvailable: Bool {
        let fm = FileManager.default
        return Self.requiredFiles.allSatisfy { fileName in
            fm.fileExists(atPath: modelDirectoryURL.appendingPathComponent(fileName).path)
        }
    }

    // MARK: - Download

    /// Tải model từ HuggingFace về Application Support
    func downloadModel() async throws {
        let fm = FileManager.default
        let dir = modelDirectoryURL

        // Danh sách file cần tải (bao gồm optional files)
        let allFiles = Array(Self.hfFileNames.keys)
        var downloaded = 0

        state = .downloading(progress: 0)
        downloadProgress = 0

        for fileName in allFiles {
            let hfName = Self.hfFileNames[fileName] ?? fileName
            let destURL = dir.appendingPathComponent(fileName)

            // Bỏ qua nếu đã có
            if fm.fileExists(atPath: destURL.path) {
                downloaded += 1
                let progress = Double(downloaded) / Double(allFiles.count)
                downloadProgress = progress
                state = .downloading(progress: progress)
                continue
            }

            guard let srcURL = URL(string: "\(Self.hfBaseURL)/\(hfName)") else { continue }

            // Tải file
            let (tempURL, _) = try await URLSession.shared.download(from: srcURL)
            try? fm.moveItem(at: tempURL, to: destURL)

            downloaded += 1
            let progress = Double(downloaded) / Double(allFiles.count)
            downloadProgress = progress
            state = .downloading(progress: progress)
        }

        state = .idle
    }

    // MARK: - Load / Unload

    /// Load model vào bộ nhớ (chỉ cần gọi một lần)
    func loadModel() async {
        // Nếu đang loading hoặc đã ready thì bỏ qua
        switch state {
        case .loading, .ready, .generating: return
        default: break
        }

        guard isModelAvailable else {
            state = .error("Model chưa được tải về. Hãy vào Settings → AI Completion để tải.")
            return
        }

        state = .loading(progress: 0)
        loadingProgress = 0

        do {
            let directory = modelDirectoryURL
            let container = try await loadModelContainer(directory: directory) { [weak self] progress in
                Task { @MainActor [weak self] in
                    let fraction = progress.fractionCompleted
                    self?.loadingProgress = fraction
                    self?.state = .loading(progress: fraction)
                }
            }
            self.modelContainer = container
            self.state = .ready
        } catch {
            self.state = .error("Lỗi load model: \(error.localizedDescription)")
        }
    }

    /// Giải phóng model khỏi bộ nhớ
    func unloadModel() {
        modelContainer = nil
        state = .idle
        loadingProgress = 0
    }

    // MARK: - Generate

    /// Sinh văn bản với streaming — trả về AsyncStream<String>
    func generate(
        prompt: String,
        systemPrompt: String = "You are a helpful coding assistant.",
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                guard let container = self.modelContainer else {
                    continuation.yield("[Lỗi] Model chưa được load.")
                    continuation.finish()
                    return
                }

                await MainActor.run { self.state = .generating }

                do {
                    let chat: [Chat.Message] = [
                        .system(systemPrompt),
                        .user(prompt),
                    ]
                    let userInput = UserInput(chat: chat)
                    let parameters = GenerateParameters(temperature: temperature)
                    let lmInput = try await container.prepare(input: userInput)
                    let stream = try await container.generate(input: lmInput, parameters: parameters)

                    var tokenCount = 0
                    for await generation in stream {
                        switch generation {
                        case .chunk(let text):
                            continuation.yield(text)
                            tokenCount += 1
                            if tokenCount >= maxTokens { break }
                        default:
                            break
                        }
                    }
                } catch {
                    continuation.yield("[Lỗi sinh văn bản] \(error.localizedDescription)")
                }

                await MainActor.run { self.state = .ready }
                continuation.finish()
            }
        }
    }
}

