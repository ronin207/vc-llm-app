import Foundation

/// Represents a Verifiable Credential
struct VerifiableCredential: Codable, Identifiable {
    let id: String
    let context: [String]?
    let type: [String]
    let issuer: Issuer
    let validFrom: String?
    let validUntil: String?
    let credentialSubject: [String: JSONValue]
    let proof: Proof?

    /// Primary type of the credential (excluding "VerifiableCredential")
    var primaryType: String {
        let filteredTypes = type.filter { $0 != "VerifiableCredential" }
        return filteredTypes.first ?? type.first ?? "Unknown Credential"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case context = "@context"
        case type
        case issuer
        case validFrom
        case validUntil
        case credentialSubject
        case proof
    }

    /// Convert to compact JSON string for prompt
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

/// Issuer information for a Verifiable Credential
struct Issuer: Codable {
    let id: String
    let name: String
}

/// Proof information for a Verifiable Credential
struct Proof: Codable {
    let type: String
    let cryptosuite: String
    let created: String
    let verificationMethod: String
    let proofPurpose: String
    let proofValue: String
}
