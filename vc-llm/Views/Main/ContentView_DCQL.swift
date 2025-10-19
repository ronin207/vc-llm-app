//
//  ContentView_DCQL.swift
//  vc-llm
//
//  Refactored on 2025/10/19
//

import SwiftUI

struct ContentViewDCQL: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var modelManager = MLXManagerFinetuned()

    @State private var messages: [DCQLMessage] = [
        DCQLMessage(text: "Hello! I can help you query your Verifiable Credentials and generate DCQL queries. Try asking me something like 'Show my driver's license' or 'Display my passport expiration date'.", isUser: false)
    ]
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var isGenerating = false
    @State private var appMode: AppMode = .dcql
    @State private var currentDCQLResponse: DCQLResponse?
    @State private var showingPresentation = false
    @State private var showingVCList = false
    @State private var selectedModel: String = "Gemma 2B Finetuned (DCQL)"

    // Example queries for quick testing
    let exampleQueries = [
        "Show my driver's license",
        "Display my passport expiration date",
        "Show my health insurance but hide the insurance number",
        "I need my university degree",
        "Show my English proficiency certificates",
        "Display my blood type certificate"
    ]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: colorScheme == .dark ?
                    [Color(red: 0.07, green: 0.08, blue: 0.13), Color(red: 0.10, green: 0.11, blue: 0.18)] :
                    [Color(red: 0.95, green: 0.96, blue: 0.99), Color(red: 0.88, green: 0.92, blue: 0.99)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with mode selector
                headerView

                // Example queries (shown when empty)
                if messages.count == 1 {
                    ExampleQueriesView(queries: exampleQueries) { query in
                        inputText = query
                        sendMessage()
                    }
                }

                // Messages ScrollView
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(messages) { message in
                                MessageBubble(message: message, onPresentTapped: {
                                    if let dcql = message.dcqlResponse {
                                        currentDCQLResponse = dcql
                                        showingPresentation = true
                                    }
                                })
                                .id(message.id)
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    }
                    .onChange(of: messages) { _ in
                        if let last = messages.last {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input Bar
                inputBar
            }
            .ignoresSafeArea(.container, edges: .bottom)

            // Loading overlay
            if modelManager.isLoading {
                loadingOverlay
            }

            // Error overlay
            if !modelManager.isModelLoaded && !modelManager.isLoading {
                errorOverlay
            }
        }
        .sheet(isPresented: $showingPresentation) {
            if let dcql = currentDCQLResponse {
                PresentationView(dcqlResponse: dcql)
            } else {
                PresentationFallbackView()
            }
        }
        .sheet(isPresented: $showingVCList) {
            VCListView()
        }
    }

    private var headerView: some View {
        HStack {
            Text("VC-LLM")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            // VC List button
            Button {
                showingVCList = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                    Text("VCs")
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.purple.opacity(0.2))
                )
            }
            .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.clear)
    }

    private var inputBar: some View {
        HStack(spacing: 16) {
            TextField("Ask about your credentials...", text: $inputText)
                .focused($isInputFocused)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(Color.primary.opacity(0.95))
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color(.systemGray5))
                )
                .submitLabel(.send)
                .onSubmit {
                    sendMessage()
                }
                .disabled(isGenerating || !modelManager.isModelLoaded)

            Button {
                sendMessage()
            } label: {
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.gray.opacity(0.6)))
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.8), Color.cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        )
                }
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating || !modelManager.isModelLoaded)
            .opacity((inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating || !modelManager.isModelLoaded) ? 0.5 : 1.0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(Color.clear)
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

                VStack(spacing: 8) {
                    Text("Loading Fine-tuned Model")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(modelManager.loadingProgress)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.primary.opacity(0.8))
                }

                if modelManager.downloadProgress > 0 {
                    VStack(spacing: 12) {
                        HStack {
                            Text("\(Int(modelManager.downloadProgress * 100))%")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.cyan)

                            Spacer()

                            if modelManager.totalMB > 0 {
                                Text("\(Int(modelManager.downloadedMB))MB / \(Int(modelManager.totalMB))MB")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary.opacity(0.7))
                            }
                        }

                        ProgressView(value: modelManager.downloadProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .cyan))
                            .scaleEffect(y: 3.0)
                    }
                }
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

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, modelManager.isModelLoaded, !isGenerating else { return }

        // Add user message
        withAnimation(.easeInOut(duration: 0.2)) {
            messages.append(DCQLMessage(text: trimmed, isUser: true))
            inputText = ""
        }

        isGenerating = true
        isInputFocused = true

        // Generate DCQL response
        Task {
            do {
                let dcqlResponse = try await modelManager.generateDCQL(from: trimmed)

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        // Format the response message
                        let responseText = """
                        I found \(dcqlResponse.selectedVCs.count) relevant credential(s) for your query.

                        Generated DCQL query to retrieve the requested information.
                        """

                        messages.append(DCQLMessage(
                            text: responseText,
                            isUser: false,
                            dcqlResponse: dcqlResponse
                        ))
                    }
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        messages.append(DCQLMessage(
                            text: "Sorry, I encountered an error: \(error.localizedDescription)",
                            isUser: false
                        ))
                    }
                    isGenerating = false
                }
            }
        }
    }
}

// Preview
#Preview {
    ContentViewDCQL()
}
