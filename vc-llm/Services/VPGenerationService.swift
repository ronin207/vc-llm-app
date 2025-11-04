//
//  VPGenerationService.swift
//  vc-llm
//
//  Service for generating Verifiable Presentations using Rust vp-dcql library
//

import Foundation

/// Result of VP generation
struct VPGenerationResult {
    let vp: String?
    let error: String?
    let generationTime: TimeInterval

    var succeeded: Bool {
        vp != nil
    }
}

/// Service responsible for VP generation using Rust vp-dcql library
@MainActor
class VPGenerationService {

    /// Generate a Verifiable Presentation from DCQL response
    /// - Parameters:
    ///   - dcqlResponse: The DCQL response containing query and selected VCs
    ///   - challenge: Challenge string for the VP (default: "mobile-app-challenge")
    /// - Returns: VPGenerationResult with VP or error information
    func generateVP(
        from dcqlResponse: DCQLResponse,
        challenge: String = "mobile-app-challenge"
    ) async -> VPGenerationResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Convert DCQL to JSON string
            let dcqlData = try JSONSerialization.data(withJSONObject: dcqlResponse.dcql, options: [])
            guard let dcqlString = String(data: dcqlData, encoding: .utf8) else {
                return VPGenerationResult(
                    vp: nil,
                    error: "Failed to convert DCQL to JSON string",
                    generationTime: CFAbsoluteTimeGetCurrent() - startTime
                )
            }

            // Get the first retrieved VC
            guard let firstVC = dcqlResponse.selectedVCs.first else {
                return VPGenerationResult(
                    vp: nil,
                    error: "No VCs available for VP generation",
                    generationTime: CFAbsoluteTimeGetCurrent() - startTime
                )
            }

            // Convert VC to JSON string
            let vcEncoder = JSONEncoder()
            vcEncoder.outputFormatting = []
            let vcData = try vcEncoder.encode(firstVC)
            guard let vcString = String(data: vcData, encoding: .utf8) else {
                return VPGenerationResult(
                    vp: nil,
                    error: "Failed to convert VC to JSON string",
                    generationTime: CFAbsoluteTimeGetCurrent() - startTime
                )
            }

            logVPGenerationStart(dcqlString: dcqlString, vcString: vcString, vcType: firstVC.type.last ?? "unknown")

            // Call Rust vp-dcql bridge
            let vp = try VPDCQLBridge.createPresentation(
                dcqlQuery: dcqlString,
                signedCredential: vcString,
                challenge: challenge
            )

            let generationTime = CFAbsoluteTimeGetCurrent() - startTime
            logVPGenerationSuccess()

            return VPGenerationResult(
                vp: vp,
                error: nil,
                generationTime: generationTime
            )

        } catch let error as VPDCQLError {
            let generationTime = CFAbsoluteTimeGetCurrent() - startTime
            let errorMsg = error.localizedDescription
            logVPGenerationError(errorMsg)

            return VPGenerationResult(
                vp: nil,
                error: errorMsg,
                generationTime: generationTime
            )

        } catch {
            let generationTime = CFAbsoluteTimeGetCurrent() - startTime
            let errorMsg = "VP Generation Failed: \(error.localizedDescription)"
            logVPGenerationError(errorMsg)

            return VPGenerationResult(
                vp: nil,
                error: errorMsg,
                generationTime: generationTime
            )
        }
    }

    // MARK: - Private Logging Methods

    private func logVPGenerationStart(dcqlString: String, vcString: String, vcType: String) {
        print("🦀 [VP] Calling Rust vp-dcql...")
        print("🦀 [VP] Using LLM-generated DCQL")
        print("🦀 [VP] VC type: \(vcType)")
        print("🦀 [VP] DCQL preview: \(dcqlString.prefix(100))...")
        print("🦀 [VP] VC preview: \(vcString.prefix(100))...")
    }

    private func logVPGenerationSuccess() {
        print("✅ [VP] VP generated successfully")
    }

    private func logVPGenerationError(_ error: String) {
        print("❌ [VP] Error: \(error)")
    }
}
