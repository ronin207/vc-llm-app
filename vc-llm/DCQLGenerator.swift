import Foundation
import MLXLMCommon
import MLXLLM
import MLX
import Tokenizers

struct DCQLGenerationResult {
    let dcql: [String: Any]
    let dcqlString: String
    let rawResponse: String
}

enum DCQLValidationError: LocalizedError {
    case invalidJSON(raw: String)
    case missingCredentials(raw: String)
    case invalidCredentialField(index: Int, field: String, raw: String)
    case invalidClaims(index: Int, raw: String)
    case invalidClaimPath(credentialIndex: Int, claimIndex: Int, raw: String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Model response is not valid JSON."
        case .missingCredentials:
            return "DCQL output does not contain a credentials array."
        case let .invalidCredentialField(index, field, _):
            return "DCQL credentials[\(index)] is missing required field \(field)."
        case let .invalidClaims(index, _):
            return "DCQL credentials[\(index)] claims is empty or not an array."
        case let .invalidClaimPath(credentialIndex, claimIndex, _):
            return "DCQL credentials[\(credentialIndex)] claims[\(claimIndex)] has an invalid path."
        }
    }

    var rawResponse: String {
        switch self {
        case let .invalidJSON(raw),
             let .missingCredentials(raw),
             let .invalidCredentialField(_, _, raw),
             let .invalidClaims(_, raw),
             let .invalidClaimPath(_, _, raw):
            return raw
        }
    }
}

struct DCQLGenerator {
    let modelContext: ModelContext
    let parameters: GenerateParameters

    func generateDCQL(query: String, formattedVCs: String) throws -> DCQLGenerationResult {
        let prompt = DCQLGenerator.buildPrompt(formattedVCs: formattedVCs, query: query)
        let promptTokens = modelContext.tokenizer.encode(text: prompt)
        let lmInput = LMInput(tokens: MLXArray(promptTokens))

        let result = try MLXLMCommon.generate(
            input: lmInput,
            parameters: parameters,
            context: modelContext,
            didGenerate: { (_: [Int]) -> GenerateDisposition in .more }
        )

        let response = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let json = try DCQLGenerator.parseDCQLJSON(from: response)
        try DCQLGenerator.validateDCQL(json, raw: response)

        let pretty = (try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted))
            .flatMap { String(data: $0, encoding: .utf8) } ?? response

        return DCQLGenerationResult(dcql: json, dcqlString: pretty, rawResponse: response)
    }

    static func buildPrompt(formattedVCs: String, query: String) -> String {
        """
        Given the following Verifiable Credentials and a natural language query, generate a DCQL query to retrieve the requested information.

        Available Verifiable Credentials:
        \(formattedVCs)

        Natural Language Query: \(query)

        Generate a DCQL query that selects the appropriate credentials and fields:
        """
    }

    static func parseDCQLJSON(from text: String) throws -> [String: Any] {
        if let data = text.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return obj
        }

        var cleaned = text
        if cleaned.contains("```") {
            cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
            cleaned = cleaned.replacingOccurrences(of: "```JSON", with: "")
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        }
        if let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}") {
            let jsonSlice = cleaned[start...end]
            if let data = String(jsonSlice).data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return obj
            }
        }

        throw DCQLValidationError.invalidJSON(raw: text)
    }

    static func validateDCQL(_ json: [String: Any], raw: String) throws {
        guard let credentials = json["credentials"] as? [[String: Any]], !credentials.isEmpty else {
            throw DCQLValidationError.missingCredentials(raw: raw)
        }

        for (index, credential) in credentials.enumerated() {
            guard let id = credential["id"] as? String, !id.isEmpty else {
                throw DCQLValidationError.invalidCredentialField(index: index, field: "id", raw: raw)
            }
            guard let format = credential["format"] as? String, !format.isEmpty else {
                throw DCQLValidationError.invalidCredentialField(index: index, field: "format", raw: raw)
            }
            guard let claims = credential["claims"] as? [[String: Any]], !claims.isEmpty else {
                throw DCQLValidationError.invalidClaims(index: index, raw: raw)
            }

            for (claimIndex, claim) in claims.enumerated() {
                guard let path = claim["path"] as? [String], !path.isEmpty,
                      path.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                    throw DCQLValidationError.invalidClaimPath(credentialIndex: index, claimIndex: claimIndex, raw: raw)
                }
            }
        }
    }

    static func generateTemplateDCQL(for vcs: [VerifiableCredential], query: String) -> [String: Any] {
        guard let firstVC = vcs.first else { return [:] }
        let credentialType = firstVC.type.last ?? "UnknownCredential"
        let credentialId = credentialType
            .lowercased()
            .replacingOccurrences(of: "credential", with: "")
            .replacingOccurrences(of: "certificate", with: "") + "_credential"

        var claims: [[String: Any]] = []
        let queryLower = query.lowercased()
        for key in firstVC.credentialSubject.keys {
            if queryLower.contains(key.lowercased()) ||
                key == "fullName" || key == "name" ||
                (queryLower.contains("expir") && (key.contains("expir") || key.contains("valid"))) {
                claims.append(["path": ["credentialSubject", key]])
            }
        }
        if claims.isEmpty {
            for key in firstVC.credentialSubject.keys.prefix(3) {
                claims.append(["path": ["credentialSubject", key]])
            }
        }
        return [
            "credentials": [
                [
                    "id": credentialId,
                    "format": "ldp_vc",
                    "meta": [
                        "type_values": [firstVC.type]
                    ],
                    "claims": claims
                ]
            ]
        ]
    }
}
