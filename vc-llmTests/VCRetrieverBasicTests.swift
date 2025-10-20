//
//  VCRetrieverBasicTests.swift
//  vc-llmTests
//
//  Created by ken.watanabe on 2025/10/20.
//

import Testing
@testable import vc_llm

@Suite("VCRetriever Basic Tests")
struct VCRetrieverBasicTests {

    // Shared retriever instance for all tests
    static let retriever: VCRetriever = {
        let r = VCRetriever(vcPoolPath: "vc_pool")
        r.prepareVCPool()
        return r
    }()

    @Test("VCRetriever initializes and loads VC pool")
    func vcRetrieverInitialization() async throws {
        // Then
        #expect(Self.retriever.vcCount > 0, "VCRetriever should load VCs from pool")
    }

    @Test("VCRetriever retrieves top-k results correctly")
    func vcRetrieverRetrieveTopK() async throws {
        // When
        let results = Self.retriever.retrieve(query: "driver license", topK: 3)

        // Then
        #expect(results.count <= 3, "Should return at most topK results")
        #expect(results.count > 0, "Should return at least one result")

        // Verify scores are in descending order
        for i in 0..<results.count-1 {
            #expect(results[i].score >= results[i+1].score, "Results should be sorted by score")
        }
    }

    @Test("VCRetriever retrieves IDs correctly")
    func vcRetrieverRetrieveIDs() async throws {
        // When
        let ids = Self.retriever.retrieveIDs(query: "driver license", topK: 3)

        // Then
        #expect(ids.count <= 3, "Should return at most topK results")
        #expect(ids.count > 0, "Should return at least one ID")
        for id in ids {
            #expect(!id.isEmpty, "IDs should not be empty")
        }
    }

    @Test("VCRetriever finds VC by ID")
    func vcRetrieverGetByID() async throws {
        // Given
        let allVCs = Self.retriever.allVCs

        guard let firstVC = allVCs.first else {
            Issue.record("VC pool should not be empty")
            return
        }

        // When
        let foundVC = Self.retriever.getVC(byID: firstVC.id)

        // Then
        #expect(foundVC != nil, "Should find VC by ID")
        #expect(foundVC?.id == firstVC.id, "Found VC should have matching ID")
    }

}
