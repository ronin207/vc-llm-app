# VC-LLM Application Setup Guide

## Overview
This iOS application uses a fine-tuned Gemma 2B model to query Verifiable Credentials (VCs) using natural language and generate DCQL (Digital Credential Query Language) outputs. The app features:

- **RAG-based VC Selection**: Retrieval-Augmented Generation to find relevant VCs from a pool of 100 credentials
- **Fine-tuned DCQL Generation**: Using the Gemma-2-2b-it model trained on your dataset
- **Verifiable Presentation Flow**: QR code-based sharing between holder and verifier
- **Beautiful UI**: Modern, animated interface with dark/light mode support

## Architecture

### Two-Stage Processing
1. **Stage 1 (RAG)**: Natural language query → Top-K relevant VCs selection using embeddings
2. **Stage 2 (LLM)**: Selected VCs + Query → DCQL generation using fine-tuned Gemma model

### Key Components

- **VCEmbeddings.swift**: RAG system using NaturalLanguage framework for VC selection
- **MLXManager_Finetuned.swift**: Model loader and DCQL generation logic
- **ContentView_DCQL.swift**: Main UI with chat interface and presentation flow
- **vc_pool.json**: Database of 100 Verifiable Credentials

## Setup Instructions

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0+ deployment target
- macOS 14.0+ for development
- MLX framework installed

### Installation Steps

1. **Open the Project**
   ```bash
   cd /Users/takumiotsuka/Documents/Projects/xcode/vc-llm
   open vc-llm.xcodeproj
   ```

2. **Install Dependencies**
   The project uses Swift Package Manager for MLX dependencies:
   - MLXLMCommon
   - MLXLLM
   
   These should auto-resolve when you open the project.

3. **Model Configuration**
   The app will attempt to load the fine-tuned model from:
   - Local path: `gemma-2-2b-it-model/` (in app bundle)
   - Fallback: Downloads from HuggingFace `mlx-community/gemma-2-2b-it-4bit`

4. **Build and Run**
   - Select your target device/simulator
   - Press Cmd+R to build and run
   - The model will load automatically on first launch

## Usage Guide

### Basic Flow

1. **Launch the App**
   - The app starts in DCQL mode
   - Model loads automatically (shows progress)

2. **Query Your Credentials**
   Try these example queries:
   - "Show my driver's license"
   - "Display my passport expiration date"
   - "Show my health insurance but hide the insurance number"
   - "I need my university degree"
   - "Show my English proficiency certificates"

3. **View DCQL Output**
   - The app generates DCQL based on selected VCs
   - Click "View DCQL" to see the JSON structure
   - Selected credentials are listed

4. **Share Presentation**
   - Click "Present" to generate a QR code
   - The QR contains selected credentials and DCQL

5. **Verifier Mode**
   - Switch to Verifier mode from the top menu
   - Scan QR codes to receive presentations
   - Verify credential authenticity

## Features

### RAG-based VC Selection
- Uses semantic embeddings to find relevant credentials
- Selects top-3 most relevant VCs for each query
- Falls back gracefully if embeddings unavailable

### DCQL Generation Patterns
The fine-tuned model supports 4 patterns:
1. **Show specific attributes**: "Show my name from ID card"
2. **Hide specific attributes**: "Show passport but hide the number"
3. **Show and hide**: "Show name and DOB but hide address"
4. **Value constraints**: "Show license if it's for motorcycles"

### Presentation Sharing
- Generates QR codes containing:
  - Selected VCs
  - DCQL query
  - Timestamp
  - Verification metadata

### Verifier Capabilities
- Scan presentation QR codes
- Verify credential authenticity
- Display credential details
- Confirm DCQL compliance

## Model Details

### Fine-tuning Configuration
- Base model: `google/gemma-2-2b-it`
- LoRA configuration:
  - r: 16
  - alpha: 32
  - dropout: 0.05
- Training: 900 examples across 4 DCQL patterns

### Prompt Format
```
Given the following Verifiable Credentials and a natural language query, generate a DCQL query to retrieve the requested information.

Available Verifiable Credentials:
VC 1: {compact JSON}
VC 2: {compact JSON}
...

Natural Language Query: {user query}

Generate a DCQL query that selects the appropriate credentials and fields:
```

## Troubleshooting

### Model Loading Issues
- Ensure sufficient device storage (1.5GB required)
- Check internet connection for HuggingFace download
- Verify MLX framework is properly installed

### RAG/Embedding Issues
- NaturalLanguage framework requires iOS 17.0+
- English language model must be available
- Falls back to random selection if embeddings fail

### UI/Performance
- Runs best on devices with Neural Engine
- A15 Bionic or newer recommended
- May be slow on older devices

## Testing

### Test Queries
1. Basic attribute selection:
   - "Show my name from driver's license"
   - "Display my blood type"

2. Privacy-preserving:
   - "Show passport but hide the number"
   - "Display insurance without showing ID"

3. Complex queries:
   - "Show name and birthday but hide address from ID"
   - "Display all my English certificates"

4. Conditional:
   - "Show license if it includes motorcycles"
   - "Display degree if it's a Master's"

### Expected Behavior
- Response time: 2-5 seconds per query
- RAG selection: < 1 second
- DCQL generation: 1-4 seconds
- QR generation: instant

## Development Notes

### File Structure
```
vc-llm/
├── ContentView_DCQL.swift    # Main UI with DCQL support
├── VCEmbeddings.swift         # RAG system
├── MLXManager_Finetuned.swift # Model manager
├── vc_pool.json              # VC database
├── gemma-2-2b-it-model/      # Fine-tuned model
│   ├── adapter_config.json
│   ├── adapter_model.safetensors
│   └── tokenizer files...
└── Assets/
```

### Extending the App
- Add more VCs to `vc_pool.json`
- Retrain model with additional DCQL patterns
- Implement camera-based QR scanning
- Add credential verification logic
- Support multiple languages

## Known Limitations
- QR scanner is simulated (not using camera)
- Verifier mode is demonstration only
- No actual cryptographic verification
- English-only queries currently supported

## Support
For issues or questions about:
- Model training: Check `v2/README.md`
- Dataset format: See `v2/generate_dcql_dataset.py`
- MLX integration: Refer to `MLX_INTEGRATION_INSTRUCTIONS.md`

## Next Steps
1. Test with real device
2. Implement actual QR scanning
3. Add credential verification
4. Deploy model to device storage
5. Optimize for production use
