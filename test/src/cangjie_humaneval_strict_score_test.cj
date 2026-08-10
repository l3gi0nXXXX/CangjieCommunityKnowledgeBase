package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.time.DateTime
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.json.*

@Test
public class CangjieHumanEvalStrictScoreTest {
    @TestCase
    public func p1Ut01HistoricalProjectionComputesStrictAndRawCounts(): Unit {
        let score = computeCkbHumanEvalStrictScore(p1ScoreRows(151, 158))
        @Expect(score.valid, true)
        @Expect(score.total, 164)
        @Expect(score.strictPassed, 151)
        @Expect(score.strictFailed, 13)
        @Expect(score.unitFirstSamplePassed, 158)
        @Expect(score.businessFailed, 3)
        @Expect(score.protocolInvalid, 10)
        @Expect(score.transportUnresolved, 0)
        @Expect(score.evidenceLevel, "public_projection")
        @Expect(renderCkbHumanEvalStrictScoreJson(score),
            "{\"valid\":true,\"total\":164,\"strictPassed\":151,\"strictFailed\":13,\"unitFirstSamplePassed\":158,\"businessFailed\":3,\"protocolInvalid\":10,\"transportUnresolved\":0,\"basePassed\":0,\"plusPassed\":0,\"baseMetricName\":\"historical_agentic_base_pass_at_1\",\"plusMetricName\":\"historical_agentic_plus_pass_at_1\",\"certificationStatus\":\"historical_agentic_not_strict\",\"evidenceLevel\":\"public_projection\",\"artifactManifestHash\":\"\",\"releaseEligible\":false,\"diagnostic\":\"ok\"}")
    }

    @TestCase
    public func p1Bnd01CountDuplicateUtf8AndSchemaBoundariesFailClosed(): Unit {
        @Expect(computeCkbHumanEvalStrictScore(p1ScoreRows(163, 163)).diagnostic,
            "evidence_count_mismatch:163:164")
        @Expect(computeCkbHumanEvalStrictScore(p1ScoreRows(165, 165)).diagnostic,
            "evidence_count_mismatch:165:164")
        let duplicate = p1ScoreRows(164, 164)
        duplicate[163].caseId = duplicate[162].caseId
        @Expect(computeCkbHumanEvalStrictScore(duplicate).diagnostic,
            "duplicate_case:CJ-HUMANEVAL-162")

        let unicode = p1ScoreRows(164, 164)
        unicode[0].runId = "公开-run🙂"
        for (i in 1..164) { unicode[i].runId = unicode[0].runId }
        let roundTrip = parseCkbStrictScoreEvidenceJsonl(
            renderCkbStrictScoreEvidenceJsonl(unicode).toArray())
        @Expect(roundTrip.valid, true)
        @Expect(roundTrip.strictPassed, 164)
        @Expect(parseCkbStrictScoreEvidenceJsonl([0xff, 0xfe]).diagnostic,
            "invalid_response_encoding")
        let blank = renderCkbStrictScoreEvidenceRowJson(
            p1ScoreRow(0, true, true, "none")) + "\n\n"
        @Expect(parseCkbStrictScoreEvidenceJsonl(blank.toArray()).diagnostic,
            "empty_evidence_line")

        let unknown = renderCkbStrictScoreEvidenceRowJson(p1ScoreRow(0, true, true, "none"))
            .replace("}", ",\"claimSigned\":true}")
        @Expect(parseCkbStrictScoreEvidenceJsonl((unknown + "\n").toArray()).diagnostic,
            "public_evidence_unknown_or_duplicate_field")
        let schema = String.fromUtf8(File.readFrom(
            Path("../reproducibility/PUBLIC-EVIDENCE.schema.json")))
        @Expect(schema.contains("\"additionalProperties\": false"), true)
        @Expect(schema.contains("\"claimSigned\""), false)
        let schemaObject = JsonValue.fromStr(schema).asObject()
        @Expect(schemaObject.get("required").getOrThrow().asArray().getItems().size, 22)
        @Expect(schemaObject.get("properties").getOrThrow().asObject().getFields().size, 22)

        let malformedPath = Path("../target/p1-score-invalid-utf8.jsonl")
        File.writeTo(malformedPath, [0xff, 0xfe])
        @Expect(runCangjieHumanEvalStrictScore([
            "cangjie-humaneval-strict-score", "--public-evidence",
            malformedPath.toString()
        ]), 1)
        @Expect(runCangjieHumanEvalStrictScore([
            "cangjie-humaneval-strict-score", "--public-evidence"
        ]), 2)
    }

