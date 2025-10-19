//
//  MLXManager_Finetuned.swift
//  vc-llm
//
//  Created by Assistant on 2025/07/28.
//

import Foundation
import Combine
import MLXLMCommon
import MLXLLM

// Model metadata structure for reading configuration
struct ModelMetadata: Codable {
    let hf_repo: String?
}

// Custom error type for MLX operations
enum MLXError: Error {
    case modelNotLoaded
    case invalidResponse
    case generationFailed(String)
}

// Model loading state
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

@MainActor
class MLXManagerFinetuned: ObservableObject {
    @Published var loadingState: ModelLoadingState = .initializing
    @Published var isLoading = false
    @Published var isModelLoaded = false
    
    private var model: ChatSession?
    private let vcEmbeddings = VCEmbeddings()
    
    // Fine-tuned model configuration
    // Note: The folder `gemma-2-2b-it-model` in this project contains LoRA adapter weights
    // (adapter_model.safetensors) and tokenizer files, not a fully merged model.
    // MLX cannot load LoRA adapters directly. To run your finetuned model, merge the adapters
    // into the base Gemma 2B and upload the merged model to Hugging Face, then set the ID below.
    private let localAdapterFolderName = "gemma-2-2b-it-model"
    private var huggingFaceModelID = "ronin207/gemma-2-2b-it-dcql-mlx" // TODO: replace with your merged finetuned repo
    
