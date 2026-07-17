package cangjie_community_knowledge_base_test

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*
import std.fs.{Directory, File, Path, exists}
import std.time.DateTime

@Test
public class CangjieHumanEvalP5RunnerTest {
    @TestCase
    public func p5Pos01DevelopmentLineagePromptAndResultAreExplicit(): Unit {
        let options = parseCkbAbcdeRunnerOptions(["cangjie-eval-abcde", "--run-mode", "development", "--dataset-version", "dataset-v1", "--candidate-version", "candidate-v2", "--knowledge-version", "knowledge-v2", "--model-fingerprint", "glm-5.2-fixed", "--claude-bin", "/usr/bin/true", "--run-id", "run-中😀"])
        @Expect(ckbAbcdeDevelopmentOptionsDiagnostic(options), "")
        let prompt = renderCkbAbcdePromptForMode(CkbAbcdeGroups.C, "CJ-HUMANEVAL-000", "实现中文 😀", "{}", options.runMode)
        @Expect(prompt.contains("Run mode: development"), true)
        @Expect(prompt.contains("@Expect("), false)
        let groupRoot = "target/p5/observed-identity-中😀"
        p5WriteObservedIdentity(groupRoot, "GLM-5.2")
        let row = ckbAbcdeRenderCaseResult(options, "target/p5", "CJ-HUMANEVAL-000", CkbAbcdeGroups.C, "passed", 0, 0, true, true, "none", "cangjie_task_knowledge_pack", "none", groupRoot)
        @Expect(row.contains("\"developmentPass\":true"), true)
        @Expect(row.contains("\"datasetVersion\":\"dataset-v1\""), true)
        @Expect(row.contains("\"candidateVersion\":\"candidate-v2\""), true)
        @Expect(row.contains("\"lineageKnowledgeVersion\":\"knowledge-v2\""), true)
        @Expect(row.contains("\"workspaceId\":\"cases/CJ-HUMANEVAL-000/C-ckb-mcp-stdio/workspace\""), true)
        @Expect(row.contains("\"certificationPassAt1\":null"), true)
        @Expect(row.contains("\"triageStatus\":\"none\""), true)
        @Expect(row.contains("\"expectedModelVersion\":\"GLM-5.2\""), true)
        @Expect(row.contains("\"observedModelVersion\":\"GLM-5.2\""), true)
        @Expect(row.contains("\"model\":\"GLM-5.2\""), true)
        @Expect(row.contains("\"providerIdentityHash\":\"sha256:"), true)
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
    public func p5Neg02RetrySuccessRecordsFinalAttemptWithoutForgingFirstPass(): Unit {
        let root = "target/p5-retry-facts-${DateTime.now().toUnixTimeStamp().toMilliseconds()}"
        Directory.create(root, recursive: true)
        File.writeTo("${root}/claude-attempts.jsonl", "{\"attempt\":1,\"exitCode\":1}\n{\"attempt\":2,\"exitCode\":0}\n".toArray())
        p5WriteObservedIdentity(root, "GLM-5.2")
        let options = CkbAbcdeRunnerOptions(); options.explicitRunMode = true; options.runMode = "development"; options.runId = "run-retry"; options.datasetVersion = "dataset-v1"; options.candidateVersion = "candidate-v1"; options.knowledgeVersion = "knowledge-v1"
        let result = ckbAbcdeRenderCaseResult(options, root, "CASE-RETRY", CkbAbcdeGroups.C, "passed", 0, 0, true, false, "none", "tool", "none", root)
        @Expect(result.contains("\"developmentPass\":true"), true)
        @Expect(result.contains("\"firstAttemptPass\":false"), true)
        @Expect(result.contains("\"firstAttemptTriage\":\"environment_failure\""), true)
        @Expect(result.contains("\"claudeAttemptCount\":2"), true)
    }

    @TestCase
    public func p5Neg03MissingMismatchedOrTamperedObservedIdentityCannotClose(): Unit {
        let options = CkbAbcdeRunnerOptions(); options.explicitRunMode = true; options.runMode = "development"; options.runId = "identity-negative"; options.datasetVersion = "dataset-v1"; options.candidateVersion = "candidate-v1"; options.knowledgeVersion = "knowledge-v1"
        let suffix = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let missingRoot = "target/p5-identity-missing-${suffix}"
        Directory.create(missingRoot, recursive: true)
        let missing = ckbAbcdeRenderCaseResult(options, missingRoot, "CASE-MISSING", CkbAbcdeGroups.C, "passed", 0, 0, true, true, "none", "tool", "none", missingRoot)
        @Expect(missing.contains("\"developmentPass\":false"), true)
        @Expect(missing.contains("\"observedModelVersion\":\"\""), true)
        @Expect(missing.contains("\"providerIdentityHash\":\"\""), true)

        let mismatchRoot = "target/p5-identity-mismatch-${suffix}"
        p5WriteObservedIdentity(mismatchRoot, "other-model")
        let mismatch = ckbAbcdeRenderCaseResult(options, mismatchRoot, "CASE-MISMATCH", CkbAbcdeGroups.C, "passed", 0, 0, true, true, "none", "tool", "none", mismatchRoot)
        @Expect(mismatch.contains("\"developmentPass\":false"), true)
        @Expect(mismatch.contains("\"observedModelVersion\":\"other-model\""), true)

        let tamperedRoot = "target/p5-identity-tampered-${suffix}"
        p5WriteObservedIdentity(tamperedRoot, "GLM-5.2")
        File.writeTo("${tamperedRoot}/provider-identity.json", "{\"provider\":\"伪造😀\",\"model\":\"GLM-5.2\"}\n".toArray())
        let tampered = ckbAbcdeRenderCaseResult(options, tamperedRoot, "CASE-TAMPERED", CkbAbcdeGroups.C, "passed", 0, 0, true, true, "none", "tool", "none", tamperedRoot)
        @Expect(tampered.contains("\"developmentPass\":false"), true)
        @Expect(tampered.contains("\"closureStatus\":\"development_open\""), true)
        @Expect(tampered.contains("伪造"), false)
    }

    @TestCase
    public func p5E2e01DevelopmentClosureStaysSeparateFromCertification(): Unit {
        let row = parseCkbCdGapAuditResultLine("{\"caseId\":\"CJ-HUMANEVAL-000\",\"group\":\"C-ckb-mcp-stdio\",\"runMode\":\"development\",\"datasetVersion\":\"dataset-v1\",\"candidateVersion\":\"candidate-v2\",\"lineageKnowledgeVersion\":\"knowledge-v2\",\"developmentPass\":true,\"certificationPassAt1\":null,\"closureStatus\":\"development_closed\",\"triageStatus\":\"none\",\"failureRoute\":\"none\",\"unitPassAt1\":false,\"failureType\":\"none\",\"protocolViolation\":false}")
        @Expect(row.ok, true)
        @Expect(classifyPassAt1(row), "development_closed")
        @Expect(row.certificationStatus, "unset")
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

    @TestCase
    public func p5RegressionLegacyAndExplicitFailureAccountingStaySeparated(): Unit {
        let legacy = parseCkbCdGapAuditResultLine("{\"caseId\":\"CJ-HUMANEVAL-001\",\"group\":\"C-ckb-mcp-stdio\",\"unitPassAt1\":true,\"failureType\":\"none\",\"protocolViolation\":false}")
        @Expect(legacy.ok, true)
        @Expect(classifyPassAt1(legacy), "ok")
        let protocol = parseCkbCdGapAuditResultLine("{\"caseId\":\"CJ-HUMANEVAL-002\",\"group\":\"D-ckb-mcp-http\",\"runMode\":\"development\",\"datasetVersion\":\"dataset-v1\",\"candidateVersion\":\"candidate-v2\",\"lineageKnowledgeVersion\":\"knowledge-v2\",\"developmentPass\":false,\"certificationPassAt1\":null,\"closureStatus\":\"development_open\",\"triageStatus\":\"protocol_violation\",\"failureRoute\":\"protocol\",\"unitPassAt1\":true,\"failureType\":\"policy_violation\",\"protocolViolation\":true}")
        @Expect(protocol.ok, true)
        @Expect(classifyPassAt1(protocol), "development_open")
        let certification = protocol.raw.replace("\"development\"", "\"certification\"").replace("\"candidate-v2\"", "\"\"")
        @Expect(classifyPassAt1(parseCkbCdGapAuditResultLine(certification)), "certification_not_run")
    }

    @TestCase
    public func p5Bnd02StrictJsonHandlesUnicodeAndRejectsWrongTypes(): Unit {
        let unicode = parseCkbCdGapAuditResultLine("{\"caseId\":\"CJ-HUMANEVAL-003\",\"group\":\"C-ckb-mcp-stdio\",\"runMode\":\"development\",\"datasetVersion\":\"版本-\\u4e2d\\ud83d\\ude00\",\"candidateVersion\":\"candidate-v2\",\"lineageKnowledgeVersion\":\"knowledge-v2\",\"developmentPass\":false,\"certificationPassAt1\":null,\"closureStatus\":\"development_open\",\"triageStatus\":\"reasoning_failure\",\"failureRoute\":\"reasoning\",\"unitPassAt1\":false,\"failureType\":\"unit_failure\",\"protocolViolation\":false}")
        @Expect(unicode.ok, true)
        @Expect(unicode.datasetVersion.contains("中"), true)
        let wrongType = unicode.raw.replace("\"developmentPass\":false", "\"developmentPass\":\"false\"")
        @Expect(parseCkbCdGapAuditResultLine(wrongType).diagnostic, "malformed_result_row")
        let wrongCase = unicode.raw.replace("\"caseId\":\"CJ-HUMANEVAL-003\"", "\"caseId\":3")
        @Expect(parseCkbCdGapAuditResultLine(wrongCase).diagnostic, "malformed_result_row")
    }

    @TestCase
    public func p5E2e02FiveCaseOrchestratorEmitsOnlyDoubleConfirmedKnowledgeGap(): Unit {
        let inputs = ArrayList<CangjieEvalDevelopmentClosureInput>()
        inputs.add(p5ClosureInput("knowledge", "\"suspectedKnowledgeGap\":true", false, true))
        inputs.add(p5ClosureInput("reasoning", "\"reasoningFailure\":true", false, false))
        inputs.add(p5ClosureInput("dataset", "\"datasetFailure\":true", false, false))
        inputs.add(p5ClosureInput("environment", "\"environmentFailure\":true", false, false))
        inputs.add(p5ClosureInput("success", "\"unitPass\":true", true, false))
        let initial = orchestrateDevelopmentClosure(inputs, "teacher-run-001")
        @Expect(initial.ok, true)
        @Expect(initial.knowledgeGapCount, 1)
        @Expect(initial.authoritativeGapJsonl.split("\n").size >= 1, true)
        @Expect(curateBenchmarkGapRecordsFromJsonl(initial.authoritativeGapJsonl).records.size, 1)
        @Expect(initial.developmentClosureJson.contains("\"certificationStatus\":\"unset\""), true)
        let pendingInput = ArrayList<CangjieEvalDevelopmentClosureInput>(); pendingInput.add(p5ClosureInput("pending", "\"suspectedKnowledgeGap\":true", false, false))
        let pending = orchestrateDevelopmentClosure(pendingInput, "teacher-run-pending")
        @Expect(pending.pendingClassifierCount, 1)
        @Expect(pending.authoritativeGapJsonl, "")

        let fixed = ArrayList<CangjieEvalDevelopmentClosureInput>()
        for (name in ["knowledge", "reasoning", "dataset", "environment", "success"]) { fixed.add(p5ClosureInput(name, "\"unitPass\":true", true, false)) }
        let closed = orchestrateDevelopmentClosure(fixed, "teacher-run-002")
        @Expect(closed.authoritativeGapJsonl, "")
        @Expect(closed.developmentClosureJson.contains("\"developmentClosed\":true"), true)
        @Expect(closed.developmentClosureJson.contains("\"developmentPassed\":5"), true)

        fixed[1].caseResultJson = fixed[1].caseResultJson.replace("cases/reasoning", "cases/knowledge")
        let duplicate = orchestrateDevelopmentClosure(fixed, "teacher-run-003")
        @Expect(duplicate.ok, false)
        @Expect(duplicate.diagnostics[0].contains("duplicate_isolation_identity"), true)
    }
}

private func p5WriteObservedIdentity(groupRoot: String, model: String): Unit {
    if (!exists(Path(groupRoot))) { Directory.create(groupRoot, recursive: true) }
    File.writeTo("${groupRoot}/claude-transcript.jsonl", "{\"type\":\"system\",\"subtype\":\"init\",\"model\":\"${model}\"}\n".toArray())
    File.writeTo("${groupRoot}/provider-identity.json", ckbAbcdeProviderIdentityJson(model, ckbAbcdeClaudeVersionForTest()).toArray())
}

private func p5ClosureInput(name: String, signal: String, developmentPass: Bool, classifiers: Bool): CangjieEvalDevelopmentClosureInput {
    let item = CangjieEvalDevelopmentClosureInput()
    let caseId = "CASE-${name}"
    item.caseResultJson = "{\"caseId\":\"${caseId}\",\"runId\":\"run-e2e\",\"datasetVersion\":\"dataset-v1\",\"runMode\":\"development\",\"workspaceId\":\"cases/${name}/workspace\",\"sessionId\":\"cases/${name}/session\",\"runtimeHomeId\":\"cases/${name}/runtime-home\",\"developmentPass\":${developmentPass},\"certificationPassAt1\":null}"
    let raw = "{\"caseId\":\"${caseId}\",\"runId\":\"run-e2e\",\"datasetVersion\":\"dataset-v1\",\"attempt\":1,\"runMode\":\"development\",\"failureObservation\":\"observed ${name}\",${signal},\"resultEvidenceHash\":\"HASH\"}"
    item.resultEvidenceJson = raw.replace("HASH", cangjieEvalTriageResultEvidenceHash(raw))
    item.taskText = "Reusable Rune task ${name}"
    if (classifiers) {
        item.firstClassifierJson = p5RunnerClassifier(caseId, "classifier-a", "artifact-a", item.resultEvidenceJson)
        item.secondClassifierJson = p5RunnerClassifier(caseId, "classifier-b", "artifact-b", item.resultEvidenceJson)
    }
    item
}

private func p5RunnerClassifier(caseId: String, classifierId: String, sourceEvidenceId: String, resultEvidence: String): String {
    let resultHash = cangjieEvalTriageResultEvidenceHash(resultEvidence)
    let request="{\"schemaVersion\":\"ckb-p5-classifier-request-v1\",\"caseId\":\"${caseId}\",\"runId\":\"run-e2e\",\"datasetVersion\":\"dataset-v1\",\"attempt\":1,\"runMode\":\"development\",\"resultEvidenceHash\":\"${resultHash}\",\"failureObservation\":\"missing reusable Rune guidance\"}"
    let c=CkbP5ClassifierConfig();c.label=sourceEvidenceId;c.classifierId=classifierId;c.provider=sourceEvidenceId;c.model="model-${classifierId}";c.executable="/fake/${sourceEvidenceId}"
    let response="{\"schemaVersion\":\"ckb-p5-classifier-response-v1\",\"observedProvider\":\"${sourceEvidenceId}\",\"observedModel\":\"model-${classifierId}\",\"category\":\"knowledge_gap\",\"knowledgeFamily\":\"standard_library\",\"reusable\":true,\"sourceClass\":\"official\",\"citation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/\",\"purificationPassed\":true,\"canonicalKnowledgeId\":\"GENERAL-RUNE\",\"targetVersion\":\"1.0.0\",\"evidenceId\":\"official-rune-doc\",\"knowledgeText\":\"General reusable Rune guidance.\"}"
    sealCkbP5ClassifierResponse(request,response,c,"/tmp/${sourceEvidenceId}/workspace","/tmp/${sourceEvidenceId}/home","${sourceEvidenceId}-session")
}
