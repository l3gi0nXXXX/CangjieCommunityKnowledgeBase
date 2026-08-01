package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
import std.fs.{File, Path, canonicalize, exists}
import std.io.{InputStream, StringReader}
import std.process.{ProcessRedirect, launch}
import stdx.encoding.json.*

public class CkbReproPublishGateOptions {
    public var mode: String = ""
    public var releaseRepository: String = ""
    public var releaseCommit: String = ""
    public var tagName: String = ""
    public var releaseTitle: String = ""
    public var signingFingerprint: String = ""
    public init() {}
}

public class CkbReproGitEvidence {
    public var originRepository: String = ""
    public var headCommit: String = ""
    public var originMainCommit: String = ""
    public var tagExistsLocal: Bool = false
    public var tagExistsRemote: Bool = false
    public var tagCommit: String = ""
    public init() {}
}

public class CkbReproSignatureEvidence {
    public var shaSumsVerified: Bool = false
    public var shaSumsFingerprint: String = ""
    public var tagSigned: Bool = false
    public var tagFingerprint: String = ""
    public init() {}
}

public class CkbReproPublishEvidence {
    public var inputSetHashMatches: Bool = false
    public var manifestCoverageComplete: Bool = false
    public var shaCoverageComplete: Bool = false
    public var noSelfReference: Bool = false
    public var p8BindingMatches: Bool = false
    public var runCriticalTreeMatches: Bool = false
    public var strictPassed: Int64 = 0
    public var transportUnresolved: Int64 = 0
    public var leakageFindingCount: Int64 = 0
    public var fullTestsPassed: Bool = false
    public var licenseComplete: Bool = false
    public var externalProofsVerified: Bool = false
    public init() {}
}

public class CkbReproPublishGateResult {
    public var componentReady: Bool = false
    public var publishable: Bool = false
    public var diagnostic: String = "not_validated"
    public init() {}
}

public interface CkbReproGitEvidenceProvider {
    func inspect(): CkbReproGitEvidence
}

public interface CkbReproSignatureVerifier {
    func verify(): CkbReproSignatureEvidence
}

public class CkbReproPublishGateCliOptions {
    public var mode: String = ""
    public var bundleRoot: String = ""
    public var json: Bool = false
    public var valid: Bool = false
    public var diagnostic: String = "usage_error"
    public init() {}
}

public interface CkbReproPublishGateCliExecutor {
    func exists(path: String): Bool
    func evaluate(options: CkbReproPublishGateCliOptions):
        CkbReproPublishGateResult
}

public class CkbReproLocalPublishGateCliExecutor <:
    CkbReproPublishGateCliExecutor {
    private let gateOptions: CkbReproPublishGateOptions
    private let evidence: CkbReproPublishEvidence
    private let gitProvider: CkbReproGitEvidenceProvider
    private let signatureVerifier: CkbReproSignatureVerifier
    public init(options: CkbReproPublishGateOptions,
        proof: CkbReproPublishEvidence,
        git: CkbReproGitEvidenceProvider,
        signature: CkbReproSignatureVerifier) {
        this.gateOptions = options
        this.evidence = proof
        this.gitProvider = git
        this.signatureVerifier = signature
    }
    public func exists(path: String): Bool { exists(Path(path)) }
    public func evaluate(options: CkbReproPublishGateCliOptions):
        CkbReproPublishGateResult {
        this.gateOptions.mode = options.mode
        validateCkbReproPublishBundle(this.gateOptions, this.evidence,
            this.gitProvider, this.signatureVerifier)
    }
}

public class CkbReproPublishLocalEvidence {
    public var gateOptions: CkbReproPublishGateOptions = CkbReproPublishGateOptions()
    public var evidence: CkbReproPublishEvidence = CkbReproPublishEvidence()
    public var valid: Bool = false
    public var diagnostic: String = "not_parsed"
    public init() {}
}

