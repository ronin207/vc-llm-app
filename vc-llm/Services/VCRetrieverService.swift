//
//  VCRetrieverService.swift
//  vc-llm
//
//  Service for VC retrieval using semantic search
//

import Foundation

/// Result of VC retrieval
struct VCRetrievalResult {
    let selectedVCs: [VerifiableCredential]
    let formattedVCs: String
    let retrievalTime: TimeInterval
    let retrievalScores: [(vc: VerifiableCredential, score: Double)]
}

/// Service responsible for VC retrieval using semantic search
@MainActor
class VCRetrieverService {

    private let retriever: VCRetriever

    init(vcPoolPath: String = "vc_pool") {
        self.retriever = VCRetriever(vcPoolPath: vcPoolPath)
        self.retriever.prepareVCPool()
    }

    /// Retrieve relevant VCs for a given query
    /// - Parameters:
    ///   - query: Natural language query
    ///   - topK: Number of top VCs to retrieve (default: 3)
    /// - Returns: VCRetrievalResult with selected VCs and metadata
    func retrieve(query: String, topK: Int = 3) -> VCRetrievalResult {
        let retrievalStart = CFAbsoluteTimeGetCurrent()

        // Perform retrieval
        let retrievalResults = retriever.retrieve(query: query, topK: topK)
        let selectedVCs = retrievalResults.map { $0.vc }

        // Format VCs for prompt
        let formattedVCs = retriever.formatVCsForPrompt(selectedVCs)

        let retrievalTime = CFAbsoluteTimeGetCurrent() - retrievalStart

        print("🔍 [Retrieval] Retrieved \(selectedVCs.count) VCs in \(String(format: "%.3f", retrievalTime))s")

        return VCRetrievalResult(
            selectedVCs: selectedVCs,
            formattedVCs: formattedVCs,
            retrievalTime: retrievalTime,
            retrievalScores: retrievalResults
        )
    }

    /// Format VCs for prompt (convenience method)
    func formatVCsForPrompt(_ vcs: [VerifiableCredential]) -> String {
        return retriever.formatVCsForPrompt(vcs)
    }
}
