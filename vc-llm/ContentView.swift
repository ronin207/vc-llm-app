//
//  ContentView.swift
//  vc-llm
//
//  Created by Takumi Otsuka on 2025/07/23.
//

import SwiftUI

struct Message: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

// MARK: - SimpleBubble View (clean dark bubble with timestamp)
struct SimpleBubble: View {
    @Environment(\.colorScheme) var colorScheme

    let text: String
    let isUser: Bool
    
    let time = Date()

    var bubbleBackground: some View {
        ZStack {
            if colorScheme == .dark {
                // Dark mode liquid glass effect
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.03)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            } else {
                // Light mode with subtle tint and liquid glass effect
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.92, green: 0.94, blue: 0.98).opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.6), Color.white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                    )
            }
        }
    }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            Text(text)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(Color.primary.opacity(0.95))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(bubbleBackground)
                .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)
                .padding(.leading, isUser ? 60 : 14) // user bubbles pushed right, assistant with default left
                .padding(.trailing, isUser ? 14 : 60)
                .if(colorScheme == .light) { view in
                    view.shadow(color: Color.black.opacity(0.06), radius: 6, y: 1)
                }

            Text(formattedTime(from: time))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color.primary.opacity(0.5))
                .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)
                .padding(.leading, isUser ? 60 : 14)
                .padding(.trailing, isUser ? 14 : 60)
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .padding(.vertical, 4)
        .padding(.horizontal, 14)
    }
    
    func formattedTime(from date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm a"
        return dateFormatter.string(from: date)
    }
}

struct Blob: View {
    @Environment(\.colorScheme) var colorScheme

    let color: Color
    let size: CGFloat
    let blurRadius: CGFloat
    let opacity: Double
    let animationDuration: Double
    let animationDelay: Double
    let initialOffset: CGPoint
    let movementRange: CGSize

    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0
    @State private var isMovingForward = true

    var adjustedColor: Color {
        if colorScheme == .dark {
            return color
        } else {
            // Map original dark colors to lighter pastel tones for light mode with stronger colors and higher opacity
            switch color {
            case Color(red: 0.01, green: 0.04, blue: 0.15):
                return Color(red: 0.55, green: 0.7, blue: 1.0)
                    .opacity(0.5)
            case Color(red: 0.3, green: 0.0, blue: 0.4):
                return Color(red: 0.75, green: 0.6, blue: 0.95)
                    .opacity(0.48)
            case Color(red: 0.0, green: 0.25, blue: 0.25):
                return Color(red: 0.55, green: 0.9, blue: 0.8)
                    .opacity(0.45)
            case Color(red: 0.07, green: 0.08, blue: 0.13):
                return Color(red: 0.8, green: 0.82, blue: 0.95)
                    .opacity(0.45)
            default:
                return color.opacity(0.45)
            }
        }
    }

    var adjustedOpacity: Double {
        if colorScheme == .dark {
            return opacity
        } else {
            return max(opacity * 0.6, 0.45)
        }
    }