public class CkbReproFilesystemPublishGateCliExecutor <:
    CkbReproPublishGateCliExecutor {
    public init() {}
    public func exists(path: String): Bool { exists(Path(path)) }
    public func evaluate(options: CkbReproPublishGateCliOptions):
        CkbReproPublishGateResult {
        let loaded = loadCkbReproPublishLocalEvidence(options.bundleRoot)
        if (!loaded.valid) { return p9PublishCliFailure(loaded.diagnostic) }
        loaded.gateOptions.mode = options.mode
        let git = p9PublishReadGitEvidence(loaded.gateOptions)
        if (git[0] != "ok") { return p9PublishCliFailure(git[0]) }
        let signature = p9PublishReadSignatureEvidence(
            options.bundleRoot, loaded.gateOptions, options.mode)
        if (signature[0] != "ok") { return p9PublishCliFailure(signature[0]) }
        validateCkbReproPublishBundle(loaded.gateOptions, loaded.evidence,
            P9PublishFixedGitProvider(git[1]),
            P9PublishFixedSignatureVerifier(signature[1]))
    }
}

private class P9PublishFixedGitProvider <: CkbReproGitEvidenceProvider {
    private let value: CkbReproGitEvidence
    public init(input: CkbReproGitEvidence) { this.value = input }
    public func inspect(): CkbReproGitEvidence { this.value }
}

private class P9PublishFixedSignatureVerifier <: CkbReproSignatureVerifier {
    private let value: CkbReproSignatureEvidence
    public init(input: CkbReproSignatureEvidence) { this.value = input }
    public func verify(): CkbReproSignatureEvidence { this.value }
}

public func parseCkbReproPublishGateCliArgs(args: Array<String>):
    CkbReproPublishGateCliOptions {
    let out = CkbReproPublishGateCliOptions()
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "ckb-repro-publish-gate") { i += 1; continue }
        if (arg == "--json") {
            if (out.json) { out.diagnostic = "duplicate_argument:--json"; return out }
            out.json = true; i += 1; continue
        }
        if (arg == "--mode" || arg == "--bundle") {
            if (i + 1 >= args.size) { out.diagnostic = "missing_value:${arg}"; return out }
            let value = args[i + 1]
            if (arg == "--mode") {
                if (out.mode != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.mode = value
            } else {
                if (out.bundleRoot != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.bundleRoot = value
            }
            i += 2; continue
        }
        out.diagnostic = "unknown_argument:${arg}"; return out
    }
    if (out.mode != "pre-tag" && out.mode != "post-tag") {
        out.diagnostic = "publish_mode_invalid"; return out
    }
    if (!p9PublishAbsolutePath(out.bundleRoot)) {
        out.diagnostic = "publish_bundle_root_invalid"; return out
    }
    out.valid = true; out.diagnostic = "ok"; out
}

public func validateCkbReproPublishGateCliOptions(
    options: CkbReproPublishGateCliOptions,
    executor: CkbReproPublishGateCliExecutor): CkbReproPublishGateResult {
    if (!options.valid) { return p9PublishCliFailure(options.diagnostic) }
    if (!executor.exists(options.bundleRoot)) {
        return p9PublishCliFailure("publish_bundle_root_missing")
    }
    let out = CkbReproPublishGateResult()
    out.componentReady = true
    out.diagnostic = "ok"
    out
}

public func executeCkbReproPublishGateCliAdapter(
    options: CkbReproPublishGateCliOptions,
    executor: CkbReproPublishGateCliExecutor): CkbReproPublishGateResult {
    let checked = validateCkbReproPublishGateCliOptions(options, executor)
    if (checked.diagnostic != "ok") { return checked }
    try { executor.evaluate(options) }
    catch (_: Exception) { p9PublishCliFailure("publish_gate_execution_failed") }
}

public func runCkbReproPublishGateCliAdapter(
    options: CkbReproPublishGateCliOptions,
    gateOptions: CkbReproPublishGateOptions,
    evidence: CkbReproPublishEvidence,
    gitProvider: CkbReproGitEvidenceProvider,
    signatureVerifier: CkbReproSignatureVerifier): CkbReproPublishGateResult {
    executeCkbReproPublishGateCliAdapter(options,
        CkbReproLocalPublishGateCliExecutor(gateOptions, evidence,
            gitProvider, signatureVerifier))
}

public func runCkbReproPublishGateCliAdapter(
    options: CkbReproPublishGateCliOptions): CkbReproPublishGateResult {
    executeCkbReproPublishGateCliAdapter(options,
        CkbReproFilesystemPublishGateCliExecutor())
}

