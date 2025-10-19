//
//  FormView.swift
//  vc-llm
//
//  Created on 2025/10/19
//

import SwiftUI

struct FormView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var modelManager = MLXManagerFinetuned()

    @State private var inputText: String = ""
    @State private var isGenerating = false
    @State private var showResult = false

    // Result data (placeholder for now)
    @State private var vcData: String = ""
    @State private var dcqlData: String = ""
    @State private var qrImage: UIImage?

    // Example queries for quick testing
    let exampleQueries = [
        "Show my driver's license",
        "Display my passport expiration date",
        "Show my health insurance but hide the insurance number",
        "I need my university degree"
    ]

    var body: some View {
        ZStack {
            // Background
            Color(colorScheme == .dark ? .black : .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                ScrollView {
                    VStack(spacing: 0) {
                        // Input Section
                        inputSection
                            .padding(.top, 20)

                        // Example queries (shown when no result)
                        if !showResult {
                            exampleQueriesSection
                                .padding(.top, 16)
                        }

                        // Submit Button
                        submitButton
                            .padding(.top, 28)

                        // Result Section (shown after submission)
                        if showResult {
                            resultSection
                                .padding(.top, 28)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }

            // Loading overlay
            if modelManager.loadingState.isLoading {
                loadingOverlay
            }

            // Error overlay
            if case .failed = modelManager.loadingState {
                errorOverlay
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text("VC-LLM")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(Color(colorScheme == .dark ? .black : .systemGroupedBackground))
    }

    private var exampleQueriesSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Try these examples")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(exampleQueries, id: \.self) { query in
                        Button {
                            inputText = query
                            handleSubmit()
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue.opacity(0.7))

                                Text(query)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(width: 160, alignment: .leading)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(colorScheme == .dark ? Color(.systemGray6).opacity(0.3) : Color(.secondarySystemGroupedBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Generate a VP according to your request")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text("Describe what credentials you need...\n\nExample:\nShow my driver's license\nDisplay my passport expiration date")
                            .font(.system(size: 16, weight: .regular, design: .default))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }

                    TextEditor(text: $inputText)
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundColor(.primary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 140)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorScheme == .dark ? Color(.systemGray6).opacity(0.3) : Color(.secondarySystemGroupedBackground))
            )
            .padding(.horizontal, 24)
        }
    }

    private var submitButton: some View {
        Button {
            handleSubmit()
        } label: {
            HStack(spacing: 10) {
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Generate VP")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isGenerating ? Color.gray : Color.blue
                    )
            )
        }
        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating || !modelManager.isModelLoaded)
        .opacity((inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating || !modelManager.isModelLoaded) ? 0.5 : 1.0)
        .padding(.horizontal, 24)
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("I found relevant credentials for your query.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.primary.opacity(0.95))

            // Selected VCs
            VStack(alignment: .leading, spacing: 8) {
                Text("Selected Credentials:")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.8))

                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                    Text("Driver's License")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.primary.opacity(0.7))
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    // Toggle DCQL view
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                        Text("View DCQL")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.1))
                    )
                }

                Button {
                    // Present action
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 12))
                        Text("Present")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.2))
                    )
                }
            }
            .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark ?
                            [Color.white.opacity(0.1), Color.white.opacity(0.05)] :
                            [Color.black.opacity(0.05), Color.black.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 24)
    }

    private var loadingOverlay: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.4))
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                    .scaleEffect(1.5)

                Text(loadingTitle)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.all, 32)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.9) : Color.white.opacity(0.98))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.cyan.opacity(0.4), lineWidth: 1.5)
                    )
            )
            .shadow(color: Color.black.opacity(0.5), radius: 30, y: 15)
        }
    }

    private var loadingTitle: String {
        switch modelManager.loadingState {
        case .initializing:
            return "Initializing"
        case .downloading:
            return "Downloading Model"
        case .loading:
            return "Loading Model"
        case .ready:
            return "Ready"
        case .failed:
            return "Error"
        }
    }

    private var errorOverlay: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.4))
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.orange)

                VStack(spacing: 8) {
                    Text("Model Failed to Load")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Check your connection and try again")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.primary.opacity(0.7))
                }

                Button("Retry") {
                    modelManager.loadModel()
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.orange)
                )
            }
            .padding(.all, 32)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.9) : Color.white.opacity(0.98))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.orange.opacity(0.4), lineWidth: 1.5)
                    )
            )
            .shadow(color: Color.black.opacity(0.5), radius: 30, y: 15)
        }
    }

    private func handleSubmit() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, modelManager.isModelLoaded, !isGenerating else { return }

        isGenerating = true

        // TODO: Implement actual VC generation logic
        // For now, just show placeholder results
        Task {
            // Simulate processing delay
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

            await MainActor.run {
                // Placeholder data
                vcData = "{\n  \"type\": \"VerifiableCredential\",\n  \"credentialSubject\": {\n    // VC data will be displayed here\n  }\n}"
                dcqlData = "{\n  \"query\": {\n    // DCQL query will be displayed here\n  }\n}"
                qrImage = nil // QR code will be generated here

                showResult = true
                isGenerating = false
            }
        }
    }
}

// Preview
#Preview {
    FormView()
}
