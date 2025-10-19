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

    // Model manager (shared, not reloaded)
    private let modelManager: MLXManagerFinetuned

    init(modelManager: MLXManagerFinetuned) {
        self.modelManager = modelManager
    }

    var isModelReady: Bool {
        modelManager.isModelLoaded
    }

    var modelLoadingState: ModelLoadingState {
        modelManager.loadingState
    }

    func submitRequest() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, isModelReady, !isGenerating else { return }

        isGenerating = true
        errorMessage = nil

        Task {
            do {
                let response = try await modelManager.generateDCQL(from: trimmed)

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
