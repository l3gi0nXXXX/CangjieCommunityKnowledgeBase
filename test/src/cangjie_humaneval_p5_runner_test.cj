package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*

@Test
public class CangjieHumanEvalP5RunnerTest {
    @TestCase
    public func p5Pos01DevelopmentLineagePromptAndResultAreExplicit(): Unit {
        let options = parseCkbAbcdeRunnerOptions(["cangjie-eval-abcde", "--run-mode", "development", "--dataset-version", "dataset-v1", "--candidate-version", "candidate-v2", "--knowledge-version", "knowledge-v2", "--model-fingerprint", "glm-5.2-fixed", "--run-id", "run-中😀"])
        @Expect(ckbAbcdeDevelopmentOptionsDiagnostic(options), "")
        let prompt = renderCkbAbcdePromptForMode(CkbAbcdeGroups.C, "CJ-HUMANEVAL-000", "实现中文 😀", "{}", options.runMode)
        @Expect(prompt.contains("Run mode: development"), true)
        @Expect(prompt.contains("@Expect("), false)
        let row = ckbAbcdeRenderCaseResult(options, "target/p5", "CJ-HUMANEVAL-000", CkbAbcdeGroups.C, "passed", 0, 0, true, true, "none", "cangjie_task_knowledge_pack", "none", "target/p5/missing-artifacts")
        @Expect(row.contains("\"developmentPass\":true"), true)
        @Expect(row.contains("\"datasetVersion\":\"dataset-v1\""), true)
        @Expect(row.contains("\"candidateVersion\":\"candidate-v2\""), true)
        @Expect(row.contains("\"lineageKnowledgeVersion\":\"knowledge-v2\""), true)
        @Expect(row.contains("\"workspaceId\":\"run-中😀:CJ-HUMANEVAL-000"), true)
    }

    @TestCase
    public func p5Neg01RetryAndCrossCaseReuseNeverBecomePassAt1(): Unit {
        let attempts = "{\"attempt\":1,\"exitCode\":1}\n{\"attempt\":2,\"exitCode\":0}\n"
        @Expect(ckbAbcdeUnitPassAt1FromAttemptsForTest(true, attempts), false)
        @Expect(ckbAbcdeIsolationDiagnostic("case-b", "ws-a", "session-b", "runtime-b", "case-a", "ws-a", "session-a", "runtime-a"), "cross_case_isolation_reuse")
        @Expect(ckbAbcdeFailureRoute("reasoning_error"), "model_capability")
        @Expect(ckbAbcdeFailureRoute("tool_failure"), "infrastructure_repair")
    }

    @TestCase
    public func p5E2e01DevelopmentClosureStaysSeparateFromCertification(): Unit {
        let row = parseCkbCdGapAuditResultLine("{\"caseId\":\"CJ-HUMANEVAL-000\",\"group\":\"C-ckb-mcp-stdio\",\"runMode\":\"development\",\"datasetVersion\":\"dataset-v1\",\"candidateVersion\":\"candidate-v2\",\"lineageKnowledgeVersion\":\"knowledge-v2\",\"developmentPass\":true,\"certificationPassAt1\":false,\"unitPassAt1\":false,\"failureType\":\"none\",\"protocolViolation\":false}")
        @Expect(row.ok, true)
        @Expect(classifyPassAt1(row), "development_closed")
        @Expect(row.certificationPassAt1, false)
        let pack = buildCangjieTaskKnowledgePackForFixedVersion(newOfflineKnowledgeBase(), CangjieTaskKnowledgeRequest(), defaultCangjieVersionManifest(), "not-active")
        @Expect(pack.degraded, true)
        @Expect(pack.diagnostics.contains("knowledge_version_lineage_mismatch"), true)
    }

    @TestCase
    public func p5Bnd01InvalidModeLineageAndMalformedPayloadFailClosed(): Unit {
        let invalid = CkbAbcdeRunnerOptions()
        invalid.explicitRunMode = true
        invalid.runMode = "unknown"
        @Expect(ckbAbcdeDevelopmentOptionsDiagnostic(invalid), "run_mode_invalid")
        let malformed = parseCkbCdGapAuditResultLine("{\"caseId\":\"中文😀\"")
        @Expect(malformed.ok, false)
        @Expect(malformed.diagnostic, "malformed_result_row")
        @Expect(ckbAbcdeFailureTypeForTest(124, 1, false, "none", "超时😀", true), "timeout")
        @Expect(ckbAbcdeFailureTypeForTest(0, 1, false, "none", "compile error 中文😀", true), "compile_error")
    }
}
