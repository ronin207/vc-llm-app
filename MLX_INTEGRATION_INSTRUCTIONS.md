# MLXSwift Integration Instructions

## ⚠️ IMPORTANT: Follow these steps to fix "No such module 'MLXLMCommon'" error

### Step 1: Add MLXSwift Package Dependency in Xcode

1. **Open your `vc-llm.xcodeproj` in Xcode**
2. **Select your project** in the Project Navigator (the top-level "vc-llm" item)
3. **Select your app target** (`vc-llm` under "Targets")
4. **Click on "Package Dependencies" tab** (next to "General", "Signing & Capabilities", etc.)
5. **Click the "+" button** at the bottom left to add a new package
6. **Enter this URL**: `https://github.com/ml-explore/mlx-swift-examples`
7. **Select "Up to Next Major Version"** and click "Add Package"
8. **Wait for Xcode to resolve the package** (this may take a minute)
9. **Select these libraries** when prompted:
   - ✅ `MLXLLM`
   - ✅ `MLXLMCommon`
10. **Click "Add Package"**

### Step 2: Update MLXManager.swift

After adding the package, update the imports in `MLXManager.swift`:

```swift
import Foundation
import MLXLMCommon  // Uncomment this line
import MLXLLM       // Uncomment this line
```

Then replace the temporary implementation with the real one:

```swift
@MainActor
class MLXManager: ObservableObject {
    @Published var isLoading = false
    @Published var isModelLoaded = false
    @Published var loadingProgress: String = ""
    
    private var model: ChatSession?  // Change from Any? to ChatSession?
    
    // Gemma 1B model from Hugging Face
    private let modelID = "mlx-community/gemma-1.1-2b-it-4bit"
    
    init() {
        loadModel()  // Enable this line
    }
    
    func loadModel() {
        Task {
            await loadModelAsync()
        }
    }
    
    private func loadModelAsync() async {
        isLoading = true
        loadingProgress = "Loading Gemma 1B model..."
        
        do {
            // Load the model using MLXLMCommon
            let loadedModel = try await MLXLLM.loadModel(id: modelID)
            
            // Create a chat session
            model = ChatSession(model: loadedModel)
            
            isModelLoaded = true
            loadingProgress = "Model loaded successfully!"
            
        } catch {
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
        model?.reset()
    }
}
```

### 2. Build Settings

Make sure your deployment target is set to:
- iOS 16.0 or later
- macOS 13.0 or later

### 3. What's been added to your project:

1. **MLXManager.swift** - A new class that handles:
   - Loading the Gemma 1B model from Hugging Face Hub
   - Managing the model state
   - Generating responses to user queries

2. **Updated ContentView.swift** - Modified to:
   - Integrate with MLXManager
   - Show model loading status
   - Handle generating responses using the local Gemma model
   - Display loading indicators during response generation

### 4. Model Information:

- **Model**: Gemma 1.1 2B Instruct (4-bit quantized)
- **Source**: `mlx-community/gemma-1.1-2b-it-4bit`
- **Runtime**: Runs completely locally on your device
- **No internet required** after initial download

### 5. First Run:

On the first run, the app will:
1. Download the Gemma model (approximately 1.5GB)
2. Cache it locally for future use
3. Show a loading progress indicator

### 6. Features:

- Local AI chat with no data leaving your device
- Persistent conversation context
- Real-time response generation
- Loading and error states
- Integration with your existing beautiful UI

### 7. Troubleshooting:

If you encounter build errors:
- Ensure you're building for a device/simulator with Apple Silicon (M1/M2/M3)
- Check that your deployment target meets the minimum requirements
- Clean and rebuild the project (Cmd+Shift+K, then Cmd+B)

The integration maintains your existing UI design while adding powerful local AI capabilities through the Gemma 1B model!