    @TestCase
    public func p1Pos01PublicProjectionAndPrivateCertificationStayDistinct(): Unit {
        let projectionRows = p1ScoreRows(151, 158)
        let projection = parseCkbStrictScoreEvidenceJsonl(
            renderCkbStrictScoreEvidenceJsonl(projectionRows).toArray())
        @Expect(projection.valid, true)
        @Expect(projection.evidenceLevel, "public_projection")
        @Expect(projection.artifactManifestHash, "")

        let fixture = p1ScorePrivateRun(151, "pos")
        p1ScoreBindPrivateProjection(projectionRows, fixture)
        let certified = computeCkbHumanEvalStrictScoreFromRunRoot(
            fixture.root, fixture.authority, projectionRows)
        @Expect(certified.valid, true)
        @Expect(certified.strictPassed, 151)
        @Expect(certified.unitFirstSamplePassed, 158)
        @Expect(certified.evidenceLevel, "private_artifact_certification")
        @Expect(p1ScoreHash(certified.artifactManifestHash), true)
        @Expect(certified.releaseEligible, false)
        let privateJson = renderCkbHumanEvalStrictScoreJson(certified)
        @Expect(privateJson.contains(
            "\"artifactManifestHash\":\"${certified.artifactManifestHash}\""), true)
        @Expect(privateJson.contains("\"releaseEligible\":false"), true)
        let projectionPath = Path(fixture.root).join("public-evidence.jsonl")
        File.writeTo(projectionPath,
            renderCkbStrictScoreEvidenceJsonl(projectionRows).toArray())
        @Expect(runCangjieHumanEvalStrictScore([
            "cangjie-humaneval-strict-score",
            "--public-evidence", projectionPath.toString(),
            "--run-root", fixture.root,
            "--manifest", Path(fixture.root).join("authority.jsonl").toString()
        ]), 0)
    }

    @TestCase
    public func p1Neg01LineageRetryExposureAndClassificationFailClosed(): Unit {
        let lineage = p1ScoreRows(151, 158)
        lineage[42].knowledgeVersion = "other-version"
        @Expect(computeCkbHumanEvalStrictScore(lineage).diagnostic,
            "evidence_lineage_drift:CJ-HUMANEVAL-042")

        let secondSample = p1ScoreRows(151, 158)
        secondSample[0].sampleAttemptCount = 2
        @Expect(computeCkbHumanEvalStrictScore(secondSample).diagnostic,
            "first_business_sample_invalid:CJ-HUMANEVAL-000")

        let retry = p1ScoreRows(151, 158)
        retry[0].retryUsed = true
        @Expect(computeCkbHumanEvalStrictScore(retry).diagnostic,
            "retry_or_fallback_forbidden:CJ-HUMANEVAL-000")
        let fallback = p1ScoreRows(151, 158)
        fallback[0].fallbackUsed = true
        @Expect(computeCkbHumanEvalStrictScore(fallback).diagnostic,
            "retry_or_fallback_forbidden:CJ-HUMANEVAL-000")

        let exposure = p1ScoreRows(151, 158)
        exposure[0].teacherExposure = 1
        @Expect(computeCkbHumanEvalStrictScore(exposure).diagnostic,
            "model_exposure_forbidden:CJ-HUMANEVAL-000")
        let protocolExposure = p1ScoreRows(151, 158)
        protocolExposure[151].referenceExposure = 1
        let protocolExposureScore = computeCkbHumanEvalStrictScore(protocolExposure)
        @Expect(protocolExposureScore.valid, true)
        @Expect(protocolExposureScore.protocolInvalid, 10)

        let classification = p1ScoreRows(151, 158)
        classification[0].classification = "business_failure"
        @Expect(computeCkbHumanEvalStrictScore(classification).diagnostic,
            "classification_closure_invalid:CJ-HUMANEVAL-000")
        let unresolved = p1ScoreRows(151, 158)
        unresolved[151].unitFirstSamplePassed = false
        unresolved[151].classification = "transport_unresolved"
        unresolved[151].sampleAttemptCount = 0
        unresolved[151].selectedBusinessSample = 0
        unresolved[151].unresolvedTransport = 1
        let unresolvedScore = computeCkbHumanEvalStrictScore(unresolved)
        @Expect(unresolvedScore.valid, true)
        @Expect(unresolvedScore.diagnostic, "ok")
        @Expect(unresolvedScore.strictPassed, 151)
        @Expect(unresolvedScore.strictFailed, 13)
        @Expect(unresolvedScore.transportUnresolved, 1)

        let privateFixture = p1ScorePrivateRun(151, "neg")
        let mismatched = p1ScoreRows(158, 158)
        p1ScoreBindPrivateProjection(mismatched, privateFixture)
        let privateScore = computeCkbHumanEvalStrictScoreFromRunRoot(
            privateFixture.root, privateFixture.authority, mismatched)
        @Expect(privateScore.valid, false)
        @Expect(privateScore.diagnostic, "private_projection_score_mismatch")
        @Expect(privateScore.artifactManifestHash, "")
        let invalidJson = renderCkbHumanEvalStrictScoreJson(privateScore)
        @Expect(invalidJson.contains(
            "\"diagnostic\":\"private_projection_score_mismatch\""), true)
        @Expect(invalidJson.contains("\"artifactManifestHash\":\"\""), true)
        @Expect(invalidJson.contains("\"releaseEligible\":false"), true)

        let wrongRun = p1ScoreRows(151, 158)
        p1ScoreBindPrivateProjection(wrongRun, privateFixture)
        for (row in wrongRun) { row.runId = "other-private-run" }
        @Expect(computeCkbHumanEvalStrictScoreFromRunRoot(
            privateFixture.root, privateFixture.authority, wrongRun).diagnostic,
            "private_projection_lineage_mismatch")

        let firstCase = Path(privateFixture.root).join("cases")
            .join("CJ-HUMANEVAL-000").join(CkbAbcdeGroups.D)
        File.writeTo(firstCase.join("test.log"), "tampered".toArray())
        let audited = p1ScoreRows(151, 158)
        p1ScoreBindPrivateProjection(audited, privateFixture)
        @Expect(computeCkbHumanEvalStrictScoreFromRunRoot(
            privateFixture.root, privateFixture.authority, audited).diagnostic,
            "private_artifact_certification_invalid")
    }

