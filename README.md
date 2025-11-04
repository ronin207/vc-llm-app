# VC-LLM Mobile App

LLM-powered Verifiable Credential query generator for iOS.

## Quick Setup

### 1. Download Model

Download the GGUF model file (1.6GB):
- Model: `gemma-2-2b-it-dcql-q4.gguf`
- Place it in: `Documents/` directory of the app container

**How to copy the model:**
1. Build and run the app in Xcode (it will fail to load model, that's OK)
2. In Xcode: Window → Devices and Simulators → Select your device/simulator
3. Find the app, click the gear icon → Download Container
4. Extract the `.xcappdata` file → Create `AppData/Documents/` folder if needed
5. Copy `gemma-2-2b-it-dcql-q4.gguf` to `AppData/Documents/`
6. Upload the modified container back to the device/simulator
7. Restart the app

### 2. Build & Run

```bash
# Open in Xcode
open vc-llm.xcodeproj

# Build and run (Cmd+R)
```

## Architecture

- **VCRetriever**: Semantic search for relevant credentials using embeddings
- **LlamaDCQLService**: llama.cpp-based DCQL query generation
- **LlamaDCQLGenerator**: Swift wrapper for llama.cpp inference
- **FormViewModel**: UI state management with streaming output

## How it Works

1. User enters natural language query (e.g., "Show my driver's license")
2. VCRetriever finds top-3 relevant credentials using semantic similarity
3. LlamaDCQLGenerator creates DCQL query using the LLM (with streaming output)
4. User can view/present the generated Verifiable Presentation

## Requirements

- Xcode 15+
- iOS 17+
- ~2GB storage for model file

## Files

```
vc-llm/
├── LlamaDCQLService.swift      # Main service
├── LlamaDCQLGenerator.swift    # llama.cpp wrapper
├── LibLlama.swift              # llama.cpp bindings
├── VCRetriever.swift           # Semantic search
├── VPDCQLBridge.swift          # Rust vp-dcql wrapper
├── RustBridge.h                # Bridging header
└── Views/Main/FormView.swift   # Main UI

Frameworks/
└── llama.framework             # llama.cpp framework

RustLib/
├── libvp_dcql.a                # Rust static library
└── vp_dcql.h                   # C header

vc_pool/                        # Sample credentials
```

## Rust Integration

The app integrates the Rust `vp-dcql` library from `vc-dcql-bbs` for BBS-based Verifiable Presentation generation.

**Usage:**
```swift
let vp = try VPDCQLBridge.createPresentation(
    dcqlQuery: dcqlQuery,    // JSON string
    signedCredential: signedVC,
    challenge: challenge
)
```

**Note:** Requires physical device (aarch64-apple-ios). Simulator not yet supported.
