import Foundation
import Combine

@MainActor
final class LlamaDCQLService: ObservableObject {
    static let shared = LlamaDCQLService()

    @Published private(set) var loadingState: ModelLoadingState = .initializing
    @Published private(set) var isLoading = false
    @Published private(set) var isModelLoaded = false

    private var llamaGenerator: LlamaDCQLGenerator?
    private let retriever: VCRetriever

    private var modelPath: String?

    init(modelPath: String? = nil, retriever: VCRetriever? = nil) {
        self.retriever = retriever ?? VCRetriever(vcPoolPath: "vc_pool")
        self.retriever.prepareVCPool()

        // Determine model path
        if let path = modelPath {
            self.modelPath = path
        } else {
            // Priority 1: Try bundle (for development)
            if let bundlePath = Bundle.main.resourcePath {
                let modelURL = URL(fileURLWithPath: bundlePath).appendingPathComponent("Model/gemma-2-2b-it-dcql-q4.gguf")
                if FileManager.default.fileExists(atPath: modelURL.path) {
                    self.modelPath = modelURL.path
                } else {
                    // Priority 2: Try Documents directory
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let docsModelURL = documentsPath.appendingPathComponent("gemma-2-2b-it-dcql-q4.gguf")

                    if FileManager.default.fileExists(atPath: docsModelURL.path) {
                        self.modelPath = docsModelURL.path
                    }
                }
            }
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
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Debug: Print search paths
            if let bundlePath = Bundle.main.resourcePath {
                let bundleModelPath = URL(fileURLWithPath: bundlePath).appendingPathComponent("Model/gemma-2-2b-it-dcql-q4.gguf").path
                print("📂 Bundle path checked: \(bundleModelPath)")
                print("📂 File exists: \(FileManager.default.fileExists(atPath: bundleModelPath))")
            }

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let docsModelPath = documentsPath.appendingPathComponent("gemma-2-2b-it-dcql-q4.gguf").path
            print("📂 Documents path checked: \(docsModelPath)")
            print("📂 File exists: \(FileManager.default.fileExists(atPath: docsModelPath))")

            guard let modelPath = modelPath else {
                let errorMsg = """
                Model file not found!

                Please copy gemma-2-2b-it-dcql-q4.gguf to:
                \(docsModelPath)

                You can use Xcode > Window > Devices and Simulators to copy the file.
                """
                throw DCQLError.generationFailed(errorMsg)
            }

            print("🔄 Loading llama.cpp model: \(modelPath)")
            loadingState = .loading

            let loadStart = CFAbsoluteTimeGetCurrent()
            print("⏱️ Starting llama.cpp model load...")
            print("📍 Model path: \(modelPath)")
            print("📊 File size: \(try FileManager.default.attributesOfItem(atPath: modelPath)[.size] ?? 0) bytes")

            do {
                llamaGenerator = try await LlamaDCQLGenerator(modelPath: modelPath)

                let loadTime = CFAbsoluteTimeGetCurrent() - loadStart
                print("⏱️ llama.cpp model loaded in \(String(format: "%.2f", loadTime))s")
            } catch {
                print("❌ Failed to create LlamaDCQLGenerator: \(error)")
                throw error
            }

            loadingState = .ready
            isModelLoaded = true

            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
            print("✅ Model ready (total: \(String(format: "%.2f", totalTime))s)")
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

    func generateDCQL(from query: String, onProgress: ((String) -> Void)? = nil) async throws -> DCQLResponse {
        guard isModelLoaded, let generator = llamaGenerator else {
            throw DCQLError.modelNotLoaded
        }

        // Measure retrieval time
        let retrievalStart = CFAbsoluteTimeGetCurrent()
        let retrievalResults = retriever.retrieve(query: query, topK: 3)
        let retrievalTime = CFAbsoluteTimeGetCurrent() - retrievalStart

        // Use retrieval results
        let relevantVCs = retrievalResults.map { $0.vc }
        print("🔍 Using retrieval results")

        guard !relevantVCs.isEmpty else {
            throw DCQLError.noRelevantVCsFound
        }

        let formattedVCs = retriever.formatVCsForPrompt(relevantVCs)

        // Build prompt using the same format as DCQLGenerator
        let prompt = buildPrompt(formattedVCs: formattedVCs, query: query)

        // Measure DCQL generation time
        let generationStart = CFAbsoluteTimeGetCurrent()

        do {
            let rawResponse: String
            if let onProgress = onProgress {
                // Use streaming version
                rawResponse = try await generator.generateDCQLStream(prompt: prompt, maxTokens: 512) { currentText in
                    onProgress(currentText)
                }
            } else {
                // Use non-streaming version
                rawResponse = try await generator.generateDCQL(prompt: prompt, maxTokens: 512)
            }
            let generationTime = CFAbsoluteTimeGetCurrent() - generationStart

            // Log timing information
            print("⏱️ Retrieval time: \(String(format: "%.3f", retrievalTime))s")
            print("⏱️ Generation time: \(String(format: "%.3f", generationTime))s")
            print("⏱️ Total time: \(String(format: "%.3f", retrievalTime + generationTime))s")

            // Parse and validate DCQL
            let json = try parseDCQLJSON(from: rawResponse)
            try validateDCQL(json, raw: rawResponse)

            let pretty = (try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted))
                .flatMap { String(data: $0, encoding: .utf8) } ?? rawResponse

            return DCQLResponse(
                dcql: json,
                dcqlString: pretty,
                selectedVCs: relevantVCs,
                query: query,
                retrievalTime: retrievalTime,
                generationTime: generationTime,
                vpGenerationTime: 0,
                vp: nil,
                vpError: nil
            )
        } catch let validationError as DCQLValidationError {
            let generationTime = CFAbsoluteTimeGetCurrent() - generationStart

            print("❌ DCQL validation failed: \(validationError.localizedDescription)")
            print("🔍 Raw response: \(validationError.rawResponse)")
            print("⏱️ Retrieval time: \(String(format: "%.3f", retrievalTime))s")
            print("⏱️ Generation time: \(String(format: "%.3f", generationTime))s")
            print("⏱️ Total time: \(String(format: "%.3f", retrievalTime + generationTime))s")

            // Use fallback template
            let fallback = generateTemplateDCQL(for: relevantVCs, query: query)
            let pretty = (try? JSONSerialization.data(withJSONObject: fallback, options: .prettyPrinted))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            return DCQLResponse(
                dcql: fallback,
                dcqlString: pretty,
                selectedVCs: relevantVCs,
                query: query,
                retrievalTime: retrievalTime,
                generationTime: generationTime,
                vpGenerationTime: 0,
                vp: nil,
                vpError: nil
            )
        } catch {
            throw DCQLError.generationFailed(error.localizedDescription)
        }
    }

    func resetModel() {
        llamaGenerator = nil
        isModelLoaded = false
        loadModel()
    }

    // MARK: - DCQL Validation (from DCQLGenerator)

    private func buildPrompt(formattedVCs: String, query: String) -> String {
        return """
Given the following Verifiable Credentials and a natural language query, generate a DCQL query to retrieve the requested information.

Available Verifiable Credentials:
\(formattedVCs)

Natural Language Query: \(query)

Generate a DCQL query that selects the appropriate credentials and fields:
"""
    }

    private func parseDCQLJSON(from text: String) throws -> [String: Any] {
        if let data = text.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return obj
        }

        var cleaned = text
        if cleaned.contains("```") {
            cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
            cleaned = cleaned.replacingOccurrences(of: "```JSON", with: "")
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        }
        if let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}") {
            let jsonSlice = cleaned[start...end]
            if let data = String(jsonSlice).data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return obj
            }
        }

        throw DCQLValidationError.invalidJSON(raw: text)
    }

    private func validateDCQL(_ json: [String: Any], raw: String) throws {
        guard let credentials = json["credentials"] as? [[String: Any]], !credentials.isEmpty else {
            throw DCQLValidationError.missingCredentials(raw: raw)
        }

        for (index, credential) in credentials.enumerated() {
            guard let id = credential["id"] as? String, !id.isEmpty else {
                throw DCQLValidationError.invalidCredentialField(index: index, field: "id", raw: raw)
            }
            guard let format = credential["format"] as? String, !format.isEmpty else {
                throw DCQLValidationError.invalidCredentialField(index: index, field: "format", raw: raw)
            }
            guard let claims = credential["claims"] as? [[String: Any]], !claims.isEmpty else {
                throw DCQLValidationError.invalidClaims(index: index, raw: raw)
            }

            for (claimIndex, claim) in claims.enumerated() {
                guard let path = claim["path"] as? [String], !path.isEmpty,
                      path.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                    throw DCQLValidationError.invalidClaimPath(credentialIndex: index, claimIndex: claimIndex, raw: raw)
                }
            }
        }
    }

    private func generateTemplateDCQL(for vcs: [VerifiableCredential], query: String) -> [String: Any] {
        guard let firstVC = vcs.first else { return [:] }
        let credentialType = firstVC.type.last ?? "UnknownCredential"
        let credentialId = credentialType
            .lowercased()
            .replacingOccurrences(of: "credential", with: "")
            .replacingOccurrences(of: "certificate", with: "") + "_credential"

        var claims: [[String: Any]] = []
        let queryLower = query.lowercased()
        for key in firstVC.credentialSubject.keys {
            if queryLower.contains(key.lowercased()) ||
                key == "fullName" || key == "name" ||
                (queryLower.contains("expir") && (key.contains("expir") || key.contains("valid"))) {
                claims.append(["path": ["credentialSubject", key]])
            }
        }
        if claims.isEmpty {
            for key in firstVC.credentialSubject.keys.prefix(3) {
                claims.append(["path": ["credentialSubject", key]])
            }
        }
        return [
            "credentials": [
                [
                    "id": credentialId,
                    "format": "ldp_vc",
                    "meta": [
                        "type_values": [firstVC.type]
                    ],
                    "claims": claims
                ]
            ]
        ]
    }
}

