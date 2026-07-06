package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieInterfaceResultsTest {
    @TestCase
    public func f2Ut001StructuredResultRenderersExposeContractFields(): Unit {
        let pack = CangjieKnowledgePack()
        pack.queryId = "q-f2"
        pack.task = "ArrayList.add"
        pack.knowledgeVersion = "test-active"
        pack.targetVersion = "1.0.0"
        pack.versionResolutionId = "vr-f2"
        pack.sourceRef = "release-1.0.0"
        pack.resolvedCommit = "interface-commit"
        pack.contentHash = "sha256:interface"
        pack.sourceRepo = "Cangjie/cangjie_runtime"
        pack.notes.add("exact_hit")
        pack.citations.add(SourceReference("src-f2", "fixture:src-f2", "test-active"))
        let api = CangjieApiItem()
        api.module = "std.collection"
        api.symbol = "ArrayList.add"
        api.sourceId = "src-f2"
        api.citation = "fixture:src-f2"
        api.knowledgeVersion = "test-active"
        api.targetVersion = "1.0.0"
        pack.apiItems.add(api)

        let freshness = cangjieCorpusFreshnessReport(KnowledgeStatus())

        this.expectInterfaceFields(renderCangjieSymbolCardResultJson(cangjieSymbolCardResultFromPack(pack, sourceSet: CangjieSourceSets.STD)))
        this.expectInterfaceFields(renderCangjieDocSectionResultJson(cangjieDocSectionResultFromPack(pack, sourceSet: CangjieSourceSets.DOCS)))
        this.expectInterfaceFields(renderCangjieToolManualResultJson(cangjieToolManualResultFromPack(pack, sourceSet: CangjieSourceSets.TOOLS)))
        this.expectInterfaceFields(renderCangjieNegativeRulesResultJson(cangjieNegativeRulesResultFromPack(pack, sourceSet: CangjieSourceSets.EVAL_SUPPORT)))
        this.expectInterfaceFields(renderCangjieCorpusFreshnessResultJson(cangjieCorpusFreshnessResultFromReport(freshness)))
    }

    private func expectInterfaceFields(json: String): Unit {
        @Expect(json.contains("\"ok\""), true)
        @Expect(json.contains("\"diagnostic\""), true)
        @Expect(json.contains("\"targetVersion\""), true)
        @Expect(json.contains("\"versionResolutionId\""), true)
        @Expect(json.contains("\"sourceRef\""), true)
        @Expect(json.contains("\"resolvedCommit\""), true)
        @Expect(json.contains("\"contentHash\""), true)
        @Expect(json.contains("\"sourceRepo\""), true)
        @Expect(json.contains("\"evidenceHash\""), true)
        @Expect(json.contains("\"citations\""), true)
        @Expect(json.contains("\"sourceSet\""), true)
    }
}
