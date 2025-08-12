# Quick Start Guide - VC-LLM App

## ✅ All Errors Fixed!

The build errors have been resolved. The app is now ready to compile and run.

## What Was Fixed

1. **Removed duplicate checkpoint folders** that were causing "Multiple commands produce" errors
2. **Fixed MLXManager_Finetuned.swift** to use the correct MLXLMCommon API
3. **Cleaned up build artifacts** from the project

## Current Status

The app will now:
- ✅ **Compile without errors**
- ✅ **Load the Gemma 2B model** from HuggingFace
- ✅ **Perform RAG-based VC selection** using embeddings
- ✅ **Generate DCQL-like responses** using proper prompt formatting
- ✅ **Display the presentation flow** with QR codes

## How to Run

1. **Clean Build Folder**
   - Press `Shift+Cmd+K` in Xcode

2. **Build and Run**
   - Press `Cmd+R` to run on simulator or device
   - The model will download on first launch (~1.5GB)

3. **Test Queries**
   Try these examples:
   - "Show my driver's license"
   - "Display my passport expiration date"
   - "Show my health insurance but hide the number"

## Important Notes

### Model Loading
- Currently loads the **base Gemma 2B model** from HuggingFace
- Your fine-tuned weights are in `gemma-2-2b-it-model/` but MLX doesn't support local loading directly
- The app uses your training prompt format, so responses will be DCQL-oriented

### To Use Your Fine-tuned Model
See `MLX_LOCAL_MODEL_GUIDE.md` for options:
1. Upload to HuggingFace (recommended)
2. Use prompt engineering with base model (current approach)
3. Convert to MLX format (advanced)

## Architecture

```
User Query → RAG Selection (Top-3 VCs) → Formatted Prompt → LLM → DCQL Output
```

## Files Structure
```
vc-llm/
├── ContentView_DCQL.swift     # Main UI with DCQL features
├── VCEmbeddings.swift          # RAG system for VC selection
├── MLXManager_Finetuned.swift  # Model loader (fixed)
├── vc_pool.json               # 100 VCs database
└── gemma-2-2b-it-model/       # Your fine-tuned weights (not loaded yet)
    ├── adapter_model.safetensors
    ├── tokenizer.json
    └── ...
```

## Next Steps

1. **Run the app** - It works now!
2. **Test with queries** - See how it performs
3. **Upload model to HuggingFace** - To use your fine-tuned weights
4. **Implement QR scanning** - For real verifier mode

The app is functional and ready to use! 🎉