public func parseCkbReproPublishLocalEvidence(bytes: Array<UInt8>):
    CkbReproPublishLocalEvidence {
    let out = CkbReproPublishLocalEvidence()
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        out.diagnostic = "invalid_response_encoding"; return out
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        if (object.size() != 21) {
            out.diagnostic = "publish_local_evidence_field_contract_invalid"
            return out
        }
        if (p9PublishLocalString(object, "schemaVersion") !=
            "ckb-repro-publish-local-evidence-v1") {
            out.diagnostic = "publish_local_evidence_schema_invalid"; return out
        }
        let options = out.gateOptions
        options.releaseRepository = p9PublishLocalString(object, "releaseRepository")
        options.releaseCommit = p9PublishLocalString(object, "releaseCommit")
        options.tagName = p9PublishLocalString(object, "tagName")
        options.releaseTitle = p9PublishLocalString(object, "releaseTitle")
        options.signingFingerprint = p9PublishLocalString(object, "signingFingerprint")
        let evidence = out.evidence
        evidence.inputSetHashMatches = p9PublishLocalBool(object, "inputSetHashMatches")
        evidence.manifestCoverageComplete = p9PublishLocalBool(object, "manifestCoverageComplete")
        evidence.shaCoverageComplete = p9PublishLocalBool(object, "shaCoverageComplete")
        evidence.noSelfReference = p9PublishLocalBool(object, "noSelfReference")
        evidence.p8BindingMatches = p9PublishLocalBool(object, "p8BindingMatches")
        evidence.runCriticalTreeMatches = p9PublishLocalBool(object, "runCriticalTreeMatches")
        evidence.strictPassed = p9PublishLocalInt(object, "strictPassed")
        evidence.transportUnresolved = p9PublishLocalInt(object, "transportUnresolved")
        evidence.leakageFindingCount = p9PublishLocalInt(object, "leakageFindingCount")
        evidence.fullTestsPassed = p9PublishLocalBool(object, "fullTestsPassed")
        evidence.licenseComplete = p9PublishLocalBool(object, "licenseComplete")
        evidence.externalProofsVerified = p9PublishLocalBool(object, "externalProofsVerified")
        let verificationHash = p9PublishLocalString(object, "verificationReportHash")
        let attestationHash = p9PublishLocalString(object, "buildAttestationHash")
        for (hash in [verificationHash, attestationHash]) {
            if (!p9PublishHash(hash)) {
                out.diagnostic = "publish_local_evidence_hash_invalid"; return out
            }
        }
        if (p9PublishLocalString(object, "evidenceHash") !=
            ckbReproBundleHash(p9PublishLocalEvidenceSeed(out,
                verificationHash, attestationHash).toArray())) {
            out.diagnostic = "publish_local_evidence_hash_mismatch"; return out
        }
        if (options.releaseRepository == "" ||
            !p9PublishCommit(options.releaseCommit) ||
            options.tagName == "" || options.releaseTitle == "" ||
            !p9PublishFingerprint(options.signingFingerprint)) {
            out.diagnostic = "publish_identity_invalid"; return out
        }
        out.valid = true; out.diagnostic = "ok"; out
    } catch (_: Exception) {
        out.diagnostic = "malformed_json"; out
    }
}

public func renderCkbReproPublishLocalEvidence(
    value: CkbReproPublishLocalEvidence,
    verificationHash: String, attestationHash: String): String {
    let o = value.gateOptions
    let e = value.evidence
    let hash = ckbReproBundleHash(p9PublishLocalEvidenceSeed(value,
        verificationHash, attestationHash).toArray())
    "{\"schemaVersion\":\"ckb-repro-publish-local-evidence-v1\"," +
        "\"releaseRepository\":\"${p9PublishJson(o.releaseRepository)}\"," +
        "\"releaseCommit\":\"${p9PublishJson(o.releaseCommit)}\"," +
        "\"tagName\":\"${p9PublishJson(o.tagName)}\"," +
        "\"releaseTitle\":\"${p9PublishJson(o.releaseTitle)}\"," +
        "\"signingFingerprint\":\"${p9PublishJson(o.signingFingerprint)}\"," +
        "\"inputSetHashMatches\":${e.inputSetHashMatches}," +
        "\"manifestCoverageComplete\":${e.manifestCoverageComplete}," +
        "\"shaCoverageComplete\":${e.shaCoverageComplete}," +
        "\"noSelfReference\":${e.noSelfReference}," +
        "\"p8BindingMatches\":${e.p8BindingMatches}," +
        "\"runCriticalTreeMatches\":${e.runCriticalTreeMatches}," +
        "\"strictPassed\":${e.strictPassed}," +
        "\"transportUnresolved\":${e.transportUnresolved}," +
        "\"leakageFindingCount\":${e.leakageFindingCount}," +
        "\"fullTestsPassed\":${e.fullTestsPassed}," +
        "\"licenseComplete\":${e.licenseComplete}," +
        "\"externalProofsVerified\":${e.externalProofsVerified}," +
        "\"verificationReportHash\":\"${verificationHash}\"," +
        "\"buildAttestationHash\":\"${attestationHash}\"," +
        "\"evidenceHash\":\"${hash}\"}"
}

