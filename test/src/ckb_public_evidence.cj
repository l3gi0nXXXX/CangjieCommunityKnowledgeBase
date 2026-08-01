package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, canonicalize, exists, remove, rename}
import std.sort.*
import stdx.encoding.json.*

public class CkbPublicEvidenceProjectionResult {
    public var ok: Bool = false
    public var diagnostic: String = ""
    public var row: CkbStrictScoreEvidenceRow = CkbStrictScoreEvidenceRow()
    public init() {}
}

public class CkbPublicEvidenceLeakageReport {
    public var ok: Bool = false
    public var diagnostic: String = ""
    public var findingCodes: ArrayList<String> = ArrayList<String>()
    public init() {}
}

public class CkbPublicEvidenceRenderResult {
    public var ok: Bool = false
    public var diagnostic: String = ""
    public var text: String = ""
    public var evidenceHash: String = ""
    public var score: CkbHumanEvalStrictScore = CkbHumanEvalStrictScore()
    public init() {}
}

public class CkbPublicEvidenceScoreComparison {
    public var ok: Bool = false
    public var diagnostic: String = ""
    public init() {}
}

public class CkbPublicEvidenceCliOptions {
    public var runRoot: String = ""
    public var referenceManifest: String = ""
    public var outputRoot: String = ""
    public var json: Bool = false
    public var valid: Bool = false
    public var diagnostic: String = "usage_error"
    public init() {}
}

public class CkbPublicEvidenceCliPathContext {
    public var worktreeRoot: String = ""
    public var productionRoot: String = ""
    public var userConfigRoot: String = ""
    public var unsignedRoot: String = ""
    public var finalRoot: String = ""
    public init() {}
}

public interface CkbPublicEvidenceCliExecutor {
    func exists(path: String): Bool
    func outputParentExists(path: String): Bool
    func exportEvidence(options: CkbPublicEvidenceCliOptions):
        CkbPublicEvidenceRenderResult
    func cleanupOutput(path: String): Bool
}

public class CkbPublicEvidenceFilesystemCliExecutor <:
    CkbPublicEvidenceCliExecutor {
    public init() {}
    public func exists(path: String): Bool { exists(Path(path)) }
    public func outputParentExists(path: String): Bool {
        exists(Path(path).parent)
    }
    public func exportEvidence(options: CkbPublicEvidenceCliOptions):
        CkbPublicEvidenceRenderResult {
        if (!p5CliExistingCanonical(options.runRoot) ||
            !p5CliExistingCanonical(options.referenceManifest) ||
            !p5CliNewOutputCanonical(options.outputRoot)) {
            return p5CliRenderFailure("public_evidence_path_not_canonical")
        }
        runCkbPublicEvidenceExportFromFiles(options)
    }
    public func cleanupOutput(path: String): Bool {
        try {
            if (exists(Path(path))) { remove(Path(path), recursive: true) }
            true
        } catch (_: Exception) { false }
    }
}

