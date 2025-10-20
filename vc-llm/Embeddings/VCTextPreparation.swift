import Foundation

/// Utility for converting Verifiable Credentials to text representations for embedding
enum VCTextPreparation {
    /// Convert VC to text representation for embedding
    /// Aligned with Python's prepare_vc_text implementation
    static func prepareVCText(_ vc: VerifiableCredential) -> String {
        var parts: [String] = []

        // Add type information (excluding "VerifiableCredential")
        let types = vc.type.filter { $0 != "VerifiableCredential" }
        if !types.isEmpty {
            parts.append("Type: \(types.joined(separator: ", "))")
        }

        // Add issuer information
        let issuerName = vc.issuer.name.isEmpty ? vc.issuer.id : vc.issuer.name
        if !issuerName.isEmpty {
            parts.append("Issuer: \(issuerName)")
        }

        // Add credential subject fields
        var fields: [String] = []
        for (key, value) in vc.credentialSubject {
            let valueStr: String

            switch value {
            case .string(let str):
                valueStr = str
            case .number(let num):
                valueStr = String(num)
            case .bool(let bool):
                valueStr = String(bool)
            case .array(let arr):
                valueStr = arr.map { $0.stringValue }.joined(separator: ", ")
            case .object:
                // Skip nested objects for simplicity
                continue
            case .null:
                continue
            }

            let trimmedValue = valueStr.trimmingCharacters(in: .whitespaces)
            if !trimmedValue.isEmpty {
                fields.append("\(key): \(trimmedValue)")
            }
        }

        if !fields.isEmpty {
            parts.append("Subject: \(fields.joined(separator: "; "))")
        }

        return parts.joined(separator: " | ")
    }
}
