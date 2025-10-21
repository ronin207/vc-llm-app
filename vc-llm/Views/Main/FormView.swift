import SwiftUI

struct FormView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var dcqlService = LlamaDCQLService.shared
    @StateObject private var viewModel: FormViewModel

    @State private var showingDCQL = false
    @State private var showingPresentation = false

    // Example queries for quick testing
    let exampleQueries = [
        "Show my driver's license",
        "Display my passport expiration date",
        "Show my health insurance but hide the insurance number",
        "I need my university degree"
    ]

    init() {
        _viewModel = StateObject(wrappedValue: FormViewModel(service: LlamaDCQLService.shared))
    }

    var body: some View {
        ZStack {
            Color(colorScheme == .dark ? .black : .systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    inputSection
                        .padding(.top, 20)

                    exampleQueriesSection
                        .padding(.top, 16)

                    submitButton
                        .padding(.top, 28)

                    if viewModel.showResult || viewModel.isGenerating {
                        resultSection
                            .padding(.top, 28)
                    }

                    if let error = viewModel.errorMessage {
                        errorMessageView(error)
                            .padding(.top, 16)
                    }
                }
                .padding(.bottom, 40)
            }

            // Loading overlay
            if dcqlService.loadingState.isLoading {
                loadingOverlay
            }

            // Error overlay
            if case .failed = dcqlService.loadingState {
                errorOverlay
            }
        }
        .navigationTitle("VC-LLM")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            print("⚠️ Memory warning received - cleaning up")
            viewModel.dcqlResponse = nil
        }
        .sheet(isPresented: $showingDCQL) {
            if let response = viewModel.dcqlResponse {
                DCQLSheetView(dcqlResponse: response)
            }
        }
        .sheet(isPresented: $showingPresentation) {
            if let response = viewModel.dcqlResponse {
                QRPresentationView(dcqlResponse: response)
            }
        }
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
                            viewModel.inputText = query
                            viewModel.submitRequest()
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue.opacity(0.7))
                                    .padding(.top, 2)

                                Text(query)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(width: 180, alignment: .leading)
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
                    if viewModel.inputText.isEmpty {
                        Text("Describe what credentials you need...\n\nExample:\nShow my driver's license\nDisplay my passport expiration date")
                            .font(.system(size: 16, weight: .regular, design: .default))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }

                    TextEditor(text: $viewModel.inputText)
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
            // Hide keyboard
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            viewModel.submitRequest()
        } label: {
            HStack(spacing: 10) {
                if viewModel.isGenerating {
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
                        viewModel.isGenerating ? Color.gray : Color.blue
                    )
            )
        }
        .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating || !viewModel.isModelReady)
        .opacity((viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating || !viewModel.isModelReady) ? 0.5 : 1.0)
        .padding(.horizontal, 24)
    }

    private var resultSection: some View {
        Group {
            // Show streaming output while generating
            if viewModel.isGenerating {
                VStack(alignment: .leading, spacing: 16) {
                    // Show selected VCs
                    if !viewModel.selectedVCsForStreaming.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Found \(viewModel.selectedVCsForStreaming.count) relevant credentials")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)

                            ForEach(viewModel.selectedVCsForStreaming) { vc in
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 14))
                                    Text(vc.type.last ?? "Unknown Credential")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.primary.opacity(0.9))
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.green.opacity(0.1))
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // Show streaming DCQL generation
                    if !viewModel.streamingOutput.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Generating DCQL Query...")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }

                            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                                Text(viewModel.streamingOutput)
                                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(colorScheme == .dark ? Color(.systemGray6).opacity(0.3) : Color(.systemGray6).opacity(0.5))
                            )
                            .frame(maxHeight: 300)
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
            }
            // Show final result when complete
            else if let response = viewModel.dcqlResponse {
                VStack(alignment: .leading, spacing: 12) {
                    Text("I found \(response.selectedVCs.count) relevant credential(s) for your query.")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.primary.opacity(0.95))

                    // Selected VCs
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected Credentials:")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary.opacity(0.8))

                        ForEach(response.selectedVCs) { vc in
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

                    // Timing Information (Debug)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.7))
                            Text("Performance:")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary.opacity(0.8))
                        }

                        HStack(spacing: 12) {
                            timingItem(label: "Retrieval", time: response.retrievalTime)
                            timingItem(label: "Generation", time: response.generationTime)
                            timingItem(label: "Total", time: response.totalTime)
                        }
                    }
                    .padding(.top, 4)

                    actionButtons(for: response)
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
        }
    }

    private func timingItem(label: String, time: TimeInterval) -> some View {
        HStack(spacing: 2) {
            Text("\(label):")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.7))
            Text(String(format: "%.3fs", time))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private func actionButtons(for response: DCQLResponse) -> some View {
        HStack(spacing: 12) {
            Button {
                showingDCQL = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
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
                showingPresentation = true
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

    private func errorMessageView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Error")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }

            Text(message)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
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
        switch dcqlService.loadingState {
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
                    dcqlService.loadModel()
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

}

// MARK: - DCQL Sheet View
struct DCQLSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    let dcqlResponse: DCQLResponse

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(dcqlResponse.dcqlString)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(colorScheme == .dark ? Color(.systemGray6).opacity(0.3) : Color(.secondarySystemGroupedBackground))
                        )
                }
                .padding(24)
            }
            .navigationTitle("DCQL Query")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        UIPasteboard.general.string = dcqlResponse.dcqlString
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }
}

// MARK: - QR Presentation View
struct QRPresentationView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    let dcqlResponse: DCQLResponse

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()

                // QR Code
                if let qrImage = generateQRCode(from: dcqlResponse.dcqlString) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 280, height: 280)
                        .padding(24)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 80))
                            .foregroundColor(.gray.opacity(0.3))

                        Text("Unable to generate QR code")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 280, height: 280)
                }

                Text("Scan this QR code to receive the verifiable presentation")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(colorScheme == .dark ? .black : .systemGroupedBackground))
            .navigationTitle("Present VP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledCIImage = ciImage.transformed(by: transform)

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }
}

// Preview
#Preview {
    FormView()
}
