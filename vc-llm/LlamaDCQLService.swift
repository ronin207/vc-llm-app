//
//  LlamaDCQLService.swift
//  vc-llm
//
//  Orchestrator service that coordinates VC retrieval, DCQL generation, and VP generation
//

import Foundation
import Combine

@MainActor
final class LlamaDCQLService: ObservableObject {
    static let shared = LlamaDCQLService()

    @Published private(set) var loadingState: ModelLoadingState = .initializing
    @Published private(set) var isLoading = false
    @Published private(set) var isModelLoaded = false

    // Three separate services
    private let vcRetrieverService: VCRetrieverService
    private let dcqlGenerationService: DCQLGenerationService
    private let vpGenerationService: VPGenerationService

    init(
        vcRetrieverService: VCRetrieverService? = nil,
        dcqlGenerationService: DCQLGenerationService? = nil,
        vpGenerationService: VPGenerationService? = nil
    ) {
        self.vcRetrieverService = vcRetrieverService ?? VCRetrieverService(vcPoolPath: "vc_pool")
        self.dcqlGenerationService = dcqlGenerationService ?? DCQLGenerationService()
        self.vpGenerationService = vpGenerationService ?? VPGenerationService()

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
            loadingState = .loading

            // Load DCQL generation model
            try await dcqlGenerationService.ensureModelLoaded()

            loadingState = .ready
            isModelLoaded = true

            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
            print("✅ [Service] All services ready (total: \(String(format: "%.2f", totalTime))s)")
        } catch {
            loadingState = .failed(error.localizedDescription)
            isModelLoaded = false
            print("❌ [Service] Error loading services: \(error)")
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

    /// Generate DCQL from natural language query
    /// This method orchestrates the three services: retrieval, generation, and (optionally) VP generation
    func generateDCQL(from query: String, onProgress: ((String) -> Void)? = nil) async throws -> DCQLResponse {
        // Step 1: VC Retrieval
        let retrievalResult = vcRetrieverService.retrieve(query: query, topK: 3)

        guard !retrievalResult.selectedVCs.isEmpty else {
            throw DCQLError.noRelevantVCsFound
        }

        // Step 2: DCQL Generation
        let dcqlResult = try await dcqlGenerationService.generateDCQL(
            from: query,
            relevantVCs: retrievalResult.selectedVCs,
            formattedVCs: retrievalResult.formattedVCs,
            onProgress: onProgress
        )

        // Log timing information
        print("⏱️ [Service] Retrieval time: \(String(format: "%.3f", retrievalResult.retrievalTime))s")
        print("⏱️ [Service] Generation time: \(String(format: "%.3f", dcqlResult.generationTime))s")
        print("⏱️ [Service] Total time: \(String(format: "%.3f", retrievalResult.retrievalTime + dcqlResult.generationTime))s")

        return DCQLResponse(
            dcql: dcqlResult.dcql,
            dcqlString: dcqlResult.dcqlString,
            selectedVCs: retrievalResult.selectedVCs,
            query: query,
            retrievalTime: retrievalResult.retrievalTime,
            generationTime: dcqlResult.generationTime,
            vpGenerationTime: 0,
            vp: nil,
            vpError: nil
        )
    }

    /// Generate complete response including VP
    /// This method orchestrates all three services: retrieval, DCQL generation, and VP generation
    func generateComplete(from query: String, onProgress: ((String) -> Void)? = nil) async throws -> DCQLResponse {
        // Step 1 & 2: VC Retrieval + DCQL Generation
        let dcqlResponse = try await generateDCQL(from: query, onProgress: onProgress)

        // Step 3: VP Generation
        let vpResult = await vpGenerationService.generateVP(from: dcqlResponse)

        // Create final response with VP information
        return DCQLResponse(
            dcql: dcqlResponse.dcql,
            dcqlString: dcqlResponse.dcqlString,
            selectedVCs: dcqlResponse.selectedVCs,
            query: dcqlResponse.query,
            retrievalTime: dcqlResponse.retrievalTime,
            generationTime: dcqlResponse.generationTime,
            vpGenerationTime: vpResult.generationTime,
            vp: vpResult.vp,
            vpError: vpResult.error
        )
    }

    func resetModel() {
        dcqlGenerationService.resetModel()
        isModelLoaded = false
        loadModel()
    }

    // MARK: - Public Access to Individual Services

    /// Access to the VC retriever service
    var retriever: VCRetrieverService {
        return vcRetrieverService
    }

    /// Access to the DCQL generation service
    var dcqlGenerator: DCQLGenerationService {
        return dcqlGenerationService
    }

    /// Access to the VP generation service
    var vpGenerator: VPGenerationService {
        return vpGenerationService
    }
}

// MARK: - Supporting Types

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
