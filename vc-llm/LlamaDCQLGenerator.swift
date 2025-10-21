import Foundation

actor LlamaDCQLGenerator {
    private var context: LlamaContext?

    init(modelPath: String) async throws {
        print("🚀 LlamaDCQLGenerator initializing with path: \(modelPath)")
        print("📂 File exists: \(FileManager.default.fileExists(atPath: modelPath))")

        do {
            self.context = try LlamaContext.create_context(path: modelPath)
            print("✅ LlamaContext created successfully")
        } catch {
            print("❌ Failed to create LlamaContext: \(error)")
            throw error
        }
    }

    func generateDCQL(
        prompt: String,
        maxTokens: Int = 512
    ) async throws -> String {
        guard let context = context else {
            throw NSError(domain: "LlamaDCQL", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Context not initialized"])
        }

        let startTime = Date()

        // Clear previous state
        await context.clear()

        // Set max length for generation
        await context.setMaxLength(Int32(maxTokens))

        // Initialize completion with prompt
        await context.completion_init(text: prompt)

        // Generate tokens
        print("\n🔄 Generating...")
        var result = ""
        var bracketCount = 0
        var hasStartedJSON = false
        var tokenCount = 0

        while !(await context.is_done) {
            let token = await context.completion_loop()
            result += token
            tokenCount += 1

            // Track JSON structure
            if token.contains("{") {
                hasStartedJSON = true
                bracketCount += token.filter { $0 == "{" }.count
            }
            if token.contains("}") {
                bracketCount -= token.filter { $0 == "}" }.count
            }

            // Stop if we've completed the JSON structure
            if hasStartedJSON && bracketCount == 0 && result.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("}") {
                break
            }

            // Safety check: stop if we hit common end markers
            if result.contains("}\n\n") || result.contains("Please note") || result.contains("This query") {
                break
            }
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let tokensPerSecond = duration > 0 ? Double(tokenCount) / duration : 0

        print("\n\n⏱️  \(String(format: "%.2f", duration))s | \(tokenCount) tokens | \(String(format: "%.1f", tokensPerSecond)) tok/s")

        // Clean up the result
        var cleanResult = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // Ensure JSON is properly closed
        let openBraces = cleanResult.filter { $0 == "{" }.count
        let closeBraces = cleanResult.filter { $0 == "}" }.count
        if openBraces > closeBraces {
            cleanResult += String(repeating: "}", count: openBraces - closeBraces)
        }

        return cleanResult
    }

    func generateDCQLStream(
        prompt: String,
        maxTokens: Int = 512,
        onToken: @escaping (String) -> Void
    ) async throws -> String {
        guard let context = context else {
            throw NSError(domain: "LlamaDCQL", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Context not initialized"])
        }

        let startTime = Date()

        // Clear previous state
        await context.clear()

        // Set max length for generation
        await context.setMaxLength(Int32(maxTokens))

        // Initialize completion with prompt
        await context.completion_init(text: prompt)

        // Generate tokens
        print("\n🔄 Generating...")
        var result = ""
        var bracketCount = 0
        var hasStartedJSON = false
        var tokenCount = 0

        while !(await context.is_done) {
            let token = await context.completion_loop()
            result += token
            tokenCount += 1

            // Stream the token to the UI
            onToken(result)

            // Track JSON structure
            if token.contains("{") {
                hasStartedJSON = true
                bracketCount += token.filter { $0 == "{" }.count
            }
            if token.contains("}") {
                bracketCount -= token.filter { $0 == "}" }.count
            }

            // Stop if we've completed the JSON structure
            if hasStartedJSON && bracketCount == 0 && result.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("}") {
                break
            }

            // Safety check: stop if we hit common end markers
            if result.contains("}\n\n") || result.contains("Please note") || result.contains("This query") {
                break
            }
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let tokensPerSecond = duration > 0 ? Double(tokenCount) / duration : 0

        print("\n\n⏱️  \(String(format: "%.2f", duration))s | \(tokenCount) tokens | \(String(format: "%.1f", tokensPerSecond)) tok/s")

        // Clean up the result
        var cleanResult = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // Ensure JSON is properly closed
        let openBraces = cleanResult.filter { $0 == "{" }.count
        let closeBraces = cleanResult.filter { $0 == "}" }.count
        if openBraces > closeBraces {
            cleanResult += String(repeating: "}", count: openBraces - closeBraces)
        }

        return cleanResult
    }
}
