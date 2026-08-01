package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove}
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.json.JsonValue

private class P5FakeCliExecutor <: CkbPublicEvidenceCliExecutor {
    public var outputExists: Bool = false
    public var parentExists: Bool = true
    public var inputExists: Bool = true
    public var failExport: Bool = false
    public var executeCalls: Int64 = 0
    public var cleanupCalls: Int64 = 0
    public init() {}
    public func exists(path: String): Bool {
        if (path.endsWith("/out")) { return this.outputExists }
        this.inputExists
    }
    public func outputParentExists(path: String): Bool { this.parentExists }
    public func exportEvidence(options: CkbPublicEvidenceCliOptions):
        CkbPublicEvidenceRenderResult {
        this.executeCalls += 1
        this.outputExists = true
        let out = CkbPublicEvidenceRenderResult()
        out.ok = !this.failExport
        out.diagnostic = if (out.ok) { "ok" } else { "sensitive_content_detected" }
        out.evidenceHash = if (out.ok) { p5Hash("public-evidence") } else { "" }
        out.score.valid = out.ok
        out.score.total = if (out.ok) { 164 } else { 0 }
        out.score.strictPassed = if (out.ok) { 151 } else { 0 }
        out
    }
    public func cleanupOutput(path: String): Bool {
        this.cleanupCalls += 1
        this.outputExists = false
        true
    }
}

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

        let parsed = parseCkbPublicEvidenceCliArgs([
            "ckb-public-evidence-export", "--run-root", "/tmp/私有🙂",
            "--reference-manifest", "/tmp/私有🙂/reference.json",
            "--output", "/tmp/发布 资料/out"
        ])
        @Expect(parsed.valid, true)
        @Expect(parsed.runRoot, "/tmp/私有🙂")
        let context = p5CliContext()
        let fake = P5FakeCliExecutor()
        @Expect(validateCkbPublicEvidenceCliOptions(parsed, context, fake).ok, true)
        let veryLong = "界" * 4097
        @Expect(parseCkbPublicEvidenceCliArgs([
            "ckb-public-evidence-export", "--run-root", "/tmp/${veryLong}",
            "--reference-manifest", "/tmp/reference.json", "--output",
            "/tmp/发布 资料/out"
        ]).diagnostic, "cli_argument_too_long")
        for (output in ["relative/out", "/tmp/../escape/out",
            "/tmp/metis-worktree/out", "/tmp/ckb-data/out",
            "/tmp/私有🙂/out", "/tmp/settings/out",
            "/tmp/repro-unsigned/out", "/tmp/repro-final/out"]) {
            let options = p5CliOptions(output)
            @Expect(validateCkbPublicEvidenceCliOptions(options, context, fake).ok,
                false)
        }
        fake.parentExists = false
        @Expect(validateCkbPublicEvidenceCliOptions(
            p5CliOptions("/tmp/发布 资料/out"), context, fake).diagnostic,
            "public_evidence_output_parent_missing")
        fake.parentExists = true
        fake.outputExists = true
        @Expect(validateCkbPublicEvidenceCliOptions(
            p5CliOptions("/tmp/发布 资料/out"), context, fake).diagnostic,
            "public_evidence_output_exists")
    }

    @TestCase
    public func p5Bnd02ExportManifestParserIsStrictAndUtf8Safe(): Unit {
        let hash = "sha256:${"a" * 64}"
        let bytes = ("{\"schemaVersion\":\"ckb-public-evidence-export-v1\"," +
            "\"referenceManifestHash\":\"${hash}\"," +
            "\"privateResultsHash\":\"${hash}\"," +
            "\"publicEvidenceHash\":\"${hash}\"," +
            "\"runId\":\"public-run\",\"knowledgeVersion\":\"knowledge-v1\"," +
            "\"providerFingerprint\":\"${hash}\"," +
            "\"modelFingerprint\":\"glm-5.2\"," +
            "\"runManifestHash\":\"${hash}\"," +
            "\"vectorProofHash\":\"${hash}\"," +
            "\"certifiedRunInputHash\":\"${hash}\"}").toArray()
        let parsed = parseCkbPublicEvidenceExportManifest(bytes)
        @Expect(parsed[0].ok, true)
        @Expect(validateCkbPublicEvidenceExportManifest(parsed[1]).ok, true)
        let roundTrip = parseCkbPublicEvidenceExportManifest(
            p5CanonicalExportManifest(parsed[1]).toArray())
        @Expect(roundTrip[0].ok, true)
        @Expect(roundTrip[1].runId, "public-run")
        @Expect(roundTrip[1].knowledgeVersion, "knowledge-v1")
        @Expect(roundTrip[1].providerFingerprint, hash)
        @Expect(roundTrip[1].modelFingerprint, "glm-5.2")
        @Expect(roundTrip[1].runManifestHash, hash)
        @Expect(roundTrip[1].vectorProofHash, hash)
        @Expect(roundTrip[1].certifiedRunInputHash, hash)
        @Expect(parseCkbPublicEvidenceExportManifest([0xff, 0xfe])[0].diagnostic,
            "invalid_response_encoding")
        @Expect(parseCkbPublicEvidenceExportManifest("{bad".toArray())[0].diagnostic,
            "public_evidence_export_manifest_invalid")
        @Expect(parseCkbPublicEvidenceExportManifest(
            String.fromUtf8(bytes).replace("}", ",\"extra\":true}").toArray()
            )[0].ok, false)
        parsed[1].publicEvidenceHash = "sha256:${"g" * 64}"
        @Expect(validateCkbPublicEvidenceExportManifest(parsed[1]).diagnostic,
            "public_evidence_export_manifest_hash_invalid")
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
    public func p5Neg02ProductionExportRequiresExactPortableTarget(): Unit {
        @Expect(p5RunProductionExportFixture(151).ok, true)
        @Expect(p5RunProductionExportFixture(150).diagnostic,
            "public_evidence_target_score_required")
        @Expect(p5RunProductionExportFixture(152).diagnostic,
            "public_evidence_target_score_required")
    }

    @TestCase
    public func p5Neg03ProductionExportBindsEveryReferenceIdentity(): Unit {
        for (field in ["run", "knowledge", "provider", "model", "proof"]) {
            @Expect(p5RunProductionExportFixture(151,
                drift: field).diagnostic,
                "public_evidence_reference_identity_mismatch")
        }
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
            "{\"prompt\":\"question\"}",
            "/private/var/folders/secret/run",
            "/tmp/private-run/output.json",
            "C:\\secret\\result.json",
            "D:/private/result.json",
            "\\\\server\\share\\result.json",
            "/etc/metis/secret.conf",
            "/opt/private/tool",
            "/srv/ckb/private.json",
            "/usr/local/bin/private-tool",
            "/mnt", "/mnt/release/result.json",
            "/Volumes", "/Volumes/private/result.json",
            "/data", "/data/release/result.json",
            "/etc"
        ]
        for (attack in attacks) {
            let report = scanCkbPublicEvidenceLeakage(attack.toArray())
            @Expect(report.ok, false)
            @Expect(report.findingCodes.size > 0, true)
        }
        for (safe in ["https://provider.example/v1/chat/completions",
            "API route /v1/embeddings", "semantic path /knowledge/search",
            "endpoint /v2/models", "documentation /guide/install"]) {
            @Expect(scanCkbPublicEvidenceLeakage(safe.toArray()).ok, true)
        }
        for (identity in [
            ("../escape", CkbAbcdeGroups.D),
            ("CJ-HUMANEVAL-000/../../escape", CkbAbcdeGroups.D),
            ("CJ-HUMANEVAL-000\u{0000}", CkbAbcdeGroups.D),
            ("CJ-HUMANEVAL-164", CkbAbcdeGroups.D),
            ("CJ-HUMANEVAL-000", "../D"),
            ("CJ-HUMANEVAL-000", "D/escape")
        ]) {
            @Expect(validateCkbPublicEvidenceArtifactIdentity(
                identity[0], identity[1]).ok, false)
        }
        @Expect(validateCkbPublicEvidenceArtifactIdentity(
            "CJ-HUMANEVAL-000", CkbAbcdeGroups.D).ok, true)
        @Expect(validateCkbPublicEvidenceArtifactPath(
            "/tmp/run", "/tmp/run/cases/CJ-HUMANEVAL-000/D/audit.json").ok,
            true)
        @Expect(validateCkbPublicEvidenceArtifactPath(
            "/tmp/run", "/tmp/escape/audit.json").ok, false)
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

        let fake = P5FakeCliExecutor()
        fake.failExport = true
        let failed = executeCkbPublicEvidenceCliAdapter(
            p5CliOptions("/tmp/发布 资料/out"), p5CliContext(), fake)
        @Expect(failed.ok, false)
        @Expect(failed.diagnostic, "sensitive_content_detected")
        @Expect(fake.executeCalls, 1)
        @Expect(fake.cleanupCalls, 1)
        @Expect(fake.outputExists, false)
        let human = renderCkbPublicEvidenceCliHuman(failed)
        @Expect(human.contains("{\""), false)
        @Expect(human.contains("Authorization"), false)
        @Expect(human.contains("/Users/"), false)
        let explicitJson = renderCkbPublicEvidenceCliJson(failed)
        @Expect(explicitJson.startsWith("{"), true)
        failed.evidenceHash = "sha256:\u{0001}🙂"
        @Expect(try { JsonValue.fromStr(
            renderCkbPublicEvidenceCliJson(failed)); true }
            catch (_: Exception) { false }, true)

        let projectedAudit = projectCkbPublicAuditFromPrivateArtifacts(
            parseCkbCertificationEvidence(p5CertificationJson(0, false)),
            ("{\"unitPassAt1\":false,\"testExitCode\":7," +
                "\"failureType\":\"test_failure\"," +
                "\"firstClaudeExitCode\":3,\"claudeExitCode\":4}").toArray(),
            ("{\"violation\":\"none\",\"developmentPass\":true," +
                "\"closureStatus\":\"closed_after_review\"," +
                "\"triageStatus\":\"triaged\"," +
                "\"failureRoute\":\"business_failure\"," +
                "\"certificationPassAt1\":null}").toArray())
        @Expect(projectedAudit[0], "ok")
        @Expect(projectedAudit[1].contains("\"firstClaudeExitCode\":3"), true)
        @Expect(projectedAudit[1].contains("\"claudeExitCode\":4"), true)
        @Expect(projectedAudit[1].contains(
            "\"closureStatus\":\"closed_after_review\""), true)
        @Expect(projectedAudit[1].contains("\"triageStatus\":\"triaged\""), true)
        @Expect(planCkbPublicEvidenceTemporaryPath("/tmp/out", 42),
            "/tmp/out.tmp-42")
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

private func p5CliOptions(output: String): CkbPublicEvidenceCliOptions {
    parseCkbPublicEvidenceCliArgs([
        "ckb-public-evidence-export", "--run-root", "/tmp/私有🙂",
        "--reference-manifest", "/tmp/私有🙂/reference.json",
        "--output", output
    ])
}

private func p5CliContext(): CkbPublicEvidenceCliPathContext {
    let context = CkbPublicEvidenceCliPathContext()
    context.worktreeRoot = "/tmp/metis-worktree"
    context.productionRoot = "/tmp/ckb-data"
    context.userConfigRoot = "/tmp/settings"
    context.unsignedRoot = "/tmp/repro-unsigned"
    context.finalRoot = "/tmp/repro-final"
    context
}

private func p5CertificationJson(caseIndex: Int64, passed: Bool): String {
    p5CertificationJsonWithRun(caseIndex, passed, "public-run")
}

private func p5CertificationJsonWithRun(
    caseIndex: Int64,
    passed: Bool,
    runId: String,
    knowledgeVersion!: String = "knowledge-v1",
    modelFingerprint!: String = "glm-5.2",
    providerIdentityHash!: String = "",
    runManifestHash!: String = ""
): String {
    let row = CkbCertificationCaseEvidence()
    row.runId = runId
    row.caseId = p5EvidenceCaseId(caseIndex)
    row.group = CkbAbcdeGroups.D
    row.datasetVersion = "dataset-v1"
    row.knowledgeVersion = knowledgeVersion
    row.modelFingerprint = modelFingerprint
    row.expectedModelVersion = "glm-5.2"
    row.observedModelVersion = "glm-5.2"
    row.claudeCodeVersion = "claude-code-v1"
    row.providerIdentityHash = if (providerIdentityHash == "") {
        p5Hash("provider")
    } else { providerIdentityHash }
    row.preflightHash = p5Hash("preflight")
    row.runManifestHash = if (runManifestHash == "") {
        p5Hash("manifest")
    } else { runManifestHash }
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

private func p5RunProductionExportFixture(
    strictPassed: Int64,
    drift!: String = ""): CkbPublicEvidenceRenderResult {
    let root = Path("target/p5-production-export-${strictPassed}-${drift}")
    if (exists(root)) { remove(root, recursive: true) }
    Directory.create(root.join("run/cases"), recursive: true)
    var results = ""
    for (i in 0..164) {
        let strict = i < strictPassed
        let raw = i < 158
        let protocol = (!strict && raw) || i >= 161
        let certification = p5CertificationJsonWithRun(i, strict,
            if (drift == "run") { "other-run" } else { "public-run" },
            knowledgeVersion: if (drift == "knowledge") {
                "other-knowledge"
            } else { "knowledge-v1" },
            modelFingerprint: if (drift == "model") {
                "other-model"
            } else { "claude-code-glm-5.2" },
            providerIdentityHash: if (drift == "provider") {
                p5Hash("other-provider")
            } else { p5Hash("provider") },
            runManifestHash: if (drift == "proof") {
                p5Hash("other-manifest")
            } else { p5Hash("manifest") })
        results += certification + "\n"
        let caseRoot = root.join(
            "run/cases/${p5EvidenceCaseId(i)}/${CkbAbcdeGroups.D}")
        Directory.create(caseRoot, recursive: true)
        File.writeTo(caseRoot.join("test-result.json"),
            ("{\"unitPassAt1\":${raw},\"testExitCode\":" +
                "${if (raw) { 0 } else { 1 }}," +
                "\"failureType\":\"${if (raw) { "none" } else { "test_failure" }}\"," +
                "\"firstClaudeExitCode\":0,\"claudeExitCode\":0}").toArray())
        let route = if (protocol) { "protocol_failure" } else if (raw) {
            "none"
        } else { "business_failure" }
        File.writeTo(caseRoot.join("audit.json"),
            ("{\"violation\":\"${if (protocol) { "protocol" } else { "none" }}\"," +
                "\"developmentPass\":false,\"closureStatus\":\"closed\"," +
                "\"triageStatus\":\"complete\",\"failureRoute\":\"${route}\"," +
                "\"certificationPassAt1\":null}").toArray())
    }
    File.writeTo(root.join("run/results.jsonl"), results.toArray())
    File.writeTo(root.join("run/run-manifest.json"),
        ("{\"runManifestHash\":\"${p5Hash("manifest")}\"}").toArray())
    let reference = CkbReproReferenceManifest()
    reference.schemaVersion = "ckb-repro-reference-v1"
    reference.baselineKind = "portable_release"
    reference.evidenceStatus = "complete"
    reference.releaseRepository = "l3gi0nXXXX/CangjieCommunityKnowledgeBase"
    reference.releaseRepositoryUrl =
        "https://github.com/l3gi0nXXXX/CangjieCommunityKnowledgeBase"
    reference.releaseBranch = "main"
    reference.observedRemote =
        "https://github.com/l3gi0nXXXX/CangjieCommunityKnowledgeBase.git"
    reference.runId = "public-run"; reference.knowledgeVersion = "knowledge-v1"
    reference.vectorProofHash = p5Hash("vector")
    reference.datasetVersion = "dataset-v1"
    reference.runnerCommit = "0123456789012345678901234567890123456789"
    reference.claudeCodeVersion = "claude-code-v1"
    reference.model = "glm-5.2"
    reference.modelFingerprint = "claude-code-glm-5.2"
    reference.providerFingerprint = p5Hash("provider")
    reference.experimentGroup = CkbAbcdeGroups.D
    reference.toolTransport = "mcp"; reference.mcpTransport = "stdio"
    reference.ckbRequired = true; reference.localDocsPolicy = "disabled"
    reference.modelEffort = "high"; reference.modelBudget = "fixed"
    reference.timeoutSeconds = 3600; reference.transportRetryBudget = 0
    reference.promptHash = p5Hash("prompt")
    reference.resultsHash = benchmarkGapSha256(results)
    reference.runCriticalTreeHash = p5Hash("critical")
    reference.certifiedRunInputHash = p5Hash("certified-input")
    reference.totalCases = 164; reference.rawPassed = 158
    reference.strictPassed = strictPassed
    reference.strictFailed = 164 - strictPassed
    reference.businessFailed = 3
    reference.protocolInvalid = 161 - strictPassed
    reference.transportUnresolved = 0
    File.writeTo(root.join("reference.json"),
        renderCkbReproReferenceManifest(reference).toArray())
    let canonicalRoot = Path(canonicalize(root).toString())
    let options = CkbPublicEvidenceCliOptions()
    options.runRoot = canonicalRoot.join("run").toString()
    options.referenceManifest = canonicalRoot.join("reference.json").toString()
    options.outputRoot = canonicalRoot.join("out").toString()
    let result = runCkbPublicEvidenceExportFromFiles(options)
    remove(root, recursive: true)
    result
}

private func p5CanonicalExportManifest(
    manifest: CkbPublicEvidenceExportManifest): String {
    renderCkbPublicEvidenceExportManifest(manifest)
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
