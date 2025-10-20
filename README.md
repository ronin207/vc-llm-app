# VC-LLM Mobile App

Verifiable Credential retrieval using CoreML-based semantic embeddings.

## Setup

### 1. Generate CoreML Model

The CoreML model is not included in the repository due to its size. Generate it using:

```bash
cd ../filtering
../venv/bin/python convert_pytorch_to_coreml_direct.py
```

This will create:
- `vc-llm/Resources/Models/SentenceTransformer.mlpackage/` (CoreML model)
- `vc-llm/Resources/Models/tokenizer/` (tokenizer files)

### 2. Build the App

Open `vc-llm.xcodeproj` in Xcode and build.

## Architecture

### Embedding System

- **EmbeddingGenerator Protocol**: Abstract interface for embedding generation
- **CoreMLEmbeddingGenerator**: CoreML-based implementation for native iOS inference
- **VCRetriever**: Main retrieval class using cosine similarity

### Model

- **Model**: `sentence-transformers/all-MiniLM-L6-v2`
- **Embedding Dimension**: 384
- **Expected Accuracy**: 80.15% (verified in benchmarks)

## Benchmark

Run the benchmark to verify accuracy:

```bash
swift run_benchmark_coreml.swift
```

**Expected Results**:
- Accuracy@3: ~80%
- Recall@3: ~0.86
- Precision@3: ~0.43

See benchmark results for detailed performance metrics.

## Files

### Core
- `vc-llm/VCRetriever.swift` - Main retrieval logic
- `vc-llm/Embeddings/CoreMLEmbeddingGenerator.swift` - CoreML-based embeddings
- `vc-llm/Embeddings/WordPieceTokenizer.swift` - WordPiece tokenization
- `vc-llm/Embeddings/VCTextPreparation.swift` - VC text preprocessing
- `vc-llm/Models/VerifiableCredential.swift` - VC data model

### Benchmark
- `vc-llm/Benchmark/VCRetrieverBenchmark.swift` - Swift benchmark implementation
- `run_benchmark_coreml.swift` - Benchmark runner script

### Resources
- `vc-llm/Resources/Models/SentenceTransformer.mlpackage/` - CoreML model (generated)
- `vc-llm/Resources/Models/tokenizer/` - Tokenizer files (generated)
- `vc-llm/vc_pool.json` - VC pool data

## Cache

Embeddings are cached in:
```
~/Library/Caches/coreml_embeddings_cache.json
```

This significantly speeds up subsequent runs.

## Testing

VCRetriever basic functionality tests are available in `vc-llmTests/VCRetrieverBasicTests.swift`.

### Running Tests

**Via Xcode:**
1. Open `vc-llm.xcodeproj` in Xcode
2. Press `Cmd+U` or select Product → Test
3. View test results in the Test Navigator (Cmd+6)

**Via Command Line:**
```bash
xcodebuild test -project vc-llm.xcodeproj -scheme vc-llm \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Test Coverage

The test suite verifies:
- VCRetriever initialization and VC pool loading
- Empty results when pool is not prepared
- ID-based retrieval functionality
- VC lookup by ID
- Invalid ID handling

## Performance

- **VC Pool Preparation**: Native CoreML inference (fast, on-device)
- **Query Embedding**: Native CoreML inference
- **Total Retrieval**: Fast on-device semantic search

## Dependencies

- Xcode 15+
- iOS 17+
- Python 3.12+ (for model conversion only)

## Notes

- CoreML provides native on-device inference with optimal performance
- Model files are excluded from git (generate locally)
- All inference runs natively on iOS without external dependencies
