//
//  VPDCQLBridge.swift
//  vc-llm
//
//  Swift wrapper for Rust vp-dcql library
//

import Foundation

// C function declarations (manually declared since bridging header isn't working)
@_silgen_name("vp_dcql_create_presentation")
func vp_dcql_create_presentation(
    _ dcqlQuery: UnsafePointer<CChar>,
    _ signedCredential: UnsafePointer<CChar>,
    _ challenge: UnsafePointer<CChar>?
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("vp_dcql_free_string")
func vp_dcql_free_string(_ s: UnsafeMutablePointer<CChar>)

/// Errors that can occur when creating presentations
enum VPDCQLError: Error {
    case nullPointerReturned
    case rustError(String)

    var localizedDescription: String {
        switch self {
        case .nullPointerReturned:
            return "Rust function returned null"
        case .rustError(let message):
            return message
        }
    }
}

/// Swift wrapper for Rust vp-dcql library
class VPDCQLBridge {

    /// Create a Verifiable Presentation from DCQL query and signed VC
    ///
    /// - Parameters:
    ///   - dcqlQuery: DCQL query as JSON string
    ///   - signedCredential: Signed VC as JSON string
    ///   - challenge: Optional challenge string
    /// - Returns: VP as JSON string
    /// - Throws: VPDCQLError if the operation fails
    static func createPresentation(
        dcqlQuery: String,
        signedCredential: String,
        challenge: String? = nil
    ) throws -> String {
        print("🔧 [VPDCQLBridge] Input lengths: DCQL=\(dcqlQuery.count), VC=\(signedCredential.count)")

        // Call Rust FFI function
        let resultPtr = dcqlQuery.withCString { dcqlCStr in
            signedCredential.withCString { vcCStr in
                if let challenge = challenge {
                    return challenge.withCString { challengeCStr in
                        vp_dcql_create_presentation(dcqlCStr, vcCStr, challengeCStr)
                    }
                } else {
                    return vp_dcql_create_presentation(dcqlCStr, vcCStr, nil)
                }
            }
        }

        // Check result
        guard let resultPtr = resultPtr else {
            print("❌ [VPDCQLBridge] Null pointer returned from Rust")
            throw VPDCQLError.nullPointerReturned
        }

        // Convert C string to Swift string
        let resultString = String(cString: resultPtr)
        print("🔧 [VPDCQLBridge] Result length: \(resultString.count)")
        print("🔧 [VPDCQLBridge] Result preview: \(resultString.prefix(200))")

        // Free the C string
        vp_dcql_free_string(resultPtr)

        // Check if result is an error
        if resultString.hasPrefix("ERROR: ") {
            let errorMessage = String(resultString.dropFirst(7))
            print("❌ [VPDCQLBridge] Rust error: \(errorMessage)")
            throw VPDCQLError.rustError(errorMessage)
        }

        print("✅ [VPDCQLBridge] VP created successfully")
        return resultString
    }

}
