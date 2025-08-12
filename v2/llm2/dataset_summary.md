# LLM2 Dataset Summary

## Overview
This dataset is designed for fine-tuning LLM2 to convert natural language queries and selected VCs into DCQL (Decentralized Credential Query Language).

## Dataset Statistics
- **Training Examples**: 900
  - Pattern 1 (Show Attributes): 202 examples
  - Pattern 2 (Hide Attributes): 202 examples
  - Pattern 3 (Show and Hide): 202 examples
  - Pattern 4 (Value Constraints): 294 examples

- **Test Examples**: 100
  - Each pattern: 25 examples

## Key Features

### 1. Compact VC Format
All VCs are formatted as single-line JSON to reduce context size while maintaining readability:
```
VC 1: {"id":"vc-001","@context":["https://www.w3.org/ns/credentials/v2"],"type":["VerifiableCredential","NationalIDCredential"],...}
```

### 2. Four Query Patterns

#### Pattern 1: Show Specific Attributes
- Queries request specific attributes to be shown
- Example: "Show me nationalId and fullName from my NationalID"

#### Pattern 2: Hide Specific Attributes  
- Queries request all attributes except specified ones
- Example: "Show my PassportCredential but hide passportNumber"

#### Pattern 3: Show and Hide Attributes
- Queries specify both attributes to show and hide
- Example: "Show only fullName from my DriverLicense and hide licenseNumber and dateOfBirth"

#### Pattern 4: Value Constraints
- Queries filter credentials based on specific values
- Example: "Show my Eiken certificate but only if it's Grade 1"
- Includes special handling for Eiken grades and other value-based filtering

### 3. Diverse Query Templates
- 15+ variations for each pattern type
- Natural language variations to improve model robustness
- English language queries throughout

### 4. Realistic Scenarios
- Each example includes 3-6 VCs
- Target VC is randomly positioned
- Mix of related and unrelated credentials

## File Organization
```
llm2/
├── train/
│   ├── pattern1_show_attributes/examples.jsonl
│   ├── pattern2_hide_attributes/examples.jsonl
│   ├── pattern3_show_and_hide/examples.jsonl
│   └── pattern4_value_constraints/examples.jsonl
└── test/
    ├── pattern1_show_attributes/examples.jsonl
    ├── pattern2_hide_attributes/examples.jsonl
    ├── pattern3_show_and_hide/examples.jsonl
    └── pattern4_value_constraints/examples.jsonl
```

## JSONL Format
Each line contains:
```json
{
  "prompt": "Given the following Verifiable Credentials...",
  "completion": "{\n  \"credentials\": [...]\n}",
  "metadata": {
    "pattern": "pattern1_show_attributes",
    "query": "Show me fullName from my NationalID",
    "target_vc_index": 2
  }
}
```

## Usage
These files are ready for fine-tuning with the scripts in `/wip/watanabe/dcql-finetuning/`