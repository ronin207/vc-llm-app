import { DcqlQuery } from 'dcql'
import { readFileSync, existsSync, readdirSync } from 'fs'
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

interface ValidationStats {
  total: number
  passed: number
  failed: number
  errors: string[]
  warnings: string[]
}

class LLM2DatasetValidator {
  private stats: Record<string, ValidationStats> = {}
  
  constructor() {
    this.initializeStats()
  }
  
  private initializeStats() {
    const patterns = [
      'pattern1_show_attributes',
      'pattern2_hide_attributes',
      'pattern3_show_and_hide',
      'pattern4_value_constraints'
    ]
    
    patterns.forEach(pattern => {
      this.stats[pattern] = {
        total: 0,
        passed: 0,
        failed: 0,
        errors: [],
        warnings: []
      }
    })
  }
  
  private validateDCQLStructure(dcql: any, pattern: string, lineNum: number): boolean {
    try {
      // Parse and validate using dcql package
      const parsedQuery = DcqlQuery.parse(dcql)
      DcqlQuery.validate(parsedQuery)
      
      // Additional validation for our specific patterns
      if (!dcql.credentials || !Array.isArray(dcql.credentials) || dcql.credentials.length === 0) {
        this.stats[pattern].errors.push(`Line ${lineNum}: DCQL must have credentials array`)
        return false
      }
      
      // Pattern 4 specific: check for value filters
      if (pattern === 'pattern4_value_constraints') {
        let hasFilter = false
        for (const cred of dcql.credentials) {
          if (cred.claims && Array.isArray(cred.claims)) {
            for (const claim of cred.claims) {
              if (claim.filter && claim.filter.type === 'value') {
                hasFilter = true
                break
              }
            }
          }
        }
        
        if (!hasFilter) {
          this.stats[pattern].errors.push(`Line ${lineNum}: Pattern 4 DCQL must have value filters`)
          return false
        }
      }
      
      return true
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error)
      this.stats[pattern].errors.push(`Line ${lineNum}: DCQL validation error - ${errorMessage}`)
      return false
    }
  }
  
  private validateVCFormat(prompt: string, pattern: string, lineNum: number): boolean {
    // Extract VC lines from the prompt
    const vcLines = prompt.split('\n').filter(line => line.trim().startsWith('VC '))
    
    if (vcLines.length === 0) {
      this.stats[pattern].errors.push(`Line ${lineNum}: No VCs found in prompt`)
      return false
    }
    
    // Validate each VC line  
    for (const vcLine of vcLines) {
      const vcJsonStr = vcLine.trim().replace(/^VC \d+: /, '')
      try {
        // Parse the VC JSON
        const vc = JSON.parse(vcJsonStr)
        if (!vc.id || !vc['@context'] || !vc.type || !vc.credentialSubject) {
          this.stats[pattern].errors.push(`Line ${lineNum}: Invalid VC structure`)
          return false
        }
      } catch (e) {
        this.stats[pattern].errors.push(`Line ${lineNum}: VC is not valid JSON`)
        return false
      }
    }
    
    return true
  }
  
  private validatePatternSpecifics(example: LLM2Example, pattern: string, lineNum: number): boolean {
    const query = example.metadata.query
    
    switch (pattern) {
      case 'pattern1_show_attributes':
        const showKeywords = ['show', 'display', 'present', 'retrieve', 'get', 'view', 'extract']
        if (!showKeywords.some(kw => query.toLowerCase().includes(kw))) {
          this.stats[pattern].warnings.push(`Line ${lineNum}: Pattern 1 query lacks show keywords`)
        }
        break
        
      case 'pattern2_hide_attributes':
        const hideKeywords = ['hide', 'without', 'excluding', 'private', 'conceal', 'mask', 'redact']
        if (!hideKeywords.some(kw => query.toLowerCase().includes(kw))) {
          this.stats[pattern].warnings.push(`Line ${lineNum}: Pattern 2 query lacks hide keywords`)
        }
        break
        
      case 'pattern3_show_and_hide':
        const hasShow = ['show', 'display', 'present'].some(kw => query.toLowerCase().includes(kw))
        const hasHide = ['hide', 'without', 'excluding'].some(kw => query.toLowerCase().includes(kw))
        if (!hasShow || !hasHide) {
          this.stats[pattern].warnings.push(`Line ${lineNum}: Pattern 3 query lacks both show and hide`)
        }
        break
        
      case 'pattern4_value_constraints':
        const valueKeywords = ['where', 'equal', 'matches', 'is', 'grade', 'value', 'only if']
        if (!valueKeywords.some(kw => query.toLowerCase().includes(kw))) {
          this.stats[pattern].warnings.push(`Line ${lineNum}: Pattern 4 query lacks value constraint keywords`)
        }
        break
    }
    
    return true
  }
  
  private validateExample(line: string, pattern: string, lineNum: number): boolean {
    try {
      const example: LLM2Example = JSON.parse(line)
      
      // Check required fields
      if (!example.prompt || !example.completion || !example.metadata) {
        this.stats[pattern].errors.push(`Line ${lineNum}: Missing required fields`)
        return false
      }
      
      // Validate prompt contains VCs
      if (!this.validateVCFormat(example.prompt, pattern, lineNum)) {
        return false
      }
      
      // Validate completion is valid DCQL
      let dcql
      try {
        dcql = JSON.parse(example.completion)
      } catch (e) {
        this.stats[pattern].errors.push(`Line ${lineNum}: Completion is not valid JSON`)
        return false
      }
      
      if (!this.validateDCQLStructure(dcql, pattern, lineNum)) {
        return false
      }
      
      // Validate metadata
      if (example.metadata.pattern !== pattern) {
        this.stats[pattern].errors.push(`Line ${lineNum}: Pattern mismatch in metadata`)
        return false
      }
      
      if (!example.metadata.query) {
        this.stats[pattern].errors.push(`Line ${lineNum}: Missing query in metadata`)
        return false
      }
      
      // Pattern-specific validation
      this.validatePatternSpecifics(example, pattern, lineNum)
      
      return true
      
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error)
      this.stats[pattern].errors.push(`Line ${lineNum}: ${errorMessage}`)
      return false
    }
  }
  
  private validateFile(filepath: string, pattern: string): { total: number, passed: number, failed: number } {
    if (!existsSync(filepath)) {
      this.stats[pattern].errors.push(`File not found: ${filepath}`)
      return { total: 0, passed: 0, failed: 0 }
    }
    
    const content = readFileSync(filepath, 'utf-8')
    const lines = content.trim().split('\n').filter(line => line.length > 0)
    
    let fileTotal = 0
    let filePassed = 0
    let fileFailed = 0
    
    lines.forEach((line, index) => {
      const lineNum = index + 1
      fileTotal++
      this.stats[pattern].total++
      
      if (this.validateExample(line, pattern, lineNum)) {
        filePassed++
        this.stats[pattern].passed++
      } else {
        fileFailed++
        this.stats[pattern].failed++
      }
    })
    
    return { total: fileTotal, passed: filePassed, failed: fileFailed }
  }
  
  public validate() {
    console.log('🔍 Validating LLM2 Dataset with DCQL package...\n')
    
    const patterns = [
      'pattern1_show_attributes',
      'pattern2_hide_attributes',
      'pattern3_show_and_hide',
      'pattern4_value_constraints'
    ]
    
    let totalStats = { total: 0, passed: 0, failed: 0 }
    
    for (const split of ['train', 'test']) {
      console.log(`\n📂 Validating ${split.toUpperCase()} data...`)
      
      for (const pattern of patterns) {
        const filepath = join(__dirname, 'llm2', split, pattern, 'examples.jsonl')
        const fileStats = this.validateFile(filepath, pattern)
        
        if (fileStats.total > 0) {
          const passRate = (fileStats.passed / fileStats.total) * 100
          const status = fileStats.failed === 0 ? '✅' : fileStats.failed < fileStats.total * 0.1 ? '⚠️' : '❌'
          
          console.log(`  ${status} ${pattern}: ${fileStats.passed}/${fileStats.total} passed (${passRate.toFixed(1)}%)`)
          
          // Show first few errors
          const patternStats = this.stats[pattern]
          const recentErrors = patternStats.errors.slice(-3)
          if (recentErrors.length > 0) {
            console.log(`     Errors (${patternStats.errors.length} total):`)
            recentErrors.forEach(error => {
              console.log(`       - ${error}`)
            })
            if (patternStats.errors.length > 3) {
              console.log(`       ... and ${patternStats.errors.length - 3} more`)
            }
          }
          
          // Show warnings
          const recentWarnings = patternStats.warnings.slice(-2)
          if (recentWarnings.length > 0) {
            console.log(`     Warnings (${patternStats.warnings.length} total):`)
            recentWarnings.forEach(warning => {
              console.log(`       - ${warning}`)
            })
            if (patternStats.warnings.length > 2) {
              console.log(`       ... and ${patternStats.warnings.length - 2} more`)
            }
          }
        }
      }
    }
    
    // Calculate totals
    for (const pattern of patterns) {
      totalStats.total += this.stats[pattern].total
      totalStats.passed += this.stats[pattern].passed
      totalStats.failed += this.stats[pattern].failed
    }
    
    // Final summary
    console.log('\n' + '='.repeat(50))
    console.log('📊 VALIDATION SUMMARY')
    console.log('='.repeat(50))
    console.log(`Total examples: ${totalStats.total}`)
    console.log(`Passed: ${totalStats.passed} (${(totalStats.passed / totalStats.total * 100).toFixed(1)}%)`)
    console.log(`Failed: ${totalStats.failed} (${(totalStats.failed / totalStats.total * 100).toFixed(1)}%)`)
    
    const totalErrors = Object.values(this.stats).reduce((sum, s) => sum + s.errors.length, 0)
    const totalWarnings = Object.values(this.stats).reduce((sum, s) => sum + s.warnings.length, 0)
    
    console.log(`\nTotal errors: ${totalErrors}`)
    console.log(`Total warnings: ${totalWarnings}`)
    
    if (totalErrors === 0) {
      console.log('\n✅ Dataset validation PASSED!')
    } else {
      console.log('\n❌ Dataset validation FAILED!')
      console.log('\nError breakdown by pattern:')
      for (const [pattern, stats] of Object.entries(this.stats)) {
        if (stats.errors.length > 0) {
          console.log(`  ${pattern}: ${stats.errors.length} errors`)
        }
      }
    }
    
    process.exit(totalErrors === 0 ? 0 : 1)
  }
}

// Run validation
const validator = new LLM2DatasetValidator()
validator.validate()