//
//  CoreMLManager.swift
//  vc-llm
//
//  Created by Assistant on 2025/07/28.
//

import Foundation
import CoreML
import NaturalLanguage
import Accelerate
import Combine

// Model configuration
struct ModelMetadata: Codable {
    let model_type: String
    let max_length: Int
    let vocab_size: Int
    let pad_token_id: Int
    let eos_token_id: Int
    let bos_token_id: Int
    let hf_repo: String? // <-- Add this optional property
}

@MainActor
class CoreMLManager: ObservableObject {
    @Published var isLoading = false
    @Published var isModelLoaded = false
    @Published var loadingProgress: String = ""
    
    private var model: MLModel?
    private var tokenizer: SimpleTokenizer?
    private let vcEmbeddings = VCEmbeddings()
    private var modelMetadata: ModelMetadata?
    
    init() {
        loadModel()
    }
    
    func loadModel() {
        Task {
            await loadModelAsync()
        }
    }
    
    private func loadModelAsync() async {
        isLoading = true
        loadingProgress = "Loading model..."
        
        do {
            // Try to load the CoreML model
            if let modelURL = Bundle.main.url(forResource: "GemmaDCQL", withExtension: "mlmodelc") {
                model = try MLModel(contentsOf: modelURL)
                loadingProgress = "CoreML model loaded!"
            } else if let packageURL = Bundle.main.url(forResource: "GemmaDCQL", withExtension: "mlpackage") {
                // Try loading from mlpackage
                loadingProgress = "Compiling model..."
                let compiledURL = try await MLModel.compileModel(at: packageURL)
                model = try MLModel(contentsOf: compiledURL)
                loadingProgress = "CoreML model loaded!"
            } else {
                // Fallback: Use template-based generation without CoreML
                print("⚠️ CoreML model not found, using template-based DCQL generation")
                loadingProgress = "Using template-based generation"
                model = nil  // Will use template fallback
            }
            
            // Load metadata
            if let metadataURL = Bundle.main.url(forResource: "model_metadata", withExtension: "json"),
               let metadataData = try? Data(contentsOf: metadataURL) {
                modelMetadata = try JSONDecoder().decode(ModelMetadata.self, from: metadataData)
            } else {
                // Use default metadata
                modelMetadata = ModelMetadata(
                    model_type: "gemma-2b-dcql",
                    max_length: 512,
                    vocab_size: 256000,
                    pad_token_id: 0,
                    eos_token_id: 1,
                    bos_token_id: 2,
                    hf_repo: nil
                )
            }
            
            // Initialize tokenizer
            let tok = SimpleTokenizer()
            await tok.loadVocabulary()
            self.tokenizer = tok
            
            isModelLoaded = true
            loadingProgress = "Model loaded successfully!"
            print("✅ CoreML model loaded successfully")
            
        } catch {
            loadingProgress = "Failed to load model: \(error.localizedDescription)"
            print("❌ Error loading CoreML model: \(error)")
        }
        
        isLoading = false
    }
    