public func loadCkbReproPublishLocalEvidence(bundleRoot: String):
    CkbReproPublishLocalEvidence {
    let failed = CkbReproPublishLocalEvidence()
    let files = ["PUBLISH-EVIDENCE.json", "RELEASE-MANIFEST.json",
        "SHA256SUMS", "SHA256SUMS.sig", "verification-report.json",
        "build-attestation.json"]
    for (name in files) {
        if (!p9PublishSafeBundleFile(bundleRoot, name)) {
            failed.diagnostic = "publish_bundle_required_evidence_missing"
            return failed
        }
    }
    let evidenceBytes = try {
        File.readFrom(Path(bundleRoot).join("PUBLISH-EVIDENCE.json"))
    } catch (_: Exception) {
        failed.diagnostic = "publish_bundle_evidence_read_failed"; return failed
    }
    let parsed = parseCkbReproPublishLocalEvidence(evidenceBytes)
    if (!parsed.valid) { return parsed }
    let text = try { String.fromUtf8(evidenceBytes) } catch (_: Exception) {
        failed.diagnostic = "invalid_response_encoding"; return failed
    }
    let object = try { JsonValue.fromStr(text).asObject() } catch (_: Exception) {
        failed.diagnostic = "malformed_json"; return failed
    }
    for (item in [("verification-report.json", "verificationReportHash"),
        ("build-attestation.json", "buildAttestationHash")]) {
        let bytes = try { File.readFrom(Path(bundleRoot).join(item[0])) }
            catch (_: Exception) {
                failed.diagnostic = "publish_bundle_evidence_read_failed"; return failed
            }
        if (ckbReproBundleHash(bytes) != p9PublishLocalString(object, item[1])) {
            failed.diagnostic = "publish_bundle_evidence_hash_mismatch"; return failed
        }
        if (item[0].endsWith(".json")) {
            try { _ = JsonValue.fromStr(String.fromUtf8(bytes)).asObject() }
            catch (_: Exception) {
                failed.diagnostic = "publish_bundle_evidence_malformed"; return failed
            }
        }
    }
    let manifestBytes = try { File.readFrom(Path(bundleRoot).join(
        "RELEASE-MANIFEST.json")) } catch (_: Exception) { Array<UInt8>() }
    let manifest = parseCkbReproBundleManifest(manifestBytes)
    if (!manifest[0].ok) {
        failed.diagnostic = "publish_release_manifest_invalid"; return failed
    }
    let derived = p9PublishDeriveEvidence(bundleRoot, parsed, manifest[1])
    if (derived != "ok") { failed.diagnostic = derived; return failed }
    parsed
}

public func renderCkbReproPublishGateCliHuman(
    result: CkbReproPublishGateResult): String {
    "publish gate: ${if (result.publishable) { "passed" } else if (result.componentReady) { "component ready" } else { "blocked" }}\n" +
        "diagnostic: ${p9PublishSafeDiagnostic(result.diagnostic)}\n" +
        "external publish action: none\n"
}

public func renderCkbReproPublishGateCliJson(
    result: CkbReproPublishGateResult): String {
    "{\"componentReady\":${result.componentReady},\"publishable\":${result.publishable}," +
        "\"diagnostic\":\"${p9PublishJson(p9PublishSafeDiagnostic(result.diagnostic))}\"}"
}