// MARK: - Supporting Types (from MLXDCQLService and DCQLGenerator)

enum DCQLValidationError: LocalizedError {
    case invalidJSON(raw: String)
    case missingCredentials(raw: String)
    case invalidCredentialField(index: Int, field: String, raw: String)
    case invalidClaims(index: Int, raw: String)
    case invalidClaimPath(credentialIndex: Int, claimIndex: Int, raw: String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Model response is not valid JSON."
        case .missingCredentials:
            return "DCQL output does not contain a credentials array."
        case let .invalidCredentialField(index, field, _):
            return "DCQL credentials[\(index)] is missing required field \(field)."
        case let .invalidClaims(index, _):
            return "DCQL credentials[\(index)] claims is empty or not an array."
        case let .invalidClaimPath(credentialIndex, claimIndex, _):
            return "DCQL credentials[\(credentialIndex)] claims[\(claimIndex)] has an invalid path."
        }
    }

    var rawResponse: String {
        switch self {
        case let .invalidJSON(raw),
             let .missingCredentials(raw),
             let .invalidCredentialField(_, _, raw),
             let .invalidClaims(_, raw),
             let .invalidClaimPath(_, _, raw):
            return raw
        }
    }
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
    let vpGenerationTime: TimeInterval

    // VP generation results
    let vp: String?  // Generated VP JSON
    let vpError: String?  // Error message if VP generation failed

    var totalTime: TimeInterval {
        retrievalTime + generationTime + vpGenerationTime
    }

    var hasVP: Bool {
        vp != nil
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
