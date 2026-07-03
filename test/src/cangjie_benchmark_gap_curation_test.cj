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
}
