#!/usr/bin/env python3
"""
Convert Fine-tuned Gemma Model to CoreML
This script converts your fine-tuned Gemma-2B model to CoreML format for iOS deployment.
"""

import torch
import coremltools as ct
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
import numpy as np
import os

def convert_gemma_to_coreml():
    """Convert fine-tuned Gemma model to CoreML format."""
    
    print("🔄 Loading base model and adapters...")
    
    # Load base model
    base_model_name = "google/gemma-2-2b-it"
    model = AutoModelForCausalLM.from_pretrained(
        base_model_name,
        torch_dtype=torch.float32,
        device_map="mps"
    )
    
    # Load tokenizer
    tokenizer = AutoTokenizer.from_pretrained(base_model_name)
    
    # Load LoRA adapters
    adapter_path = "./gemma-2-2b-it-model"
    if os.path.exists(adapter_path):
        print(f"📦 Loading adapters from {adapter_path}")
        model = PeftModel.from_pretrained(model, adapter_path)
        # Merge adapters with base model for deployment
        model = model.merge_and_unload()
        print("✅ Adapters merged with base model")
    else:
        print(f"⚠️  No adapters found at {adapter_path}, using base model")
    
    # Set model to evaluation mode
    model.eval()
    
    print("🔄 Creating traced model...")
    
    # Create example input
    max_length = 512  # Reduced for mobile deployment
    example_input = "Given the following Verifiable Credentials and a natural language query"
    inputs = tokenizer(
        example_input,
        return_tensors="pt",
        max_length=max_length,
        padding="max_length",
        truncation=True
    )
    
    # Trace the model
    class GemmaWrapper(torch.nn.Module):
        def __init__(self, model):
            super().__init__()
            self.model = model
            
        def forward(self, input_ids, attention_mask):
            outputs = self.model(
                input_ids=input_ids,
                attention_mask=attention_mask,
                use_cache=False
            )
            return outputs.logits
    
    wrapped_model = GemmaWrapper(model)
    wrapped_model.eval()
    
    # Trace model
    traced_model = torch.jit.trace(
        wrapped_model,
        (inputs["input_ids"], inputs["attention_mask"])
    )
    
    print("🔄 Converting to CoreML...")
    
    # Define input types for CoreML
    mlmodel_input_types = [
        ct.TensorType(
            name="input_ids",
            shape=(1, max_length),
            dtype=np.int32
        ),
        ct.TensorType(
            name="attention_mask", 
            shape=(1, max_length),
            dtype=np.int32
        )
    ]
    
    # Convert to CoreML
    mlmodel = ct.convert(
        traced_model,
        inputs=mlmodel_input_types,
        minimum_deployment_target=ct.target.iOS17,
        compute_units=ct.ComputeUnit.ALL,  # Use Neural Engine when available
        convert_to="mlprogram"  # Use ML Program format for better performance
    )
    
    # Save CoreML model
    output_path = "GemmaDCQL.mlpackage"
    mlmodel.save(output_path)
    print(f"✅ CoreML model saved to {output_path}")
    
    # Save tokenizer configuration
    tokenizer.save_pretrained("./tokenizer_files")
    print("✅ Tokenizer files saved to ./tokenizer_files")
    
    # Generate metadata
    metadata = {
        "model_type": "gemma-2b-dcql",
        "max_length": max_length,
        "vocab_size": tokenizer.vocab_size,
        "pad_token_id": tokenizer.pad_token_id,
        "eos_token_id": tokenizer.eos_token_id,
        "bos_token_id": tokenizer.bos_token_id
    }
    
    import json
    with open("model_metadata.json", "w") as f:
        json.dump(metadata, f, indent=2)
    print("✅ Metadata saved to model_metadata.json")
    
    print("\n🎉 Conversion complete!")
    print("\nNext steps:")
    print("1. Add GemmaDCQL.mlpackage to your Xcode project")
    print("2. Copy tokenizer_files to your app bundle")
    print("3. Update the app to use CoreML instead of MLX")
    
    return output_path

if __name__ == "__main__":
    # Check dependencies
    try:
        import coremltools
        import transformers
        import peft
    except ImportError as e:
        print("❌ Missing dependencies. Install with:")
        print("pip install torch transformers peft coremltools")
        exit(1)
    
    convert_gemma_to_coreml()