    @TestCase
    public func p1Reg01FullScoreAndCriticalSourceBoundariesRemainStable(): Unit {
        let score = computeCkbHumanEvalStrictScore(p1ScoreRows(164, 164))
        @Expect(score.valid, true)
        @Expect(score.strictPassed, 164)
        @Expect(score.releaseEligible, false)
        @Expect(score.evidenceLevel, "public_projection")

        @Expect(p1ScoreFileHash("../src/cangjie_eval_abcde_runner.cj"),
            "sha256:69637038cdd23fdf768b69bcc18a9bdff153aa5077c0721c8fcf4ec1fbaa022b")
        @Expect(p1ScoreFileHash("../src/cangjie_eval_knowledge_audit.cj"),
            "sha256:de1ed91483fdda2eade6939208098d6e89f28af4d0eac0527812748f3ad20e73")
        @Expect(p1ScoreFileHash("../src/cangjie_strict_certification.cj"),
            "sha256:01ddadd5851c9be0ae4cac383970741c0228bf8258b5cdf43a7022b2232e1ca7")
    }
}

private class P1ScorePrivateRunFixture {
    public let root: String
    public let authority: String
    public init(root: String, authority: String) {
        this.root = root
        this.authority = authority
    }
}

private func p1ScoreRows(strictPassed: Int64, rawPassed: Int64): ArrayList<CkbStrictScoreEvidenceRow> {
    let rows = ArrayList<CkbStrictScoreEvidenceRow>()
    let count = if (strictPassed > 164) { strictPassed } else { Int64(164) }
    for (i in 0..count) {
        let strict = i < strictPassed
        let raw = i < rawPassed
        let classification = if (strict) {
            "none"
        } else if (raw) {
            "protocol_invalid"
        } else if (i < rawPassed + 3) {
            "business_failure"
        } else {
            "protocol_invalid"
        }
        rows.add(p1ScoreRow(i, strict, raw, classification))
    }
    if (strictPassed == 163) { rows.remove(at: 163) }
    rows
}

private func p1ScoreRow(
    i: Int64,
    strict: Bool,
    raw: Bool,
    classification: String
): CkbStrictScoreEvidenceRow {
    let row = CkbStrictScoreEvidenceRow()
    row.caseId = p1ScoreCaseId(i)
    row.runId = "historical-public-run"
    row.datasetVersion = "dataset-v1"
    row.knowledgeVersion = "knowledge-v1"
    row.modelFingerprint = benchmarkGapSha256("model")
    row.providerIdentityHash = benchmarkGapSha256("provider")
    row.runManifestHash = benchmarkGapSha256("run-manifest")
    row.certificationPassAt1 = strict
    row.unitFirstSamplePassed = raw
    row.classification = classification
    row.sampleAttemptCount = 1
    row.selectedBusinessSample = 1
    row.transportAttemptCount = 1
    row.transportRetryCount = 0
    row.unresolvedTransport = 0
    row.retryUsed = false
    row.fallbackUsed = false
    row.referenceExposure = 0
    row.hiddenTestExposure = 0
    row.teacherExposure = 0
    row.crossCaseExposure = 0
    row
}

