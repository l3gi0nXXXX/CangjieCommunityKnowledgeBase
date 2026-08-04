package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.fs.{Directory, File, OpenMode, Path, canonicalize, exists, remove, rename}
import std.sort.*
import std.time.DateTime
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
    public var runManifestHash: String = ""
    public var score: CkbHumanEvalStrictScore = CkbHumanEvalStrictScore()
    public init() {}
}

public class CkbPublicEvidenceScoreComparison {
    public var ok: Bool = false
    public var diagnostic: String = ""
    public init() {}
}

public class CkbPublicEvidenceExportManifest {
    public var schemaVersion: String = ""
    public var referenceManifestHash: String = ""
    public var privateResultsHash: String = ""
    public var publicEvidenceHash: String = ""
    public var runId: String = ""
    public var knowledgeVersion: String = ""
    public var providerFingerprint: String = ""
    public var modelFingerprint: String = ""
    public var runManifestHash: String = ""
    public var vectorProofHash: String = ""
    public var certifiedRunInputHash: String = ""
    public init() {}
}

public func parseCkbPublicEvidenceExportManifest(bytes: Array<UInt8>):
    (CkbPublicEvidenceScoreComparison, CkbPublicEvidenceExportManifest) {
    let manifest = CkbPublicEvidenceExportManifest()
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return (p5ExportManifestResult(false, "invalid_response_encoding"), manifest)
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        if (object.size() != 11) {
            return (p5ExportManifestResult(false,
                "public_evidence_export_manifest_invalid"), manifest)
        }
        manifest.schemaVersion = object.get("schemaVersion").getOrThrow()
            .asString().getValue()
        manifest.referenceManifestHash = object.get("referenceManifestHash")
            .getOrThrow().asString().getValue()
        manifest.privateResultsHash = object.get("privateResultsHash")
            .getOrThrow().asString().getValue()
        manifest.publicEvidenceHash = object.get("publicEvidenceHash")
            .getOrThrow().asString().getValue()
        manifest.runId = object.get("runId").getOrThrow()
            .asString().getValue()
        manifest.knowledgeVersion = object.get("knowledgeVersion").getOrThrow()
            .asString().getValue()
        manifest.providerFingerprint = object.get("providerFingerprint")
            .getOrThrow().asString().getValue()
        manifest.modelFingerprint = object.get("modelFingerprint")
            .getOrThrow().asString().getValue()
        manifest.runManifestHash = object.get("runManifestHash").getOrThrow()
            .asString().getValue()
        manifest.vectorProofHash = object.get("vectorProofHash").getOrThrow()
            .asString().getValue()
        manifest.certifiedRunInputHash = object.get("certifiedRunInputHash")
            .getOrThrow().asString().getValue()
    } catch (_: Exception) {
        return (p5ExportManifestResult(false,
            "public_evidence_export_manifest_invalid"),
            CkbPublicEvidenceExportManifest())
    }
    (p5ExportManifestResult(true, "ok"), manifest)
}

public func validateCkbPublicEvidenceExportManifest(
    manifest: CkbPublicEvidenceExportManifest): CkbPublicEvidenceScoreComparison {
    if (manifest.schemaVersion != "ckb-public-evidence-export-v1") {
        return p5ExportManifestResult(false,
            "public_evidence_export_manifest_identity_invalid")
    }
    if (manifest.runId == "" || manifest.knowledgeVersion == "" ||
        manifest.modelFingerprint == "") {
        return p5ExportManifestResult(false,
            "public_evidence_export_manifest_identity_invalid")
    }
    for (hash in [manifest.referenceManifestHash, manifest.privateResultsHash,
        manifest.publicEvidenceHash, manifest.providerFingerprint,
        manifest.runManifestHash, manifest.vectorProofHash,
        manifest.certifiedRunInputHash]) {
        if (!p5ExportManifestHashValid(hash)) {
            return p5ExportManifestResult(false,
                "public_evidence_export_manifest_hash_invalid")
        }
    }
    p5ExportManifestResult(true, "ok")
}

