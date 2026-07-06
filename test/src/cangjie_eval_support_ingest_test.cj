package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*

@Test
public class CangjieEvalSupportIngestTest {
    @TestCase
    public func p2Pos002ExtractsVisibleEvalSupportRecords(): Unit {
        let result = extractEvalSupportRecords("test/cangjie_eval/cases/Cangjie-HumanEval/CJ-HUMANEVAL-000")

        @Expect(result.ok, true)
        @Expect(result.records.size, 4)
        @Expect(cangjieEvalSupportTestContainsFamily(result, "prompt"), true)
        @Expect(cangjieEvalSupportTestContainsFamily(result, "metadata"), true)
        @Expect(cangjieEvalSupportTestContainsFamily(result, "eval_support"), true)
        @Expect(cangjieEvalSupportTestContainsFamily(result, "visible_test_helpers"), true)
        @Expect(cangjieEvalSupportTestContentContains(result, "EvalValue"), true)
        @Expect(cangjieEvalSupportTestContentContains(result, "EvalEntry"), true)
    }

    @TestCase
    public func p2Bnd002VisibleTestsExcludeMainAssertions(): Unit {
        let result = extractEvalSupportRecords("test/cangjie_eval/cases/Cangjie-HumanEval/CJ-HUMANEVAL-000")
        let helpers = cangjieEvalSupportTestFamilyContent(result, "visible_test_helpers")

        @Expect(helpers.contains("func listOfFloat64"), true)
        @Expect(helpers.contains("main(): Int64"), false)
        @Expect(helpers.contains("has_close_elements("), false)
    }

    @TestCase
    public func p2Neg002ReferenceSolutionPathIsRejected(): Unit {
        let result = extractEvalSupportRecords("test/cangjie_eval/cases/Cangjie-HumanEval/CJ-HUMANEVAL-000/reference")

        @Expect(result.ok, false)
        @Expect(result.diagnostics.contains("forbidden_reference_solution_source"), true)
        @Expect(result.records.size, 0)
    }
}

private func cangjieEvalSupportTestContainsFamily(result: CangjieTypedRecordResult, family: String): Bool {
    for (record in result.records) {
        if (record.sourceFamily == family) {
            return true
        }
    }
    false
}

private func cangjieEvalSupportTestContentContains(result: CangjieTypedRecordResult, needle: String): Bool {
    for (record in result.records) {
        if (record.content.contains(needle)) {
            return true
        }
    }
    false
}

private func cangjieEvalSupportTestFamilyContent(result: CangjieTypedRecordResult, family: String): String {
    for (record in result.records) {
        if (record.sourceFamily == family) {
            return record.content
        }
    }
    ""
}
