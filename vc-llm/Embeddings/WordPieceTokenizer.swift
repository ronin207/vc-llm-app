import Foundation

/// WordPiece tokenizer for BERT-based models
class WordPieceTokenizer {
    private let vocab: [String: Int]
    private let unkToken = "[UNK]"
    private let maxInputCharsPerWord = 200

    // Special token IDs (for BERT/MiniLM)
    private let clsTokenId = 101  // [CLS]
    private let sepTokenId = 102  // [SEP]
    private let padTokenId = 0    // [PAD]

    init(vocabPath: String) throws {
        // Load vocab.txt
        let vocabText = try String(contentsOfFile: vocabPath, encoding: .utf8)
        var vocab: [String: Int] = [:]

        for (index, line) in vocabText.components(separatedBy: .newlines).enumerated() {
            let token = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty {
                vocab[token] = index
            }
        }

        self.vocab = vocab
        print("✅ WordPiece tokenizer loaded: \(vocab.count) tokens")
    }

    func tokenize(text: String, maxLength: Int = 128) -> (inputIds: [Int32], attentionMask: [Int32]) {
        // 1. Basic tokenization (lowercase + split)
        let tokens = basicTokenize(text.lowercased())

        // 2. WordPiece tokenization
        var wordPieceTokens: [String] = []
        for token in tokens {
            let subTokens = wordpieceTokenize(token)
            wordPieceTokens.append(contentsOf: subTokens)
        }

        // 3. Convert to IDs
        var inputIds = [clsTokenId]  // Start with [CLS]
        for token in wordPieceTokens.prefix(maxLength - 2) {
            inputIds.append(vocab[token] ?? vocab[unkToken]!)
        }
        inputIds.append(sepTokenId)  // End with [SEP]

        // 4. Create attention mask
        var attentionMask = Array(repeating: Int32(1), count: inputIds.count)

        // 5. Pad to maxLength
        while inputIds.count < maxLength {
            inputIds.append(padTokenId)
            attentionMask.append(0)
        }

        return (
            inputIds: inputIds.prefix(maxLength).map { Int32($0) },
            attentionMask: Array(attentionMask.prefix(maxLength))
        )
    }

    private func basicTokenize(_ text: String) -> [String] {
        // Split on whitespace and punctuation
        var tokens: [String] = []
        var currentToken = ""

        for char in text {
            if char.isWhitespace || char.isPunctuation {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
                if !char.isWhitespace {
                    tokens.append(String(char))
                }
            } else {
                currentToken.append(char)
            }
        }

        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }

        return tokens
    }

    private func wordpieceTokenize(_ word: String) -> [String] {
        if word.count > maxInputCharsPerWord {
            return [unkToken]
        }

        var tokens: [String] = []
        var start = 0

        while start < word.count {
            var end = word.count
            var foundSubToken: String?

            // Greedy longest-match-first
            while start < end {
                let startIndex = word.index(word.startIndex, offsetBy: start)
                let endIndex = word.index(word.startIndex, offsetBy: end)
                var subToken = String(word[startIndex..<endIndex])

                // Add "##" prefix for non-first subtokens
                if start > 0 {
                    subToken = "##" + subToken
                }

                if vocab[subToken] != nil {
                    foundSubToken = subToken
                    break
                }

                end -= 1
            }

            if let subToken = foundSubToken {
                tokens.append(subToken)
                start = end
            } else {
                return [unkToken]
            }
        }

        return tokens
    }
}
