//
//  ContentView_DCQL.swift
//  vc-llm
//
//  Created by Assistant on 2025/07/28.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

// QR Code generator for presentation sharing
struct QRCodeGenerator {
    static func generate(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        
        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                let uiImage = UIImage(cgImage: cgimg)
                
                // Scale up the image for better quality
                let size = CGSize(width: 300, height: 300)
                UIGraphicsBeginImageContext(size)
                uiImage.draw(in: CGRect(origin: .zero, size: size))
                let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                return scaledImage
            }
        }
        
        return nil
    }
}

// Mode enum for different app states
enum AppMode {
    case chat
    case dcql
    case presentation
}

// Message type extended for DCQL
struct DCQLMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let dcqlResponse: DCQLResponse?
    let timestamp = Date()
    
    init(text: String, isUser: Bool, dcqlResponse: DCQLResponse? = nil) {
        self.text = text
        self.isUser = isUser
        self.dcqlResponse = dcqlResponse
    }
    
    static func == (lhs: DCQLMessage, rhs: DCQLMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct ContentViewDCQL: View {
    @Environment(\.colorScheme) var colorScheme
    // Choose between CoreML (recommended) or MLX
    // @StateObject private var modelManager = CoreMLManager()  // Use CoreML for local fine-tuned model
    @StateObject private var modelManager = MLXManagerFinetuned()  // Use MLX for HuggingFace model
    
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
                    exampleQueriesView
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
    
    private var exampleQueriesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try these examples:")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.primary.opacity(0.6))
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(exampleQueries, id: \.self) { query in
                        Button {
                            inputText = query
                            sendMessage()
                        } label: {
                            Text(query)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.cyan.opacity(0.15))
                                )
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 12)
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

// Message bubble component
struct MessageBubble: View {
    @Environment(\.colorScheme) var colorScheme
    let message: DCQLMessage
    let onPresentTapped: () -> Void
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 8) {
                Text(message.text)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(Color.primary.opacity(0.95))
                
                // Show DCQL details if available
                if let dcql = message.dcqlResponse {
                    DCQLDetailsView(dcqlResponse: dcql, onPresentTapped: onPresentTapped)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(bubbleBackground)
            .frame(maxWidth: 320, alignment: message.isUser ? .trailing : .leading)
            
            Text(formattedTime(from: message.timestamp))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color.primary.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }
    
    var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(message.isUser ?
                  LinearGradient(
                    colors: [Color.cyan.opacity(0.3), Color.cyan.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  ) :
                  LinearGradient(
                    colors: colorScheme == .dark ?
                        [Color.white.opacity(0.1), Color.white.opacity(0.05)] :
                        [Color.black.opacity(0.05), Color.black.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        message.isUser ?
                            Color.cyan.opacity(0.3) :
                            Color.primary.opacity(0.1),
                        lineWidth: 0.5
                    )
            )
    }
    
    func formattedTime(from date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        return dateFormatter.string(from: date)
    }
}

// DCQL Details View
struct DCQLDetailsView: View {
    let dcqlResponse: DCQLResponse
    let onPresentTapped: () -> Void
    @State private var showingJSON = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Selected VCs
            VStack(alignment: .leading, spacing: 4) {
                Text("Selected Credentials:")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.8))
                
                ForEach(dcqlResponse.selectedVCs) { vc in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12))
                        Text(vc.type.last ?? "Unknown")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.primary.opacity(0.7))
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button {
                    showingJSON.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showingJSON ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                        Text(showingJSON ? "Hide DCQL" : "View DCQL")
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
                    onPresentTapped()
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
                            .fill(Color.cyan.opacity(0.3))
                    )
                }
            }
            .foregroundColor(.primary)
            
            // DCQL JSON (collapsible)
            if showingJSON {
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    Text(dcqlResponse.dcqlString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.7))
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.05))
                        )
                }
                .frame(maxHeight: 200)
            }
        }
    }
}

// Presentation View for sharing VCs
struct PresentationView: View {
    @Environment(\.dismiss) var dismiss
    let dcqlResponse: DCQLResponse
    @State private var qrImage: UIImage?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Share Presentation")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .padding(.top)
                
                if let qrImage = qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                        )
                        .shadow(radius: 10)
                } else {
                    VStack(spacing: 8) {
                        ProgressView("Generating QR Code...")
                        Text("Preparing your presentation data...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 300, height: 300)
                }
                
                VStack(spacing: 8) {
                    Text("Scan to receive presentation")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                    
                    Text("This QR code contains your selected credentials")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.cyan)
                )
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
        .task { await generateQRCodeAsync() }
    }
    
    private func generateQRCodeAsync() async {
        // Filter credentials strictly to those referenced in DCQL if possible
        var selected: [VCEmbeddings.VerifiableCredential] = dcqlResponse.selectedVCs
        if let dcqlCreds = dcqlResponse.dcql["credentials"] as? [[String: Any]] {
            let dcqlTypeSet: Set<String> = Set(dcqlCreds.compactMap { cred in
                if let meta = cred["meta"] as? [String: Any],
                   let typeValues = meta["type_values"] as? [[String]],
                   let types = typeValues.first {
                    return types.last
                }
                return nil
            })
            if !dcqlTypeSet.isEmpty {
                selected = dcqlResponse.selectedVCs.filter { vc in
                    if let t = vc.type.last { return dcqlTypeSet.contains(t) }
                    return false
                }
            }
        }
        
        let presentationData: [String: Any] = [
            "type": "VerifiablePresentation",
            "credentials": selected.map { vc in
                [
                    "id": vc.id,
                    "type": vc.type,
                    "issuer": ["id": vc.issuer.id, "name": vc.issuer.name],
                    "credentialSubject": vc.credentialSubject.mapValues { $0.value }
                ]
            },
            "dcql": dcqlResponse.dcql,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: presentationData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            await MainActor.run { qrImage = QRCodeGenerator.generate(from: jsonString) }
        } else {
            await MainActor.run { qrImage = QRCodeGenerator.generate(from: "{}") }
        }
    }
}

// Fallback view shown if `currentDCQLResponse` is nil
struct PresentationFallbackView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ProgressView("Preparing presentation...")
                Text("Please try again.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Button("Close") { dismiss() }
                    .padding(.top, 4)
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

// Preview
#Preview {
    ContentViewDCQL()
}
