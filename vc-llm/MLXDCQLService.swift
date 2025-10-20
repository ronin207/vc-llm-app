import Foundation
import Combine
import MLXLMCommon
import MLXLLM

@MainActor
final class MLXDCQLService: ObservableObject {
    static let shared = MLXDCQLService()

    @Published private(set) var loadingState: ModelLoadingState = .initializing
    @Published private(set) var isLoading = false
    @Published private(set) var isModelLoaded = false

    private var modelContext: ModelContext?
    private var generator: DCQLGenerator?

    private let retriever: VCRetriever
    private let generationParameters = GenerateParameters(
        maxTokens: 512,
        temperature: 0.0,
        topP: 1.0,
        repetitionPenalty: 1.05,
        repetitionContextSize: 128
    )

    private var huggingFaceModelID = "ronin207/gemma-2-2b-it-dcql-mlx"

    init(huggingFaceModelID: String? = nil, retriever: VCRetriever? = nil) {
        self.retriever = retriever ?? VCRetriever(vcPoolPath: "vc_pool")
        self.retriever.prepareVCPool()

        if let hfID = huggingFaceModelID, !hfID.isEmpty {
            self.huggingFaceModelID = hfID
        } else if
            let url = Bundle.main.url(forResource: "model_metadata", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let meta = try? JSONDecoder().decode(ModelMetadata.self, from: data),
            let repo = meta.hf_repo, !repo.isEmpty {
            self.huggingFaceModelID = repo
        }

        loadModel()
    }

    func loadModel() {
        loadingState = .initializing
        isLoading = true
        isModelLoaded = false

        Task {
            await loadModelAsync()
        }
    }

    private func loadModelAsync() async {
        do {
            let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            let modelPath = cachesDir?
                .appendingPathComponent("models")
                .appendingPathComponent(huggingFaceModelID)
            let isModelCached = modelPath.map { FileManager.default.fileExists(atPath: $0.path) } ?? false

            print("🔄 Loading model: \(huggingFaceModelID)")

            loadingState = isModelCached ? .loading : .downloading

            let context = try await MLXLMCommon.loadModel(id: huggingFaceModelID)
            modelContext = context
            generator = DCQLGenerator(modelContext: context, parameters: generationParameters)

            loadingState = .ready
            isModelLoaded = true
            print("✅ Model ready")
        } catch {
            loadingState = .failed(error.localizedDescription)
            isModelLoaded = false
            print("❌ Error loading model: \(error)")
        }

        isLoading = false
    }

    func ensureModelLoaded(timeout: TimeInterval = 240) async throws {
        if !isModelLoaded && !isLoading {
            loadModel()
        }

        let deadline = Date().addingTimeInterval(timeout)
        while !isModelLoaded {
            if case .failed(let message) = loadingState {
                throw DCQLError.generationFailed(message)
            }
            if Date() > deadline {
                throw DCQLError.modelNotLoaded
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    func generateDCQL(from query: String) async throws -> DCQLResponse {
        guard isModelLoaded, let generator else {
            throw DCQLError.modelNotLoaded
        }

        // Measure retrieval time
        let retrievalStart = CFAbsoluteTimeGetCurrent()
        let retrievalResults = retriever.retrieve(query: query, topK: 3)
        let retrievalTime = CFAbsoluteTimeGetCurrent() - retrievalStart

        let relevantVCs = retrievalResults.map { $0.vc }

        guard !relevantVCs.isEmpty else {
            throw DCQLError.noRelevantVCsFound
        }

        let formattedVCs = retriever.formatVCsForPrompt(relevantVCs)

        // Measure DCQL generation time
        let generationStart = CFAbsoluteTimeGetCurrent()

        do {
            let generationResult = try generator.generateDCQL(query: query, formattedVCs: formattedVCs)
            let generationTime = CFAbsoluteTimeGetCurrent() - generationStart

            // Log timing information
            print("⏱️ Retrieval time: \(String(format: "%.3f", retrievalTime))s")
            print("⏱️ Generation time: \(String(format: "%.3f", generationTime))s")
            print("⏱️ Total time: \(String(format: "%.3f", retrievalTime + generationTime))s")

            return DCQLResponse(
                dcql: generationResult.dcql,
                dcqlString: generationResult.dcqlString,
                selectedVCs: relevantVCs,
                query: query,
                retrievalTime: retrievalTime,
                generationTime: generationTime
            )
        } catch let validationError as DCQLValidationError {
            let generationTime = CFAbsoluteTimeGetCurrent() - generationStart

            print("❌ DCQL validation failed: \(validationError.localizedDescription)")
            print("🔍 Raw response: \(validationError.rawResponse)")
            print("⏱️ Retrieval time: \(String(format: "%.3f", retrievalTime))s")
            print("⏱️ Generation time: \(String(format: "%.3f", generationTime))s")
            print("⏱️ Total time: \(String(format: "%.3f", retrievalTime + generationTime))s")

            let fallback = DCQLGenerator.generateTemplateDCQL(for: relevantVCs, query: query)
            let pretty = (try? JSONSerialization.data(withJSONObject: fallback, options: .prettyPrinted))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            return DCQLResponse(
                dcql: fallback,
                dcqlString: pretty,
                selectedVCs: relevantVCs,
                query: query,
                retrievalTime: retrievalTime,
                generationTime: generationTime
            )
        } catch {
            throw DCQLError.generationFailed(error.localizedDescription)
        }
    }

    func resetModel() {
        modelContext = nil
        generator = nil
        isModelLoaded = false
        loadModel()
    }
}

// MARK: - Supporting Types

struct ModelMetadata: Codable {
    let hf_repo: String?
}

enum ModelLoadingState {
    case initializing
    case downloading
    case loading
    case ready
    case failed(String)

    var isLoading: Bool {
        switch self {
        case .initializing, .downloading, .loading:
            return true
        case .ready, .failed:
            return false
        }
    }

    var isReady: Bool {
        if case .ready = self {
            return true
        }
        return false
    }
}

struct DCQLResponse {
    let dcql: [String: Any]
    let dcqlString: String
    let selectedVCs: [VerifiableCredential]
    let query: String
    let retrievalTime: TimeInterval
    let generationTime: TimeInterval

    var totalTime: TimeInterval {
        retrievalTime + generationTime
    }
}

enum DCQLError: LocalizedError {
    case noRelevantVCsFound
    case invalidDCQLResponse
    case modelNotLoaded
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .noRelevantVCsFound:
            return "No relevant verifiable credentials found for your query."
        case .invalidDCQLResponse:
            return "Model output is not valid DCQL."
        case .modelNotLoaded:
            return "Model is not ready yet."
        case .generationFailed(let message):
            return "Failed to generate response: \(message)"
        }
    }
}