public func renderCkbPublicEvidenceExportManifest(
    manifest: CkbPublicEvidenceExportManifest): String {
    "{\"schemaVersion\":\"${p5CliJson(manifest.schemaVersion)}\"," +
        "\"referenceManifestHash\":\"${manifest.referenceManifestHash}\"," +
        "\"privateResultsHash\":\"${manifest.privateResultsHash}\"," +
        "\"publicEvidenceHash\":\"${manifest.publicEvidenceHash}\"," +
        "\"runId\":\"${p5CliJson(manifest.runId)}\"," +
        "\"knowledgeVersion\":\"${p5CliJson(manifest.knowledgeVersion)}\"," +
        "\"providerFingerprint\":\"${manifest.providerFingerprint}\"," +
        "\"modelFingerprint\":\"${p5CliJson(manifest.modelFingerprint)}\"," +
        "\"runManifestHash\":\"${manifest.runManifestHash}\"," +
        "\"vectorProofHash\":\"${manifest.vectorProofHash}\"," +
        "\"certifiedRunInputHash\":\"${manifest.certifiedRunInputHash}\"}"
}

private func p5ExportManifestResult(ok: Bool, diagnostic: String):
    CkbPublicEvidenceScoreComparison {
    let out = CkbPublicEvidenceScoreComparison()
    out.ok = ok; out.diagnostic = diagnostic; out
}