public func validateCkbTagReleaseBindingEvidence(
    options: CkbReproPublishGateOptions, git: CkbReproGitEvidence,
    signature: CkbReproSignatureEvidence): CkbReproPublishGateResult {
    let out = CkbReproPublishGateResult()
    if (options.mode != "pre-tag" && options.mode != "post-tag") {
        out.diagnostic = "publish_mode_invalid"
        return out
    }
    if (options.tagName == "" || options.releaseTitle == "" ||
        !p9PublishFingerprint(options.signingFingerprint)) {
        out.diagnostic = "publish_identity_invalid"
        return out
    }
    if (normalizeCkbReproRepositoryRemote(git.originRepository) !=
        options.releaseRepository) {
        out.diagnostic = "publish_repository_mismatch"
        return out
    }
    if (!p9PublishCommit(options.releaseCommit) ||
        git.headCommit != options.releaseCommit ||
        git.originMainCommit != options.releaseCommit) {
        out.diagnostic = "publish_commit_mismatch"
        return out
    }
    if (!signature.shaSumsVerified ||
        signature.shaSumsFingerprint != options.signingFingerprint) {
        out.diagnostic = "publish_signature_mismatch"
        return out
    }
    if (options.mode == "pre-tag") {
        if (git.tagExistsLocal || git.tagExistsRemote) {
            out.diagnostic = "publish_tag_already_exists"
            return out
        }
    } else if (!git.tagExistsLocal || !git.tagExistsRemote ||
        git.tagCommit != options.releaseCommit || !signature.tagSigned ||
        signature.tagFingerprint != options.signingFingerprint) {
        out.diagnostic = "publish_tag_binding_mismatch"
        return out
    }
    out.componentReady = true
    out.diagnostic = "component_ready_external_proofs_required"
    out
}

public func validateCkbReproPublishBundle(options: CkbReproPublishGateOptions,
    evidence: CkbReproPublishEvidence, gitProvider: CkbReproGitEvidenceProvider,
    signatureVerifier: CkbReproSignatureVerifier): CkbReproPublishGateResult {
    let failed = p9PublishEvidenceDiagnostic(evidence)
    if (failed != "ok") {
        let out = CkbReproPublishGateResult()
        out.diagnostic = failed
        return out
    }
    let out = validateCkbTagReleaseBindingEvidence(options,
        gitProvider.inspect(), signatureVerifier.verify())
    if (!out.componentReady) { return out }
    // W2 deliberately cannot turn synthetic evidence into a release decision.
    // The W2 component has no authority to publish, even if a caller supplies
    // a handcrafted "verified" flag. W7-W11 bind real typed proofs.
    out.publishable = false
    out.diagnostic = "component_ready_external_proofs_required"
    out
}

public func renderCkbReproPublishGateReport(
    result: CkbReproPublishGateResult): String {
    "{\"schemaVersion\":\"ckb-repro-publish-gate-component-v1\"," +
        "\"componentReady\":${result.componentReady}," +
        "\"publishable\":${result.publishable}," +
        "\"diagnostic\":\"${p9PublishJson(result.diagnostic)}\"}"
}

private func p9PublishEvidenceDiagnostic(evidence: CkbReproPublishEvidence):
    String {
    if (!evidence.inputSetHashMatches) { return "publish_input_set_mismatch" }
    if (!evidence.manifestCoverageComplete) { return "publish_manifest_incomplete" }
    if (!evidence.shaCoverageComplete) { return "publish_sha_coverage_incomplete" }
    if (!evidence.noSelfReference) { return "publish_self_reference_forbidden" }
    if (!evidence.p8BindingMatches) { return "publish_p8_binding_mismatch" }
    if (!evidence.runCriticalTreeMatches) { return "publish_run_critical_drift" }
    if (evidence.strictPassed != 151 || evidence.transportUnresolved != 0) {
        return "publish_reference_score_mismatch"
    }
    if (evidence.leakageFindingCount != 0) {
        return "publish_leakage_gate_failed"
    }
    if (!evidence.fullTestsPassed) { return "publish_tests_failed" }
    if (!evidence.licenseComplete) { return "publish_license_incomplete" }
    "ok"
}

