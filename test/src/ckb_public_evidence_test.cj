package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbPublicEvidenceTest {
    @TestCase
    public func p5Ut01ProjectsOnlyTheP1PublicWhitelist(): Unit {
        let certification = p5CertificationJson(0, true)
            .replace("}", ",\"privatePrompt\":\"不得公开🙂\",\"extra\":42}")
        let projected = projectCkbPublicEvidenceRow(
            certification.toArray(), p5AuditJson(0, true, true, false).toArray())
        @Expect(projected.ok, true)
        @Expect(projected.diagnostic, "ok")
        @Expect(projected.row.caseId, "CJ-HUMANEVAL-000")
        @Expect(projected.row.classification, "none")
        @Expect(projected.row.certificationPassAt1, true)
        let publicJson = renderCkbStrictScoreEvidenceRowJson(projected.row)
        @Expect(publicJson.contains("privatePrompt"), false)
        @Expect(publicJson.contains("不得公开"), false)
        @Expect(publicJson.contains("workspaceId"), false)
        @Expect(publicJson.contains("sessionId"), false)
        @Expect(publicJson.contains("transcriptHash"), false)
        @Expect(publicJson.split("\":").size - 1, 22)
    }

    @TestCase
    public func p5Bnd01Utf8UnicodeAndMalformedInputsFailClosed(): Unit {
        let unicode = p5CertificationJsonWithRun(0, true, "公开运行🙂")
        let projected = projectCkbPublicEvidenceRow(
            unicode.toArray(), p5AuditJson(0, true, true, false).toArray())
        @Expect(projected.ok, true)
        @Expect(projected.row.runId, "公开运行🙂")
        @Expect(projectCkbPublicEvidenceRow(
            [0xff, 0xfe], p5AuditJson(0, true, true, false).toArray()).diagnostic,
            "invalid_certification_encoding")
        @Expect(projectCkbPublicEvidenceRow(
            p5CertificationJson(0, true).toArray(), [0xff, 0xfe]).diagnostic,
            "invalid_audit_encoding")
        @Expect(projectCkbPublicEvidenceRow(
            "{bad".toArray(), p5AuditJson(0, true, true, false).toArray()).diagnostic,
            "certification_malformed_json")
        @Expect(projectCkbPublicEvidenceRow(
            p5CertificationJson(0, true).toArray(), "{bad".toArray()).diagnostic,
            "audit_malformed_result_row")
    }

    @TestCase
    public func p5Pos01Fake164CanonicalProjectionRecomputes151(): Unit {
        let rows = ArrayList<CkbStrictScoreEvidenceRow>()
        for (i in 0..164) {
            let strict = i < 151
            let raw = i < 158
            let protocol = (!strict && raw) || i >= 161
            let projected = projectCkbPublicEvidenceRow(
                p5CertificationJson(i, strict).toArray(),
                p5AuditJson(i, strict, raw, protocol).toArray())
            @Expect(projected.ok, true)
            rows.add(projected.row)
        }
        let rendered = renderCkbPublicEvidence(rows)
        @Expect(rendered.ok, true)
        @Expect(rendered.diagnostic, "ok")
        @Expect(rendered.score.valid, true)
        @Expect(rendered.score.total, 164)
        @Expect(rendered.score.strictPassed, 151)
        @Expect(rendered.score.unitFirstSamplePassed, 158)
        @Expect(rendered.score.businessFailed, 3)
        @Expect(rendered.score.protocolInvalid, 10)
        @Expect(rendered.score.transportUnresolved, 0)
        @Expect(rendered.text.split("\n").size, 165)
        @Expect(rendered.evidenceHash.startsWith("sha256:"), true)
    }

    @TestCase
    public func p5Neg01LeakageAndInputDriftBlockProjection(): Unit {
        let attacks = [
            "Authorization: Bearer secret",
            "api_key=secret",
            "/Users/private/run",
            "{\"solution\":\"answer\"}",
            "{\"transcript\":\"full\"}",
            "{\"hiddenTest\":\"assert\"}",
            "{\"sessionId\":\"real\"}",
            "{\"prompt\":\"question\"}"
        ]
        for (attack in attacks) {
            let report = scanCkbPublicEvidenceLeakage(attack.toArray())
            @Expect(report.ok, false)
            @Expect(report.findingCodes.size > 0, true)
        }
        @Expect(scanCkbPublicEvidenceLeakage([0xff, 0xfe]).diagnostic,
            "invalid_response_encoding")

        let mismatch = projectCkbPublicEvidenceRow(
            p5CertificationJson(0, true).toArray(),
            p5AuditJson(1, true, true, false).toArray())
        @Expect(mismatch.ok, false)
        @Expect(mismatch.diagnostic, "case_identity_mismatch")

        let inconsistent = projectCkbPublicEvidenceRow(
            p5CertificationJson(0, true).toArray(),
            p5AuditJson(0, false, false, false).toArray())
        @Expect(inconsistent.ok, false)
        @Expect(inconsistent.diagnostic, "certification_audit_outcome_mismatch")
    }

    @TestCase
    public func p5Reg01TypedPrivateAndPublicScoreComparisonIsExact(): Unit {
        let rows = ArrayList<CkbStrictScoreEvidenceRow>()
        for (i in 0..164) {
            let strict = i < 151
            let raw = i < 158
            let protocol = (!strict && raw) || i >= 161
            rows.add(projectCkbPublicEvidenceRow(
                p5CertificationJson(i, strict).toArray(),
                p5AuditJson(i, strict, raw, protocol).toArray()).row)
        }
        let privateScore = computeCkbHumanEvalStrictScore(rows)
        let publicScore = computeCkbHumanEvalStrictScore(rows)
        let same = compareCkbPrivateAndPublicScores(
            privateScore, publicScore, rows[0], rows[0])
        @Expect(same.ok, true)
        @Expect(same.diagnostic, "ok")

        let drifted = computeCkbHumanEvalStrictScore(rows)
        drifted.strictPassed -= 1
        @Expect(compareCkbPrivateAndPublicScores(
            privateScore, drifted, rows[0], rows[0]).diagnostic,
            "score_mismatch")
        let otherIdentity = p5CopyIdentity(rows[0])
        otherIdentity.knowledgeVersion = "other"
        @Expect(compareCkbPrivateAndPublicScores(
            privateScore, publicScore, rows[0], otherIdentity).diagnostic,
            "identity_mismatch")
    }
}

