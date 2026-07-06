package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieBenchmarkGapCurationTest {
    @TestCase
    public func p6Pos001VisibleBenchmarkGapBecomesReviewedRecord(): Unit {
        let inputs = ArrayList<CangjieBenchmarkGapInput>()
        let input = CangjieBenchmarkGapInput()
        input.caseId = "CJ-HUMANEVAL-000"
        input.taskText = "Implement ArrayList sum."
        input.visibleTestExcerpt = "assert solve([1,2]) == 3"
        input.compilerOutput = "ArrayList import required"
        input.missingKnowledge = "ArrayList.add"
        input.officialCitation = "https://docs.cangjie-lang.cn/docs/1.0.0/"
        inputs.add(input)

        let result = curateBenchmarkGapRecords(inputs)

        @Expect(result.ok, true)
        @Expect(result.accepted, 1)
        @Expect(result.records[0].metadata.reviewState, ReviewStates.REVIEWED)
        @Expect(result.records[0].metadata.sourceSet, CangjieSourceSets.EVAL_SUPPORT)
        @Expect(result.records[0].citation.contains("docs.cangjie-lang.cn"), true)
        @Expect(result.records[0].chunk.contains("Interface ID: KI-02"), true)
        @Expect(result.records[0].chunk.contains("Content family: KC-02"), true)
        @Expect(result.records[0].chunk.contains("Update mechanism: KU-11"), true)
    }

    @TestCase
    public func p6Neg001ReferenceAndHiddenSignalsAreRejected(): Unit {
        let inputs = ArrayList<CangjieBenchmarkGapInput>()
        let input = CangjieBenchmarkGapInput()
        input.caseId = "CJ-HUMANEVAL-001"
        input.taskText = "Read test/cangjie_eval/cases/Cangjie-HumanEval/CJ-HUMANEVAL-001/reference/answer.cj"
        input.officialCitation = "https://docs.cangjie-lang.cn/docs/1.0.0/"
        inputs.add(input)

        let result = curateBenchmarkGapRecords(inputs)

        @Expect(result.ok, false)
        @Expect(result.accepted, 0)
        @Expect(result.rejected, 1)
        @Expect(result.diagnostics[0].contains("hidden_or_reference_source_rejected"), true)
    }

    @TestCase
    public func f7Ut001ParsesGateJsonlIntoCuratedTraceableRecords(): Unit {
        let jsonl = "{\"caseId\":\"CJ-HUMANEVAL-002\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Implement frequency map.\",\"visibleTestExcerpt\":\"assert solve([1,1]) == 2\",\"compilerOutput\":\"compile_error\",\"missingKnowledge\":\"G-HASHMAP\",\"interfaceId\":\"KI-02\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"1.0.0\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection\"}\n"

        let result = curateBenchmarkGapRecordsFromJsonl(jsonl)

        @Expect(result.ok, true)
        @Expect(result.accepted, 1)
        @Expect(result.records[0].metadata.targetVersion, "1.0.0")
        @Expect(result.records[0].metadata.symbol, "KI-02:G-HASHMAP")
        @Expect(result.records[0].metadata.path.contains("/KI-02"), true)
        @Expect(result.records[0].chunk.contains("Content family: KC-02"), true)
    }

    @TestCase
    public func f7Bnd001CurationJsonlWithoutOfficialCitationIsRejected(): Unit {
        let jsonl = "{\"caseId\":\"CJ-HUMANEVAL-003\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Implement tuple result.\",\"missingKnowledge\":\"G-TUPLE\",\"interfaceId\":\"KI-04\",\"contentFamily\":\"KC-01\",\"updateMechanism\":\"KU-11\"}\n"

        let result = curateBenchmarkGapRecordsFromJsonl(jsonl)

        @Expect(result.ok, false)
        @Expect(result.accepted, 0)
        @Expect(result.rejected, 1)
        @Expect(result.diagnostics[0].contains("official_citation_required"), true)
    }
}
