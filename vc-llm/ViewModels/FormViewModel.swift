import Foundation
import Combine

@MainActor
class FormViewModel: ObservableObject {
    // Published states
    @Published var inputText: String = ""
    @Published var isGenerating = false
    @Published var showResult = false
    @Published var errorMessage: String?

    // Result data
    @Published var dcqlResponse: DCQLResponse?

    // Streaming output
    @Published var streamingOutput: String = ""
    @Published var selectedVCsForStreaming: [VerifiableCredential] = []

    private let service: LlamaDCQLService

    init(service: LlamaDCQLService) {
        self.service = service
    }

    var isModelReady: Bool {
        service.isModelLoaded
    }

    var modelLoadingState: ModelLoadingState {
        service.loadingState
    }

    func submitRequest() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, isModelReady, !isGenerating else { return }

        // Clear previous response to free memory
        dcqlResponse = nil
        showResult = false
        streamingOutput = ""
        selectedVCsForStreaming = []

        isGenerating = true
        errorMessage = nil

        Task {
            do {
                try await service.ensureModelLoaded()

                // Generate DCQL using retrieval
                let response = try await service.generateDCQL(from: trimmed) { currentText in
                    Task { @MainActor in
                        self.streamingOutput = currentText
                    }
                }

                // Generate VP using Rust vp-dcql
                let vpStartTime = CFAbsoluteTimeGetCurrent()
                var vp: String? = nil
                var vpError: String? = nil

                do {
                    // Use LLM-generated DCQL (from response)
                    let dcqlData = try JSONSerialization.data(withJSONObject: response.dcql, options: [])
                    let dcqlString = String(data: dcqlData, encoding: .utf8) ?? "{}"

                    // Use the first retrieved VC (from retrieval results)
                    guard let firstVC = response.selectedVCs.first else {
                        throw VPDCQLError.rustError("No VCs available for VP generation")
                    }

                    // Convert VC to JSON string
                    let vcEncoder = JSONEncoder()
                    vcEncoder.outputFormatting = []
                    let vcData = try vcEncoder.encode(firstVC)
                    let vcString = String(data: vcData, encoding: .utf8) ?? "{}"

                    print("🦀 [VP] Calling Rust vp-dcql...")
                    print("🦀 [VP] Using LLM-generated DCQL")
                    print("🦀 [VP] VC type: \(firstVC.type.last ?? "unknown")")
                    print("🦀 [VP] DCQL preview: \(dcqlString.prefix(100))...")
                    print("🦀 [VP] VC preview: \(vcString.prefix(100))...")

                    vp = try VPDCQLBridge.createPresentation(
                        dcqlQuery: dcqlString,
                        signedCredential: vcString,
                        challenge: "mobile-app-challenge"
                    )

                    print("✅ [VP] VP generated successfully")
                } catch let error as VPDCQLError {
                    let errorMsg = error.localizedDescription
                    print("❌ [VP] VPDCQLError: \(errorMsg)")
                    vpError = errorMsg
                } catch {
                    let errorMsg = error.localizedDescription
                    print("❌ [VP] Unknown error: \(errorMsg)")
                    vpError = "VP Generation Failed: \(errorMsg)"
                }

                let vpGenerationTime = CFAbsoluteTimeGetCurrent() - vpStartTime

                // Create final response with VP information
                let finalResponse = DCQLResponse(
                    dcql: response.dcql,
                    dcqlString: response.dcqlString,
                    selectedVCs: response.selectedVCs,  // Use retrieval results
                    query: response.query,
                    retrievalTime: response.retrievalTime,
                    generationTime: response.generationTime,
                    vpGenerationTime: vpGenerationTime,
                    vp: vp,
                    vpError: vpError
                )

                await MainActor.run {
                    dcqlResponse = finalResponse
                    showResult = true
                    isGenerating = false
                    selectedVCsForStreaming = []
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showResult = false
                    isGenerating = false
                    selectedVCsForStreaming = []
                }
            }
        }
    }

    func reset() {
        inputText = ""
        showResult = false
        dcqlResponse = nil
        errorMessage = nil
        streamingOutput = ""
        selectedVCsForStreaming = []
    }
}
