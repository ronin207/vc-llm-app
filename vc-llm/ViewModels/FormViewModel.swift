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

    private let service: MLXDCQLService

    init(service: MLXDCQLService) {
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

        isGenerating = true
        errorMessage = nil

        Task {
            do {
                try await service.ensureModelLoaded()
                let response = try await service.generateDCQL(from: trimmed)

                await MainActor.run {
                    dcqlResponse = response
                    showResult = true
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showResult = false
                    isGenerating = false
                }
            }
        }
    }

    func reset() {
        inputText = ""
        showResult = false
        dcqlResponse = nil
        errorMessage = nil
    }
}