private func p9PublishCommit(value: String): Bool {
    if (value.size != 40) { return false }
    for (rune in value.runes()) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
    }
    true
}

private func p9PublishFingerprint(value: String): Bool {
    if (value.size != 40) { return false }
    for (rune in value.runes()) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'A' && rune <= r'F'))) { return false }
    }
    true
}

private func p9PublishJson(value: String): String {
    value.replace("\\", "\\\\").replace("\"", "\\\"")
        .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}

private func p9PublishAbsolutePath(value: String): Bool {
    value.startsWith("/") && value != "/" && !value.endsWith("/") &&
        !value.contains("//") && !value.contains("/./") &&
        !value.contains("/../") && !value.endsWith("/.") &&
        !value.endsWith("/..") && !value.contains("\\") &&
        !value.contains("\n") && !value.contains("\r") &&
        value.toRuneArray().size <= 4096
}

private func p9PublishCliFailure(code: String): CkbReproPublishGateResult {
    let out = CkbReproPublishGateResult(); out.diagnostic = code; out
}

private func p9PublishSafeDiagnostic(value: String): String {
    if (value == "" || value.toRuneArray().size > 128 || value.contains(":") ||
        value.contains("/") || value.contains("\\") || value.contains(" ")) {
        return "redacted_diagnostic"
    }
    value
}

private func p9PublishLocalString(object: JsonObject, key: String): String {
    object.get(key).getOrThrow().asString().getValue()
}

private func p9PublishLocalBool(object: JsonObject, key: String): Bool {
    object.get(key).getOrThrow().asBool().getValue()
}

private func p9PublishLocalInt(object: JsonObject, key: String): Int64 {
    object.get(key).getOrThrow().asInt().getValue()
}

private func p9PublishHash(value: String): Bool {
    if (!value.startsWith("sha256:") || value.toRuneArray().size != 71) {
        return false
    }
    for (rune in value.toRuneArray()[7..]) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
    }
    true
}

private func p9PublishLocalEvidenceSeed(
    value: CkbReproPublishLocalEvidence,
    verificationHash: String, attestationHash: String): String {
    let o = value.gateOptions
    let e = value.evidence
    "ckb-repro-publish-local-evidence-v1|${o.releaseRepository}|" +
        "${o.releaseCommit}|${o.tagName}|${o.releaseTitle}|" +
        "${o.signingFingerprint}|${e.inputSetHashMatches}|" +
        "${e.manifestCoverageComplete}|${e.shaCoverageComplete}|" +
        "${e.noSelfReference}|${e.p8BindingMatches}|" +
        "${e.runCriticalTreeMatches}|${e.strictPassed}|" +
        "${e.transportUnresolved}|${e.leakageFindingCount}|" +
        "${e.fullTestsPassed}|${e.licenseComplete}|" +
        "${e.externalProofsVerified}|${verificationHash}|${attestationHash}"
}

private func p9PublishSafeBundleFile(root: String, name: String): Bool {
    if (!p9PublishAbsolutePath(root) || name.contains("/") || name == "") {
        return false
    }
    let path = Path(root).join(name)
    if (!exists(path)) { return false }
    try {
        canonicalize(path).toString() == Path(canonicalize(Path(root)).toString())
            .join(name).toString()
    } catch (_: Exception) { false }
}

private func p9PublishReadGitEvidence(options: CkbReproPublishGateOptions):
    (String, CkbReproGitEvidence) {
    let out = CkbReproGitEvidence()
    let origin = p9PublishCommand("git", ["config", "--get", "remote.origin.url"])
    let head = p9PublishCommand("git", ["rev-parse", "HEAD"])
    let remoteMain = p9PublishCommand("git", ["rev-parse", "refs/remotes/origin/main"])
    if (origin[0] != 0 || head[0] != 0 || remoteMain[0] != 0) {
        return ("publish_git_evidence_unavailable", out)
    }
    out.originRepository = origin[1]
    out.headCommit = head[1]
    out.originMainCommit = remoteMain[1]
    let tag = p9PublishCommand("git", ["rev-parse", "refs/tags/${options.tagName}"])
    out.tagExistsLocal = tag[0] == 0
    // The offline gate intentionally performs no fetch. The local ref is the
    // only tag fact available after the maintainer's explicit push/fetch step.
    out.tagExistsRemote = out.tagExistsLocal
    out.tagCommit = if (out.tagExistsLocal) {
        let commit = p9PublishCommand("git", ["rev-list", "-n", "1",
            "refs/tags/${options.tagName}"])
        if (commit[0] == 0) { commit[1] } else { "" }
    } else { "" }
    ("ok", out)
}

