import { readFileSync, existsSync } from 'fs'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))

interface LLM2Example {
  prompt: string
  completion: string
  metadata: {
    pattern: string
    query: string
    target_vc_index?: number
    constraint?: {
      attribute: string
      value: string
    }
  }
}

function inspectPattern(filepath: string, patternName: string, numSamples: number = 2) {
  console.log(`\n${'='.repeat(60)}`)
  console.log(`Pattern: ${patternName}`)
  console.log(`File: ${filepath}`)
  console.log('='.repeat(60))
  
  if (!existsSync(filepath)) {
    console.log('❌ File not found!')
    return
  }
  
  const content = readFileSync(filepath, 'utf-8')
  const lines = content.trim().split('\n').filter(line => line.length > 0)
  
  console.log(`Total examples: ${lines.length}`)
  
  for (let i = 0; i < Math.min(numSamples, lines.length); i++) {
    try {
      const example: LLM2Example = JSON.parse(lines[i])
      
      console.log(`\n--- Example ${i + 1} ---`)
      console.log(`Query: ${example.metadata.query}`)
      
      // Extract VCs from prompt
      const vcMatches = example.prompt.match(/VC \d+: .+/g) || []
      console.log(`Number of VCs: ${vcMatches.length}`)
      
      // Show first VC (truncated)
      if (vcMatches.length > 0) {
        const firstVC = vcMatches[0]
        if (firstVC.length > 100) {
          console.log(`First VC: ${firstVC.substring(0, 100)}...`)
        } else {
          console.log(`First VC: ${firstVC}`)
        }
      }
      
      // Parse and show DCQL structure
      const dcql = JSON.parse(example.completion)
      if (dcql.credentials) {
        for (const cred of dcql.credentials) {
          console.log(`\nDCQL Credential ID: ${cred.id || 'N/A'}`)
          console.log(`Claims: ${cred.claims ? cred.claims.length : 0}`)
          
          // Show claim paths
          if (cred.claims) {
            const claimsToShow = cred.claims.slice(0, 3)
            claimsToShow.forEach((claim: any) => {
              const path = claim.path ? claim.path.join(' → ') : 'N/A'
              if (claim.filter) {
                console.log(`  - ${path} (filtered: ${claim.filter.type} = ${claim.filter.value})`)
              } else {
                console.log(`  - ${path}`)
              }
            })
            
            if (cred.claims.length > 3) {
              console.log(`  ... and ${cred.claims.length - 3} more claims`)
            }
          }
        }
      }
      
      // Show constraint metadata for pattern 4
      if (example.metadata.constraint) {
        console.log(`\nConstraint: ${example.metadata.constraint.attribute} = ${example.metadata.constraint.value}`)
      }
      
    } catch (error) {
      console.log(`Error parsing example ${i + 1}: ${error}`)
    }
  }
}

function main() {
  const patterns: [string, string][] = [
    ['pattern1_show_attributes', 'Show specific attributes'],
    ['pattern2_hide_attributes', 'Hide specific attributes'],
    ['pattern3_show_and_hide', 'Show and hide attributes'],
    ['pattern4_value_constraints', 'Value constraints (e.g., Eiken grades)']
  ]
  
  console.log('📊 LLM2 Dataset Inspection')
  console.log('='.repeat(60))
  
  for (const split of ['train', 'test']) {
    console.log(`\n\n${split === 'train' ? '🚂 TRAINING' : '🧪 TEST'} DATA`)
    
    for (const [patternDir, patternDesc] of patterns) {
      const filepath = join(__dirname, 'llm2', split, patternDir, 'examples.jsonl')
      inspectPattern(filepath, patternDesc, split === 'test' ? 1 : 2)
    }
  }
  
  console.log('\n\n✅ Inspection complete!')
}

main()