private func p1ScorePrivateRun(strictPassed: Int64, label: String): P1ScorePrivateRunFixture {
    let root = p1ScoreEmptyRoot("p1-score-${label}-${strictPassed}")
    let authorityText = cangjieHumanEvalRenderAuthorityManifest(
        buildCangjieHumanEvalManifest("cangjie_eval/cases/Cangjie-HumanEval", ""))
    let authority = parseCangjieHumanEvalAuthorityManifest(authorityText)
    let runId = "p1-score-private-run"
    let knowledgeVersion = "knowledge-v1"
    let fingerprint = benchmarkGapSha256("model")
    let model = "GLM-5.2"
    let claudeBin = "/bin/echo"
    let claudeVersion = ckbAbcdeClaudeVersionForTest(executable: claudeBin)
    let preflight = "p1-score-preflight"
    let pointerHash = benchmarkGapSha256("p1-score-pointer")
    let candidateChecksum = benchmarkGapSha256("p1-score-candidate")
    let frozen = "{\"knowledgeVersion\":\"${knowledgeVersion}\",\"activePointerHash\":\"${pointerHash}\",\"candidateChecksum\":\"${candidateChecksum}\"}"
    let provider = "{\"provider\":\"fake-transport\",\"model\":\"${model}\",\"claudeCodeVersion\":\"${claudeVersion}\"}"
    let providerHash = benchmarkGapSha256(provider)
    let runManifestHash = benchmarkGapSha256("p1-score-run-manifest")
    let binaryHash = benchmarkGapSha256("p1-score-binary")
    let launchHash = benchmarkGapSha256("p1-score-launch")
    let commandHash = benchmarkGapSha256("p1-score-command")
    let runManifest = "{\"frozenCandidateManifestHash\":\"${benchmarkGapSha256(frozen)}\",\"providerIdentityHash\":\"${providerHash}\",\"modelVersion\":\"${model}\",\"fingerprint\":\"${fingerprint}\",\"preflightHash\":\"${benchmarkGapSha256(preflight)}\",\"runManifestHash\":\"${runManifestHash}\",\"modelTimeoutSeconds\":180,\"claudeCodeVersion\":\"${claudeVersion}\",\"runId\":\"${runId}\",\"certificationBinaryHash\":\"${binaryHash}\",\"certificationHttpLaunchSpecHash\":\"${launchHash}\",\"certificationHttpCommandHash\":\"${commandHash}\"}"
    let owner = "{\"schemaVersion\":\"ckb-certification-http-owner-v1\",\"pid\":4242,\"binaryHash\":\"${binaryHash}\",\"launchSpecHash\":\"${launchHash}\",\"commandHash\":\"${commandHash}\"}"
    let stopped = "{\"schemaVersion\":\"ckb-certification-http-stop-v1\",\"pid\":4242,\"stopMethod\":\"term\",\"aliveAfterStop\":false}"
    let identity = "{\"ok\":true,\"apiVersion\":\"v1\",\"data\":{\"schemaVersion\":\"ckb-certification-identity-v1\",\"activeVersion\":\"${knowledgeVersion}\",\"pointerIdentityHash\":\"${pointerHash}\",\"candidateChecksum\":\"${candidateChecksum}\"},\"diagnostics\":{}}"
    let rootPath = Path(root)
    File.writeTo(rootPath.join("authority.jsonl"), authorityText.toArray())
    File.writeTo(rootPath.join("preflight.json"), preflight.toArray())
    File.writeTo(rootPath.join("run-manifest.json"), runManifest.toArray())
    File.writeTo(rootPath.join("frozen-candidate-manifest.json"), frozen.toArray())
    File.writeTo(rootPath.join("provider-identity.json"), provider.toArray())
    File.writeTo(rootPath.join("certification-http-owner.json"), owner.toArray())
    File.writeTo(rootPath.join("certification-http-stopped.json"), stopped.toArray())
    File.writeTo(rootPath.join("certification-http-identity.json"), identity.toArray())

    let options = CkbAbcdeRunnerOptions()
    options.runId = runId
    options.explicitRunMode = true
    options.runMode = "certification"
    options.datasetVersion = authority.datasetVersion
    options.knowledgeVersion = knowledgeVersion
    options.modelFingerprint = fingerprint
    options.expectedModelVersion = model
    options.claudeBin = claudeBin
    options.providerIdentityHash = providerHash
    options.modelTimeoutSeconds = 180
    options.manifestPath = rootPath.join("authority.jsonl").toString()
    options.certificationPreflightPath = rootPath.join("preflight.json").toString()
    options.certificationRunManifestPath = rootPath.join("run-manifest.json").toString()
    options.providerIdentityArtifactPath = rootPath.join("provider-identity.json").toString()
    options.frozenCandidateManifestPath = rootPath.join("frozen-candidate-manifest.json").toString()

    let results = StringBuilder()
    for (i in 0..164) {
        let authorityRow = authority.rows[i]
        let groupRoot = rootPath.join("cases").join(authorityRow.caseId).join(CkbAbcdeGroups.D)
        var rendered = ckbAbcdeWriteSuccessfulFakeTransportCaseForTest(
            options, authorityRow.caseId, groupRoot.toString())
        if (i >= strictPassed) {
            let evidence = parseCkbCertificationEvidence(rendered)
            evidence.certificationPassAt1 = false
            sealCkbCertificationEvidence(evidence)
            rendered = renderCkbCertificationEvidenceJson(evidence)
            let testResultPath = groupRoot.join("test-result.json")
            let testResult = String.fromUtf8(File.readFrom(testResultPath))
                .replace("\"testExitCode\":0", "\"testExitCode\":1")
                .replace("\"unitPassAt1\":true", "\"unitPassAt1\":false")
                .replace("\"failureType\":\"none\"", "\"failureType\":\"unit_failure\"")
            File.writeTo(testResultPath, testResult.toArray())
            File.writeTo(groupRoot.join("result-evidence.json"), rendered.toArray())
        }
        results.append(rendered)
        results.append("\n")
    }
    let resultsText = results.toString()
    File.writeTo(rootPath.join("results.jsonl"), resultsText.toArray())
    let provenance = "{\"schemaVersion\":\"ckb-certification-runner-provenance-v1\",\"runId\":\"${runId}\",\"canonicalRunRootHash\":\"${benchmarkGapSha256(canonicalize(rootPath).toString())}\",\"runManifestHash\":\"${runManifestHash}\",\"runnerBinaryHash\":\"${binaryHash}\",\"launchSpecHash\":\"${launchHash}\",\"commandHash\":\"${commandHash}\",\"authorityHash\":\"${benchmarkGapSha256(authorityText)}\",\"caseCount\":164,\"resultManifestHash\":\"${benchmarkGapSha256(resultsText)}\"}"
    File.writeTo(rootPath.join("runner-provenance.json"), provenance.toArray())
    P1ScorePrivateRunFixture(root, authorityText)
}