    // Generate DCQL from natural language query
    func generateDCQL(from query: String) async throws -> DCQLResponse {
        // Note: We can work without the CoreML model using template-based generation
        guard let activeTokenizer = self.tokenizer else {
            // Initialize tokenizer if not already done
            if self.tokenizer == nil {
                let newTokenizer = SimpleTokenizer()
                await newTokenizer.loadVocabulary()
                self.tokenizer = newTokenizer
            }
            // Continue with template-based generation
            return try await generateTemplateDCQL(from: query)
        }
        
        // Step 1: Find relevant VCs using RAG
        let relevantVCs = vcEmbeddings.findRelevantVCs(query: query, topK: 3)
        
        if relevantVCs.isEmpty {
            throw CoreMLError.noRelevantVCsFound
        }
        
        // Step 2: Format prompt for DCQL generation
        let vcFormatted = vcEmbeddings.formatVCsForPrompt(relevantVCs)
        let prompt = """
        Given the following Verifiable Credentials and a natural language query, generate a DCQL query to retrieve the requested information.
        
        Available Verifiable Credentials:
        \(vcFormatted)
        
        Natural Language Query: \(query)
        
        Generate a DCQL query that selects the appropriate credentials and fields:
        """
        
        // Check if we have a CoreML model loaded
        if let model = model {
            // Step 3: Tokenize input
            let tokens = activeTokenizer.encode(prompt)
            let inputArray = try MLMultiArray(shape: [1, NSNumber(value: modelMetadata?.max_length ?? 512)], dataType: .int32)
            let attentionArray = try MLMultiArray(shape: [1, NSNumber(value: modelMetadata?.max_length ?? 512)], dataType: .int32)
            
            // Fill input arrays
            for i in 0..<min(tokens.count, modelMetadata?.max_length ?? 512) {
                inputArray[i] = NSNumber(value: tokens[i])
                attentionArray[i] = 1
            }
            
            // Pad remaining positions
            for i in tokens.count..<(modelMetadata?.max_length ?? 512) {
                inputArray[i] = NSNumber(value: modelMetadata?.pad_token_id ?? 0)
                attentionArray[i] = 0
            }
            
            // Step 4: Run inference
            let input = GemmaDCQLInput(input_ids: inputArray, attention_mask: attentionArray)
            let output = try await model.prediction(from: input)
            
            // Step 5: Decode output
            let outputArray = output.featureValue(for: "logits")?.multiArrayValue
            let decodedText = try decodeOutput(outputArray)
            
            // Step 6: Parse DCQL from output
            let dcqlString = extractDCQL(from: decodedText)
            
            guard let dcqlData = dcqlString.data(using: .utf8),
                  let dcqlJSON = try? JSONSerialization.jsonObject(with: dcqlData) as? [String: Any] else {
                // If parsing fails, generate a template DCQL based on the query
                let templateDCQL = generateTemplateDCQL(for: relevantVCs, query: query)
                return DCQLResponse(
                    dcql: templateDCQL,
                    dcqlString: try String(data: JSONSerialization.data(withJSONObject: templateDCQL, options: .prettyPrinted), encoding: .utf8) ?? "{}",
                    selectedVCs: relevantVCs,
                    query: query
                )
            }
            
            return DCQLResponse(
                dcql: dcqlJSON,
                dcqlString: dcqlString,
                selectedVCs: relevantVCs,
                query: query
            )
        } else {
            // No CoreML model - use template-based generation
            let templateDCQL = generateTemplateDCQL(for: relevantVCs, query: query)
            return DCQLResponse(
                dcql: templateDCQL,
                dcqlString: try String(data: JSONSerialization.data(withJSONObject: templateDCQL, options: .prettyPrinted), encoding: .utf8) ?? "{}",
                selectedVCs: relevantVCs,
                query: query
            )
        }
    }
    
    // Async template-based DCQL generation (fallback when no model)
    private func generateTemplateDCQL(from query: String) async throws -> DCQLResponse {
        // Find relevant VCs using RAG
        let relevantVCs = vcEmbeddings.findRelevantVCs(query: query, topK: 3)
        
        if relevantVCs.isEmpty {
            throw CoreMLError.noRelevantVCsFound
        }
        
        // Generate template DCQL
        let templateDCQL = generateTemplateDCQL(for: relevantVCs, query: query)
        
        return DCQLResponse(
            dcql: templateDCQL,
            dcqlString: try String(data: JSONSerialization.data(withJSONObject: templateDCQL, options: .prettyPrinted), encoding: .utf8) ?? "{}",
            selectedVCs: relevantVCs,
            query: query
        )
    }
    
    private func decodeOutput(_ output: MLMultiArray?) throws -> String {
        guard let output = output else { throw CoreMLError.invalidOutput }
        
        // Get the most likely token at each position
        var tokens: [Int] = []
        let sequenceLength = output.shape[1].intValue
        let vocabSize = output.shape[2].intValue
        
        for i in 0..<sequenceLength {
            var maxLogit: Float = -Float.infinity
            var maxIndex = 0
            
            for j in 0..<vocabSize {
                let idx: [NSNumber] = [0, NSNumber(value: i), NSNumber(value: j)]
                let number = output[idx]
                let value = number.floatValue
                if value > maxLogit {
                    maxLogit = value
                    maxIndex = j
                }
            }
            
            tokens.append(maxIndex)
            
            // Stop at EOS token
            if maxIndex == (modelMetadata?.eos_token_id ?? 1) {
                break
            }
        }
        
        // Decode tokens to text
        return tokenizer?.decode(tokens) ?? ""
    }
    
