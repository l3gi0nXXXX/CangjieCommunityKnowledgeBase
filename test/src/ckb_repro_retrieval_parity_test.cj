package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

private class P3FakeRetrievalBackend <: CkbRetrievalParityBackend {
    public var drift: Bool = false
    public var invalidEncoding: Bool = false
    public init() {}
    public func query(transport: String, query: String):
        CkbRetrievalParityResponse {
        let out = CkbRetrievalParityResponse()
        out.ok = true
        out.knowledgeVersion = "portable-v1"
        if (this.invalidEncoding) {
            out.rawBytes = [0xff, 0xfe]
            return out
        }
        let hit = CkbRetrievalParityHit()
        hit.logicalId = if (this.drift && transport == "mcp_http") {
            "different"
        } else { "doc-1" }
        hit.contentHash = p3ParityHash("content")
        hit.citation = "docs/language/basic.md"
        hit.rank = 1
        out.hits.add(hit)
        out
    }
}

@Test
public class CkbReproRetrievalParityTest {
    @TestCase
    public func p3Pos01FixedGenericRestAndMcpParityMatches(): Unit {
        let backend = P3FakeRetrievalBackend()
        let built = buildCkbRetrievalParityManifest(
            "portable-v1", p3HashForParity("logical"), backend)
        @Expect(built.ok, true)
        @Expect(built.manifest.transports.size, 3)
        @Expect(verifyCkbRetrievalParityManifest(
            built.manifest, backend).ok, true)
    }

    @TestCase
    public func p3Neg01BenchmarkDirectedQueriesAndTransportDriftAreRejected(): Unit {
        for (query in [
            "HumanEval case 145", "pass@1 solution", "hidden tests",
            "reference solution", "请实现 humaneval_101"
        ]) {
            @Expect(validateCkbRetrievalParityQuery(query).ok, false)
        }
        let backend = P3FakeRetrievalBackend()
        backend.drift = true
        @Expect(buildCkbRetrievalParityManifest(
            "portable-v1", p3HashForParity("logical"), backend).diagnostic,
            "retrieval_parity_result_mismatch")
        backend.drift = false
        backend.invalidEncoding = true
        @Expect(buildCkbRetrievalParityManifest(
            "portable-v1", p3HashForParity("logical"), backend).diagnostic,
            "invalid_response_encoding")
    }

    @TestCase
    public func p3Reg01ManifestDetectsPostBuildRetrievalDrift(): Unit {
        let backend = P3FakeRetrievalBackend()
        let built = buildCkbRetrievalParityManifest(
            "portable-v1", p3HashForParity("logical"), backend)
        @Expect(built.ok, true)
        backend.drift = true
        @Expect(verifyCkbRetrievalParityManifest(
            built.manifest, backend).diagnostic,
            "retrieval_parity_result_mismatch")
    }
}

private func p3HashForParity(value: String): String {
    benchmarkGapSha256(value)
}

private func p3ParityHash(value: String): String {
    benchmarkGapSha256(value)
}
