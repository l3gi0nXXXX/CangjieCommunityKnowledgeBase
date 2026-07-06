package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieHumanEvalPass1GateTest {
    @TestCase
    public func p8Ut001PassesCompleteCd164EquivalentFixture(): Unit {
        let options = CangjieHumanEvalPass1GateOptions()
        options.expectedTotal = 2
        options.expectedPass = 2
        let manifest = p8ManifestLine("CJ-HUMANEVAL-000", "Implement ArrayList sum.", "[\"ArrayList\",\"Int64\"]") + "\n" +
            p8ManifestLine("CJ-HUMANEVAL-001", "Implement String reverse.", "[\"String\"]") + "\n"
        let results = p8ResultLine("CJ-HUMANEVAL-000", CangjieHumanEvalPass1GateGroups.C, true, "none", false, "cangjie_task_knowledge_pack") + "\n" +
            p8ResultLine("CJ-HUMANEVAL-000", CangjieHumanEvalPass1GateGroups.D, true, "none", false, "cangjie_task_knowledge_pack") + "\n" +
            p8ResultLine("CJ-HUMANEVAL-001", CangjieHumanEvalPass1GateGroups.C, true, "none", false, "cangjie_task_knowledge_pack") + "\n" +
            p8ResultLine("CJ-HUMANEVAL-001", CangjieHumanEvalPass1GateGroups.D, true, "none", false, "cangjie_task_knowledge_pack") + "\n"

        let gate = cangjieHumanEvalPass1GateFromText(results, manifest, options, "/tmp/p8-pass", "/tmp/manifest.jsonl")

        @Expect(gate.ok, true)
        @Expect(gate.manifestCaseCount, 2)
        @Expect(gate.groups[0].total, 2)
        @Expect(gate.groups[0].passAt1, 2)
        @Expect(gate.groups[1].total, 2)
        @Expect(gate.groups[1].passAt1, 2)
        @Expect(gate.remainingGaps.size, 0)
    }

    @TestCase
    public func p8Bnd001ReportsDuplicateMissingProtocolAndTransportFailures(): Unit {
        let options = CangjieHumanEvalPass1GateOptions()
        options.expectedTotal = 2
        options.expectedPass = 2
        let manifest = p8ManifestLine("CJ-HUMANEVAL-000", "Implement ArrayList sum.", "[\"ArrayList\"]") + "\n" +
            p8ManifestLine("CJ-HUMANEVAL-001", "Implement String reverse.", "[\"String\"]") + "\n"
        let results = p8ResultLine("CJ-HUMANEVAL-000", CangjieHumanEvalPass1GateGroups.C, true, "none", false, "cangjie_task_knowledge_pack") + "\n" +
            p8ResultLine("CJ-HUMANEVAL-000", CangjieHumanEvalPass1GateGroups.C, true, "none", false, "cangjie_task_knowledge_pack") + "\n" +
            p8ResultLine("CJ-HUMANEVAL-001", CangjieHumanEvalPass1GateGroups.C, false, "compile_error", true, "manual_required") + "\n" +
            p8ResultLine("CJ-HUMANEVAL-000", CangjieHumanEvalPass1GateGroups.D, false, "model_error", false, "manual_required") + "\n"

        let gate = cangjieHumanEvalPass1GateFromText(results, manifest, options, "/tmp/p8-fail", "/tmp/manifest.jsonl")
        let markdown = renderCangjieHumanEvalPass1GateMarkdown(gate)

        @Expect(gate.ok, false)
        @Expect(p8DiagnosticsContain(gate, "duplicate_result_rows:C-ckb-mcp-stdio:1"), true)
        @Expect(p8DiagnosticsContain(gate, "missing_result_rows:D-ckb-mcp-http:1"), true)
        @Expect(p8DiagnosticsContain(gate, "protocol_violation_rows:C-ckb-mcp-stdio:1"), true)
        @Expect(p8DiagnosticsContain(gate, "transport_parity_failure_rows:D-ckb-mcp-http:1"), true)
        @Expect(markdown.contains("releaseGate: fail"), true)
    }

    @TestCase
    public func p8Pos001RemainingGapMapsTagsToGapCodesAndKiInterfaces(): Unit {
        let options = CangjieHumanEvalPass1GateOptions()
        options.expectedTotal = 1
        options.expectedPass = 1
        let manifest = p8ManifestLine("CJ-HUMANEVAL-000", "Implement ArrayList sum.", "[\"ArrayList\",\"Int64\"]") + "\n"
        let results = p8ResultLine("CJ-HUMANEVAL-000", CangjieHumanEvalPass1GateGroups.C, false, "compile_error", false, "cangjie_task_knowledge_pack") + "\n" +
            p8ResultLine("CJ-HUMANEVAL-000", CangjieHumanEvalPass1GateGroups.D, true, "none", false, "cangjie_task_knowledge_pack") + "\n"

        let gate = cangjieHumanEvalPass1GateFromText(results, manifest, options, "/tmp/p8-gap", "/tmp/manifest.jsonl")
        let json = renderCangjieHumanEvalPass1GateJson(gate)

        @Expect(gate.ok, false)
        @Expect(gate.remainingGaps.size, 1)
        @Expect(json.contains("\"G-ARRAYLIST\""), true)
        @Expect(json.contains("\"G-INT64\""), true)
        @Expect(json.contains("\"KI-04\""), true)
        @Expect(json.contains("\"KI-06\""), true)
        @Expect(json.contains("\"KI-07\""), true)
    }

    @TestCase
    public func p8Neg001CurationInputUsesVisibleTaskAndRejectsReferenceSignals(): Unit {
        let options = CangjieHumanEvalPass1GateOptions()
        options.expectedTotal = 1
        options.expectedPass = 1
        let manifest = p8ManifestLine("CJ-HUMANEVAL-000", "Implement String helper.", "[\"String\"]") + "\n"
        let results = p8ResultLine("CJ-HUMANEVAL-000", CangjieHumanEvalPass1GateGroups.C, false, "compile_error", false, "cangjie_task_knowledge_pack") + "\n" +
            p8ResultLine("CJ-HUMANEVAL-000", CangjieHumanEvalPass1GateGroups.D, false, "compile_error", false, "cangjie_task_knowledge_pack") + "\n"

        let gate = cangjieHumanEvalPass1GateFromText(results, manifest, options, "/tmp/p8-curation", "/tmp/manifest.jsonl")
        let curation = emitCangjieHumanEvalGapCurationInput(gate)

        @Expect(curation.contains("\"taskText\":\"Implement String helper.\""), true)
        @Expect(curation.contains("\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\""), true)
        @Expect(curation.contains("reference/"), false)
        @Expect(curation.contains("hidden/"), false)
    }

    @TestCase
    public func f7Ut001GateCurationInputCarriesInterfaceFamilyUpdateAndVersion(): Unit {
        let options = CangjieHumanEvalPass1GateOptions()
        options.expectedTotal = 1
        options.expectedPass = 1
        let manifest = p8ManifestLine("CJ-HUMANEVAL-010", "Implement ArrayList helper.", "[\"ArrayList\"]") + "\n"
        let results = p8ResultLine("CJ-HUMANEVAL-010", CangjieHumanEvalPass1GateGroups.D, false, "compile_error", false, "cangjie_task_knowledge_pack") + "\n"

        let gate = cangjieHumanEvalPass1GateFromText(results, manifest, options, "/tmp/f7-gate", "/tmp/manifest.jsonl")
        let curation = emitCangjieHumanEvalGapCurationInput(gate)

        @Expect(gate.ok, false)
        @Expect(curation.contains("\"missingKnowledge\":\"G-ARRAYLIST\""), true)
        @Expect(curation.contains("\"interfaceId\":\"KI-04\""), false)
        @Expect(curation.contains("\"interfaceId\":\"KI-02\""), true)
        @Expect(curation.contains("\"contentFamily\":\"KC-02\""), true)
        @Expect(curation.contains("\"updateMechanism\":\"KU-11\""), true)
        @Expect(curation.contains("\"targetVersion\":\"1.0.0\""), true)
    }
}

private func p8ManifestLine(caseId: String, prompt: String, tagsJson: String): String {
    "{\"id\":\"${caseId}\",\"category\":\"unit\",\"targetVersion\":\"1.0.0\",\"prompt\":\"${prompt}\",\"entryPoint\":\"cases/${caseId}/starter\",\"testCommand\":\"cjpm run\",\"expectedKnowledgeTags\":${tagsJson}}"
}

private func p8ResultLine(caseId: String, group: String, passAt1: Bool, failureType: String, protocolViolation: Bool, toolEvidence: String): String {
    "{\"runId\":\"unit\",\"benchmark\":\"Cangjie-HumanEval\",\"caseId\":\"${caseId}\",\"group\":\"${group}\",\"unitPassAt1\":${passAt1},\"failureType\":\"${failureType}\",\"protocolViolation\":${protocolViolation},\"toolEvidence\":\"${toolEvidence}\"}"
}

private func p8DiagnosticsContain(gate: CangjieHumanEvalPass1GateResult, needle: String): Bool {
    for (diagnostic in gate.diagnostics) {
        if (diagnostic.contains(needle)) {
            return true
        }
    }
    false
}
