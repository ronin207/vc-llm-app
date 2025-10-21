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

                // Get selected VCs first
                let retriever = VCRetriever(vcPoolPath: "vc_pool")
                retriever.prepareVCPool()
                let retrievalResults = retriever.retrieve(query: trimmed, topK: 3)
                let selectedVCs = retrievalResults.map { $0.vc }

                // Show selected VCs immediately
                await MainActor.run {
                    self.selectedVCsForStreaming = selectedVCs
                }

                // Generate with streaming
                let response = try await service.generateDCQL(from: trimmed) { currentText in
                    Task { @MainActor in
                        self.streamingOutput = currentText
                    }
                }

                await MainActor.run {
                    dcqlResponse = response
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