public func parseCkbPublicEvidenceCliArgs(args: Array<String>):
    CkbPublicEvidenceCliOptions {
    let out = CkbPublicEvidenceCliOptions()
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "ckb-public-evidence-export") { i += 1; continue }
        if (arg == "--json") {
            if (out.json) { out.diagnostic = "duplicate_argument:--json"; return out }
            out.json = true; i += 1; continue
        }
        if (arg == "--run-root" || arg == "--reference-manifest" ||
            arg == "--output") {
            if (i + 1 >= args.size) { out.diagnostic = "missing_value:${arg}"; return out }
            let value = args[i + 1]
            if (value.toRuneArray().size > 4096) {
                out.diagnostic = "cli_argument_too_long"; return out
            }
            if (arg == "--run-root") {
                if (out.runRoot != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.runRoot = value
            } else if (arg == "--reference-manifest") {
                if (out.referenceManifest != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.referenceManifest = value
            } else {
                if (out.outputRoot != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.outputRoot = value
            }
            i += 2; continue
        }
        out.diagnostic = "unknown_argument:${arg}"; return out
    }
    if (out.runRoot == "" || out.referenceManifest == "" ||
        out.outputRoot == "") {
        out.diagnostic = "required_argument_missing"; return out
    }
    out.valid = true; out.diagnostic = "ok"; out
}

public func validateCkbPublicEvidenceCliOptions(
    options: CkbPublicEvidenceCliOptions,
    context: CkbPublicEvidenceCliPathContext,
    executor: CkbPublicEvidenceCliExecutor): CkbReproContractResult {
    if (!options.valid) { return p5CliFailure(options.diagnostic) }
    for (path in [options.runRoot, options.referenceManifest,
        options.outputRoot, context.worktreeRoot, context.productionRoot,
        context.userConfigRoot, context.unsignedRoot, context.finalRoot]) {
        if (!p5CliAbsolutePath(path)) {
            return p5CliFailure("public_evidence_path_invalid")
        }
    }
    if (!executor.exists(options.runRoot)) {
        return p5CliFailure("public_evidence_run_root_missing")
    }
    if (!executor.exists(options.referenceManifest)) {
        return p5CliFailure("public_evidence_reference_missing")
    }
    if (executor.exists(options.outputRoot)) {
        return p5CliFailure("public_evidence_output_exists")
    }
    if (!executor.outputParentExists(options.outputRoot)) {
        return p5CliFailure("public_evidence_output_parent_missing")
    }
    for (protected in [options.runRoot, context.worktreeRoot,
        context.productionRoot, context.userConfigRoot, context.unsignedRoot,
        context.finalRoot]) {
        if (p5CliRootsOverlap(options.outputRoot, protected)) {
            return p5CliFailure("public_evidence_output_forbidden")
        }
    }
    p5CliSuccess()
}

public func executeCkbPublicEvidenceCliAdapter(
    options: CkbPublicEvidenceCliOptions,
    context: CkbPublicEvidenceCliPathContext,
    executor: CkbPublicEvidenceCliExecutor): CkbPublicEvidenceRenderResult {
    let checked = validateCkbPublicEvidenceCliOptions(options, context, executor)
    if (!checked.ok) { return p5CliRenderFailure(checked.diagnostic) }
    let out = try { executor.exportEvidence(options) } catch (_: Exception) {
        p5CliRenderFailure("public_evidence_export_failed")
    }
    if (!out.ok) { _ = executor.cleanupOutput(options.outputRoot) }
    out
}

public func runCkbPublicEvidenceCliAdapter(options: CkbPublicEvidenceCliOptions,
    context: CkbPublicEvidenceCliPathContext): CkbPublicEvidenceRenderResult {
    executeCkbPublicEvidenceCliAdapter(options, context,
        CkbPublicEvidenceFilesystemCliExecutor())
}

public func renderCkbPublicEvidenceCliHuman(
    result: CkbPublicEvidenceRenderResult): String {
    "public evidence: ${if (result.ok) { "exported" } else { "blocked" }}\n" +
        "diagnostic: ${p5CliSafeDiagnostic(result.diagnostic)}\n" +
        "cases: ${result.score.total}\n" +
        "strict passed: ${result.score.strictPassed}\n" +
        "evidence hash: ${result.evidenceHash}\n"
}

public func renderCkbPublicEvidenceCliJson(
    result: CkbPublicEvidenceRenderResult): String {
    "{\"ok\":${result.ok},\"diagnostic\":\"${p5CliJson(p5CliSafeDiagnostic(result.diagnostic))}\"," +
        "\"total\":${result.score.total},\"strictPassed\":${result.score.strictPassed}," +
        "\"evidenceHash\":\"${p5CliJson(result.evidenceHash)}\"}"
}

public func projectCkbPublicEvidenceRow(
    certificationBytes: Array<UInt8>,
    auditBytes: Array<UInt8>
): CkbPublicEvidenceProjectionResult {
    let result = CkbPublicEvidenceProjectionResult()
    let certificationText = try {
        String.fromUtf8(certificationBytes)
    } catch (_: Exception) {
        result.diagnostic = "invalid_certification_encoding"
        return result
    }
    let auditText = try {
        String.fromUtf8(auditBytes)
    } catch (_: Exception) {
        result.diagnostic = "invalid_audit_encoding"
        return result
    }
    let certification = parseCkbCertificationEvidence(certificationText.trimAscii())
    if (!certification.valid) {
        result.diagnostic = "certification_${certification.diagnostic}"
        return result
    }
    let audits = parseCkbCdGapAuditResults(auditText)
    if (audits.size != 1) {
        result.diagnostic = "audit_row_count_mismatch:${audits.size}:1"
        return result
    }
    let audit = audits[0]
    if (!audit.ok) {
        result.diagnostic = "audit_${audit.diagnostic}"
        return result
    }
    if (audit.runMode != "certification") {
        result.diagnostic = "audit_requires_certification_mode"
        return result
    }
    if (certification.caseId != audit.caseId || certification.group != audit.group) {
        result.diagnostic = "case_identity_mismatch"
        return result
    }
    if (certification.datasetVersion != audit.datasetVersion ||
        certification.knowledgeVersion != audit.knowledgeVersion) {
        result.diagnostic = "knowledge_identity_mismatch"
        return result
    }
    if ((certification.certificationPassAt1 &&
            (!audit.unitPassAt1 || audit.protocolViolation)) ||
        (!certification.certificationPassAt1 &&
            audit.unitPassAt1 && !audit.protocolViolation)) {
        result.diagnostic = "certification_audit_outcome_mismatch"
        return result
    }

    let row = CkbStrictScoreEvidenceRow()
    row.caseId = certification.caseId
    row.runId = certification.runId
    row.datasetVersion = certification.datasetVersion
    row.knowledgeVersion = certification.knowledgeVersion
    row.modelFingerprint = certification.modelFingerprint
    row.providerIdentityHash = certification.providerIdentityHash
    row.runManifestHash = certification.runManifestHash
    row.certificationPassAt1 = certification.certificationPassAt1
    row.unitFirstSamplePassed = audit.unitPassAt1
    row.sampleAttemptCount = certification.sampleAttemptCount
    row.selectedBusinessSample = certification.selectedBusinessSample
    row.transportAttemptCount = certification.transportAttemptCount
    row.transportRetryCount = certification.retryCount
    row.unresolvedTransport = certification.unresolvedTransport
    row.retryUsed = certification.retryUsed
    row.fallbackUsed = certification.fallbackUsed
    row.referenceExposure = certification.referenceExposure
    row.hiddenTestExposure = certification.hiddenTestExposure
    row.teacherExposure = certification.teacherExposure
    row.crossCaseExposure = certification.crossCaseExposure
    row.classification = ckbPublicEvidenceClassification(certification, audit)
    if (!ckbPublicEvidenceSingleRowValid(row)) {
        result.diagnostic = "projected_row_invalid"
        return result
    }
    result.row = row
    result.ok = true
    result.diagnostic = "ok"
    result
}

public func scanCkbPublicEvidenceLeakage(
    bytes: Array<UInt8>
): CkbPublicEvidenceLeakageReport {
    let report = CkbPublicEvidenceLeakageReport()
    let text = try {
        String.fromUtf8(bytes)
    } catch (_: Exception) {
        report.diagnostic = "invalid_response_encoding"
        return report
    }
    let lower = text.toAsciiLower()
    ckbPublicEvidenceFinding(report, lower.contains("authorization:"),
        "authorization_header")
    ckbPublicEvidenceFinding(report,
        lower.contains("api_key") || lower.contains("apikey") ||
            lower.contains("x-api-key") || lower.contains("bearer "),
        "credential")
    ckbPublicEvidenceFinding(report,
        text.contains("/Users/") || text.contains("/home/") ||
            text.contains("\\\\Users\\\\"),
        "absolute_path")
    ckbPublicEvidenceFinding(report,
        lower.contains("\"prompt\"") || lower.contains("\"prompttext\""),
        "prompt_body")
    ckbPublicEvidenceFinding(report,
        lower.contains("\"solution\"") || lower.contains("\"answerbody\"") ||
            lower.contains("\"studentanswer\"") || lower.contains("\"teacheranswer\""),
        "solution_body")
    ckbPublicEvidenceFinding(report, lower.contains("\"transcript\""),
        "transcript_body")
    ckbPublicEvidenceFinding(report,
        lower.contains("\"hiddentest\"") || lower.contains("\"hiddentests\"") ||
            lower.contains("\"testbody\"") || lower.contains("\"visibletest\""),
        "test_body")
    ckbPublicEvidenceFinding(report,
        lower.contains("\"sessionid\"") || lower.contains("\"workspaceid\"") ||
            lower.contains("\"runtimehomeid\""),
        "private_runtime_identity")
    report.ok = report.findingCodes.size == 0
    report.diagnostic = if (report.ok) { "ok" } else { "sensitive_content_detected" }
    report
}

public func renderCkbPublicEvidence(
    rows: ArrayList<CkbStrictScoreEvidenceRow>
): CkbPublicEvidenceRenderResult {
    let result = CkbPublicEvidenceRenderResult()
    let ordered = ckbPublicEvidenceCanonicalRows(rows)
    let score = computeCkbHumanEvalStrictScore(ordered)
    result.score = score
    if (!score.valid) {
        result.diagnostic = score.diagnostic
        return result
    }
    let text = renderCkbStrictScoreEvidenceJsonl(ordered)
    let leakage = scanCkbPublicEvidenceLeakage(text.toArray())
    if (!leakage.ok) {
        result.diagnostic = leakage.diagnostic
        return result
    }
    let reparsed = parseCkbStrictScoreEvidenceJsonl(text.toArray())
    if (!reparsed.valid ||
        compareCkbPrivateAndPublicScores(score, reparsed, ordered[0], ordered[0])
            .diagnostic != "ok") {
        result.diagnostic = "render_roundtrip_mismatch"
        return result
    }
    result.text = text
    result.evidenceHash = benchmarkGapSha256(text)
    result.score = reparsed
    result.ok = true
    result.diagnostic = "ok"
    result
}

public func compareCkbPrivateAndPublicScores(
    privateScore: CkbHumanEvalStrictScore,
    publicScore: CkbHumanEvalStrictScore,
    privateIdentity: CkbStrictScoreEvidenceRow,
    publicIdentity: CkbStrictScoreEvidenceRow
): CkbPublicEvidenceScoreComparison {
    let result = CkbPublicEvidenceScoreComparison()
    if (!privateScore.valid || !publicScore.valid) {
        result.diagnostic = "score_invalid"
        return result
    }
    if (!ckbPublicEvidenceIdentityEqual(privateIdentity, publicIdentity)) {
        result.diagnostic = "identity_mismatch"
        return result
    }
    if (privateScore.total != publicScore.total ||
        privateScore.strictPassed != publicScore.strictPassed ||
        privateScore.strictFailed != publicScore.strictFailed ||
        privateScore.unitFirstSamplePassed != publicScore.unitFirstSamplePassed ||
        privateScore.businessFailed != publicScore.businessFailed ||
        privateScore.protocolInvalid != publicScore.protocolInvalid ||
        privateScore.transportUnresolved != publicScore.transportUnresolved) {
        result.diagnostic = "score_mismatch"
        return result
    }
    result.ok = true
    result.diagnostic = "ok"
    result
}

private func ckbPublicEvidenceClassification(
    certification: CkbCertificationCaseEvidence,
    audit: CkbCdGapAuditResultRow
): String {
    if (certification.certificationPassAt1) { return "none" }
    if (certification.unresolvedTransport == 1) { return "transport_unresolved" }
    if (audit.protocolViolation ||
        audit.failureRoute.toAsciiLower().contains("protocol") ||
        audit.failureType.toAsciiLower().contains("protocol")) {
        return "protocol_invalid"
    }
    "business_failure"
}

private func ckbPublicEvidenceSingleRowValid(row: CkbStrictScoreEvidenceRow): Bool {
    if (row.caseId == "" || row.runId == "" || row.datasetVersion == "" ||
        row.knowledgeVersion == "" || row.modelFingerprint == "" ||
        !row.providerIdentityHash.startsWith("sha256:") ||
        !row.runManifestHash.startsWith("sha256:")) {
        return false
    }
    if (row.transportAttemptCount < 1 ||
        row.transportRetryCount != row.transportAttemptCount - 1 ||
        row.retryUsed || row.fallbackUsed ||
        row.referenceExposure != 0 || row.hiddenTestExposure != 0 ||
        row.teacherExposure != 0 || row.crossCaseExposure != 0) {
        return false
    }
    if (row.classification == "transport_unresolved") {
        return row.sampleAttemptCount == 0 && row.selectedBusinessSample == 0 &&
            row.unresolvedTransport == 1 && !row.certificationPassAt1 &&
            !row.unitFirstSamplePassed
    }
    if (row.sampleAttemptCount != 1 ||
        row.selectedBusinessSample != row.transportAttemptCount ||
        row.unresolvedTransport != 0) {
        return false
    }
    if (row.classification == "none") {
        return row.certificationPassAt1 && row.unitFirstSamplePassed
    }
    if (row.classification == "business_failure") {
        return !row.certificationPassAt1 && !row.unitFirstSamplePassed
    }
    if (row.classification == "protocol_invalid") {
        return !row.certificationPassAt1
    }
    false
}

private func ckbPublicEvidenceCanonicalRows(
    rows: ArrayList<CkbStrictScoreEvidenceRow>
): ArrayList<CkbStrictScoreEvidenceRow> {
    let caseIds = ArrayList<String>()
    for (row in rows) { caseIds.add(row.caseId) }
    let orderedIds = caseIds.toArray()
    sort(orderedIds)
    let ordered = ArrayList<CkbStrictScoreEvidenceRow>()
    for (caseId in orderedIds) {
        for (row in rows) {
            if (row.caseId == caseId) {
                ordered.add(row)
                break
            }
        }
    }
    ordered
}

private func ckbPublicEvidenceFinding(
    report: CkbPublicEvidenceLeakageReport,
    matched: Bool,
    code: String
): Unit {
    if (matched) { report.findingCodes.add(code) }
}

private func ckbPublicEvidenceIdentityEqual(
    left: CkbStrictScoreEvidenceRow,
    right: CkbStrictScoreEvidenceRow
): Bool {
    left.runId == right.runId &&
        left.datasetVersion == right.datasetVersion &&
        left.knowledgeVersion == right.knowledgeVersion &&
        left.modelFingerprint == right.modelFingerprint &&
        left.providerIdentityHash == right.providerIdentityHash &&
        left.runManifestHash == right.runManifestHash
}

public func runCkbPublicEvidenceExportFromFiles(
    options: CkbPublicEvidenceCliOptions): CkbPublicEvidenceRenderResult {
    let referenceBytes = try { File.readFrom(Path(options.referenceManifest)) }
        catch (_: Exception) { return p5CliRenderFailure("public_evidence_reference_read_failed") }
    let parsedReference = parseCkbReproReferenceManifest(referenceBytes)
    if (!parsedReference[0].ok ||
        !validateCkbReproReferenceManifest(parsedReference[1]).ok ||
        parsedReference[1].baselineKind != "portable_release" ||
        parsedReference[1].evidenceStatus != "complete") {
        return p5CliRenderFailure("public_evidence_portable_reference_required")
    }
    let resultsBytes = try { File.readFrom(Path(options.runRoot).join("results.jsonl")) }
        catch (_: Exception) { return p5CliRenderFailure("public_evidence_results_missing") }
    let resultsText = try { String.fromUtf8(resultsBytes) } catch (_: Exception) {
        return p5CliRenderFailure("invalid_response_encoding")
    }
    if (benchmarkGapSha256(resultsText) != parsedReference[1].resultsHash) {
        return p5CliRenderFailure("public_evidence_results_hash_mismatch")
    }
    let rows = ArrayList<CkbStrictScoreEvidenceRow>()
    for (line in resultsText.split("\n")) {
        if (line.trimAscii() == "") { continue }
        let certification = parseCkbCertificationEvidence(line.trimAscii())
        if (!certification.valid) {
            return p5CliRenderFailure("public_evidence_certification_invalid")
        }
        let testBytes = try { File.readFrom(Path(options.runRoot).join(
            "cases/${certification.caseId}/${certification.group}/test-result.json")) }
            catch (_: Exception) { return p5CliRenderFailure("public_evidence_test_result_missing") }
        let auditBytes = try { File.readFrom(Path(options.runRoot).join(
            "cases/${certification.caseId}/${certification.group}/audit.json")) }
            catch (_: Exception) { return p5CliRenderFailure("public_evidence_audit_missing") }
        let audit = p5CliAuditProjection(certification, testBytes, auditBytes)
        if (audit[0] != "ok") { return p5CliRenderFailure(audit[0]) }
        let projected = projectCkbPublicEvidenceRow(
            line.trimAscii().toArray(), audit[1].toArray())
        if (!projected.ok) { return p5CliRenderFailure(projected.diagnostic) }
        rows.add(projected.row)
    }
    let rendered = renderCkbPublicEvidence(rows)
    if (!rendered.ok || rendered.score.strictPassed !=
            parsedReference[1].strictPassed ||
        rendered.score.unitFirstSamplePassed != parsedReference[1].rawPassed ||
        rendered.score.businessFailed != parsedReference[1].businessFailed ||
        rendered.score.protocolInvalid != parsedReference[1].protocolInvalid) {
        return p5CliRenderFailure("public_evidence_reference_score_mismatch")
    }
    let temporary = options.outputRoot + ".tmp"
    try {
        if (exists(Path(temporary))) { remove(Path(temporary), recursive: true) }
        Directory.create(Path(temporary), recursive: false)
        let score = renderCkbHumanEvalStrictScoreJson(rendered.score)
        let manifest = "{\"schemaVersion\":\"ckb-public-evidence-export-v1\"," +
            "\"referenceManifestHash\":\"${benchmarkGapSha256(String.fromUtf8(referenceBytes))}\"," +
            "\"privateResultsHash\":\"${parsedReference[1].resultsHash}\"," +
            "\"publicEvidenceHash\":\"${rendered.evidenceHash}\"}"
        for (payload in [rendered.text, score, manifest]) {
            if (!scanCkbPublicEvidenceLeakage(payload.toArray()).ok) {
                throw Exception("public evidence leakage")
            }
        }
        File.writeTo(Path(temporary).join("public-evidence.jsonl"),
            rendered.text.toArray())
        File.writeTo(Path(temporary).join("score.json"), score.toArray())
        File.writeTo(Path(temporary).join("manifest.json"), manifest.toArray())
        rename(temporary, to: options.outputRoot, overwrite: false)
        rendered
    } catch (_: Exception) {
        try { if (exists(Path(temporary))) { remove(Path(temporary), recursive: true) } }
        catch (_: Exception) {}
        p5CliRenderFailure("public_evidence_export_failed")
    }
}

private func p5CliAuditProjection(certification: CkbCertificationCaseEvidence,
    testBytes: Array<UInt8>, auditBytes: Array<UInt8>): (String, String) {
    try {
        let test = JsonValue.fromStr(String.fromUtf8(testBytes)).asObject()
        let audit = JsonValue.fromStr(String.fromUtf8(auditBytes)).asObject()
        let unit = test.get("unitPassAt1").getOrThrow().asBool().getValue()
        let testExit = test.get("testExitCode").getOrThrow().asInt().getValue()
        let failure = test.get("failureType").getOrThrow().asString().getValue()
        let violation = audit.get("violation").getOrThrow().asString().getValue()
        let protocol = violation != "none" ||
            (unit && !certification.certificationPassAt1)
        let route = if (protocol) { "protocol_failure" } else if (unit) {
            "none"
        } else { "business_failure" }
        ("ok", "{\"runMode\":\"certification\",\"caseId\":\"${p5CliJson(certification.caseId)}\"," +
            "\"group\":\"${p5CliJson(certification.group)}\",\"unitPassAt1\":${unit}," +
            "\"protocolViolation\":${protocol},\"firstClaudeExitCode\":0," +
            "\"claudeExitCode\":0,\"testExitCode\":${testExit}," +
            "\"failureType\":\"${p5CliJson(failure)}\",\"datasetVersion\":\"${p5CliJson(certification.datasetVersion)}\"," +
            "\"lineageKnowledgeVersion\":\"${p5CliJson(certification.knowledgeVersion)}\"," +
            "\"developmentPass\":false,\"closureStatus\":\"certification_closed\"," +
            "\"triageStatus\":\"none\",\"failureRoute\":\"${route}\"," +
            "\"certificationPassAt1\":null}")
    } catch (_: Exception) { ("public_evidence_private_artifact_invalid", "") }
}

private func p5CliAbsolutePath(value: String): Bool {
    value.startsWith("/") && value != "/" && !value.endsWith("/") &&
        !value.contains("//") && !value.contains("/./") &&
        !value.contains("/../") && !value.endsWith("/.") &&
        !value.endsWith("/..") && !value.contains("\\") &&
        !value.contains("\n") && !value.contains("\r") && !value.contains("\t")
}

private func p5CliRootsOverlap(left: String, right: String): Bool {
    left == right || left.startsWith(right + "/") || right.startsWith(left + "/")
}

private func p5CliExistingCanonical(value: String): Bool {
    try { canonicalize(Path(value)).toString() == value }
    catch (_: Exception) { false }
}

private func p5CliNewOutputCanonical(value: String): Bool {
    let path = Path(value)
    try {
        Path(canonicalize(path.parent).toString()).join(path.fileName).toString() == value
    } catch (_: Exception) { false }
}

private func p5CliSuccess(): CkbReproContractResult {
    let out = CkbReproContractResult(); out.ok = true; out.diagnostic = "ok"; out
}

private func p5CliFailure(code: String): CkbReproContractResult {
    let out = CkbReproContractResult(); out.diagnostic = code; out
}

private func p5CliRenderFailure(code: String): CkbPublicEvidenceRenderResult {
    let out = CkbPublicEvidenceRenderResult(); out.diagnostic = code; out
}

private func p5CliSafeDiagnostic(value: String): String {
    if (value == "" || value.toRuneArray().size > 128 || value.contains(":") ||
        value.contains("/") || value.contains("\\") || value.contains(" ")) {
        return "redacted_diagnostic"
    }
    value
}

private func p5CliJson(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"")
        .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}
