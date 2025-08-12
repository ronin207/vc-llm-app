# VC-LLM v2 Dataset

This dataset is designed for the two-stage VC-LLM architecture described in `/docs/ARCHITECTURE.md`.

## Architecture Overview

The system consists of two LLMs:
- **LLM1**: Selects relevant VCs from a pool of ~100 VCs based on natural language query (RAG-based approach)
- **LLM2**: Converts selected VCs into DCQL (Decentralized Credential Query Language)

## Dataset Structure

```
v2/
├── llm1/                    # LLM1 Dataset: VC Selection (RAG-based)
│   ├── vcs/                # VC Pool
│   │   └── vc_pool.json    # 100 Verifiable Credentials
│   ├── train/              # Training data
│   │   └── vc_selection_train.json  # Query → VC ID pairs
│   └── test/               # Test data
│       └── vc_selection_test.json   # Query → VC ID pairs
└── llm2/                    # LLM2 Dataset: DCQL Generation
    ├── train/              # Training data
    │   └── dcql_generation_train.json
    └── test/               # Test data
        └── dcql_generation_test.json
```

## LLM1 Dataset Format (RAG-based)

The LLM1 uses a RAG (Retrieval-Augmented Generation) approach. The VC pool is stored separately, and the training data only contains query-result pairs.

**VC Pool** (`llm1/vcs/vc_pool.json`):
- Contains 100 Verifiable Credentials covering various categories
- Each VC has a unique ID (vc-001 to vc-100)

**Training/Test Data Format**:
```json
{
  "query": "私の運転免許証を見せてください",
  "selected_vc_ids": ["vc-003"]
}
```

## LLM2 Dataset Format

Input:
- `natural_language`: Query in natural language
- `selected_vcs`: Array of 1-3 Verifiable Credentials (selected by LLM1)

Output:
- DCQL query object with credentials and claims

Example:
```json
{
  "input": {
    "natural_language": "運転免許証の名前と有効期限を確認したい",
    "selected_vcs": [/* VC objects */]
  },
  "output": {
    "credentials": [
      {
        "id": "mobile_drivers_license",
        "format": "ldp_vc",
        "meta": {
          "type_values": [["...VerifiableCredential", "...MobileDriverLicenseCredential"]]
        },
        "claims": [
          {"path": ["credentialSubject", "fullName"]},
          {"path": ["credentialSubject", "validUntil"]}
        ]
      }
    ]
  }
}
```

## VC Categories

The VC pool includes the following categories:
- **Personal ID**: National ID, Health Insurance, Driver's License, Passport
- **Medical**: Blood Type, Vaccination, Health Check
- **Education**: University Degree, Academic Transcript, Student ID
- **Professional**: Various certifications (IT, Language, etc.)
- **Employment**: Employee ID, Professional licenses
- **Lifestyle**: Gym membership, Marathon completion
- **Financial**: Annual income, Tax payment, Credit score
- **Travel**: Travel history, Hotel stays
- **Public Information**: Population data, University accreditation
- **Others**: 75+ additional credential types

## Dataset Statistics

- **LLM1**:
  - VC Pool: 100 VCs (all in English)
  - Training samples: 30
  - Test samples: 10
  
- **LLM2**:
  - Training samples: 900 (in dcql_training_900.jsonl)
  - Test samples: 5
  - All natural language queries are in English

## Usage

1. **LLM1 (RAG-based)**:
   - Load the VC pool into a vector database
   - Use embeddings to find relevant VCs based on queries
   - Fine-tune to improve selection accuracy

2. **LLM2 (Fine-tuning)**:
   - Train on VC → DCQL conversion
   - Handles both single credentials and credential_sets

3. **Pipeline**: Natural Language → LLM1 (RAG) → Relevant VCs → LLM2 → DCQL