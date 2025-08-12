//
//  MLXManager.swift
//  vc-llm
//
//  Created by Assistant on 2025/07/28.
//

import Foundation
import Combine
import MLXLMCommon
import MLXLLM

@MainActor
class MLXManager: ObservableObject {
    @Published var isLoading = false
    @Published var isModelLoaded = false
    @Published var loadingProgress: String = ""
    @Published var downloadProgress: Double = 0.0
    @Published var downloadedMB: Double = 0.0
    @Published var totalMB: Double = 0.0
    
    private var model: ChatSession? // Changed from Any? to ChatSession?
    
    // Gemma 1B model from Hugging Face
    private let modelID = "mlx-community/gemma-2-2b-it-4bit"
    
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
        downloadProgress = 0.0
        loadingProgress = "Downloading Gemma 2B model..."
        
        // Simulate progress updates (since MLX doesn't provide real progress callbacks)
        let progressUpdates = [
            (0.1, "Connecting to Hugging Face..."),
            (0.2, "Downloading model weights..."),
            (0.4, "Downloading tokenizer..."),
            (0.6, "Processing model files..."),
            (0.8, "Loading into memory..."),
            (0.9, "Finalizing setup...")
        ]
        
        do {
            // Start a background task to simulate progress
            let progressTask = Task {
                for (progress, message) in progressUpdates {
                    try? await Task.sleep(nanoseconds: UInt64(1.5 * 1_000_000_000)) // 1.5 seconds
                    await MainActor.run {
                        self.downloadProgress = progress
                        self.loadingProgress = message
                        self.downloadedMB = progress * 1500 // Approximate model size
                        self.totalMB = 1500
                    }
                }
            }
            
            // Load the actual model
            let loadedModel = try await MLXLMCommon.loadModel(id: modelID)
            
            // Cancel the progress simulation since we're done
            progressTask.cancel()
            
            model = ChatSession(loadedModel)
            
            downloadProgress = 1.0
            downloadedMB = 1500
            totalMB = 1500
            isModelLoaded = true
            loadingProgress = "Model loaded successfully!"
            
        } catch {
            downloadProgress = 0.0
            loadingProgress = "Failed to load model: \(error.localizedDescription)"
            print("Error loading model: \(error)")
        }
        
        isLoading = false
    }
    
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

enum MLXError: LocalizedError {
    case modelNotLoaded
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Model is not loaded yet. Please wait for the model to finish loading."
        case .generationFailed(let message):
            return "Failed to generate response: \(message)"
        }
    }
}
