//
//  DCQLGenerationService.swift
//  vc-llm
//
//  Service for DCQL generation using LLM
//

import Foundation

/// Result of DCQL generation
struct DCQLGenerationResult {
    let dcql: [String: Any]
    let dcqlString: String
    let generationTime: TimeInterval
    let rawResponse: String
}

/// Service responsible for DCQL generation using LLM
@MainActor
class DCQLGenerationService {

    private var llamaGenerator: LlamaDCQLGenerator?
    private var isModelLoaded = false
    private var isLoading = false
    private var modelPath: String?

    init(modelPath: String? = nil) {
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
    }

    // MARK: - Model Management

    func ensureModelLoaded(timeout: TimeInterval = 240) async throws {
        if !isModelLoaded && !isLoading {
            try await loadModel()
        }

        let deadline = Date().addingTimeInterval(timeout)
        while !isModelLoaded {
            if Date() > deadline {
                throw DCQLError.modelNotLoaded
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func loadModel() async throws {
        isLoading = true
        defer { isLoading = false }

        let startTime = CFAbsoluteTimeGetCurrent()

        guard let modelPath = modelPath else {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let docsModelPath = documentsPath.appendingPathComponent("gemma-2-2b-it-dcql-q4.gguf").path

            let errorMsg = """
            Model file not found!

            Please copy gemma-2-2b-it-dcql-q4.gguf to:
            \(docsModelPath)

            You can use Xcode > Window > Devices and Simulators to copy the file.
            """
            throw DCQLError.generationFailed(errorMsg)
        }

        print("🔄 [DCQL] Loading llama.cpp model: \(modelPath)")
        let loadStart = CFAbsoluteTimeGetCurrent()

        llamaGenerator = try await LlamaDCQLGenerator(modelPath: modelPath)
        isModelLoaded = true

        let loadTime = CFAbsoluteTimeGetCurrent() - loadStart
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        print("✅ [DCQL] Model loaded in \(String(format: "%.2f", loadTime))s (total: \(String(format: "%.2f", totalTime))s)")
    }

    func resetModel() {
        llamaGenerator = nil
        isModelLoaded = false
    }

    // MARK: - DCQL Generation

    /// Generate DCQL from natural language query and VCs
    /// - Parameters:
    ///   - query: Natural language query
    ///   - relevantVCs: Relevant VCs retrieved for the query
    ///   - formattedVCs: Formatted VC string for prompt
    ///   - onProgress: Optional callback for streaming progress
    /// - Returns: DCQLGenerationResult with generated DCQL
    func generateDCQL(
        from query: String,
        relevantVCs: [VerifiableCredential],
        formattedVCs: String,
        onProgress: ((String) -> Void)? = nil
    ) async throws -> DCQLGenerationResult {
        guard isModelLoaded, let generator = llamaGenerator else {
            throw DCQLError.modelNotLoaded
        }

        guard !relevantVCs.isEmpty else {
            throw DCQLError.noRelevantVCsFound
        }

        // Build prompt
        let prompt = buildPrompt(formattedVCs: formattedVCs, query: query)

        // Measure DCQL generation time
        let generationStart = CFAbsoluteTimeGetCurrent()

        do {
            // Generate using LLM
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

            print("⏱️ [DCQL] Generation time: \(String(format: "%.3f", generationTime))s")

            // Parse and validate DCQL
            let json = try parseDCQLJSON(from: rawResponse)
            try validateDCQL(json, raw: rawResponse)

            let pretty = (try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted))
                .flatMap { String(data: $0, encoding: .utf8) } ?? rawResponse

            return DCQLGenerationResult(
                dcql: json,
                dcqlString: pretty,
                generationTime: generationTime,
                rawResponse: rawResponse
            )

        } catch let validationError as DCQLValidationError {
            let generationTime = CFAbsoluteTimeGetCurrent() - generationStart

            print("❌ [DCQL] Validation failed: \(validationError.localizedDescription)")
            print("🔍 [DCQL] Raw response: \(validationError.rawResponse)")
            print("⏱️ [DCQL] Generation time: \(String(format: "%.3f", generationTime))s")

            // Use fallback template
            let fallback = generateTemplateDCQL(for: relevantVCs, query: query)
            let pretty = (try? JSONSerialization.data(withJSONObject: fallback, options: .prettyPrinted))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

            return DCQLGenerationResult(
                dcql: fallback,
                dcqlString: pretty,
                generationTime: generationTime,
                rawResponse: validationError.rawResponse
            )

        } catch {
            throw DCQLError.generationFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Methods

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
