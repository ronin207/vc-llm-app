#!/usr/bin/env python3
"""
Merge Gemma LoRA adapters, convert to MLX q4, and upload to Hugging Face.

Usage:
  python merge_and_upload.py \
    --base google/gemma-2-2b-it \
    --adapters ./gemma-2-2b-it/model \
    --out ./gemma-2-2b-it-merged \
    --mlx-out ./gemma-2-2b-it-dcql-mlx \
    --repo USER/gemma-2-2b-it-dcql-mlx \
    [--push]

Requires: torch, transformers, peft, huggingface_hub, accelerate, mlx-lm
Login first: huggingface-cli login
"""
import argparse
import os
import shutil
import subprocess
from pathlib import Path

import torch  # noqa: F401 - ensures torch is available
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import PeftModel
from huggingface_hub import HfApi


def run(cmd: list[str]):
    print("$", " ".join(cmd))
    subprocess.check_call(cmd)


def merge_lora(base_id: str, adapters_dir: str, out_dir: str):
    print("🔄 Merging LoRA adapters into base:", base_id)
    tok = AutoTokenizer.from_pretrained(base_id, use_fast=True)
    base = AutoModelForCausalLM.from_pretrained(base_id, torch_dtype="auto")
    peft_model = PeftModel.from_pretrained(base, adapters_dir)
    merged = peft_model.merge_and_unload()

    Path(out_dir).mkdir(parents=True, exist_ok=True)
    merged.save_pretrained(out_dir, safe_serialization=True)
    tok.save_pretrained(out_dir)
    print("✅ Merged model saved to", out_dir)


def convert_to_mlx(hf_path: str, mlx_path: str):
    print("🔁 Converting to MLX q4:", hf_path, "→", mlx_path)
    # Newer mlx-lm uses: `mlx_lm convert ... -q --q-bits 4`
    # Prefer module invocation to avoid PATH issues.
    try:
        run(["python", "-m", "mlx_lm", "convert", "--hf-path", hf_path, "--mlx-path", mlx_path, "-q", "--q-bits", "4"])
    except subprocess.CalledProcessError:
        # Fallback to executable form
        run(["mlx_lm", "convert", "--hf-path", hf_path, "--mlx-path", mlx_path, "-q", "--q-bits", "4"])

    # Copy chat template if present in adapters folder
    adapters_dir = Path("./gemma-2-2b-it/model")
    template = adapters_dir / "chat_template.jinja"
    if template.exists():
        shutil.copy(str(template), str(Path(mlx_path) / "chat_template.jinja"))
        print("📄 Copied chat_template.jinja into MLX folder")


def push_to_hf(local_dir: str, repo: str):
    print("☁️  Uploading to Hugging Face:", repo)
    api = HfApi()
    api.create_repo(repo_id=repo, repo_type="model", exist_ok=True)
    api.upload_folder(repo_id=repo, folder_path=local_dir)
    print("✅ Uploaded", local_dir, "to", repo)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--base", default="google/gemma-2-2b-it")
    p.add_argument("--adapters", default="./gemma-2-2b-it/model")
    p.add_argument("--out", default="./gemma-2-2b-it-merged")
    p.add_argument("--mlx-out", default="./gemma-2-2b-it-dcql-mlx")
    p.add_argument("--repo", required=True)
    p.add_argument("--push", action="store_true")
    args = p.parse_args()

    merge_lora(args.base, args.adapters, args.out)
    convert_to_mlx(args.out, args.mlx_out)

    if args.push:
        push_to_hf(args.mlx_out, args.repo)
        # Also update model_metadata.json with the repo (if present)
        meta_path = Path("model_metadata.json")
        if meta_path.exists():
            import json
            meta = json.loads(meta_path.read_text())
            meta["hf_repo"] = args.repo
            meta_path.write_text(json.dumps(meta, indent=2))
            print("📝 Updated model_metadata.json hf_repo →", args.repo)

    print("\nAll done. Set hf_repo in model_metadata.json to:", args.repo)


if __name__ == "__main__":
    main()