private func p1ScoreEmptyRoot(prefix: String): String {
    let nonce = "${DateTime.now().toUnixTimeStamp().toMilliseconds()}-${benchmarkGapSha256(prefix + DateTime.now().toString()).replace("sha256:", "")}"
    let root = "../target/${prefix}-${nonce}"
    if (exists(Path(root))) { remove(Path(root), recursive: true) }
    Directory.create(Path(root), recursive: true)
    root
}

private func p1ScoreBindPrivateProjection(
    rows: ArrayList<CkbStrictScoreEvidenceRow>,
    fixture: P1ScorePrivateRunFixture
): Unit {
    let firstLine = String.fromUtf8(
        File.readFrom(Path(fixture.root).join("results.jsonl"))).split("\n")[0]
    let privateRow = parseCkbCertificationEvidence(firstLine)
    for (row in rows) {
        row.runId = privateRow.runId
        row.datasetVersion = privateRow.datasetVersion
        row.knowledgeVersion = privateRow.knowledgeVersion
        row.modelFingerprint = privateRow.modelFingerprint
        row.providerIdentityHash = privateRow.providerIdentityHash
        row.runManifestHash = privateRow.runManifestHash
    }
}

private func p1ScoreCaseId(i: Int64): String {
    if (i < 10) { "CJ-HUMANEVAL-00${i}" }
    else if (i < 100) { "CJ-HUMANEVAL-0${i}" }
    else { "CJ-HUMANEVAL-${i}" }
}

private func p1ScoreHash(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 71 || !value.startsWith("sha256:")) { return false }
    for (i in 7..71) {
        let rune = runes[i]
        if (!((rune >= r'0' && rune <= r'9') || (rune >= r'a' && rune <= r'f'))) {
            return false
        }
    }
    true
}

private func p1ScoreFileHash(path: String): String {
    benchmarkGapSha256(String.fromUtf8(File.readFrom(Path(path))))
}