private func p9PublishReadSignatureEvidence(root: String,
    options: CkbReproPublishGateOptions, mode: String):
    (String, CkbReproSignatureEvidence) {
    let out = CkbReproSignatureEvidence()
    let verify = p9PublishCommand("gpg", ["--batch", "--status-fd", "1",
        "--verify", Path(root).join("SHA256SUMS.sig").toString(),
        Path(root).join("SHA256SUMS").toString()])
    if (verify[0] != 0 || !verify[1].contains(
        "VALIDSIG ${options.signingFingerprint} ")) {
        return ("publish_signature_mismatch", out)
    }
    out.shaSumsVerified = true
    out.shaSumsFingerprint = options.signingFingerprint
    if (mode == "post-tag") {
        let tag = p9PublishCommand("git", ["verify-tag", "--raw", options.tagName])
        if (tag[0] != 0 || !tag[1].contains(options.signingFingerprint)) {
            return ("publish_tag_binding_mismatch", out)
        }
        out.tagSigned = true
        out.tagFingerprint = options.signingFingerprint
    }
    ("ok", out)
}

private func p9PublishCommand(command: String, args: Array<String>):
    (Int64, String) {
    try {
        let process = launch(command, args, stdOut: ProcessRedirect.Pipe,
            stdErr: ProcessRedirect.Pipe)
        let stdout = p9PublishReadPipe(process.stdOutPipe)
        let stderr = p9PublishReadPipe(process.stdErrPipe)
        let code = process.wait()
        let text = if (command == "gpg" ||
            (command == "git" && args.size > 0 && args[0] == "verify-tag")) {
            stdout + stderr
        } else { stdout }
        (code, p9PublishTrimLine(text))
    } catch (_: Exception) { (127, "") }
}

private func p9PublishReadPipe(pipe: InputStream): String {
    try { StringReader<InputStream>(pipe).readToEnd() }
    catch (_: Exception) { "" }
}

private func p9PublishTrimLine(value: String): String {
    value.trimAscii().replace("\n", " ").replace("\r", " ")
}

