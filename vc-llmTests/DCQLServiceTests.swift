import Testing
@testable import vc_llm

@Suite("DCQL Service Tests")
struct DCQLServiceTests {

    @MainActor
    @Test("Llama.cpp model generates valid DCQL")
    func llamaCppModelGeneratesValidDCQL() async throws {
        let service = LlamaDCQLService()
        try await service.ensureModelLoaded()

        let response = try await service.generateDCQL(from: "Show my driver's license")

        #expect(!response.dcqlString.isEmpty, "DCQL string should not be empty")
        #expect(!response.selectedVCs.isEmpty, "Should select at least one VC")

        guard let credentials = response.dcql["credentials"] as? [[String: Any]] else {
            Issue.record("DCQL response should contain credentials array")
            return
        }

        #expect(!credentials.isEmpty, "Credentials array should not be empty")
    }
}