private func p5ExportManifestHashValid(value: String): Bool {
    if (!value.startsWith("sha256:") || value.toRuneArray().size != 71) {
        return false
    }
    var index: Int64 = 0
    for (rune in value.runes()) {
        if (index >= 7 && !((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
        index += 1
    }
    true
}

public class CkbPublicEvidenceCliOptions {
    public var runRoot: String = ""
    public var referenceManifest: String = ""
    public var outputRoot: String = ""
    public var worktreeRoot: String = ""
    public var productionRoot: String = ""
    public var userConfigRoot: String = ""
    public var unsignedRoot: String = ""
    public var finalRoot: String = ""
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
        // The filesystem exporter only removes the unique temporary path it
        // created. It never owns an output path that appeared after validation.
        true
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
            arg == "--output" || arg == "--worktree-root" ||
            arg == "--production-root" || arg == "--user-config-root" ||
            arg == "--unsigned-root" || arg == "--final-root") {
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
            } else if (arg == "--output") {
                if (out.outputRoot != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.outputRoot = value
            } else if (arg == "--worktree-root") {
                if (out.worktreeRoot != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.worktreeRoot = value
            } else if (arg == "--production-root") {
                if (out.productionRoot != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.productionRoot = value
            } else if (arg == "--user-config-root") {
                if (out.userConfigRoot != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.userConfigRoot = value
            } else if (arg == "--unsigned-root") {
                if (out.unsignedRoot != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.unsignedRoot = value
            } else {
                if (out.finalRoot != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.finalRoot = value
            }
            i += 2; continue
        }
        out.diagnostic = "unknown_argument:${arg}"; return out
    }
    if (out.runRoot == "" || out.referenceManifest == "" ||
        out.outputRoot == "" || out.worktreeRoot == "" ||
        out.productionRoot == "" || out.userConfigRoot == "" ||
        out.unsignedRoot == "" || out.finalRoot == "") {
        out.diagnostic = "required_argument_missing"; return out
    }
    out.valid = true; out.diagnostic = "ok"; out
}

public func validateCkbPublicEvidenceCliOptions(
    options: CkbPublicEvidenceCliOptions,
    context: CkbPublicEvidenceCliPathContext,
    executor: CkbPublicEvidenceCliExecutor): CkbReproContractResult {
    if (!options.valid) { return p5CliFailure(options.diagnostic) }
    if (options.worktreeRoot != context.worktreeRoot ||
        options.productionRoot != context.productionRoot ||
        options.userConfigRoot != context.userConfigRoot ||
        options.unsignedRoot != context.unsignedRoot ||
        options.finalRoot != context.finalRoot) {
        return p5CliFailure("public_evidence_context_mismatch")
    }
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
    for (protected in [context.worktreeRoot, context.productionRoot,
        context.userConfigRoot]) {
        if (!executor.exists(protected)) {
            return p5CliFailure("public_evidence_protected_root_missing")
        }
    }
    for (future in [context.unsignedRoot, context.finalRoot]) {
        if (!executor.exists(future) && !executor.outputParentExists(future)) {
            return p5CliFailure("public_evidence_future_root_parent_missing")
        }
    }
    if (!options.referenceManifest.startsWith(options.runRoot + "/")) {
        return p5CliFailure("public_evidence_reference_outside_run")
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
    let protected = [context.worktreeRoot, context.productionRoot,
        context.userConfigRoot, context.unsignedRoot, context.finalRoot]
    for (i in 0..protected.size) {
        for (j in (i + 1)..protected.size) {
            if (p5CliRootsOverlap(protected[i], protected[j])) {
                return p5CliFailure("public_evidence_protected_roots_overlap")
            }
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
    let output = try {
        Path(canonicalize(Path(options.outputRoot).parent).toString())
            .join(Path(options.outputRoot).fileName).toString()
    } catch (_: Exception) {
        return p5CliRenderFailure("public_evidence_path_not_canonical")
    }
    if (output != options.outputRoot) {
        return p5CliRenderFailure("public_evidence_path_not_canonical")
    }
    for (protected in [context.worktreeRoot, context.productionRoot,
        context.userConfigRoot, context.unsignedRoot, context.finalRoot]) {
        let path = Path(protected)
        let resolved = try {
            if (exists(path)) { canonicalize(path).toString() }
            else {
                Path(canonicalize(path.parent).toString())
                    .join(path.fileName).toString()
            }
        } catch (_: Exception) {
            return p5CliRenderFailure("public_evidence_path_not_canonical")
        }
        if (resolved != protected) {
            return p5CliRenderFailure("public_evidence_path_not_canonical")
        }
        if (p5CliRootsOverlap(output, resolved)) {
            return p5CliRenderFailure("public_evidence_output_forbidden")
        }
    }
    executeCkbPublicEvidenceCliAdapter(options, context,
        CkbPublicEvidenceFilesystemCliExecutor())
}

public func runCkbPublicEvidenceCliAdapter(options: CkbPublicEvidenceCliOptions):
    CkbPublicEvidenceRenderResult {
    let context = CkbPublicEvidenceCliPathContext()
    context.worktreeRoot = options.worktreeRoot
    context.productionRoot = options.productionRoot
    context.userConfigRoot = options.userConfigRoot
    context.unsignedRoot = options.unsignedRoot
    context.finalRoot = options.finalRoot
    runCkbPublicEvidenceCliAdapter(options, context)
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
    if (!ckbPublicEvidenceCertificationAccepted(certification)) {
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
            lower.contains("x-api-key") || lower.contains("bearer ") ||
            lower.contains("access_token") || lower.contains("token=") ||
            lower.contains("\"token\""),
        "credential")
    ckbPublicEvidenceFinding(report,
        text.contains("/Users/") || text.contains("/home/") ||
            text.contains("/private/") || text.contains("/tmp/") ||
            text.contains("/var/folders/") || text.contains("\\\\") ||
            p5CliPosixAbsolutePath(text) ||
            p5CliWindowsAbsolutePath(text),
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

// A sealed exposure violation is evidence of a protocol failure, not a reason
// to erase the case from the public strict-failure aggregate.
private func ckbPublicEvidenceCertificationAccepted(
    row: CkbCertificationCaseEvidence
): Bool {
    if (row.valid) { return true }
    row.diagnostic == "model_exposure_forbidden" &&
        row.resultEvidenceHash == benchmarkGapSha256(
            ckbCertificationEvidenceSeed(row))
}

private func ckbPublicEvidenceSingleRowValid(row: CkbStrictScoreEvidenceRow): Bool {
    if (row.caseId == "" || row.runId == "" || row.datasetVersion == "" ||
        row.knowledgeVersion == "" || row.modelFingerprint == "" ||
        !row.providerIdentityHash.startsWith("sha256:") ||
        !row.runManifestHash.startsWith("sha256:")) {
        return false
    }
    let exposure = row.referenceExposure != 0 ||
        row.hiddenTestExposure != 0 || row.teacherExposure != 0 ||
        row.crossCaseExposure != 0
    if (row.transportAttemptCount < 1 ||
        row.transportRetryCount != row.transportAttemptCount - 1 ||
        row.retryUsed || row.fallbackUsed ||
        (exposure && row.classification != "protocol_invalid")) {
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
    let referenceRead = p5CliReadBounded(options.referenceManifest, 16 * 1024 * 1024)
    if (referenceRead[0] != "ok") {
        return p5CliRenderFailure("public_evidence_reference_read_failed")
    }
    let referenceBytes = referenceRead[1]
    let parsedReference = parseCkbReproReferenceManifest(referenceBytes)
    if (!parsedReference[0].ok ||
        !validateCkbReproReferenceManifest(parsedReference[1]).ok ||
        parsedReference[1].baselineKind != "portable_release" ||
        parsedReference[1].evidenceStatus != "complete") {
        return p5CliRenderFailure("public_evidence_portable_reference_required")
    }
    if (parsedReference[1].strictPassed < 151) {
        return p5CliRenderFailure("public_evidence_target_score_required")
    }
    let rendered = projectCkbPublicEvidenceFromRunFiles(
        options.runRoot, parsedReference[1])
    if (!rendered.ok) { return rendered }
    let declaredRunManifestHash = rendered.runManifestHash
    let temporary = planCkbPublicEvidenceTemporaryPath(options.outputRoot,
        DateTime.now().toUnixTimeStamp().toMilliseconds())
    var temporaryOwned = false
    try {
        if (exists(Path(temporary))) {
            return p5CliRenderFailure("public_evidence_temporary_conflict")
        }
        Directory.create(Path(temporary), recursive: false)
        temporaryOwned = true
        let score = renderCkbHumanEvalStrictScoreJson(rendered.score)
        let exportManifest = CkbPublicEvidenceExportManifest()
        exportManifest.schemaVersion = "ckb-public-evidence-export-v1"
        exportManifest.referenceManifestHash =
            validateCkbReproReferenceManifest(parsedReference[1]).manifestHash
        exportManifest.privateResultsHash = parsedReference[1].resultsHash
        exportManifest.publicEvidenceHash = rendered.evidenceHash
        exportManifest.runId = parsedReference[1].runId
        exportManifest.knowledgeVersion = parsedReference[1].knowledgeVersion
        exportManifest.providerFingerprint =
            parsedReference[1].providerFingerprint
        exportManifest.modelFingerprint = parsedReference[1].modelFingerprint
        exportManifest.runManifestHash = declaredRunManifestHash
        exportManifest.vectorProofHash = parsedReference[1].vectorProofHash
        exportManifest.certifiedRunInputHash =
            parsedReference[1].certifiedRunInputHash
        let manifest = renderCkbPublicEvidenceExportManifest(exportManifest)
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
        try {
            if (temporaryOwned && exists(Path(temporary))) {
                remove(Path(temporary), recursive: true)
            }
        }
        catch (_: Exception) {}
        p5CliRenderFailure("public_evidence_export_failed")
    }
}

public func projectCkbPublicEvidenceFromRunFiles(
    runRoot: String,
    reference: CkbReproReferenceManifest,
    bindReferenceOutcome!: Bool = true): CkbPublicEvidenceRenderResult {
    if (!validateCkbReproReferenceManifest(reference).ok ||
        reference.baselineKind != "portable_release" ||
        reference.evidenceStatus != "complete") {
        return p5CliRenderFailure("public_evidence_portable_reference_required")
    }
    let resultsRead = p5CliReadBounded(
        Path(runRoot).join("results.jsonl").toString(), 64 * 1024 * 1024)
    if (resultsRead[0] != "ok") {
        return p5CliRenderFailure("public_evidence_results_missing")
    }
    let resultsText = try { String.fromUtf8(resultsRead[1]) }
        catch (_: Exception) {
            return p5CliRenderFailure("invalid_response_encoding")
        }
    if (bindReferenceOutcome &&
        benchmarkGapSha256(resultsText) != reference.resultsHash) {
        return p5CliRenderFailure("public_evidence_results_hash_mismatch")
    }
    let runManifestRead = p5CliReadBounded(
        Path(runRoot).join("run-manifest.json").toString(), 16 * 1024 * 1024)
    if (runManifestRead[0] != "ok") {
        return p5CliRenderFailure("public_evidence_run_manifest_missing")
    }
    let declaredRunManifestHash = p5RunManifestHash(runManifestRead[1])
    if (declaredRunManifestHash == "") {
        return p5CliRenderFailure("public_evidence_run_manifest_invalid")
    }
    let rows = ArrayList<CkbStrictScoreEvidenceRow>()
    for (line in resultsText.split("\n")) {
        let certificationLine = line.trimAscii()
        if (certificationLine == "") { continue }
        let certification = parseCkbCertificationEvidence(certificationLine)
        if (!ckbPublicEvidenceCertificationAccepted(certification)) {
            return p5CliRenderFailure("public_evidence_certification_invalid")
        }
        if (certification.runId != reference.runId ||
            certification.knowledgeVersion != reference.knowledgeVersion ||
            certification.providerIdentityHash != reference.providerFingerprint ||
            certification.expectedModelVersion != reference.model ||
            (certification.sampleAttemptCount == 1 &&
                certification.observedModelVersion != reference.model) ||
            certification.claudeCodeVersion != reference.claudeCodeVersion ||
            certification.runManifestHash != declaredRunManifestHash) {
            return p5CliRenderFailure(
                "public_evidence_reference_identity_mismatch")
        }
        if (!validateCkbPublicEvidenceArtifactIdentity(
                certification.caseId, certification.group).ok) {
            return p5CliRenderFailure("public_evidence_case_identity_invalid")
        }
        let caseRoot = Path(runRoot).join(
            "cases/${certification.caseId}/${certification.group}")
        let testPath = caseRoot.join("test-result.json").toString()
        let auditPath = caseRoot.join("audit.json").toString()
        if (!exists(Path(testPath))) {
            return p5CliRenderFailure("public_evidence_test_result_missing")
        }
        if (!exists(Path(auditPath))) {
            return p5CliRenderFailure("public_evidence_audit_missing")
        }
        if (!p5CliCanonicalArtifactPath(runRoot, testPath) ||
            !p5CliCanonicalArtifactPath(runRoot, auditPath)) {
            return p5CliRenderFailure("public_evidence_artifact_path_invalid")
        }
        let testRead = p5CliReadBounded(testPath, 16 * 1024 * 1024)
        if (testRead[0] != "ok") {
            return p5CliRenderFailure("public_evidence_test_result_missing")
        }
        let auditRead = p5CliReadBounded(auditPath, 16 * 1024 * 1024)
        if (auditRead[0] != "ok") {
            return p5CliRenderFailure("public_evidence_audit_missing")
        }
        let audit = projectCkbPublicAuditFromPrivateArtifacts(
            certification, testRead[1], auditRead[1])
        if (audit[0] != "ok") { return p5CliRenderFailure(audit[0]) }
        let projected = projectCkbPublicEvidenceRow(
            certificationLine.toArray(), audit[1].toArray())
        if (!projected.ok) { return p5CliRenderFailure(projected.diagnostic) }
        rows.add(projected.row)
    }
    let rendered = renderCkbPublicEvidence(rows)
    if (!rendered.ok || (bindReferenceOutcome &&
        (rendered.score.strictPassed != reference.strictPassed ||
        rendered.score.unitFirstSamplePassed != reference.rawPassed ||
        rendered.score.businessFailed != reference.businessFailed ||
        rendered.score.protocolInvalid != reference.protocolInvalid))) {
        return p5CliRenderFailure("public_evidence_reference_score_mismatch")
    }
    rendered.runManifestHash = declaredRunManifestHash
    rendered
}

private func p5RunManifestHash(bytes: Array<UInt8>): String {
    try {
        let value = JsonValue.fromStr(String.fromUtf8(bytes)).asObject()
            .get("runManifestHash").getOrThrow().asString().getValue()
        if (p5ExportManifestHashValid(value)) { value } else { "" }
    } catch (_: Exception) { "" }
}

public func projectCkbPublicAuditFromPrivateArtifacts(
    certification: CkbCertificationCaseEvidence,
    testBytes: Array<UInt8>, auditBytes: Array<UInt8>): (String, String) {
    try {
        let test = JsonValue.fromStr(String.fromUtf8(testBytes)).asObject()
        let audit = JsonValue.fromStr(String.fromUtf8(auditBytes)).asObject()
        let unit = test.get("unitPassAt1").getOrThrow().asBool().getValue()
        let testExit = test.get("testExitCode").getOrThrow().asInt().getValue()
        let failure = test.get("failureType").getOrThrow().asString().getValue()
        let firstClaudeExit = match (test.get("firstClaudeExitCode")) {
            case Some(value) => value.asInt().getValue()
            case None => 0
        }
        let claudeExit = match (test.get("claudeExitCode")) {
            case Some(value) => value.asInt().getValue()
            case None => 0
        }
        let violation = audit.get("violation").getOrThrow().asString().getValue()
        let development = match (audit.get("developmentPass")) {
            case Some(value) => value.asBool().getValue()
            case None => false
        }
        let closure = match (audit.get("closureStatus")) {
            case Some(value) => value.asString().getValue()
            case None => "closed"
        }
        let triage = match (audit.get("triageStatus")) {
            case Some(value) => value.asString().getValue()
            case None => "complete"
        }
        let recordedRoute = match (audit.get("failureRoute")) {
            case Some(value) => value.asString().getValue()
            case None => ""
        }
        let certificationValue = match (audit.get("certificationPassAt1")) {
            case Some(value) => value.toString()
            case None => "null"
        }
        if (certificationValue != "null") {
            return ("public_evidence_private_artifact_invalid", "")
        }
        let protocol = violation != "none" || certification.referenceExposure != 0 ||
            certification.hiddenTestExposure != 0 ||
            certification.teacherExposure != 0 ||
            certification.crossCaseExposure != 0 ||
            (unit && !certification.certificationPassAt1)
        let route = if (protocol) { "protocol_failure" } else if (unit) {
            "none"
        } else { "business_failure" }
        if (recordedRoute != "" && recordedRoute != route) {
            return ("public_evidence_private_artifact_mismatch", "")
        }
        ("ok", "{\"runMode\":\"certification\",\"caseId\":\"${p5CliJson(certification.caseId)}\"," +
            "\"group\":\"${p5CliJson(certification.group)}\",\"unitPassAt1\":${unit}," +
            "\"protocolViolation\":${protocol},\"firstClaudeExitCode\":${firstClaudeExit}," +
            "\"claudeExitCode\":${claudeExit},\"testExitCode\":${testExit}," +
            "\"failureType\":\"${p5CliJson(failure)}\",\"datasetVersion\":\"${p5CliJson(certification.datasetVersion)}\"," +
            "\"lineageKnowledgeVersion\":\"${p5CliJson(certification.knowledgeVersion)}\"," +
            "\"developmentPass\":${development},\"closureStatus\":\"${p5CliJson(closure)}\"," +
            "\"triageStatus\":\"${p5CliJson(triage)}\",\"failureRoute\":\"${route}\"," +
            "\"certificationPassAt1\":${certificationValue}}")
    } catch (_: Exception) { ("public_evidence_private_artifact_invalid", "") }
}

public func planCkbPublicEvidenceTemporaryPath(output: String,
    nonce: Int64): String {
    "${output}.tmp-${nonce}"
}

public func validateCkbPublicEvidenceArtifactIdentity(
    caseId: String, group: String): CkbReproContractResult {
    if (group != CkbAbcdeGroups.D) {
        return p5CliFailure("public_evidence_group_invalid")
    }
    for (index in 0..164) {
        if (caseId == p5CliCaseId(index)) { return p5CliSuccess() }
    }
    p5CliFailure("public_evidence_case_id_invalid")
}

public func validateCkbPublicEvidenceArtifactPath(
    runRoot: String, candidate: String): CkbReproContractResult {
    if (!p5CliAbsolutePath(runRoot) || !p5CliAbsolutePath(candidate) ||
        !candidate.startsWith(runRoot + "/")) {
        return p5CliFailure("public_evidence_artifact_path_invalid")
    }
    p5CliSuccess()
}

private func p5CliCaseId(index: Int64): String {
    if (index < 10) { return "CJ-HUMANEVAL-00${index}" }
    if (index < 100) { return "CJ-HUMANEVAL-0${index}" }
    "CJ-HUMANEVAL-${index}"
}

private func p5CliCanonicalArtifactPath(runRoot: String,
    candidate: String): Bool {
    if (!validateCkbPublicEvidenceArtifactPath(runRoot, candidate).ok) {
        return false
    }
    try {
        let root = canonicalize(Path(runRoot)).toString()
        let artifact = canonicalize(Path(candidate)).toString()
        artifact.startsWith(root + "/")
    } catch (_: Exception) { false }
}

private func p5CliReadBounded(path: String, limit: Int64):
    (String, Array<UInt8>) {
    let bytes = ArrayList<UInt8>()
    try {
        try (file = File(Path(path), OpenMode.Read)) {
            let buffer = Array<UInt8>(65536, repeat: UInt8(0))
            while (true) {
                let count = file.read(buffer)
                if (count < 0 || count > buffer.size) {
                    return ("read_failed", Array<UInt8>())
                }
                if (count == 0) { break }
                if (bytes.size + count > limit) {
                    return ("size_invalid", Array<UInt8>())
                }
                for (i in 0..count) { bytes.add(buffer[i]) }
            }
        }
        ("ok", bytes.toArray())
    } catch (_: Exception) { ("read_failed", Array<UInt8>()) }
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
        .replace("\u{0000}", "\\u0000").replace("\u{0001}", "\\u0001")
        .replace("\u{0002}", "\\u0002").replace("\u{0003}", "\\u0003")
        .replace("\u{0004}", "\\u0004").replace("\u{0005}", "\\u0005")
        .replace("\u{0006}", "\\u0006").replace("\u{0007}", "\\u0007")
        .replace("\u{0008}", "\\b").replace("\t", "\\t")
        .replace("\n", "\\n").replace("\u{000b}", "\\u000b")
        .replace("\u{000c}", "\\f").replace("\r", "\\r")
        .replace("\u{000e}", "\\u000e").replace("\u{000f}", "\\u000f")
        .replace("\u{0010}", "\\u0010").replace("\u{0011}", "\\u0011")
        .replace("\u{0012}", "\\u0012").replace("\u{0013}", "\\u0013")
        .replace("\u{0014}", "\\u0014").replace("\u{0015}", "\\u0015")
        .replace("\u{0016}", "\\u0016").replace("\u{0017}", "\\u0017")
        .replace("\u{0018}", "\\u0018").replace("\u{0019}", "\\u0019")
        .replace("\u{001a}", "\\u001a").replace("\u{001b}", "\\u001b")
        .replace("\u{001c}", "\\u001c").replace("\u{001d}", "\\u001d")
        .replace("\u{001e}", "\\u001e").replace("\u{001f}", "\\u001f")
}

private func p5CliWindowsAbsolutePath(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size < 3) { return false }
    for (i in 0..(runes.size - 2)) {
        let boundary = i == 0 || runes[i - 1] == r' ' ||
            runes[i - 1] == r'\t' || runes[i - 1] == r'\n' ||
            runes[i - 1] == r'\r' || runes[i - 1] == r'"' ||
            runes[i - 1] == r'\''
        if (boundary && ((runes[i] >= r'a' && runes[i] <= r'z') ||
            (runes[i] >= r'A' && runes[i] <= r'Z')) &&
            runes[i + 1] == r':' &&
            (runes[i + 2] == r'/' || runes[i + 2] == r'\\')) {
            return true
        }
    }
    false
}

private func p5CliPosixAbsolutePath(value: String): Bool {
    let normalized = value.replace("\n", " ").replace("\r", " ")
        .replace("\t", " ").replace("\"", " ").replace("'", " ")
        .replace(",", " ").replace(";", " ").replace("{", " ")
        .replace("}", " ").replace("[", " ").replace("]", " ")
        .replace("(", " ").replace(")", " ")
    for (token in normalized.split(" ")) {
        if (!token.startsWith("/") || token.contains("://")) { continue }
        let parts = token.split("/")
        if (parts.size < 2 || parts[1] == "") { continue }
        let root = parts[1].toAsciiLower()
        if (root != "v1" && root != "v2" && root != "api" &&
            root != "knowledge" && root != "guide" && root != "docs") {
            return true
        }
    }
    false
}