    var body: some View {
        Circle()
            .fill(adjustedColor)
            .frame(width: size, height: size)
            .blur(radius: blurRadius)
            .opacity(adjustedOpacity)
            .offset(x: offsetX, y: offsetY)
            .onAppear {
                offsetX = initialOffset.x
                offsetY = initialOffset.y

                DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay) {
                    animateBlob()
                }
            }
    }

    private func animateBlob() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            if isMovingForward {
                offsetX = initialOffset.x + movementRange.width
                offsetY = initialOffset.y + movementRange.height
            } else {
                offsetX = initialOffset.x
                offsetY = initialOffset.y
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            isMovingForward.toggle()
            animateBlob()
        }
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var mlxManager = MLXManager()

    @State private var messages: [Message] = [
        Message(text: "Hello! I'm Gemma 2B running locally on your device. How can I help you today?", isUser: false)
    ]
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var isGenerating = false

    @State private var selectedModel: String = "Gemma 2B (Local)"
    @State private var showingModelActionSheet = false

    let availableModels: [String] = [
        "Gemma 2B (Local)",
    ]

    var baseBackground: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color(red: 0.07, green: 0.08, blue: 0.13), Color(red: 0.10, green: 0.11, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(red: 0.95, green: 0.96, blue: 0.99), Color(red: 0.88, green: 0.92, blue: 0.99)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var inputBackground: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.12)
        } else {
            return Color(.systemGray5) // more visible light background for input bar in light mode
        }
    }

    var body: some View {
        ZStack {
            // Dark solid base color behind blobs or a subtle gradient in light mode
            baseBackground
                .ignoresSafeArea()

            // Animated Blob Background
            GeometryReader { geo in
                ZStack {
                    Blob(
                        color: Color(red: 0.01, green: 0.04, blue: 0.15), // deep dark blue
                        size: 280,
                        blurRadius: 160,
                        opacity: 0.65,
                        animationDuration: 45,
                        animationDelay: 0,
                        initialOffset: CGPoint(x: geo.size.width * 0.15, y: geo.size.height * 0.3),
                        movementRange: CGSize(width: 40, height: 35)
                    )
                    Blob(
                        color: Color(red: 0.3, green: 0.0, blue: 0.4), // deep dark purple
                        size: 320,
                        blurRadius: 180,
                        opacity: 0.70,
                        animationDuration: 52,
                        animationDelay: 10,
                        initialOffset: CGPoint(x: geo.size.width * 0.7, y: geo.size.height * 0.2),
                        movementRange: CGSize(width: -35, height: 40)
                    )
                    Blob(
                        color: Color(red: 0.0, green: 0.25, blue: 0.25), // deep teal
                        size: 220,
                        blurRadius: 140,
                        opacity: 0.60,
                        animationDuration: 38,
                        animationDelay: 6,
                        initialOffset: CGPoint(x: geo.size.width * 0.4, y: geo.size.height * 0.7),
                        movementRange: CGSize(width: 30, height: -30)
                    )
                    Blob(
                        color: Color(red: 0.07, green: 0.08, blue: 0.13), // very dark base tone blob for depth
                        size: 260,
                        blurRadius: 150,
                        opacity: 0.55,
                        animationDuration: 50,
                        animationDelay: 3,
                        initialOffset: CGPoint(x: geo.size.width * 0.85, y: geo.size.height * 0.8),
                        movementRange: CGSize(width: -40, height: -25)
                    )
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }

            VStack(spacing: 0) {
                Spacer().frame(height: 50) // space for model picker button

                // Messages ScrollView
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(messages) { message in
                                SimpleBubble(text: message.text, isUser: message.isUser)
                                    .id(message.id)
                            }
                        }
                        .padding(.top, 32)
                        .padding(.bottom, 8)
                    }
                    .onChange(of: messages) { _ in
                        if let last = messages.last {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                // Input Bar
                HStack(spacing: 16) {
                    TextField("Write anything here ...", text: $inputText)
                        .focused($isInputFocused)
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundColor(Color.primary.opacity(0.95))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(inputBackground)
                        )
                        .submitLabel(.send)
                        .onSubmit {
                            sendMessage()
                        }
                        .disabled(isGenerating || !mlxManager.isModelLoaded)

                    Button {
                        sendMessage()
                    } label: {
                        if isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(Color.gray.opacity(0.6))
                                )
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.cyan)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.cyan.opacity(0.6), Color.cyan],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                        }
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating || !mlxManager.isModelLoaded)
                    .opacity((inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating || !mlxManager.isModelLoaded) ? 0.5 : 1.0)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .background(Color.clear)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 0) // ensure safe area inset for keyboard
                }
            }
            .ignoresSafeArea(.container, edges: .bottom) // allow input bar to respect safe area at bottom

            // Model Picker Button overlay: top trailing
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showingModelActionSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 18, weight: .semibold))
                            Text(selectedModel)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 20)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
            
            // Centered Modal Loading Overlay
            if mlxManager.isLoading {
                ZStack {
                    // Backdrop with blur effect
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .ignoresSafeArea()
                        .onTapGesture {
                            // Prevent dismissal during loading
                        }
                    
                    // Centered loading card
                    VStack(spacing: 20) {
                        // Loading icon and title
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                                .scaleEffect(1.5)
                            
                            VStack(spacing: 8) {
                                Text("Loading Gemma 2B")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text(mlxManager.loadingProgress)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        
                        // Progress information
                        VStack(spacing: 12) {
                            // Progress percentage and file size
                            HStack {
                                Text("\(Int(mlxManager.downloadProgress * 100))%")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.cyan)
                                
                                Spacer()
                                
                                if mlxManager.totalMB > 0 {
                                    Text("\(Int(mlxManager.downloadedMB))MB / \(Int(mlxManager.totalMB))MB")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.primary.opacity(0.7))
                                }
                            }
                            
                            // Progress bar
                            ProgressView(value: mlxManager.downloadProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .cyan))
                                .scaleEffect(y: 3.0)
                        }
                    }
                    .padding(.all, 32)
                    .frame(maxWidth: 320)
                    .background(
                        ZStack {
                            // Enhanced liquid glass effect for modal
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(colorScheme == .dark ? 
                                      Color.black.opacity(0.9) : 
                                      Color.white.opacity(0.98))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: colorScheme == .dark ? 
                                                [Color.cyan.opacity(0.2), Color.cyan.opacity(0.05)] :
                                                [Color.cyan.opacity(0.1), Color.cyan.opacity(0.03)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(
                                            colorScheme == .dark ? 
                                            Color.cyan.opacity(0.4) : 
                                            Color.cyan.opacity(0.3), 
                                            lineWidth: 1.5
                                        )
                                )
                        }
                        .shadow(color: Color.black.opacity(0.5), radius: 30, y: 15)
                    )
                    .scaleEffect(mlxManager.isLoading ? 1.0 : 0.8)
                    .opacity(mlxManager.isLoading ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: mlxManager.isLoading)
                }
            }
            
            // Error Modal Overlay
            if !mlxManager.isModelLoaded && !mlxManager.isLoading {
                ZStack {
                    // Backdrop
                    Rectangle()
                        .fill(Color.black.opacity(0.4))
                        .ignoresSafeArea()
                        .onTapGesture {
                            // Allow dismissal by tapping backdrop
                        }
                    
                    // Centered error card
                    VStack(spacing: 20) {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.orange)
                            
                            VStack(spacing: 8) {
                                Text("Model Failed to Load")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text("Check your internet connection and try again")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        
                        Button("Retry") {
                            mlxManager.loadModel()
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
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(colorScheme == .dark ? 
                                      Color.black.opacity(0.9) : 
                                      Color.white.opacity(0.98))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: colorScheme == .dark ? 
                                                [Color.orange.opacity(0.15), Color.orange.opacity(0.05)] :
                                                [Color.orange.opacity(0.08), Color.orange.opacity(0.02)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(
                                            colorScheme == .dark ? 
                                            Color.orange.opacity(0.4) : 
                                            Color.orange.opacity(0.3), 
                                            lineWidth: 1.5
                                        )
                                )
                        }
                        .shadow(color: Color.black.opacity(0.5), radius: 30, y: 15)
                    )
                }
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
        .confirmationDialog("Select Model", isPresented: $showingModelActionSheet, titleVisibility: .visible) {
            ForEach(availableModels, id: \.self) { model in
                Button {
                    selectedModel = model
                } label: {
                    if model == selectedModel {
                        HStack {
                            Text(model)
                                .foregroundColor(colorScheme == .dark ? .primary : .primary)
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(colorScheme == .dark ? .cyan : .blue)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(colorScheme == .dark ? Color.cyan.opacity(0.2) : Color.blue.opacity(0.16))
                        )
                    } else {
                        Text(model)
                            .foregroundColor(colorScheme == .dark ? .primary : .primary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // Handle sending message
    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, mlxManager.isModelLoaded, !isGenerating else { return }
        
        // Add user message
        withAnimation(.easeInOut(duration: 0.2)) {
            messages.append(Message(text: trimmed, isUser: true))
            inputText = ""
        }
        
        isGenerating = true
        isInputFocused = true
        
        // Generate response from Gemma model
        Task {
            do {
                let response = try await mlxManager.generateResponse(to: trimmed)
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        messages.append(Message(text: response, isUser: false))
                    }
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        messages.append(Message(text: "Sorry, I encountered an error: \(error.localizedDescription)", isUser: false))
                    }
                    isGenerating = false
                }
            }
        }
    }
}

#if DEBUG
extension View {
    /// Conditional modifier helper
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
#endif

#Preview {
    Group {
        ContentView()
    }
}
