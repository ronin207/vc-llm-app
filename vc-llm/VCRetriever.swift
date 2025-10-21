import Foundation
import Combine

/// Retrieves relevant VCs based on natural language queries using embeddings
/// Aligned with Python's VCRetriever implementation
class VCRetriever: ObservableObject {
    // Required publisher to satisfy Combine.ObservableObject when no @Published properties
    let objectWillChange = ObservableObjectPublisher()

    private var vcPool: [VerifiableCredential] = []
    private var vcTexts: [String] = []
    private var vcEmbeddings: [[Double]] = []
    private let embedder: EmbeddingGenerator
    private let cachePath: String

    init(
        vcPoolPath: String,
        embedder: EmbeddingGenerator? = nil,
        cachePath: String? = nil
    ) {
        // Initialize embedder (default: CoreML)
        if let embedder = embedder {
            self.embedder = embedder
        } else {
            // Use CoreML embedder
            do {
                self.embedder = try CoreMLEmbeddingGenerator()
                print("✅ Using CoreML embedder")
            } catch {
                fatalError("Failed to initialize CoreML embedder: \(error)")
            }
        }

        // Set cache path
        if let cachePath = cachePath {
            self.cachePath = cachePath
        } else {
            let cacheDir = FileManager.default.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            ).first!
            self.cachePath = cacheDir
                .appendingPathComponent("coreml_embeddings_cache.json")
                .path
        }

        // Load VCs
        loadVCPool(from: vcPoolPath)

        // Load cache if available
        try? self.embedder.loadCache(from: self.cachePath)
    }

    private func loadVCPool(from path: String) {
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

    /// Prepare VC pool by generating embeddings for all VCs
    func prepareVCPool() {
        // Skip if already prepared
        guard vcEmbeddings.isEmpty else {
            print("VC pool already prepared (\(vcPool.count) VCs)")
            return
        }

        print("Preparing VC pool...")

        // Clear cache to prevent bloat - we only want VC pool embeddings
        embedder.clearCache()

        // Prepare texts
        vcTexts = vcPool.map { VCTextPreparation.prepareVCText($0) }

        // Generate embeddings (with caching enabled for VC texts only)
        vcEmbeddings = embedder.getEmbeddingsBatch(for: vcTexts, useCache: true)

        // Save cache with only VC embeddings
        try? embedder.saveCache(to: cachePath)

        print("Prepared \(vcPool.count) VCs with embeddings")
    }

    /// Retrieve top-k relevant VCs for a query
    func retrieve(query: String, topK: Int = 3) -> [(vc: VerifiableCredential, score: Double)] {
        guard !vcEmbeddings.isEmpty else {
            print("Error: VC pool not prepared. Call prepareVCPool() first.")
            return []
        }

        // Generate query embedding WITHOUT caching (to avoid cache bloat)
        guard let queryEmbedding = embedder.getEmbedding(for: query, useCache: false) else {
            print("Error: Failed to generate embedding for query")
            return []
        }

        // Calculate cosine similarities
        var similarities: [(index: Int, score: Double)] = []
        for (index, vcEmbedding) in vcEmbeddings.enumerated() {
            let similarity = cosineSimilarity(queryEmbedding, vcEmbedding)
            similarities.append((index, similarity))
        }

        // Sort by similarity and take top-k
        let topIndices = similarities
            .sorted { $0.score > $1.score }
            .prefix(topK)

        return topIndices.map { (vcPool[$0.index], $0.score) }
    }

    /// Retrieve only the IDs of top-k relevant VCs
    func retrieveIDs(query: String, topK: Int = 3) -> [String] {
        return retrieve(query: query, topK: topK).map { vc, _ in
            // Extract just the VC ID part from the full URL if needed
            let vcID = vc.id
            if vcID.hasPrefix("https://") {
                return vcID.components(separatedBy: "/").last ?? vcID
            }
            return vcID
        }
    }

    /// Get a specific VC by its ID
    func getVC(byID vcID: String) -> VerifiableCredential? {
        return vcPool.first { $0.id == vcID }
    }

    /// Calculate cosine similarity between two vectors
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

    /// Format VCs for prompt (utility function) - match training format
    func formatVCsForPrompt(_ vcs: [VerifiableCredential]) -> String {
        var result = ""
        for (index, vc) in vcs.enumerated() {
            // Match the training data format: "VC 1: {json}"
            result += "VC \(index + 1): \(vc.toCompactJSON())"
            if index < vcs.count - 1 {
                result += "\n"
            }
        }
        return result
    }

    /// Get all VCs in the pool
    var allVCs: [VerifiableCredential] {
        return vcPool
    }

    /// Get the number of VCs in the pool
    var vcCount: Int {
        return vcPool.count
    }
}