private func p5CertificationJson(caseIndex: Int64, passed: Bool): String {
    p5CertificationJsonWithRun(caseIndex, passed, "public-run")
}

private func p5CertificationJsonWithRun(
    caseIndex: Int64,
    passed: Bool,
    runId: String
): String {
    let row = CkbCertificationCaseEvidence()
    row.runId = runId
    row.caseId = p5EvidenceCaseId(caseIndex)
    row.group = CkbAbcdeGroups.D
    row.datasetVersion = "dataset-v1"
    row.knowledgeVersion = "knowledge-v1"
    row.modelFingerprint = "glm-5.2"
    row.expectedModelVersion = "glm-5.2"
    row.observedModelVersion = "glm-5.2"
    row.claudeCodeVersion = "claude-code-v1"
    row.providerIdentityHash = p5Hash("provider")
    row.preflightHash = p5Hash("preflight")
    row.runManifestHash = p5Hash("manifest")
    row.authorityCaseHash = p5Hash("case-${caseIndex}")
    row.authorityTestsHash = p5Hash("tests-${caseIndex}")
    row.workspaceId = "private-workspace-${caseIndex}"
    row.sessionId = "private-session-${caseIndex}"
    row.runtimeHomeId = "private-home-${caseIndex}"
    row.isolationEvidenceHash = p5Hash("isolation-${caseIndex}")
    row.answerHash = p5Hash("answer-${caseIndex}")
    row.transcriptHash = p5Hash("transcript-${caseIndex}")
    row.testHash = p5Hash("test-${caseIndex}")
    row.configHash = p5Hash("config-${caseIndex}")
    row.artifactHash = p5Hash("artifact-${caseIndex}")
    row.sampleAttemptCount = 1
    row.lastAuditedTransportAttempt = 1
    row.selectedBusinessSample = 1
    row.transportAttemptCount = 1
    row.retryCount = 0
    row.unresolvedTransport = 0
    row.attemptLineageHash = p5Hash("lineage-${caseIndex}")
    row.llmTurnCount = 1
    row.sandboxDeniedOutsideWorkspace = true
    row.verifierMountedAfterAnswerFreeze = true
    row.certificationPassAt1 = passed
    sealCkbCertificationEvidence(row)
    renderCkbCertificationEvidenceJson(row)
}

private func p5AuditJson(
    caseIndex: Int64,
    strict: Bool,
    raw: Bool,
    protocol: Bool
): String {
    let route = if (protocol) { "protocol_failure" } else if (strict) { "none" } else {
        "business_failure"
    }
    let failure = if (strict) { "none" } else if (protocol) { "protocol_invalid" } else {
        "test_failure"
    }
    "{\"runMode\":\"certification\",\"caseId\":\"${p5EvidenceCaseId(caseIndex)}\"," +
        "\"group\":\"${CkbAbcdeGroups.D}\",\"unitPassAt1\":${raw}," +
        "\"protocolViolation\":${protocol},\"firstClaudeExitCode\":0," +
        "\"claudeExitCode\":0,\"testExitCode\":${if (raw) { 0 } else { 1 }}," +
        "\"failureType\":\"${failure}\",\"datasetVersion\":\"dataset-v1\"," +
        "\"lineageKnowledgeVersion\":\"knowledge-v1\",\"developmentPass\":false," +
        "\"closureStatus\":\"closed\",\"triageStatus\":\"complete\"," +
        "\"failureRoute\":\"${route}\",\"certificationPassAt1\":null}"
}

private func p5EvidenceCaseId(index: Int64): String {
    if (index < 10) { return "CJ-HUMANEVAL-00${index}" }
    if (index < 100) { return "CJ-HUMANEVAL-0${index}" }
    "CJ-HUMANEVAL-${index}"
}

private func p5Hash(seed: String): String {
    benchmarkGapSha256(seed)
}

private func p5CopyIdentity(source: CkbStrictScoreEvidenceRow): CkbStrictScoreEvidenceRow {
    let row = CkbStrictScoreEvidenceRow()
    row.caseId = source.caseId
    row.runId = source.runId
    row.datasetVersion = source.datasetVersion
    row.knowledgeVersion = source.knowledgeVersion
    row.modelFingerprint = source.modelFingerprint
    row.providerIdentityHash = source.providerIdentityHash
    row.runManifestHash = source.runManifestHash
    row
}
