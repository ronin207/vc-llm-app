# CoreML Setup Guide for VC-LLM

## Why CoreML?

CoreML is Apple's framework for on-device machine learning, offering:
- ✅ **Local model loading** - No need for HuggingFace
- ✅ **Neural Engine support** - Optimized for Apple Silicon
- ✅ **Better iOS integration** - Native Apple framework
- ✅ **Your fine-tuned weights** - Use your actual trained model

## Setup Instructions

### Step 1: Install Python Dependencies

```bash
# Create a virtual environment (recommended)
python3 -m venv venv
source venv/bin/activate

# Install required packages
pip install torch transformers peft coremltools accelerate
```

### Step 2: Convert Your Model to CoreML

```bash
cd /Users/takumiotsuka/Documents/Projects/xcode/vc-llm
python3 convert_to_coreml.py
```

This will:
1. Load your fine-tuned model from `gemma-2-2b-it-model/`
2. Merge the LoRA adapters with the base model
3. Convert to CoreML format
4. Output `GemmaDCQL.mlpackage`

Expected output:
```
🔄 Loading base model and adapters...
📦 Loading adapters from ./gemma-2-2b-it-model
✅ Adapters merged with base model
🔄 Creating traced model...
🔄 Converting to CoreML...
✅ CoreML model saved to GemmaDCQL.mlpackage
✅ Tokenizer files saved to ./tokenizer_files
✅ Metadata saved to model_metadata.json
🎉 Conversion complete!
```

### Step 3: Add CoreML Model to Xcode

1. **In Finder**, locate `GemmaDCQL.mlpackage` in your project folder
2. **Drag and drop** it into Xcode's project navigator
3. **When prompted**:
   - ✅ Check "Copy items if needed"
   - ✅ Check your app target
   - Click "Finish"

### Step 4: Add Tokenizer Files

1. **In Finder**, locate the `tokenizer_files` folder
2. **Drag the entire folder** into Xcode
3. **When prompted**:
   - ✅ Check "Create folder references"
   - ✅ Check your app target

### Step 5: Update App Configuration

The app is already configured to use CoreML! The line in `ContentView_DCQL.swift`:
```swift
@StateObject private var modelManager = CoreMLManager()
```

### Step 6: Build and Run

1. **Clean Build Folder**: `Shift+Cmd+K`
2. **Build and Run**: `Cmd+R`

## Model Size Optimization

The full Gemma-2B model might be large for mobile. Consider these optimizations:

### Option 1: Quantization (Recommended)
```python
# In convert_to_coreml.py, add:
mlmodel = ct.convert(
    traced_model,
    inputs=mlmodel_input_types,
    minimum_deployment_target=ct.target.iOS17,
    compute_units=ct.ComputeUnit.ALL,
    compute_precision=ct.precision.FLOAT16,  # Use 16-bit precision
    convert_to="mlprogram"
)
```

### Option 2: Reduce Sequence Length
```python
max_length = 256  # Instead of 512
```

### Option 3: Model Pruning
Use CoreML's pruning tools to reduce model size further.

## Troubleshooting

### Issue: "Module 'coremltools' not found"
```bash
pip install coremltools
```

### Issue: "Model too large for device"
- Use quantization (Option 1 above)
- Reduce max sequence length
- Consider using a smaller base model

### Issue: "Tokenizer not loading correctly"
- Ensure tokenizer_files folder is added as "folder reference" (blue folder icon)
- Check that all .json files are included

### Issue: "Conversion fails with memory error"
```bash
# Use CPU-only conversion
export PYTORCH_ENABLE_MPS_FALLBACK=1
python3 convert_to_coreml.py
```

## Performance Tips

1. **Use Neural Engine**: The app is configured to use `ComputeUnit.ALL` which includes Neural Engine
2. **Batch Processing**: Process multiple queries together when possible
3. **Cache Models**: The model is loaded once and cached
4. **Optimize Context**: Keep prompts concise for faster inference

## Alternative: Simplified Approach

If conversion is complex, you can use a hybrid approach:
1. Use CoreML for embeddings (RAG)
2. Use MLX for generation
3. This gives you fast VC selection with cloud-based generation

## Next Steps

After successful setup:
1. ✅ Test with example queries
2. ✅ Monitor performance on device
3. ✅ Fine-tune max_length for your use case
4. ✅ Consider implementing token streaming for better UX

## Benefits Over MLX

| Feature | CoreML | MLX |
|---------|--------|-----|
| Local Model Loading | ✅ Yes | ❌ HuggingFace only |
| Fine-tuned Weights | ✅ Your model | ❌ Base model |
| Neural Engine | ✅ Full support | ⚠️ Limited |
| Model Size | ✅ Can optimize | ❌ Fixed |
| iOS Integration | ✅ Native | ⚠️ Third-party |

## Support

If you encounter issues:
1. Check Xcode console for detailed error messages
2. Verify model files are in the app bundle
3. Ensure iOS 17.0+ deployment target
4. Test on a real device for best performance
