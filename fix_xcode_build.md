# Fix Xcode Build Errors

## Quick Fix Instructions

1. **In Xcode, remove the checkpoint folders from the project:**
   - In the Project Navigator (left sidebar), find `gemma-2-2b-it-model`
   - Right-click on each checkpoint folder (checkpoint-100, checkpoint-200, etc.)
   - Select "Delete" and choose "Remove Reference" (NOT "Move to Trash")
   - Keep only these files in the project:
     - adapter_config.json
     - adapter_model.safetensors
     - chat_template.jinja
     - special_tokens_map.json
     - tokenizer_config.json
     - tokenizer.json
     - training_args.bin

2. **Clean and rebuild:**
   - Product → Clean Build Folder (Shift+Cmd+K)
   - Product → Build (Cmd+B)

## Alternative: Exclude from Build

If you want to keep the checkpoints in the project for reference but not include them in the build:

1. Select your project in the navigator
2. Select your app target
3. Go to "Build Phases" tab
4. Expand "Copy Bundle Resources"
5. Find and remove all checkpoint folders from this list
6. Keep only the main model files

## Why This Happens

The checkpoint folders are training artifacts that contain intermediate model states during fine-tuning. Each checkpoint has the same file structure, causing Xcode to try copying duplicate files to the app bundle.

For runtime, you only need:
- The final adapter weights: `adapter_model.safetensors`
- The tokenizer files: `tokenizer.json`, `tokenizer_config.json`
- The configuration: `adapter_config.json`

The checkpoint folders are only useful if you want to resume training or analyze training progress.
