//
//  VCEmbeddings.swift
//  vc-llm
//
//  Created by Assistant on 2025/07/28.
//

import Foundation
import NaturalLanguage
import SwiftUI
import Combine

class VCEmbeddings: ObservableObject {
    // Required publisher to satisfy Combine.ObservableObject when no @Published properties
    let objectWillChange = ObservableObjectPublisher()
    
    private var vcPool: [VerifiableCredential] = []
    private var vcEmbeddings: [String: [Double]] = [:]
    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)
    
    // Inverted index for dynamic lexical ranking
    private var vcTokenFrequencies: [String: [String: Int]] = [:]   // vcID -> term -> count
    private var vcTokenSets: [String: Set<String>] = [:]            // vcID -> tokens set
    private var documentFrequency: [String: Int] = [:]              // term -> doc freq
    private var idfWeights: [String: Double] = [:]                  // term -> idf
    private var numDocuments: Int = 0
    
    struct VerifiableCredential: Codable, Identifiable {
        let id: String
        let context: [String]
        let type: [String]
        let issuer: IssuerInfo
        let credentialSubject: [String: AnyCodable]
        
        enum CodingKeys: String, CodingKey {
            case id
            case context = "@context"
            case type
            case issuer
            case credentialSubject
        }

        func toSearchableText() -> String {
            var text = type.joined(separator: " ")
            
            // Add issuer name
            text += " " + issuer.name
            
            // Add credential subject fields
            for (key, value) in credentialSubject {
                text += " \(key) \(value.description)"
            }
            
            return text
        }
        
        // Convert to compact JSON string for prompt
        func toCompactJSON() -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = []
            if let data = try? encoder.encode(self),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            return "{}"
        }
    }
    
    struct IssuerInfo: Codable {
        let id: String
        let name: String
    }

    struct AnyCodable: Codable {
        let value: Any
        
        init(_ value: Any) {
            self.value = value
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            
            if let intVal = try? container.decode(Int.self) {
                value = intVal
            } else if let doubleVal = try? container.decode(Double.self) {
                value = doubleVal
            } else if let boolVal = try? container.decode(Bool.self) {
                value = boolVal
            } else if let stringVal = try? container.decode(String.self) {
                value = stringVal
            } else if let arrayVal = try? container.decode([AnyCodable].self) {
                value = arrayVal.map { $0.value }
            } else if let dictVal = try? container.decode([String: AnyCodable].self) {
                value = dictVal.mapValues { $0.value }
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            
            if let intVal = value as? Int {
                try container.encode(intVal)
            } else if let doubleVal = value as? Double {
                try container.encode(doubleVal)
            } else if let boolVal = value as? Bool {
                try container.encode(boolVal)
            } else if let stringVal = value as? String {
                try container.encode(stringVal)
            } else if let arrayVal = value as? [Any] {
                let codableArray = arrayVal.map { AnyCodable($0) }
                try container.encode(codableArray)
            } else if let dictVal = value as? [String: Any] {
                let codableDict = dictVal.mapValues { AnyCodable($0) }
                try container.encode(codableDict)
            } else {
                throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Cannot encode value"))
            }
        }
        
        var description: String {
            if let stringVal = value as? String {
                return stringVal
            } else if let arrayVal = value as? [Any] {
                return arrayVal.map { "\($0)" }.joined(separator: " ")
            } else if let dictVal = value as? [String: Any] {
                return dictVal.map { "\($0.key): \($0.value)" }.joined(separator: " ")
            } else {
                return "\(value)"
            }
        }
    }
    
    init() {
        loadVCPool()
        generateEmbeddings()
        buildLexicalIndex()
    }
    
    private func loadVCPool() {
        guard let url = Bundle.main.url(forResource: "vc_pool", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Failed to load vc_pool.json")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            vcPool = try decoder.decode([VerifiableCredential].self, from: data)
            print("Loaded \(vcPool.count) VCs from pool")
        } catch {
            print("Failed to decode VC pool: \(error)")
        }
    }
    
    private func generateEmbeddings() {
        guard let embedding = embedding else {
            print("Embedding model not available")
            return
        }
        
        for vc in vcPool {
            let text = vc.toSearchableText()
            if let vector = embedding.vector(for: text) {
                vcEmbeddings[vc.id] = vector
            }
        }
        print("Generated embeddings for \(vcEmbeddings.count) VCs")
    }
    
    private func buildLexicalIndex() {
        vcTokenFrequencies.removeAll()
        vcTokenSets.removeAll()
        documentFrequency.removeAll()
        numDocuments = vcPool.count
        
        for vc in vcPool {
            let text = vc.toSearchableText().lowercased()
            let tokens = tokenize(text)
            vcTokenSets[vc.id] = tokens
            var freq: [String: Int] = [:]
            for t in tokens { freq[t, default: 0] += 1 }
            vcTokenFrequencies[vc.id] = freq
            for term in Set(tokens) { documentFrequency[term, default: 0] += 1 }
        }
        // Compute IDF with smoothing
        idfWeights = documentFrequency.mapValues { df in
            let n = max(1, numDocuments)
            let d = max(1, df)
            return log(Double(n + 1) / Double(d + 1)) + 1.0
        }
        print("Built lexical index for \(numDocuments) VCs, vocab=\(idfWeights.count)")
    }
    
    // RAG function to find context-aware relevant VCs
    // Uses a hybrid score: semantic (embeddings) + lexical overlap (dynamic tokens)
    func findRelevantVCs(query: String, topK: Int = 3) -> [VerifiableCredential] {
        let queryLower = query.lowercased()
        let queryTokens = tokenize(queryLower)
        let queryTF = termFrequency(queryTokens)
        
        var queryVector: [Double]? = nil
        if let embedding = embedding {
            queryVector = embedding.vector(for: query)
        }
        
        var scored: [(vc: VerifiableCredential, score: Double)] = []
        
        for vc in vcPool {
            // 1) Semantic similarity if available
            var semantic: Double = 0
            if let qv = queryVector, let vv = vcEmbeddings[vc.id] {
                semantic = cosineSimilarity(qv, vv) // [0,1]
            }
            
            // 2) Lexical overlap on dynamic tokens
            let vcTokens = vcTokenSets[vc.id] ?? tokenize(vc.toSearchableText().lowercased())
            let lexical = jaccardSimilarity(queryTokens, vcTokens) // [0,1]
            
            // 2b) TF-IDF cosine for sharper term matching
            let tfidf = tfidfCosine(queryTF: queryTF, docID: vc.id)
            
            // 3) Lightweight type focus boost (dynamic, no hardcoding)
            let typeTokens = tokenize(vc.type.joined(separator: " ").lowercased())
            let typeMatch = jaccardSimilarity(queryTokens, typeTokens) // [0,1]
            
            // Hybrid score
            // Favor semantic, but let lexical/type sharpen focus
            let score = 0.50 * semantic + 0.30 * tfidf + 0.15 * lexical + 0.05 * typeMatch
            scored.append((vc, score))
        }
        
        // Aggregate by credential type and pick best matching type cluster when confident
        var typeScores: [String: Double] = [:]
        for item in scored.prefix(20) { // consider top 20 to compute type cluster
            let typeKey = item.vc.type.last ?? item.vc.type.joined(separator: ":")
            let typeTokens = tokenize(typeKey.lowercased())
            let tm = jaccardSimilarity(queryTokens, typeTokens)
            typeScores[typeKey, default: 0] += tm
        }
        let sortedTypes = typeScores.sorted { $0.value > $1.value }
        
        // Sort by score desc overall
        scored.sort { $0.score > $1.score }
        let maxK = max(topK, 3)
        guard let best = scored.first?.score, best > 0 else {
            return Array(vcPool.prefix(topK))
        }
        
        // If there is a clearly best type, gate to that type only
        if let bestType = sortedTypes.first?.key {
            let bestTypeScore = sortedTypes.first!.value
            let secondTypeScore = sortedTypes.dropFirst().first?.value ?? 0
            let margin = bestTypeScore - secondTypeScore
            if bestTypeScore >= 0.20 && margin >= 0.07 { // confident type intent
                let gated = scored.filter { ($0.vc.type.last ?? "").caseInsensitiveCompare(bestType) == .orderedSame || ($0.vc.type.joined(separator: ":").lowercased().contains(bestType.lowercased())) }
                if !gated.isEmpty {
                    return Array(gated.prefix(maxK).map { $0.vc })
                }
            }
        }
        
        // Else: Dynamic cutoff within 80% of best
        let threshold = best * 0.8
        let filtered = scored.prefix(10).filter { $0.score >= threshold }.map { $0.vc }
        return Array((filtered.isEmpty ? scored.map { $0.vc } : filtered).prefix(5))
    }
    
    private func tokenize(_ text: String) -> Set<String> {
        // Simple dynamic tokenization: split on non-alphanumerics, remove empties, keep unigrams and meaningful bigrams
        let parts = text.lowercased().split { !$0.isLetter && !$0.isNumber }
        let tokens = parts.map(String.init)
        var grams = Set(tokens.filter { !$0.isEmpty && $0.count > 2 })
        // Add bigrams to capture phrases like "driver license"
        for i in 0..<(tokens.count - 1) {
            let bi = tokens[i] + " " + tokens[i+1]
            if bi.count > 3 { grams.insert(bi) }
        }
        return grams
    }
    
    private func termFrequency(_ tokens: Set<String>) -> [String: Double] {
        var tf: [String: Double] = [:]
        for t in tokens { tf[t, default: 0] += 1 }
        let total = max(1, tokens.count)
        for (k, v) in tf { tf[k] = v / Double(total) }
        return tf
    }
    
    private func tfidfCosine(queryTF: [String: Double], docID: String) -> Double {
        guard let docTF = vcTokenFrequencies[docID] else { return 0 }
        var dot = 0.0, qNorm = 0.0, dNorm = 0.0
        for (t, qtf) in queryTF {
            let idf = idfWeights[t] ?? 1.0
            let q = qtf * idf
            qNorm += q * q
            let dtf = Double(docTF[t] ?? 0)
            let d = dtf * idf
            dNorm += d * d
            dot += q * d
        }
        if qNorm == 0 || dNorm == 0 { return 0 }
        return dot / (sqrt(qNorm) * sqrt(dNorm))
    }
    
    private func jaccardSimilarity(_ a: Set<String>, _ b: Set<String>) -> Double {
        if a.isEmpty || b.isEmpty { return 0 }
        let inter = a.intersection(b).count
        let union = a.union(b).count
        if union == 0 { return 0 }
        return Double(inter) / Double(union)
    }
    
    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }
        
        var dotProduct = 0.0
        var normA = 0.0
        var normB = 0.0
        
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        
        guard normA > 0 && normB > 0 else { return 0 }
        return dotProduct / (sqrt(normA) * sqrt(normB))
    }

    func formatVCsForPrompt(_ vcs: [VerifiableCredential]) -> String {
        var result = ""
        for (index, vc) in vcs.enumerated() {
            result += "VC \(index + 1): \(vc.toCompactJSON())"
            if index < vcs.count - 1 {
                result += "\n"
            }
        }
        return result
    }
}