private func p9PublishDeriveEvidence(root: String,
    local: CkbReproPublishLocalEvidence,
    manifest: CkbReproBundleManifest): String {
    for (asset in manifest.assets) {
        if (!validateCkbReproBundleRelativePath(asset.relativePath).ok ||
            p9PublishDerivedName(asset.relativePath)) {
            return "publish_manifest_coverage_invalid"
        }
        let path = Path(root).join(asset.relativePath)
        if (!p9PublishSafeNestedFile(root, asset.relativePath)) {
            return "publish_manifest_coverage_invalid"
        }
        let bytes = try { File.readFrom(path) } catch (_: Exception) {
            return "publish_manifest_coverage_invalid"
        }
        if (bytes.size != asset.size || ckbReproBundleHash(bytes) != asset.sha256) {
            return "publish_manifest_coverage_invalid"
        }
    }
    let sumsBytes = try { File.readFrom(Path(root).join("SHA256SUMS")) }
        catch (_: Exception) { return "publish_sha_coverage_invalid" }
    let sumsText = try { String.fromUtf8(sumsBytes) } catch (_: Exception) {
        return "invalid_response_encoding"
    }
    let sums = p9PublishParseSums(sumsText)
    if (sums[0] != "ok") { return sums[0] }
    let required = ArrayList<String>()
    for (asset in manifest.assets) { required.add(asset.relativePath) }
    for (name in ["RELEASE-MANIFEST.json", "verification-report.json",
        "build-attestation.json", "PUBLISH-EVIDENCE.json"]) { required.add(name) }
    if (sums[1].size != required.size) { return "publish_sha_coverage_invalid" }
    for (name in required) {
        var expected = ""
        for (row in sums[1]) {
            if (row[0] == name) { expected = row[1] }
        }
        if (expected == "" || !p9PublishSafeNestedFile(root, name)) {
            return "publish_sha_coverage_invalid"
        }
        let bytes = try { File.readFrom(Path(root).join(name)) }
            catch (_: Exception) { return "publish_sha_coverage_invalid" }
        if (expected != ckbReproBundleHash(bytes).replace("sha256:", "")) {
            return "publish_sha_coverage_invalid"
        }
    }
    let verification = p9PublishObject(root, "verification-report.json", 19)
    if (verification[0] != "ok") { return verification[0] }
    let report = verification[1]
    if (p9PublishLocalString(report, "schemaVersion") !=
            "ckb-repro-verification-report-v1" ||
        !p9PublishLocalBool(report, "ok") ||
        p9PublishLocalInt(report, "runnerCalls") != 0 ||
        p9PublishLocalString(report, "releaseCommit") !=
            local.gateOptions.releaseCommit) {
        return "publish_p8_report_invalid"
    }
    let attestation = p9PublishObject(root, "build-attestation.json", 8)
    if (attestation[0] != "ok") { return attestation[0] }
    let proof = attestation[1]
    if (p9PublishLocalString(proof, "schemaVersion") !=
        "ckb-repro-build-attestation-v1") {
        return "publish_build_attestation_invalid"
    }
    local.evidence.inputSetHashMatches =
        p9PublishLocalString(report, "verifiedReleaseInputSetHash") ==
            manifest.inputSetHash
    local.evidence.manifestCoverageComplete = true
    local.evidence.shaCoverageComplete = true
    local.evidence.noSelfReference = true
    local.evidence.p8BindingMatches = true
    local.evidence.runCriticalTreeMatches =
        p9PublishLocalBool(proof, "runCriticalTreeMatches")
    local.evidence.strictPassed = p9PublishLocalInt(proof, "strictPassed")
    local.evidence.transportUnresolved =
        p9PublishLocalInt(proof, "transportUnresolved")
    local.evidence.leakageFindingCount =
        p9PublishLocalInt(proof, "leakageFindingCount")
    local.evidence.fullTestsPassed = p9PublishLocalBool(proof, "fullTestsPassed")
    local.evidence.licenseComplete = p9PublishLocalBool(proof, "licenseComplete")
    local.evidence.externalProofsVerified =
        p9PublishLocalBool(proof, "externalProofsVerified")
    "ok"
}

private func p9PublishObject(root: String, name: String, fields: Int64):
    (String, JsonObject) {
    let empty = JsonObject()
    try {
        let object = JsonValue.fromStr(String.fromUtf8(
            File.readFrom(Path(root).join(name)))).asObject()
        if (object.size() != fields) {
            return ("publish_bundle_evidence_field_contract_invalid", empty)
        }
        ("ok", object)
    } catch (_: Exception) { ("publish_bundle_evidence_malformed", empty) }
}

private func p9PublishParseSums(text: String):
    (String, ArrayList<(String, String)>) {
    let rows = ArrayList<(String, String)>()
    let seen = HashSet<String>()
    for (line in text.split("\n")) {
        if (line == "") { continue }
        let parts = line.split("  ")
        if (parts.size != 2 || parts[0].toRuneArray().size != 64 ||
            !validateCkbReproBundleRelativePath(parts[1]).ok ||
            p9PublishDerivedName(parts[1]) || seen.contains(parts[1])) {
            return ("publish_sha_coverage_invalid", rows)
        }
        for (rune in parts[0].runes()) {
            if (!((rune >= r'0' && rune <= r'9') ||
                (rune >= r'a' && rune <= r'f'))) {
                return ("publish_sha_coverage_invalid", rows)
            }
        }
        seen.add(parts[1]); rows.add((parts[1], parts[0]))
    }
    ("ok", rows)
}

private func p9PublishDerivedName(path: String): Bool {
    path == "SHA256SUMS" || path == "SHA256SUMS.sig"
}

private func p9PublishSafeNestedFile(root: String, relative: String): Bool {
    if (!validateCkbReproBundleRelativePath(relative).ok) { return false }
    let path = Path(root).join(relative)
    if (!exists(path)) { return false }
    try {
        let canonicalRoot = canonicalize(Path(root)).toString()
        canonicalize(path).toString() == Path(canonicalRoot).join(relative).toString()
    } catch (_: Exception) { false }
}
