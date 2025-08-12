//
//  ModelTestView.swift
//  vc-llm
//
//  Created by Assistant on 2025/07/28.
//

import SwiftUI

struct ModelTestView: View {
    @StateObject private var mlxManager = MLXManager()
    @State private var testPrompt = "Hello, how are you?"
    @State private var response = ""
    @State private var isGenerating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("MLX Gemma Model Test")
                .font(.title)
                .padding()
            
            if mlxManager.isLoading {
                VStack {
                    ProgressView()
                    Text(mlxManager.loadingProgress)
                        .padding(.top)
                }
            } else if mlxManager.isModelLoaded {
                VStack(spacing: 16) {
                    Text("✅ Model Loaded Successfully!")
                        .foregroundColor(.green)
                        .font(.headline)
                    
                    TextField("Test prompt", text: $testPrompt)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Button("Test Generation") {
                        testGeneration()
                    }
                    .disabled(isGenerating)
                    .buttonStyle(.borderedProminent)
                    
                    if isGenerating {
                        ProgressView("Generating...")
                    }
                    
                    if !response.isEmpty {
                        Text("Response:")
                            .font(.headline)
                        Text(response)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            } else {
                Text("❌ Failed to load model")
                    .foregroundColor(.red)
                    .font(.headline)
            }
        }
        .padding()
    }
    
    private func testGeneration() {
        isGenerating = true
        response = ""
        
        Task {
            do {
                let result = try await mlxManager.generateResponse(to: testPrompt)
                await MainActor.run {
                    response = result
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    response = "Error: \(error.localizedDescription)"
                    isGenerating = false
                }
            }
        }
    }
}

#Preview {
    ModelTestView()
}
