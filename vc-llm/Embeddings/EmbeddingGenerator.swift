import Foundation

/// Protocol for embedding generation
/// Aligned with Python's BaseEmbeddingGenerator
protocol EmbeddingGenerator {
    /// Get embedding for a single text
    func getEmbedding(for text: String, useCache: Bool) -> [Double]?

    /// Get embeddings for multiple texts with batch processing
    func getEmbeddingsBatch(for texts: [String], useCache: Bool) -> [[Double]]

    /// Save embedding cache to file
    func saveCache(to filepath: String) throws

    /// Load embedding cache from file
    func loadCache(from filepath: String) throws

    /// Clear embedding cache
    func clearCache()
}

extension EmbeddingGenerator {
    /// Default implementation with cache enabled
    func getEmbedding(for text: String) -> [Double]? {
        return getEmbedding(for: text, useCache: true)
    }

    /// Default implementation with cache enabled
    func getEmbeddingsBatch(for texts: [String]) -> [[Double]] {
        return getEmbeddingsBatch(for: texts, useCache: true)
    }
}
