package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbR1CompletionOnlyContextContractTest {
    // P2-CKB-UT-02
    @TestCase
    public func requestContainsOnlyFrozenPublicCompletionFields(): Unit {
        let request=buildCompletionOnlyRetrievalRequest("Implement a Rune-safe formatter 中文😀","public func format(value:String):String","1.0.0")
        @Expect(request.diagnostic,"ok");@Expect(request.json.contains("taskText"),true);@Expect(request.json.contains("starterSignature"),true);@Expect(request.json.contains("targetVersion"),true)
        @Expect(request.json.contains("caseId"),false);@Expect(request.json.contains("expectedKnowledgeTags"),false);@Expect(request.requestHash.startsWith("sha256:"),true)
    }

    // P2-CKB-POS-02
    @TestCase
    public func validUtf8KnowledgePackIsPrefetchedAndEvidenceHasNoPayload(): Unit {
        let request=buildCompletionOnlyRetrievalRequest("Review public boundaries","public func solve(input:String):String","1.0.0")
        let raw="{\"knowledgeVersion\":\"knowledge-v1\",\"knowledgePack\":\"Rune-safe public guidance 中文😀\"}"
        let pack=prefetchCompletionKnowledgePack(request,raw.toArray());@Expect(pack.ok,true);@Expect(pack.diagnostic,"ok")
        let evidence=renderCompletionContextEvidence(pack);@Expect(evidence.contains("Rune-safe"),false);@Expect(evidence.contains("contentBytes"),true)
    }

    // P2-CKB-BND-02
    @TestCase
    public func exactPackLimitPassesAndOneByteOverFails(): Unit {
        let request=buildCompletionOnlyRetrievalRequest("Public task","public func solve():Int64","1.0.0")
        let exact=StringBuilder();for(_ in 0..65536){exact.append("x")}
        @Expect(prefetchCompletionKnowledgePack(request,p2Pack(exact.toString()).toArray()).ok,true)
        exact.append("x");@Expect(prefetchCompletionKnowledgePack(request,p2Pack(exact.toString()).toArray()).diagnostic,"knowledge_pack_too_large")
        @Expect(prefetchCompletionKnowledgePack(request,[UInt8(0xff),UInt8(0xfe)]).diagnostic,"invalid_response_encoding")
        @Expect(prefetchCompletionKnowledgePack(request,"{".toArray()).diagnostic,"malformed_json")
    }

    // P2-CKB-NEG-03
    @TestCase
    public func unknownFieldsProtectedArtifactsAndSecretsFailClosed(): Unit {
        let request=buildCompletionOnlyRetrievalRequest("Public task","public func solve():Int64","1.0.0")
        @Expect(prefetchCompletionKnowledgePack(request,"{\"knowledgeVersion\":\"v1\",\"knowledgePack\":\"safe\",\"extra\":1}".toArray()).diagnostic,"knowledge_response_schema_invalid")
        @Expect(prefetchCompletionKnowledgePack(request,p2Pack("canonical_solution").toArray()).diagnostic,"knowledge_pack_protected_or_secret")
        @Expect(buildCompletionOnlyRetrievalRequest("token=secret","public func solve():Int64","1.0.0").diagnostic,"public_retrieval_input_invalid")
    }
}

private func p2Pack(value:String):String{"{\"knowledgeVersion\":\"knowledge-v1\",\"knowledgePack\":\"${value}\"}"}
