import Foundation
import CoreML

/// CoreML-based embedding generator using sentence-transformers model
@available(iOS 17.0, *)
class CoreMLEmbeddingGenerator: EmbeddingGenerator {
    private let model: SentenceTransformer
    private let tokenizer: WordPieceTokenizer
    private var embeddingCache: [String: [Double]] = [:]

    init(vocabPath: String? = nil) throws {
        // Load tokenizer
        let vocabFilePath: String
        if let vocabPath = vocabPath {
            vocabFilePath = vocabPath
        } else {
            // Try multiple possible locations for vocab.txt in bundle
            let possiblePaths = [
                Bundle.main.path(forResource: "vocab", ofType: "txt", inDirectory: "Models/tokenizer"),
                Bundle.main.path(forResource: "vocab", ofType: "txt", inDirectory: "Resources/Models/tokenizer"),
                Bundle.main.path(forResource: "vocab", ofType: "txt"),
                Bundle.main.url(forResource: "vocab", withExtension: "txt")?.path
            ]

            guard let bundleVocabPath = possiblePaths.compactMap({ $0 }).first else {
                // Debug: print all bundle resources
                if let resourcePath = Bundle.main.resourcePath {
                    print("Bundle resource path: \(resourcePath)")
                    if let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
                        print("Bundle contents: \(contents)")
                    }
                }

                throw NSError(domain: "CoreMLEmbedding", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "vocab.txt not found in bundle. Tried: Models/tokenizer/, Resources/Models/tokenizer/, root"
                ])
            }
            vocabFilePath = bundleVocabPath
        }

        self.tokenizer = try WordPieceTokenizer(vocabPath: vocabFilePath)

        // Load CoreML model using auto-generated class
        self.model = try SentenceTransformer(configuration: MLModelConfiguration())
        print("✅ Loaded CoreML SentenceTransformer model")
    }

    func getEmbedding(for text: String, useCache: Bool = true) -> [Double]? {
        // Check cache
        if useCache, let cached = embeddingCache[text] {
            return cached
        }

        // 1. Tokenize
        let (inputIds, attentionMask) = tokenizer.tokenize(text: text, maxLength: 128)

        // 2. Create MLMultiArray inputs
        guard let inputIdsArray = try? createMLMultiArray(from: inputIds, shape: [1, 128]),
              let attentionMaskArray = try? createMLMultiArray(from: attentionMask, shape: [1, 128]) else {
            print("❌ Failed to create MLMultiArray inputs")
            return nil
        }

        // 3. Create input using auto-generated class
        let input = SentenceTransformerInput(
            input_ids: inputIdsArray,
            attention_mask: attentionMaskArray
        )

        // 4. Run CoreML inference
        guard let output = try? model.prediction(input: input) else {
            print("❌ CoreML inference failed")
            return nil
        }

        // 5. Extract embedding
        let embeddingArray = output.sentence_embedding

        // 6. Convert to [Double]
        let embedding = extractDoubleArray(from: embeddingArray)

        // 7. Cache
        if useCache {
            embeddingCache[text] = embedding
        }

        return embedding
    }

    func getEmbeddingsBatch(for texts: [String], useCache: Bool = true) -> [[Double]] {
        return texts.compactMap { getEmbedding(for: $0, useCache: useCache) }
    }

    func saveCache(to filepath: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(embeddingCache)
        try data.write(to: URL(fileURLWithPath: filepath))
        print("✅ Saved \(embeddingCache.count) embeddings to cache: \(filepath)")
    }

    func loadCache(from filepath: String) throws {
        guard FileManager.default.fileExists(atPath: filepath) else {
            print("⚠️ Cache file not found: \(filepath)")
            return
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: filepath))
        let decoder = JSONDecoder()
        let loadedCache = try decoder.decode([String: [Double]].self, from: data)

        // Merge loaded cache with current cache (avoid duplicates)
        embeddingCache.merge(loadedCache) { (current, _) in current }
        print("✅ Loaded \(loadedCache.count) embeddings from cache (total: \(embeddingCache.count))")
    }

    func clearCache() {
        embeddingCache.removeAll()
    }

    // MARK: - Helper methods

    private func createMLMultiArray(from array: [Int32], shape: [Int]) -> MLMultiArray {
        guard let mlArray = try? MLMultiArray(shape: shape as [NSNumber], dataType: .int32) else {
            fatalError("Failed to create MLMultiArray")
        }

        for (index, value) in array.enumerated() {
            mlArray[index] = NSNumber(value: value)
        }

        return mlArray
    }

    private func extractDoubleArray(from mlArray: MLMultiArray) -> [Double] {
        let count = mlArray.count
        var result: [Double] = []
        result.reserveCapacity(count)

        for i in 0..<count {
            result.append(mlArray[i].doubleValue)
        }

        return result
    }
}