    private func extractDCQL(from text: String) -> String {
        // Extract JSON from the generated text
        // Look for content between { and }
        if let startIndex = text.firstIndex(of: "{"),
           let endIndex = text.lastIndex(of: "}") {
            let dcqlString = String(text[startIndex...endIndex])
            return dcqlString
        }
        return "{}"
    }
    
    private func generateTemplateDCQL(for vcs: [VCEmbeddings.VerifiableCredential], query: String) -> [String: Any] {
        // Generate a template DCQL based on selected VCs
        guard let firstVC = vcs.first else {
            return [:]
        }
        
        let credentialType = firstVC.type.last ?? "UnknownCredential"
        let credentialId = credentialType.lowercased()
            .replacingOccurrences(of: "credential", with: "")
            .replacingOccurrences(of: "certificate", with: "") + "_credential"
        
        // Determine which fields to include based on query keywords
        var claims: [[String: Any]] = []
        let queryLower = query.lowercased()
        
        for (key, _) in firstVC.credentialSubject {
            // Include fields mentioned in query or commonly requested fields
            if queryLower.contains(key.lowercased()) ||
               key == "fullName" || key == "name" ||
               (queryLower.contains("expir") && (key.contains("expir") || key.contains("valid"))) {
                claims.append(["path": ["credentialSubject", key]])
            }
        }
        
        // If no specific fields matched, include some default fields
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

// CoreML model input class
@objcMembers
class GemmaDCQLInput: NSObject, MLFeatureProvider {
    var input_ids: MLMultiArray
    var attention_mask: MLMultiArray
    
    init(input_ids: MLMultiArray, attention_mask: MLMultiArray) {
        self.input_ids = input_ids
        self.attention_mask = attention_mask
    }
    
    var featureNames: Set<String> {
        return ["input_ids", "attention_mask"]
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        switch featureName {
        case "input_ids":
            return MLFeatureValue(multiArray: input_ids)
        case "attention_mask":
            return MLFeatureValue(multiArray: attention_mask)
        default:
            return nil
        }
    }
}

// Simple tokenizer (you would need to implement proper tokenization)
class SimpleTokenizer {
    private var vocabulary: [String: Int] = [:]
    private var reverseVocabulary: [Int: String] = [:]
    
    func loadVocabulary() async {
        // Load tokenizer vocabulary from bundle
        // For now, use a simple character-based tokenizer
        // In production, load the actual Gemma tokenizer vocabulary
        
        // Simple character tokenizer for demo
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,;:!?()[]{}\"'-\n")
        for (index, char) in chars.enumerated() {
            let key = String(char)
            vocabulary[key] = index + 3  // Reserve 0-2 for special tokens
            reverseVocabulary[index + 3] = key
        }
        
        // Special tokens
        vocabulary["<pad>"] = 0
        vocabulary["<eos>"] = 1
        vocabulary["<bos>"] = 2
        reverseVocabulary[0] = "<pad>"
        reverseVocabulary[1] = "<eos>"
        reverseVocabulary[2] = "<bos>"
    }
    
    func encode(_ text: String) -> [Int] {
        var tokens: [Int] = [2]  // Start with BOS token
        
        for char in text {
            if let token = vocabulary[String(char)] {
                tokens.append(token)
            } else {
                tokens.append(3)  // Unknown token
            }
        }
        
        tokens.append(1)  // End with EOS token
        return tokens
    }
    
    func decode(_ tokens: [Int]) -> String {
        var text = ""
        for token in tokens {
            if token == 0 || token == 1 || token == 2 {
                continue  // Skip special tokens
            }
            if let char = reverseVocabulary[token] {
                text += char
            }
        }
        return text
    }
}

// Error types for CoreML
enum CoreMLError: LocalizedError {
    case modelNotFound
    case modelNotLoaded
    case noRelevantVCsFound
    case invalidOutput
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "CoreML model not found in bundle. Please add GemmaDCQL.mlpackage to your project."
        case .modelNotLoaded:
            return "Model is not loaded yet. Please wait for the model to finish loading."
        case .noRelevantVCsFound:
            return "No relevant verifiable credentials found for your query"
        case .invalidOutput:
            return "Invalid model output format"
        case .generationFailed(let message):
            return "Failed to generate response: \(message)"
        }
    }
}

