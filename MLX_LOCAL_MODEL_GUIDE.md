# Loading Fine-tuned Models in MLX

## Current Limitation
The MLXLMCommon framework currently only supports loading models via HuggingFace model IDs, not local file paths.

## Solutions

### Option 1: Upload to HuggingFace (Recommended)
1. Create a HuggingFace account at https://huggingface.co
2. Upload your fine-tuned model:
   ```bash
   # Install huggingface-hub
   pip install huggingface-hub
   
   # Login to HuggingFace
   huggingface-cli login
   
   # Upload your model
   huggingface-cli upload your-username/gemma-2b-dcql-finetuned ./gemma-2-2b-it-model/
   ```
3. Update `MLXManager_Finetuned.swift`:
   ```swift
   private let huggingFaceModelID = "your-username/gemma-2b-dcql-finetuned"
   ```

### Option 2: Use Base Model + Custom Prompting
Since your fine-tuned model is based on `gemma-2-2b-it`, you can:
1. Load the base model from HuggingFace
2. Use carefully crafted prompts that match your training format
3. The current implementation does this as a fallback

### Option 3: Convert to MLX Format (Advanced)
You can convert your model to MLX format and load it differently:
```python
from mlx_lm import convert
convert("./gemma-2-2b-it-model", mlx_path="./mlx_model")
```

Then use MLX's lower-level APIs to load the model directly.

## Current Implementation
The app currently:
1. Loads the base `gemma-2-2b-it` model from HuggingFace
2. Uses your training prompt format for DCQL generation
3. The RAG system still works to select relevant VCs

## Testing the App
Even without the fine-tuned weights loaded, the app will:
- ✅ Perform RAG-based VC selection
- ✅ Format prompts correctly
- ✅ Generate responses (though less specialized than fine-tuned)
- ✅ Display DCQL-like outputs
- ✅ Handle presentation flow

## Next Steps
For production use with your fine-tuned model:
1. Upload to HuggingFace (easiest)
2. Or investigate MLX's model conversion tools
3. Or use the base model with prompt engineering
