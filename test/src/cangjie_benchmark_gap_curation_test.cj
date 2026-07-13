package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieBenchmarkGapCurationTest {
    @TestCase
    public func p7S1U01StrictJsonParserPreservesUnicodeEscapesAndFieldOrder(): Unit {
        let jsonl = "  { \"officialCitation\" : \"https://docs.cangjie-lang.cn/docs/1.0.0/\", \"targetVersion\" : \"1.0.0\", \"updateMechanism\" : \"KU-11\", \"contentFamily\" : \"KC-02\", \"interfaceId\" : \"KI-02\", \"missingKnowledge\" : \"G-STRING\", \"compilerOutput\" : \"编译失败 😀\", \"visibleTestExcerpt\" : \"line\\n\\\"quoted\\\"\", \"taskText\" : \"处理中文与 emoji 😀\", \"benchmark\" : \"Cangjie-HumanEval\", \"caseId\" : \"CJ-HUMANEVAL-UTF8\" }  \n"

        let parsed = parseBenchmarkGapInputsJsonl(jsonl)
        let result = curateBenchmarkGapRecordsFromJsonl(jsonl)

        @Expect(parsed.ok, true)
        @Expect(parsed.inputs.size, 1)
        @Expect(parsed.inputs[0].taskText, "处理中文与 emoji 😀")
        @Expect(parsed.inputs[0].visibleTestExcerpt, "line\n\"quoted\"")
        @Expect(result.ok, true)
        @Expect(result.records[0].chunk.contains("编译失败 😀"), true)
    }

    @TestCase
    public func p7S1B01ParserAccepts440RowsAndEnforcesIdentityBoundaries(): Unit {
        var jsonl = "\n"
        for (i in 0..440) {
            jsonl += p7S1GapJson("CJ-HUMANEVAL-${i}", "task-${i}")
        }
        let accepted = curateBenchmarkGapRecordsFromJsonl(jsonl)
        let slash = curateBenchmarkGapRecordsFromJsonl(p7S1GapJson("CJ/HUMANEVAL", "task"))
        let emoji = curateBenchmarkGapRecordsFromJsonl(p7S1GapJson("CJ-😀", "task"))
        let longCase = curateBenchmarkGapRecordsFromJsonl(p7S1GapJson(p7S1Repeat("C", 257), "task"))
        let longField = curateBenchmarkGapRecordsFromJsonl(p7S1GapJson("CJ-LONG", p7S1Repeat("中😀", 32769)))

        @Expect(accepted.ok, true)
        @Expect(accepted.accepted, 440)
        @Expect(slash.diagnostic, "case_id_invalid")
        @Expect(emoji.diagnostic, "case_id_invalid")
        @Expect(longCase.diagnostic, "case_id_invalid")
        @Expect(longField.diagnostic, "benchmark_gap_field_too_long")
    }

    @TestCase
    public func p7S1P01ExactDuplicateIsCanonicalAndIdempotent(): Unit {
        let row = p7S1GapJson("CJ-DUPLICATE", "中文 😀")
        let result = curateBenchmarkGapRecordsFromJsonl(row + row)

        @Expect(result.ok, true)
        @Expect(result.accepted, 1)
        @Expect(result.duplicates, 1)
        @Expect(result.records.size, 1)
        @Expect(result.records[0].sourceId, "curated-gap-${stableSummaryHash("CJ-DUPLICATE:KI-02:KC-02:KU-11:G-ARRAYLIST")}")
    }

    @TestCase
    public func p7S1N01MalformedMissingKnowledgeConflictAndPartialFailClosed(): Unit {
        let valid = p7S1GapJson("CJ-CONFLICT", "safe task")
        let conflict = p7S1GapJson("CJ-CONFLICT", "different task")
        let conflicted = curateBenchmarkGapRecordsFromJsonl(valid + conflict)
        let malformed = curateBenchmarkGapRecordsFromJsonl(valid + "{\"caseId\":\"secret-token-value\"\n")
        let missing = curateBenchmarkGapRecordsFromJsonl("{\"caseId\":\"CJ-MISSING\",\"taskText\":\"task\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\"}\n")
        let wrongType = curateBenchmarkGapRecordsFromJsonl("{\"caseId\":7,\"taskText\":\"task\"}\n")
        let hostileCitation = curateBenchmarkGapRecordsFromJsonl(p7S1GapJson("CJ-HOST", "task").replace("https://docs.cangjie-lang.cn/", "https://docs.cangjie-lang.cn.evil.invalid/"))

        @Expect(conflicted.ok, false)
        @Expect(conflicted.diagnostic, "benchmark_gap_identity_conflict")
        @Expect(conflicted.records.size, 0)
        @Expect(conflicted.diagnostics[0].contains("different task"), false)
        @Expect(malformed.ok, false)
        @Expect(malformed.diagnostic, "malformed_json")
        @Expect(malformed.records.size, 0)
        @Expect(malformed.diagnostics[0], "line=2:errorCode=malformed_json")
        @Expect(malformed.diagnostics[0].contains("secret-token-value"), false)
        @Expect(missing.diagnostic, "missing_knowledge_required")
        @Expect(wrongType.diagnostic, "field_contract_invalid")
        @Expect(hostileCitation.diagnostic, "official_citation_not_allowed")
    }

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

    @TestCase
    public func f7Neg001CurationJsonlWithWrongInterfaceMappingIsRejected(): Unit {
        let jsonl = "{\"caseId\":\"CJ-HUMANEVAL-004\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Implement ArrayList helper.\",\"compilerOutput\":\"compile_error\",\"missingKnowledge\":\"G-ARRAYLIST\",\"interfaceId\":\"KI-04\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"1.0.0\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection\"}\n"

        let result = curateBenchmarkGapRecordsFromJsonl(jsonl)

        @Expect(result.ok, false)
        @Expect(result.accepted, 0)
        @Expect(result.rejected, 1)
        @Expect(result.diagnostics[0].contains("interface_mapping_mismatch:KI-02"), true)
    }
}

private func p7S1GapJson(caseId: String, taskText: String): String {
    "{\"caseId\":\"${caseId}\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"${taskText}\",\"visibleTestExcerpt\":\"assert true\",\"compilerOutput\":\"compile_error\",\"missingKnowledge\":\"G-ARRAYLIST\",\"interfaceId\":\"KI-02\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"1.0.0\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection\"}\n"
}

private func p7S1Repeat(value: String, count: Int64): String {
    let out = StringBuilder()
    for (_ in 0..count) { out.append(value) }
    out.toString()
}