    init() {
        // Attempt to read a Hugging Face repo override from bundle metadata
        if let url = Bundle.main.url(forResource: "model_metadata", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let meta = try? JSONDecoder().decode(ModelMetadata.self, from: data),
           let repo = meta.hf_repo, !repo.isEmpty {
            huggingFaceModelID = repo
        }
        loadModel()
    }
    
    func loadModel() {
        Task {
            await loadModelAsync()
        }
    }
    
    private func loadModelAsync() async {
        loadingState = .initializing
        isLoading = true

        do {
            // Check if model is cached
            let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            let modelPath = cachesDir?.appendingPathComponent("models").appendingPathComponent(huggingFaceModelID)
            let isModelCached = modelPath.map { FileManager.default.fileExists(atPath: $0.path) } ?? false

            print("🔄 Loading model: \(huggingFaceModelID)")

            if isModelCached {
                print("💾 Model found in cache")
                // Cache available: initializing -> loading -> ready
                loadingState = .loading
            } else {
                print("📥 Model not in cache, will download")
                // No cache: initializing -> downloading -> loading -> ready
                loadingState = .downloading
            }

            let loadedModel = try await MLXLMCommon.loadModel(id: huggingFaceModelID)

            // After download/cache load, transition to loading state
            if case .downloading = loadingState {
                print("📦 Download complete, loading into memory...")
                loadingState = .loading
            }

            model = ChatSession(loadedModel)

            loadingState = .ready
            isModelLoaded = true
            print("✅ Model ready")

        } catch {
            loadingState = .failed(error.localizedDescription)
            print("❌ Error loading model: \(error)")
        }

        isLoading = false
    }
    
    // Generate DCQL from natural language query
    func generateDCQL(from query: String) async throws -> DCQLResponse {
        guard let model = model else {
            throw DCQLError.modelNotLoaded
        }
        
        // Step 1: Find relevant VCs using RAG
        let relevantVCs = vcEmbeddings.findRelevantVCs(query: query, topK: 3)
        
        if relevantVCs.isEmpty {
            throw DCQLError.noRelevantVCsFound
        }
        
        // Step 2: Format prompt for DCQL generation (matching training format)
        let vcFormatted = vcEmbeddings.formatVCsForPrompt(relevantVCs)
        let prompt = """
        You are a DCQL generator. Given the following Verifiable Credentials and a natural language query, output ONLY a valid JSON object representing the DCQL. Do not include explanations or markdown fences.
        
        Available Verifiable Credentials:
        \(vcFormatted)
        
        Natural Language Query: \(query)
        
        Generate a DCQL query that selects the appropriate credentials and fields. Output strictly a JSON object like this:
        {"credentials":[{"id":"<snake_case_type>_credential","format":"ldp_vc","meta":{"type_values":[["VerifiableCredential","<ExactCredentialType>"]]},"claims":[{"path":["credentialSubject","<field>"]}]}]}
        """
        
        // Step 3: Generate DCQL using fine-tuned model
        do {
            let response = try await model.respond(to: prompt)
            
            // Parse the DCQL JSON response (robust)
            if let dcqlJSON = parseDCQLJSON(from: response) {
                let pretty = (try? JSONSerialization.data(withJSONObject: dcqlJSON, options: .prettyPrinted)).flatMap { String(data: $0, encoding: .utf8) } ?? response
                return DCQLResponse(
                    dcql: dcqlJSON,
                    dcqlString: pretty,
                    selectedVCs: relevantVCs,
                    query: query
                )
            } else {
                // Fallback: template-based DCQL from the selected VCs
                let template = generateTemplateDCQL(for: relevantVCs, query: query)
                let pretty = (try? JSONSerialization.data(withJSONObject: template, options: .prettyPrinted)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                return DCQLResponse(
                    dcql: template,
                    dcqlString: pretty,
                    selectedVCs: relevantVCs,
                    query: query
                )
            }
            
        } catch {
            throw DCQLError.generationFailed(error.localizedDescription)
        }
    }
    
    // Generate conversational response (for general chat)
    func generateResponse(to prompt: String) async throws -> String {
        guard let model = model else {
            throw MLXError.modelNotLoaded
        }
        
        do {
            let response = try await model.respond(to: prompt)
            return response
        } catch {
            throw MLXError.generationFailed(error.localizedDescription)
        }
    }
    
    func resetChat() {
        model = nil
        loadModel()
    }
}

// MARK: - JSON parsing and template fallback
extension MLXManagerFinetuned {
    private func parseDCQLJSON(from text: String) -> [String: Any]? {
        // 1) Try direct parse
        if let data = text.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return obj
        }
        // 2) Strip code fences and language tags
        var cleaned = text
        if cleaned.contains("```") {
            cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
            cleaned = cleaned.replacingOccurrences(of: "```JSON", with: "")
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        }
        // 3) Extract substring between first '{' and last '}'
        if let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}") {
            let jsonSlice = cleaned[start...end]
            if let data = String(jsonSlice).data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return obj
            }
        }
        return nil
    }
    
    private func generateTemplateDCQL(for vcs: [VCEmbeddings.VerifiableCredential], query: String) -> [String: Any] {
        guard let firstVC = vcs.first else { return [:] }
        let credentialType = firstVC.type.last ?? "UnknownCredential"
        let credentialId = credentialType
            .lowercased()
            .replacingOccurrences(of: "credential", with: "")
            .replacingOccurrences(of: "certificate", with: "") + "_credential"
        
        var claims: [[String: Any]] = []
        let queryLower = query.lowercased()
        for (key, _) in firstVC.credentialSubject {
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

// DCQL Response structure
struct DCQLResponse {
    let dcql: [String: Any]  // Parsed DCQL JSON
    let dcqlString: String    // Raw DCQL string
    let selectedVCs: [VCEmbeddings.VerifiableCredential]  // VCs used for generation
    let query: String         // Original query
}

// Extended error types for DCQL
enum DCQLError: LocalizedError {
    case noRelevantVCsFound
    case invalidDCQLResponse
    case modelNotLoaded
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noRelevantVCsFound:
            return "No relevant verifiable credentials found for your query"
        case .invalidDCQLResponse:
            return "Invalid DCQL response format"
        case .modelNotLoaded:
            return "Model is not loaded yet. Please wait for the model to finish loading."
        case .generationFailed(let message):
            return "Failed to generate response: \(message)"
        }
    }
}
