package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieEvalKnowledgeAuditTest {
    @TestCase
    public func p0Ut001SummarizesCdUnionAndTagCounts(): Unit {
        let manifest = auditManifestLine("CJ-HUMANEVAL-000", "[\"ArrayList\",\"Float64\"]") + "\n" +
            auditManifestLine("CJ-HUMANEVAL-001", "[\"ArrayList\",\"String\"]") + "\n"
        let results = auditResultLine("CJ-HUMANEVAL-000", CkbCdGapAuditGroups.C, false, 1, 1, "compile_error") + "\n" +
            auditResultLine("CJ-HUMANEVAL-000", CkbCdGapAuditGroups.D, true, 0, 0, "none") + "\n" +
            auditResultLine("CJ-HUMANEVAL-001", CkbCdGapAuditGroups.C, true, 0, 0, "none") + "\n" +
            auditResultLine("CJ-HUMANEVAL-001", CkbCdGapAuditGroups.D, false, 0, 1, "unit_failure") + "\n"

        let summary = auditCkbCdKnowledgeGapsFromText(results, manifest, "/tmp/ckb-p0", "/tmp/manifest.jsonl")

        @Expect(summary.ok, true)
        @Expect(summary.manifestCaseCount, 2)
        @Expect(summary.parsedResultRows, 4)
        @Expect(summary.cPassAt1, 1)
        @Expect(summary.dPassAt1, 1)
        @Expect(summary.cdFailureUnion, 2)
        @Expect(summary.cOnlyFailure, 1)
        @Expect(summary.dOnlyFailure, 1)
        @Expect(summary.cdDualFailure, 0)
        @Expect(auditTagCount(summary, "ArrayList"), 2)
        @Expect(auditTagCount(summary, "Float64"), 1)
        @Expect(auditTagCount(summary, "String"), 1)
    }

    @TestCase
    public func p0Bnd001BadRowsUnknownGroupsAndMissingManifestAreDiagnostics(): Unit {
        let manifest = auditManifestLine("CJ-HUMANEVAL-000", "[\"ArrayList\"]") + "\n"
        let results = "not-json\n" +
            auditResultLine("CJ-HUMANEVAL-000", "A-no-ckb", false, 1, 1, "compile_error") + "\n" +
            auditResultLine("CJ-HUMANEVAL-999", CkbCdGapAuditGroups.C, false, 1, 1, "compile_error") + "\n"

        let summary = auditCkbCdKnowledgeGapsFromText(results, manifest, "/tmp/ckb-p0", "/tmp/manifest.jsonl")

        @Expect(summary.ok, false)
        @Expect(auditDiagnosticsContain(summary, "malformed_result_row"), true)
        @Expect(auditDiagnosticsContain(summary, "unsupported_group"), true)
        @Expect(auditDiagnosticsContain(summary, "missing_manifest_case:CJ-HUMANEVAL-999"), true)
        @Expect(auditDiagnosticsContain(summary, "missing_result_case_group:CJ-HUMANEVAL-000:D"), true)
    }

    @TestCase
    public func p0Pos001RendersMarkdownAndJsonSummary(): Unit {
        let manifest = auditManifestLine("CJ-HUMANEVAL-000", "[\"ArrayList\",\"Bool\"]") + "\n"
        let results = auditResultLine("CJ-HUMANEVAL-000", CkbCdGapAuditGroups.C, false, 1, 1, "compile_error") + "\n" +
            auditResultLine("CJ-HUMANEVAL-000", CkbCdGapAuditGroups.D, false, 124, 1, "timeout") + "\n"
        let summary = auditCkbCdKnowledgeGapsFromText(results, manifest, "/tmp/ckb-p0", "/tmp/manifest.jsonl")

        let markdown = renderCkbCdGapAuditMarkdown(summary)
        let json = renderCkbCdGapAuditJson(summary)

        @Expect(markdown.contains("C/D failure union: 1"), true)
        @Expect(markdown.contains("| ArrayList | 1 |"), true)
        @Expect(markdown.contains("| CJ-HUMANEVAL-000 | compile_error | timeout |"), true)
        @Expect(json.contains("\"cdFailureUnion\":1"), true)
        @Expect(json.contains("\"tag\":\"ArrayList\""), true)
        @Expect(json.contains("\"dStatus\":\"timeout\""), true)
    }

    @TestCase
    public func p0Neg001MissingRunRootFailsWithoutCreatingOutputs(): Unit {
        let summary = auditCkbCdKnowledgeGapsFromFiles("/tmp/ckb-p0-run-root-that-should-not-exist-20260703", "/tmp/manifest-that-should-not-exist.jsonl")

        @Expect(summary.ok, false)
        @Expect(auditDiagnosticsContain(summary, "run_root_not_found"), true)
        @Expect(summary.parsedResultRows, 0)
        @Expect(summary.cdFailureUnion, 0)
    }
}

private func auditManifestLine(caseId: String, tagsJson: String): String {
    "{\"id\":\"${caseId}\",\"category\":\"unit\",\"targetVersion\":\"1.0.0\",\"prompt\":\"Implement ${caseId}.\",\"entryPoint\":\"cases/${caseId}/starter\",\"testCommand\":\"cjpm run\",\"expectedKnowledgeTags\":${tagsJson}}"
}

private func auditResultLine(caseId: String, group: String, passAt1: Bool, firstExit: Int64, testExit: Int64, failureType: String): String {
    "{\"runId\":\"unit\",\"benchmark\":\"Cangjie-HumanEval\",\"caseId\":\"${caseId}\",\"group\":\"${group}\",\"unitPassAt1\":${passAt1},\"firstClaudeExitCode\":${firstExit},\"claudeExitCode\":${firstExit},\"testExitCode\":${testExit},\"failureType\":\"${failureType}\",\"protocolViolation\":false}"
}

private func auditDiagnosticsContain(summary: CkbCdGapAuditSummary, needle: String): Bool {
    for (diagnostic in summary.diagnostics) {
        if (diagnostic.contains(needle)) {
            return true
        }
    }
    false
}

private func auditTagCount(summary: CkbCdGapAuditSummary, tag: String): Int64 {
    for (count in summary.tagCounts) {
        if (count.tag == tag) {
            return count.count
        }
    }
    0
}
