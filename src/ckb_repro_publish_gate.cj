package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
import std.env.getVariable
import std.fs.{Directory, File, OpenMode, Path, canonicalize, exists, remove}
import std.io.InputStream
import std.process.{ProcessRedirect, launch}
import std.sort.*
import std.time.DateTime
import stdx.encoding.base64.fromBase64String
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
    public var tagObjectHash: String = ""
    public var remoteTagObjectHash: String = ""
    public var tagCommit: String = ""
    public var remoteTagSnapshotAvailable: Bool = false
    public var remoteTagSnapshotFresh: Bool = false
    public var remoteTagState: String = "unavailable"
    public var remoteTagCommit: String = ""
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

private class CkbReproFilesystemPublishAuthentication {
    public var bundleSignatureVerified: Bool = false
    public var remoteAttestationVerified: Bool = false
    public var gitSnapshotBound: Bool = false
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

public interface CkbReproPublishAuthenticationProvider {
    func readGit(options: CkbReproPublishGateOptions,
        root: String): (String, CkbReproGitEvidence)
    func readSignature(root: String, options: CkbReproPublishGateOptions,
        mode: String): (String, CkbReproSignatureEvidence)
}

public interface CkbReproGpgvRunner {
    func run(command: String, args: Array<String>): (Int64, String)
}

private class P9ProductionGpgvRunner <: CkbReproGpgvRunner {
    public func run(command: String, args: Array<String>): (Int64, String) {
        p9PublishCommand(command, args)
    }
}

private class P9PublishProductionAuthentication <:
    CkbReproPublishAuthenticationProvider {
    public func readGit(options: CkbReproPublishGateOptions,
        root: String): (String, CkbReproGitEvidence) {
        p9PublishReadGitEvidence(options, root)
    }
    public func readSignature(root: String,
        options: CkbReproPublishGateOptions,
        mode: String): (String, CkbReproSignatureEvidence) {
        p9PublishReadSignatureEvidence(root, options, mode)
    }
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

private class CkbReproPublishBindingResult {
    public var contract: CkbReproContractResult = CkbReproContractResult()
    public var evidence: CkbReproPublishEvidence = CkbReproPublishEvidence()
    public init() {}
}

public class CkbReproFilesystemPublishGateCliExecutor <:
    CkbReproPublishGateCliExecutor {
    private let authentication: CkbReproPublishAuthenticationProvider
    public init() { this.authentication = P9PublishProductionAuthentication() }
    public init(provider: CkbReproPublishAuthenticationProvider) {
        this.authentication = provider
    }
    public func exists(path: String): Bool { exists(Path(path)) }
    public func evaluate(options: CkbReproPublishGateCliOptions):
        CkbReproPublishGateResult {
        let loaded = loadCkbReproPublishLocalEvidence(options.bundleRoot)
        if (!loaded.valid) { return p9PublishCliFailure(loaded.diagnostic) }
        loaded.gateOptions.mode = options.mode
        let git = this.authentication.readGit(loaded.gateOptions,
            options.bundleRoot)
        if (git[0] != "ok") { return p9PublishCliFailure(git[0]) }
        let signature = this.authentication.readSignature(
            options.bundleRoot, loaded.gateOptions, options.mode)
        if (signature[0] != "ok") { return p9PublishCliFailure(signature[0]) }
        let result = validateCkbReproPublishBundle(
            loaded.gateOptions, loaded.evidence,
            P9PublishFixedGitProvider(git[1]),
            P9PublishFixedSignatureVerifier(signature[1]))
        let authentication = CkbReproFilesystemPublishAuthentication()
        authentication.bundleSignatureVerified = signature[1].shaSumsVerified
        authentication.remoteAttestationVerified =
            git[1].remoteTagSnapshotAvailable &&
            git[1].remoteTagSnapshotFresh
        authentication.gitSnapshotBound = if (options.mode == "pre-tag") {
            git[1].remoteTagState == "absent" &&
                !git[1].tagExistsRemote
        } else {
            git[1].remoteTagState == "present" &&
                git[1].tagExistsRemote &&
                git[1].remoteTagCommit == loaded.gateOptions.releaseCommit
        }
        finalizeCkbReproFilesystemPublishResult(result, loaded.evidence,
            authentication)
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
        "build-attestation.json", "REMOTE-TAG-EVIDENCE.json",
        "REMOTE-TAG-EVIDENCE.json.sig"]
    for (name in files) {
        if (!p9PublishSafeBundleFile(bundleRoot, name)) {
            failed.diagnostic = "publish_bundle_required_evidence_missing"
            return failed
        }
    }
    let evidenceRead = p9PublishReadBounded(
        Path(bundleRoot).join("PUBLISH-EVIDENCE.json").toString(),
        16 * 1024 * 1024)
    if (evidenceRead[0] != "ok") {
        failed.diagnostic = "publish_bundle_evidence_read_failed"; return failed
    }
    let evidenceBytes = evidenceRead[1]
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
        let read = p9PublishReadBounded(
            Path(bundleRoot).join(item[0]).toString(), 16 * 1024 * 1024)
        if (read[0] != "ok") {
            failed.diagnostic = "publish_bundle_evidence_read_failed"; return failed
        }
        let bytes = read[1]
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
    let manifestRead = p9PublishReadBounded(Path(bundleRoot).join(
        "RELEASE-MANIFEST.json").toString(), 16 * 1024 * 1024)
    let manifestBytes = if (manifestRead[0] == "ok") {
        manifestRead[1]
    } else { Array<UInt8>() }
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
    if (!p9PublishTagName(options.tagName) || options.releaseTitle == "" ||
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
    if (!git.remoteTagSnapshotAvailable) {
        out.diagnostic = "publish_remote_tag_evidence_unavailable"
        return out
    }
    if (!git.remoteTagSnapshotFresh) {
        out.diagnostic = "publish_remote_tag_evidence_stale"
        return out
    }
    if (options.mode == "pre-tag") {
        if (git.remoteTagState != "absent" || git.tagExistsLocal ||
            git.tagExistsRemote || git.remoteTagCommit != "") {
            out.diagnostic = "publish_tag_already_exists"
            return out
        }
    } else if (!git.tagExistsLocal || !git.tagExistsRemote ||
        git.remoteTagState != "present" ||
        git.tagObjectHash == "" ||
        git.tagObjectHash != git.remoteTagObjectHash ||
        git.tagCommit != options.releaseCommit ||
        git.remoteTagCommit != options.releaseCommit || !signature.tagSigned ||
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

private func finalizeCkbReproFilesystemPublishResult(
    component: CkbReproPublishGateResult,
    evidence: CkbReproPublishEvidence,
    authentication: CkbReproFilesystemPublishAuthentication):
    CkbReproPublishGateResult {
    let out = CkbReproPublishGateResult()
    out.componentReady = component.componentReady
    out.publishable = component.componentReady &&
        evidence.externalProofsVerified &&
        authentication.bundleSignatureVerified &&
        authentication.remoteAttestationVerified &&
        authentication.gitSnapshotBound
    out.diagnostic = if (out.publishable) { "ok" } else {
        component.diagnostic
    }
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

private func p9PublishTagName(value: String): Bool {
    if (value == "" || value.toRuneArray().size > 128 ||
        value.startsWith(".") || value.endsWith(".")) { return false }
    for (rune in value.runes()) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'z') ||
            (rune >= r'A' && rune <= r'Z') || rune == r'-' ||
            rune == r'_' || rune == r'.')) { return false }
    }
    true
}

private func p9PublishJson(value: String): String {
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

private func p9PublishReadGitEvidence(options: CkbReproPublishGateOptions,
    root: String):
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
    out.tagObjectHash = if (out.tagExistsLocal) { tag[1] } else { "" }
    out.tagCommit = if (out.tagExistsLocal) {
        let commit = p9PublishCommand("git", ["rev-list", "-n", "1",
            "refs/tags/${options.tagName}"])
        if (commit[0] == 0) { commit[1] } else { "" }
    } else { "" }
    let snapshot = p9PublishReadRemoteTagSnapshot(root, options,
        out.originRepository, out.originMainCommit)
    if (snapshot[0] != "ok") { return (snapshot[0], out) }
    out.remoteTagSnapshotAvailable = true
    out.remoteTagSnapshotFresh = true
    out.remoteTagState = snapshot[1]
    out.remoteTagCommit = snapshot[2]
    let remoteQuery = p9PublishCommandRaw("git", ["ls-remote", "--tags", "origin",
        "refs/tags/${options.tagName}", "refs/tags/${options.tagName}^{}"])
    if (remoteQuery[0] != 0) {
        return ("publish_remote_tag_evidence_unavailable", out)
    }
    let remote = parseCkbRemoteTagLsRemote(remoteQuery[1], options.tagName)
    if (remote[0] != "ok") { return (remote[0], out) }
    out.tagExistsRemote = remote[1]
    out.remoteTagObjectHash = remote[2]
    if (out.remoteTagState == "present") {
        if (!out.tagExistsRemote) {
            return ("publish_remote_tag_evidence_unavailable", out)
        }
        if (remote[3] != out.remoteTagCommit ||
            remote[2] != out.tagObjectHash) {
            return ("publish_tag_binding_mismatch", out)
        }
    } else if (out.tagExistsRemote) {
        return ("publish_tag_already_exists", out)
    }
    ("ok", out)
}

private func p9PublishReadRemoteTagSnapshot(root: String,
    options: CkbReproPublishGateOptions, origin: String,
    originMainCommit: String): (String, String, String) {
    if (!p9PublishSafeBundleFile(root, "REMOTE-TAG-EVIDENCE.json") ||
        !p9PublishSafeBundleFile(root, "REMOTE-TAG-EVIDENCE.json.sig") ||
        !p9PublishSafeNestedFile(root,
            "reproducibility/RELEASE-SIGNING-KEY.asc")) {
        return ("publish_remote_tag_evidence_unavailable", "", "")
    }
    let repositoryRoot = p9PublishRepositoryRoot()
    if (repositoryRoot == "") {
        return ("publish_release_key_missing", "", "")
    }
    if (ckbReproVerifyReleaseSignatureAtCommit(repositoryRoot,
        options.releaseCommit, root,
        "REMOTE-TAG-EVIDENCE.json.sig", "REMOTE-TAG-EVIDENCE.json",
        options.signingFingerprint, P9ProductionGpgvRunner()) != "ok") {
        return ("publish_remote_tag_evidence_signature_invalid", "", "")
    }
    try {
        let read = p9PublishReadBounded(Path(root).join(
            "REMOTE-TAG-EVIDENCE.json").toString(), 16 * 1024 * 1024)
        if (read[0] != "ok") {
            return ("publish_remote_tag_evidence_invalid", "", "")
        }
        let bytes = read[1]
        let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
            return ("invalid_response_encoding", "", "")
        }
        let object = JsonValue.fromStr(text).asObject()
        if (object.size() != 11 ||
            p9PublishLocalString(object, "schemaVersion") !=
                "ckb-repro-remote-tag-evidence-v1" ||
            p9PublishLocalString(object, "queryKind") !=
                "signed-remote-tag-attestation" ||
            !p9PublishLocalBool(object, "querySucceeded")) {
            return ("publish_remote_tag_evidence_invalid", "", "")
        }
        let repository = p9PublishLocalString(object, "originRepository")
        let mainCommit = p9PublishLocalString(object, "originMainCommit")
        let tagName = p9PublishLocalString(object, "tagName")
        let state = p9PublishLocalString(object, "state")
        let tagCommit = p9PublishLocalString(object, "tagCommit")
        let observed = p9PublishLocalInt(object, "observedAtMillis")
        let expires = p9PublishLocalInt(object, "expiresAtMillis")
        let evidenceHash = p9PublishLocalString(object, "evidenceHash")
        let seed = "ckb-repro-remote-tag-evidence-v1|${repository}|" +
            "${mainCommit}|${tagName}|${state}|${tagCommit}|${observed}|" +
            "${expires}|signed-remote-tag-attestation|true"
        if (evidenceHash != ckbReproBundleHash(seed.toArray()) ||
            normalizeCkbReproRepositoryRemote(repository) !=
                options.releaseRepository ||
            normalizeCkbReproRepositoryRemote(origin) !=
                options.releaseRepository || mainCommit != originMainCommit ||
            tagName != options.tagName ||
            (state != "absent" && state != "present") ||
            (state == "absent" && tagCommit != "") ||
            (state == "present" && !p9PublishCommit(tagCommit))) {
            return ("publish_remote_tag_evidence_invalid", "", "")
        }
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        if (observed <= 0 || expires <= observed ||
            expires - observed > 600000 || now < observed || now > expires) {
            return ("publish_remote_tag_evidence_stale", "", "")
        }
        ("ok", state, tagCommit)
    } catch (_: Exception) {
        ("publish_remote_tag_evidence_invalid", "", "")
    }
}

private func p9PublishReadSignatureEvidence(root: String,
    options: CkbReproPublishGateOptions, mode: String):
    (String, CkbReproSignatureEvidence) {
    let out = CkbReproSignatureEvidence()
    let repositoryRoot = p9PublishRepositoryRoot()
    if (repositoryRoot == "") { return ("publish_release_key_missing", out) }
    if (ckbReproVerifyReleaseSignatureAtCommit(repositoryRoot,
        options.releaseCommit, root,
        "SHA256SUMS.sig", "SHA256SUMS", options.signingFingerprint,
        P9ProductionGpgvRunner()) != "ok") {
        return ("publish_signature_mismatch", out)
    }
    out.shaSumsVerified = true
    out.shaSumsFingerprint = options.signingFingerprint
    if (mode == "post-tag") {
        let tag = p9PublishVerifyAnnotatedTag(repositoryRoot, options,
            P9ProductionGpgvRunner())
        if (tag != "ok") {
            return ("publish_tag_binding_mismatch", out)
        }
        out.tagSigned = true
        out.tagFingerprint = options.signingFingerprint
    }
    ("ok", out)
}

public func ckbReproVerifyReleaseSignatureAtCommit(repositoryRoot: String,
    releaseCommit: String, bundleRoot: String, signatureRelativePath: String,
    payloadRelativePath: String, fingerprint: String,
    runner: CkbReproGpgvRunner): String {
    if (!p9PublishFingerprint(fingerprint) ||
        !p9PublishCommit(releaseCommit)) { return "publish_identity_invalid" }
    let bundleKey = Path(bundleRoot).join(
        "reproducibility/RELEASE-SIGNING-KEY.asc")
    if (!p9PublishCanonicalRoot(repositoryRoot) ||
        !p9PublishCanonicalRoot(bundleRoot) ||
        !exists(bundleKey)) { return "publish_release_key_missing" }
    let sourceRead = p9PublishReadReleaseKeyAtCommit(repositoryRoot,
        releaseCommit)
    let bundleRead = p9PublishReadBounded(bundleKey.toString(), 16 * 1024 * 1024)
    if (sourceRead[0] != "ok" || bundleRead[0] != "ok") {
        return "publish_release_key_missing"
    }
    if (ckbReproBundleHash(sourceRead[1]) != ckbReproBundleHash(bundleRead[1])) {
        return "publish_release_key_mismatch"
    }
    let signature = Path(bundleRoot).join(signatureRelativePath)
    let payload = Path(bundleRoot).join(payloadRelativePath)
    if (!exists(signature) || !exists(payload)) {
        return "publish_signature_input_missing"
    }
    p9PublishRunIsolatedGpgv(bundleRoot, sourceRead[1],
        signature.toString(), payload.toString(), fingerprint, runner)
}

private func p9PublishReadReleaseKeyAtCommit(repositoryRoot: String,
    releaseCommit: String): (String, Array<UInt8>) {
    let read = p9PublishCommandBytes("git", ["-C", repositoryRoot, "show",
        "${releaseCommit}:reproducibility/RELEASE-SIGNING-KEY.asc"])
    if (read[0] != 0 || read[1] != "ok" || read[2].size == 0) {
        return ("publish_release_key_missing", Array<UInt8>())
    }
    ("ok", read[2])
}

private func p9PublishRunIsolatedGpgv(workRoot: String,
    keyBytes: Array<UInt8>,
    signaturePath: String, payloadPath: String, fingerprint: String,
    runner: CkbReproGpgvRunner): String {
    let home = Path(workRoot).parent.join(
        ".ckb-gpgv-${DateTime.now().toUnixTimeStamp().toMilliseconds()}")
    if (exists(home)) { return "publish_gpgv_home_unavailable" }
    try {
        let decodedKey = p9PublishDecodeArmoredPublicKey(keyBytes)
        if (decodedKey[0] != "ok") { return "publish_signature_mismatch" }
        Directory.create(home)
        let canonicalHome = canonicalize(home).toString()
        let keyPath = Path(canonicalHome).join("release-signing-key.gpg")
        File.writeTo(keyPath, decodedKey[1])
        let verified = runner.run("gpgv", ["--homedir", canonicalHome,
            "--status-fd", "1", "--keyring",
            keyPath.toString(),
            signaturePath, payloadPath])
        remove(home, recursive: true)
        if (verified[0] != 0 || !verified[1].contains(
            "VALIDSIG ${fingerprint} ")) {
            return "publish_signature_mismatch"
        }
        "ok"
    } catch (_: Exception) {
        if (exists(home)) { try { remove(home, recursive: true) } catch (_: Exception) {} }
        "publish_signature_mismatch"
    }
}

private func p9PublishDecodeArmoredPublicKey(bytes: Array<UInt8>):
    (String, Array<UInt8>) {
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return ("invalid_response_encoding", Array<UInt8>())
    }
    var body = false; var ended = false; var encoded = ""
    for (raw in text.split("\n")) {
        let line = raw.trimAscii()
        if (line == "-----BEGIN PGP PUBLIC KEY BLOCK-----") {
            if (body) { return ("malformed_public_key", Array<UInt8>()) }
            body = true
        } else if (line == "-----END PGP PUBLIC KEY BLOCK-----") {
            ended = body; break
        } else if (body && line != "" &&
            !line.startsWith("Version:") && !line.startsWith("Comment:") &&
            !line.startsWith("=")) {
            encoded += line
        }
    }
    if (!body || !ended || encoded == "") {
        return ("malformed_public_key", Array<UInt8>())
    }
    if (let Some(value) <- fromBase64String(encoded)) {
        if (value.size > 0) { return ("ok", value) }
    }
    ("malformed_public_key", Array<UInt8>())
}

private func p9PublishRepositoryRoot(): String {
    let value = match (getVariable("CKB_REPRO_REPOSITORY_ROOT")) {
        case Some(root) => root
        case None => return ""
    }
    if (!p9PublishCanonicalRoot(value)) { return "" }
    value
}

private func p9PublishCanonicalRoot(value: String): Bool {
    if (!p9PublishAbsolutePath(value) || !exists(Path(value))) { return false }
    try { canonicalize(Path(value)).toString() == value }
    catch (_: Exception) { false }
}

private func p9PublishVerifyAnnotatedTag(repositoryRoot: String,
    options: CkbReproPublishGateOptions,
    runner: CkbReproGpgvRunner): String {
    let tag = p9PublishCommandBytes("git", ["-C", repositoryRoot,
        "cat-file", "tag", "refs/tags/${options.tagName}"])
    if (tag[0] != 0 || tag[1] != "ok") {
        return "publish_tag_binding_mismatch"
    }
    let parsed = parseCkbReproAnnotatedTag(tag[2], options.releaseCommit,
        options.tagName)
    if (parsed[0] != "ok") { return parsed[0] }
    let work = Path(repositoryRoot).join(
        ".ckb-tag-verify-${DateTime.now().toUnixTimeStamp().toMilliseconds()}")
    if (exists(work)) { return "publish_tag_verification_unavailable" }
    try {
        Directory.create(work)
        let payloadPath = work.join("tag.payload")
        let signaturePath = work.join("tag.sig")
        File.writeTo(payloadPath, parsed[1])
        File.writeTo(signaturePath, parsed[2])
        let key = p9PublishReadReleaseKeyAtCommit(repositoryRoot,
            options.releaseCommit)
        if (key[0] != "ok") {
            remove(work, recursive: true)
            return key[0]
        }
        let result = p9PublishRunIsolatedGpgv(work.toString(), key[1],
            signaturePath.toString(), payloadPath.toString(),
            options.signingFingerprint, runner)
        remove(work, recursive: true)
        if (result == "ok") { "ok" } else { "publish_tag_signature_invalid" }
    } catch (_: Exception) {
        if (exists(work)) { try { remove(work, recursive: true) } catch (_: Exception) {} }
        "publish_tag_signature_invalid"
    }
}

public func parseCkbReproAnnotatedTag(raw: Array<UInt8>, releaseCommit: String,
    tagName: String): (String, Array<UInt8>, Array<UInt8>) {
    let marker = "-----BEGIN PGP SIGNATURE-----".toArray()
    let split = p9PublishBytesIndexOf(raw, marker)
    if (split <= 0) {
        return ("publish_tag_signature_invalid", Array<UInt8>(), Array<UInt8>())
    }
    let payload = ArrayList<UInt8>()
    let signature = ArrayList<UInt8>()
    for (i in 0..raw.size) {
        if (i < split) { payload.add(raw[i]) } else { signature.add(raw[i]) }
    }
    let text = try { String.fromUtf8(payload.toArray()) }
        catch (_: Exception) {
            return ("publish_tag_encoding_invalid", Array<UInt8>(), Array<UInt8>())
        }
    if (!text.startsWith("object ${releaseCommit}\n") ||
        !text.contains("\ntype commit\n") ||
        !text.contains("\ntag ${tagName}\n") ||
        !text.contains("\ntagger ")) {
        return ("publish_tag_binding_mismatch", Array<UInt8>(), Array<UInt8>())
    }
    ("ok", payload.toArray(), signature.toArray())
}

private func p9PublishCommandBytes(command: String, args: Array<String>):
    (Int64, String, Array<UInt8>) {
    try {
        let process = launch(command, args, stdOut: ProcessRedirect.Pipe,
            stdErr: ProcessRedirect.Pipe)
        let stdout = spawn { => p9PublishReadPipeBytes(
            process.stdOutPipe, 16 * 1024 * 1024) }
        let stderr = spawn { => p9PublishReadPipeBytes(
            process.stdErrPipe, 1024 * 1024) }
        let code = process.wait()
        let output = stdout.get()
        let error = stderr.get()
        if (output[0] != "ok") { return (code, output[0], Array<UInt8>()) }
        if (error[0] != "ok") { return (code, error[0], Array<UInt8>()) }
        (code, "ok", output[1])
    } catch (_: Exception) {
        (127, "publish_tag_verification_unavailable", Array<UInt8>())
    }
}

private func p9PublishReadPipeBytes(pipe: InputStream, maxBytes: Int64):
    (String, Array<UInt8>) {
    let out = ArrayList<UInt8>()
    let buffer = Array<UInt8>(8192, repeat: UInt8(0))
    var total: Int64 = 0
    try {
        while (true) {
            let count = pipe.read(buffer)
            if (count < 0 || count > buffer.size) {
                return ("publish_tag_read_failed", Array<UInt8>())
            }
            if (count == 0) { break }
            total += count
            if (total <= maxBytes) {
                for (i in 0..count) { out.add(buffer[i]) }
            }
        }
    } catch (_: Exception) {
        return ("publish_tag_read_failed", Array<UInt8>())
    }
    if (total > maxBytes) {
        return ("publish_tag_output_too_large", Array<UInt8>())
    }
    ("ok", out.toArray())
}

private func p9PublishBytesIndexOf(value: Array<UInt8>, marker: Array<UInt8>): Int64 {
    if (marker.size == 0 || value.size < marker.size) { return -1 }
    for (i in 0..value.size - marker.size + 1) {
        var matches = true
        for (j in 0..marker.size) {
            if (value[i + j] != marker[j]) { matches = false; break }
        }
        if (matches) { return i }
    }
    -1
}

private func p9PublishCommand(command: String, args: Array<String>):
    (Int64, String) {
    let result = ckbReproBoundedProbeCommand(command, args, 1024 * 1024)
    if (result[1] != "ok") { return (127, "") }
    (result[0], p9PublishTrimLine(result[2]))
}

private func p9PublishCommandRaw(command: String, args: Array<String>):
    (Int64, String) {
    let result = ckbReproBoundedProbeCommand(command, args, 1024 * 1024)
    if (result[1] != "ok") { return (127, "") }
    (result[0], result[2])
}

public func parseCkbRemoteTagLsRemote(value: String,
    tagName: String): (String, Bool, String, String) {
    if (!p9PublishTagName(tagName)) {
        return ("publish_remote_tag_query_invalid", false, "", "")
    }
    let exact = "refs/tags/${tagName}"
    let peeledRef = "${exact}^{}"
    var direct = ""
    var peeled = ""
    for (raw in value.split("\n")) {
        let line = raw.trimAscii()
        if (line == "") { continue }
        let fields = line.split("\t")
        if (fields.size != 2 || !p9PublishCommit(fields[0])) {
            return ("publish_remote_tag_query_invalid", false, "", "")
        }
        if (fields[1] == exact && direct == "") {
            direct = fields[0]
        } else if (fields[1] == peeledRef && peeled == "") {
            peeled = fields[0]
        } else {
            return ("publish_remote_tag_query_invalid", false, "", "")
        }
    }
    if (direct == "" && peeled != "") {
        return ("publish_remote_tag_query_invalid", false, "", "")
    }
    if (direct == "") { return ("ok", false, "", "") }
    if (peeled == "" || direct == peeled) {
        return ("publish_remote_tag_query_invalid", false, "", "")
    }
    ("ok", true, direct, peeled)
}

private func p9PublishTrimLine(value: String): String {
    value.trimAscii().replace("\n", " ").replace("\r", " ")
}

private func p9PublishDeriveEvidence(root: String,
    local: CkbReproPublishLocalEvidence,
    manifest: CkbReproBundleManifest): String {
    let streamed = validateCkbReproBundleAssetsStreaming(root, manifest,
        CkbReproFilesystemBundleReadBackend())
    if (!streamed.ok) { return streamed.diagnostic }
    let manifestBytes = renderCkbReproBundleManifest(manifest).toArray()
    let reportForBinding = p9PublishReadBounded(Path(root).join(
        "verification-report.json").toString(), 16 * 1024 * 1024)
    if (reportForBinding[0] != "ok") {
        return "publish_p8_report_invalid"
    }
    let binding = p9PublishBindings(
        root, manifestBytes, reportForBinding[1])
    if (!binding.contract.ok) { return binding.contract.diagnostic }
    let sumsRead = p9PublishReadBounded(
        Path(root).join("SHA256SUMS").toString(), 16 * 1024 * 1024)
    if (sumsRead[0] != "ok") { return "publish_sha_coverage_invalid" }
    let sumsBytes = sumsRead[1]
    let sumsText = try { String.fromUtf8(sumsBytes) } catch (_: Exception) {
        return "invalid_response_encoding"
    }
    let sums = p9PublishParseSums(sumsText)
    if (sums[0] != "ok") { return sums[0] }
    let required = ArrayList<String>()
    for (asset in manifest.assets) { required.add(asset.relativePath) }
    for (name in ["RELEASE-MANIFEST.json", "verification-report.json",
        "build-attestation.json", "PUBLISH-EVIDENCE.json",
        "REMOTE-TAG-EVIDENCE.json"]) { required.add(name) }
    if (sums[1].size != required.size) { return "publish_sha_coverage_invalid" }
    for (name in required) {
        var expected = ""
        for (row in sums[1]) {
            if (row[0] == name) { expected = row[1] }
        }
        if (expected == "" || !p9PublishSafeNestedFile(root, name)) {
            return "publish_sha_coverage_invalid"
        }
        var manifestHash = ""
        for (asset in manifest.assets) {
            if (asset.relativePath == name) {
                manifestHash = asset.sha256.replace("sha256:", "")
            }
        }
        if (manifestHash != "") {
            if (expected != manifestHash) {
                return "publish_sha_coverage_invalid"
            }
        } else {
            let read = p9PublishReadBounded(
                Path(root).join(name).toString(), 16 * 1024 * 1024)
            if (read[0] != "ok") { return "publish_sha_coverage_invalid" }
            let bytes = read[1]
            if (expected != ckbReproBundleHash(bytes).replace("sha256:", "")) {
                return "publish_sha_coverage_invalid"
            }
        }
    }
    let verification = p9PublishObject(root, "verification-report.json", 19)
    if (verification[0] != "ok") { return verification[0] }
    let report = verification[1]
    if (p9PublishLocalString(report, "schemaVersion") !=
            "ckb-repro-verification-report-v1" ||
        !p9PublishLocalBool(report, "ok") ||
        p9PublishLocalString(report, "diagnostic") != "verified" ||
        p9PublishLocalInt(report, "runnerCalls") != 0 ||
        p9PublishLocalString(report, "releaseCommit") !=
            local.gateOptions.releaseCommit ||
        !p9PublishLocalBool(report, "restoreOk") ||
        p9PublishLocalString(report, "restoreDiagnostic") != "ok" ||
        !p9PublishLocalBool(report, "rebuildOk") ||
        p9PublishLocalString(report, "rebuildDiagnostic") != "ok" ||
        !p9PublishLocalBool(report, "publicEvidenceOk") ||
        p9PublishLocalString(report, "publicEvidenceDiagnostic") != "ok" ||
        !p9PublishLocalBool(report, "documentationOk") ||
        p9PublishLocalString(report, "documentationDiagnostic") != "ok") {
        return "publish_p8_report_invalid"
    }
    for (name in ["bundleProofSetHash", "certifiedRunInputHash",
        "runCriticalTreeHash", "referenceManifestHash", "authorityHash"]) {
        if (!p9PublishHash(p9PublishLocalString(report, name))) {
            return "publish_p8_report_invalid"
        }
    }
    let reportRead = p9PublishReadBounded(
        Path(root).join("verification-report.json").toString(),
        16 * 1024 * 1024)
    let attestationRead = p9PublishReadBounded(
        Path(root).join("build-attestation.json").toString(),
        16 * 1024 * 1024)
    let manifestRead = p9PublishReadBounded(
        Path(root).join("RELEASE-MANIFEST.json").toString(),
        16 * 1024 * 1024)
    if (reportRead[0] != "ok" || attestationRead[0] != "ok" ||
        manifestRead[0] != "ok" ||
        !validateCkbReproBuildAttestation(attestationRead[1],
            reportRead[1], manifestRead[1]).ok) {
        return "publish_build_attestation_invalid"
    }
    let referencePath =
        "reproducibility/manifests/reference-run.json"
    let referenceAsset = p9PublishFindManifestAsset(manifest, referencePath)
    if (!referenceAsset[0] || referenceAsset[1].role != "p8_reference") {
        return "publish_reference_evidence_invalid"
    }
    let referenceRead = p9PublishReadBounded(
        Path(root).join(referencePath).toString(), 16 * 1024 * 1024)
    if (referenceRead[0] != "ok" ||
        ckbReproBundleHash(referenceRead[1]) !=
            p9PublishLocalString(report, "referenceManifestHash")) {
        return "publish_reference_evidence_invalid"
    }
    let reference = parseCkbReproReferenceManifest(referenceRead[1])
    if (!reference[0].ok ||
        !validateCkbReproReferenceManifest(reference[1]).ok ||
        reference[1].baselineKind != "portable_release" ||
        reference[1].evidenceStatus != "complete") {
        return "publish_reference_evidence_invalid"
    }
    let leakageAsset = p9PublishFindManifestAsset(manifest,
        "leakage-report.json")
    if (!leakageAsset[0] || leakageAsset[1].role != "portable_report") {
        return "publish_leakage_evidence_invalid"
    }
    let leakage = p9PublishObject(root, "leakage-report.json", 3)
    if (leakage[0] != "ok" ||
        p9PublishLocalString(leakage[1], "schemaVersion") !=
            "ckb-repro-leakage-report-v1") {
        return "publish_leakage_evidence_invalid"
    }
    var licenseCount: Int64 = 0
    for (asset in manifest.assets) {
        if (asset.role == "license" && asset.size > 0) { licenseCount += 1 }
    }
    local.evidence.inputSetHashMatches =
        p9PublishLocalString(report, "verifiedReleaseInputSetHash") ==
            manifest.inputSetHash
    local.evidence.manifestCoverageComplete = true
    local.evidence.shaCoverageComplete = true
    local.evidence.noSelfReference = true
    local.evidence.p8BindingMatches = true
    local.evidence.runCriticalTreeMatches =
        binding.evidence.runCriticalTreeMatches
    local.evidence.strictPassed = binding.evidence.strictPassed
    local.evidence.transportUnresolved =
        binding.evidence.transportUnresolved
    local.evidence.leakageFindingCount =
        binding.evidence.leakageFindingCount
    local.evidence.fullTestsPassed = binding.evidence.fullTestsPassed
    local.evidence.licenseComplete = binding.evidence.licenseComplete
    local.evidence.externalProofsVerified = true
    "ok"
}

public func validateCkbReproPublishBindings(root: String,
    manifestBytes: Array<UInt8>, reportBytes: Array<UInt8>):
    CkbReproContractResult {
    p9PublishBindings(root, manifestBytes, reportBytes).contract
}

public func renderCkbReproFullTestProof(releaseCommit: String,
    runCriticalTreeHash: String, certifiedRunInputHash: String,
    verifiedInputManifestHash: String, verifiedInputAssetHash: String,
    testTopologyHash: String, testRunnerHash: String,
    sourceArtifactHash: String, cleanLogHash: String, buildLogHash: String,
    testLogHash: String, testPassedCount: Int64): String {
    let clean = "cjpm clean"; let build = "cjpm build -i"
    let test = "cjpm test -j 1"
    let cleanHash = ckbReproBundleHash(clean.toArray())
    let buildHash = ckbReproBundleHash(build.toArray())
    let testHash = ckbReproBundleHash(test.toArray())
    let proofHash = computeCkbReproFullTestProofHash(releaseCommit,
        runCriticalTreeHash, certifiedRunInputHash,
        verifiedInputManifestHash, verifiedInputAssetHash, testTopologyHash,
        testRunnerHash, sourceArtifactHash, cleanHash, cleanLogHash,
        buildHash, buildLogHash, testHash, testLogHash, testPassedCount)
    "{\"schemaVersion\":\"ckb-repro-full-test-proof-v2\"," +
        "\"releaseCommit\":\"${releaseCommit}\"," +
        "\"runCriticalTreeHash\":\"${runCriticalTreeHash}\"," +
        "\"certifiedRunInputHash\":\"${certifiedRunInputHash}\"," +
        "\"verifiedInputManifestHash\":\"${verifiedInputManifestHash}\"," +
        "\"verifiedInputAssetHash\":\"${verifiedInputAssetHash}\"," +
        "\"testTopologyHash\":\"${testTopologyHash}\"," +
        "\"testRunnerHash\":\"${testRunnerHash}\"," +
        "\"cleanCommandId\":\"cjpm-clean\",\"cleanCommand\":\"${clean}\"," +
        "\"cleanCommandHash\":\"${cleanHash}\",\"cleanExitCode\":0," +
        "\"cleanPassedCount\":1,\"cleanLogHash\":\"${cleanLogHash}\"," +
        "\"buildCommandId\":\"cjpm-build-incremental\"," +
        "\"buildCommand\":\"${build}\",\"buildCommandHash\":\"${buildHash}\"," +
        "\"buildExitCode\":0,\"buildPassedCount\":1," +
        "\"buildLogHash\":\"${buildLogHash}\"," +
        "\"testCommandId\":\"cjpm-test-full\",\"testCommand\":\"${test}\"," +
        "\"testCommandHash\":\"${testHash}\",\"testExitCode\":0," +
        "\"testPassedCount\":${testPassedCount},\"testLogHash\":\"${testLogHash}\"," +
        "\"sourceKind\":\"signed-release-source-artifact\"," +
        "\"sourceArtifactHash\":\"${sourceArtifactHash}\"," +
        "\"proofHash\":\"${proofHash}\"}"
}

public func validateCkbReproFullTestProof(bytes: Array<UInt8>,
    releaseCommit: String, runCriticalTreeHash: String,
    certifiedRunInputHash: String, verifiedInputManifestHash: String,
    verifiedInputAssetHash: String, testTopologyHash: String,
    testRunnerHash: String, sourceArtifactHash: String): String {
    let text = try { String.fromUtf8(bytes) }
        catch (_: Exception) { return "invalid_response_encoding" }
    try {
        let object = JsonValue.fromStr(text).asObject()
        if (object.size() != 29 || p9PublishLocalString(object,
            "schemaVersion") != "ckb-repro-full-test-proof-v2" ||
            p9PublishLocalString(object, "releaseCommit") != releaseCommit ||
            p9PublishLocalString(object, "runCriticalTreeHash") != runCriticalTreeHash ||
            p9PublishLocalString(object, "certifiedRunInputHash") != certifiedRunInputHash ||
            p9PublishLocalString(object, "verifiedInputManifestHash") != verifiedInputManifestHash ||
            p9PublishLocalString(object, "verifiedInputAssetHash") != verifiedInputAssetHash ||
            p9PublishLocalString(object, "testTopologyHash") != testTopologyHash ||
            p9PublishLocalString(object, "testRunnerHash") != testRunnerHash ||
            p9PublishLocalString(object, "sourceKind") !=
                "signed-release-source-artifact" ||
            p9PublishLocalString(object, "sourceArtifactHash") != sourceArtifactHash) {
            return "publish_full_test_proof_invalid"
        }
        let commands = [("clean", "cjpm-clean", "cjpm clean"),
            ("build", "cjpm-build-incremental", "cjpm build -i"),
            ("test", "cjpm-test-full", "cjpm test -j 1")]
        for (entry in commands) {
            if (p9PublishLocalString(object, "${entry[0]}CommandId") != entry[1] ||
                p9PublishLocalString(object, "${entry[0]}Command") != entry[2] ||
                p9PublishLocalString(object, "${entry[0]}CommandHash") !=
                    ckbReproBundleHash(entry[2].toArray()) ||
                p9PublishLocalInt(object, "${entry[0]}ExitCode") != 0 ||
                p9PublishLocalInt(object, "${entry[0]}PassedCount") <= 0 ||
                !p9PublishHash(p9PublishLocalString(object,
                    "${entry[0]}LogHash"))) {
                return "publish_full_test_proof_invalid"
            }
        }
        let expected = computeCkbReproFullTestProofHash(releaseCommit,
            runCriticalTreeHash, certifiedRunInputHash,
            verifiedInputManifestHash, verifiedInputAssetHash,
            testTopologyHash, testRunnerHash, sourceArtifactHash,
            p9PublishLocalString(object, "cleanCommandHash"),
            p9PublishLocalString(object, "cleanLogHash"),
            p9PublishLocalString(object, "buildCommandHash"),
            p9PublishLocalString(object, "buildLogHash"),
            p9PublishLocalString(object, "testCommandHash"),
            p9PublishLocalString(object, "testLogHash"),
            p9PublishLocalInt(object, "testPassedCount"))
        if (p9PublishLocalString(object, "proofHash") != expected) {
            return "publish_full_test_proof_invalid"
        }
        "ok"
    } catch (_: Exception) { "publish_full_test_proof_invalid" }
}

public func computeCkbReproFullTestProofHash(releaseCommit: String,
    runCriticalTreeHash: String, certifiedRunInputHash: String,
    verifiedInputManifestHash: String, verifiedInputAssetHash: String,
    testTopologyHash: String, testRunnerHash: String,
    sourceArtifactHash: String, cleanCommandHash: String,
    cleanLogHash: String, buildCommandHash: String, buildLogHash: String,
    testCommandHash: String, testLogHash: String,
    testPassedCount: Int64): String {
    p9PublishHashParts("ckb-repro-full-test-proof-v2", [releaseCommit,
        runCriticalTreeHash, certifiedRunInputHash, verifiedInputManifestHash,
        verifiedInputAssetHash, testTopologyHash, testRunnerHash,
        sourceArtifactHash, "cjpm-clean", cleanCommandHash, "0", "1",
        cleanLogHash, "cjpm-build-incremental", buildCommandHash, "0", "1",
        buildLogHash, "cjpm-test-full", testCommandHash, "0",
        "${testPassedCount}", testLogHash,
        "signed-release-source-artifact"])
}

private func p9PublishBindings(root: String, manifestBytes: Array<UInt8>,
    reportBytes: Array<UInt8>): CkbReproPublishBindingResult {
    let out = CkbReproPublishBindingResult()
    let parsed = parseCkbReproBundleManifest(manifestBytes)
    if (!parsed[0].ok || renderCkbReproBundleManifest(parsed[1]).toArray() !=
        manifestBytes) {
        out.contract = p9PublishFailure("publish_release_manifest_invalid")
        return out
    }
    let streamed = validateCkbReproBundleAssetsStreaming(root, parsed[1],
        CkbReproFilesystemBundleReadBackend())
    if (!streamed.ok) { out.contract = streamed; return out }
    let reportText = try { String.fromUtf8(reportBytes) }
        catch (_: Exception) {
            out.contract = p9PublishFailure("invalid_response_encoding")
            return out
        }
    let report = try { JsonValue.fromStr(reportText).asObject() }
        catch (_: Exception) {
            out.contract = p9PublishFailure("publish_p8_report_invalid")
            return out
        }
    if (report.size() != 19 ||
        p9PublishLocalString(report, "schemaVersion") !=
            "ckb-repro-verification-report-v1" ||
        !p9PublishLocalBool(report, "ok") ||
        p9PublishLocalString(report, "diagnostic") != "verified" ||
        p9PublishLocalInt(report, "runnerCalls") != 0 ||
        !p9PublishLocalBool(report, "restoreOk") ||
        !p9PublishLocalBool(report, "rebuildOk") ||
        !p9PublishLocalBool(report, "publicEvidenceOk") ||
        !p9PublishLocalBool(report, "documentationOk") ||
        p9PublishLocalString(report, "verifiedReleaseInputSetHash") !=
            parsed[1].inputSetHash ||
        p9PublishLocalString(report, "bundleProofSetHash") !=
            computeCkbReproBundleProofSetHash(parsed[1])) {
        out.contract = p9PublishFailure("publish_p8_binding_invalid")
        return out
    }
    let attestation = p9PublishReadBounded(Path(root).join(
        "build-attestation.json").toString(), 16 * 1024 * 1024)
    if (attestation[0] != "ok" ||
        !validateCkbReproBuildAttestation(attestation[1], reportBytes,
            manifestBytes).ok) {
        out.contract = p9PublishFailure("publish_build_attestation_invalid")
        return out
    }
    let referencePath = "reproducibility/manifests/reference-run.json"
    let referenceRead = p9PublishReadBounded(
        Path(root).join(referencePath).toString(), 16 * 1024 * 1024)
    let reference = if (referenceRead[0] == "ok") {
        parseCkbReproReferenceManifest(referenceRead[1])
    } else {
        (p9PublishFailure("publish_reference_evidence_invalid"),
            CkbReproReferenceManifest())
    }
    if (!reference[0].ok ||
        !validateCkbReproReferenceManifest(reference[1]).ok ||
        reference[1].baselineKind != "portable_release" ||
        reference[1].evidenceStatus != "complete" ||
        p9PublishLocalString(report, "referenceManifestHash") !=
            ckbReproBundleHash(referenceRead[1]) ||
        p9PublishLocalString(report, "certifiedRunInputHash") !=
            reference[1].certifiedRunInputHash ||
        p9PublishLocalString(report, "runCriticalTreeHash") !=
            reference[1].runCriticalTreeHash) {
        out.contract = p9PublishFailure("publish_reference_binding_invalid")
        return out
    }
    let releaseCommit = p9PublishLocalString(report, "releaseCommit")
    let commitRead = p9PublishReadBounded(Path(root).join(
        "release/release-commit.txt").toString(), 1024)
    if (commitRead[0] != "ok" ||
        try { String.fromUtf8(commitRead[1]).trimAscii() != releaseCommit }
            catch (_: Exception) { true }) {
        out.contract = p9PublishFailure("publish_release_commit_invalid")
        return out
    }
    let authority = computeCkbReproPublishAuthorityHash(parsed[1],
        computeCkbReproBundleProofSetHash(parsed[1]),
        ckbReproBundleHash(referenceRead[1]), releaseCommit)
    if (authority == "" || authority !=
        p9PublishLocalString(report, "authorityHash")) {
        out.contract = p9PublishFailure("publish_authority_binding_invalid")
        return out
    }
    let cleanLog = p9PublishReadManifestRole(root, parsed[1],
        "full_test_clean_log")
    let buildLog = p9PublishReadManifestRole(root, parsed[1],
        "full_test_build_log")
    let testLog = p9PublishReadManifestRole(root, parsed[1],
        "full_test_test_log")
    let testTopology = p9PublishReadManifestRole(root, parsed[1],
        "full_test_topology")
    let testRunner = p9PublishReadManifestRole(root, parsed[1],
        "full_test_runner")
    let sourceArtifact = p9PublishReadManifestRole(root, parsed[1],
        "full_test_source")
    let fullTests = p9PublishReadBounded(Path(root).join(
        "full-test-report.json").toString(), 16 * 1024 * 1024)
    if (!cleanLog[0] || !buildLog[0] || !testLog[0] ||
        !testTopology[0] || !testRunner[0] || !sourceArtifact[0] ||
        fullTests[0] != "ok" ||
        validateCkbReproFullTestProof(fullTests[1], releaseCommit,
            reference[1].runCriticalTreeHash,
            reference[1].certifiedRunInputHash,
            ckbReproBundleHash(referenceRead[1]), reference[1].resultsHash,
            testTopology[1], testRunner[1], sourceArtifact[1]) != "ok" ||
        !p9PublishFullTestLogHashesMatch(fullTests[1], cleanLog[1],
            buildLog[1], testLog[1])) {
        out.contract = p9PublishFailure("publish_full_test_proof_invalid")
        return out
    }
    let leakage = p9PublishObject(root, "leakage-report.json", 3)
    if (leakage[0] != "ok") {
        out.contract = p9PublishFailure("publish_leakage_evidence_invalid")
        return out
    }
    var licenseCount: Int64 = 0
    for (asset in parsed[1].assets) {
        if (asset.role == "license" && asset.size > 0) { licenseCount += 1 }
    }
    out.evidence.inputSetHashMatches = true
    out.evidence.manifestCoverageComplete = true
    out.evidence.shaCoverageComplete = true
    out.evidence.noSelfReference = true
    out.evidence.p8BindingMatches = true
    out.evidence.runCriticalTreeMatches = true
    out.evidence.strictPassed = reference[1].strictPassed
    out.evidence.transportUnresolved = reference[1].transportUnresolved
    out.evidence.leakageFindingCount =
        p9PublishLocalInt(leakage[1], "findingCount") +
        p9PublishLocalInt(leakage[1], "pathFindingCount")
    out.evidence.fullTestsPassed = true
    out.evidence.licenseComplete = licenseCount == 1
    out.evidence.externalProofsVerified = true
    out.contract = p9PublishSuccess()
    out
}

private func p9PublishFindManifestRole(manifest: CkbReproBundleManifest,
    role: String): (Bool, CkbReproBundleAsset) {
    var found = false; var value = CkbReproBundleAsset()
    for (asset in manifest.assets) {
        if (asset.role == role) {
            if (found) { return (false, CkbReproBundleAsset()) }
            found = true; value = asset
        }
    }
    (found, value)
}

private func p9PublishReadManifestRole(root: String,
    manifest: CkbReproBundleManifest, role: String): (Bool, String) {
    let found = p9PublishFindManifestRole(manifest, role)
    if (!found[0] || found[1].partCount != 1 ||
        found[1].logicalSize != found[1].size ||
        found[1].logicalSha256 != found[1].sha256) {
        return (false, "")
    }
    let read = p9PublishReadBounded(Path(root).join(
        found[1].relativePath).toString(), 64 * 1024 * 1024)
    if (read[0] != "ok" || read[1].size != found[1].logicalSize) {
        return (false, "")
    }
    let actual = ckbReproBundleHash(read[1])
    if (actual != found[1].logicalSha256) { return (false, "") }
    (true, actual)
}

private func p9PublishFullTestLogHashesMatch(bytes: Array<UInt8>,
    cleanLogHash: String, buildLogHash: String,
    testLogHash: String): Bool {
    let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
        return false
    }
    try {
        let object = JsonValue.fromStr(text).asObject()
        p9PublishLocalString(object, "cleanLogHash") == cleanLogHash &&
            p9PublishLocalString(object, "buildLogHash") == buildLogHash &&
            p9PublishLocalString(object, "testLogHash") == testLogHash
    } catch (_: Exception) { false }
}

public func computeCkbReproPublishAuthorityHash(
    manifest: CkbReproBundleManifest, proofSetHash: String,
    referenceManifestHash: String, releaseCommit: String): String {
    let mandatory = ["p0_manifest", "p1_score_contract",
        "p2_logical_snapshot", "p3_qdrant_snapshot", "p4_build_proof",
        "p5_public_evidence", "p6_environment_lock", "p7_documentation",
        "p8_reference", "source_lock", "authority_delivery",
        "full_test_clean_log", "full_test_build_log",
        "full_test_test_log", "full_test_topology", "full_test_runner",
        "full_test_source",
        "portable_report", "license", "release_commit"]
    for (role in mandatory) {
        var count: Int64 = 0
        for (asset in manifest.assets) { if (asset.role == role) { count += 1 } }
        if (count == 0 || ((role == "p8_reference" ||
            role == "release_commit") && count != 1)) { return "" }
    }
    let seen = HashSet<String>(); let rows = ArrayList<String>()
    for (asset in manifest.assets) {
        let key = asset.role + "\t" + asset.logicalAsset
        if (!seen.contains(key)) {
            seen.add(key)
            rows.add(key + "\t${asset.logicalSize}\t${asset.logicalSha256}")
        }
    }
    let ordered = rows.toArray(); sort(ordered)
    p9PublishHashParts("ckb-repro-release-authority-v1",
        [manifest.inputSetHash, proofSetHash, referenceManifestHash,
        ckbReproBundleHash(releaseCommit.toArray()),
        p9PublishHashParts("ckb-repro-release-authority-contract-v1",
            ordered)])
}

public func prepareCkbReproPreSignatureArtifacts(root: String,
    options: CkbReproPublishGateOptions, remoteEvidence: Array<UInt8>,
    remoteSignature: Array<UInt8>): CkbReproContractResult {
    let manifest = p9PublishReadBounded(Path(root).join(
        "RELEASE-MANIFEST.json").toString(), 16 * 1024 * 1024)
    let report = p9PublishReadBounded(Path(root).join(
        "verification-report.json").toString(), 16 * 1024 * 1024)
    let attestation = p9PublishReadBounded(Path(root).join(
        "build-attestation.json").toString(), 16 * 1024 * 1024)
    if (manifest[0] != "ok" || report[0] != "ok" ||
        attestation[0] != "ok" || remoteSignature.size == 0) {
        return p9PublishFailure("publish_pre_signature_inputs_invalid")
    }
    let binding = p9PublishBindings(root, manifest[1], report[1])
    if (!binding.contract.ok) { return binding.contract }
    try { _ = JsonValue.fromStr(String.fromUtf8(remoteEvidence)).asObject() }
    catch (_: Exception) {
        return p9PublishFailure("publish_remote_tag_evidence_invalid")
    }
    let local = CkbReproPublishLocalEvidence()
    local.gateOptions = options; local.evidence = binding.evidence
    let localText = renderCkbReproPublishLocalEvidence(local,
        ckbReproBundleHash(report[1]), ckbReproBundleHash(attestation[1]))
    try {
        File.writeTo(Path(root).join("PUBLISH-EVIDENCE.json"),
            localText.toArray())
        File.writeTo(Path(root).join("REMOTE-TAG-EVIDENCE.json"),
            remoteEvidence)
        File.writeTo(Path(root).join("REMOTE-TAG-EVIDENCE.json.sig"),
            remoteSignature)
        let parsed = parseCkbReproBundleManifest(manifest[1])
        let rows = ArrayList<String>()
        for (asset in parsed[1].assets) {
            rows.add("${asset.sha256.replace("sha256:", "")}  ${asset.relativePath}")
        }
        for (item in [("RELEASE-MANIFEST.json", manifest[1]),
            ("verification-report.json", report[1]),
            ("build-attestation.json", attestation[1]),
            ("PUBLISH-EVIDENCE.json", localText.toArray()),
            ("REMOTE-TAG-EVIDENCE.json", remoteEvidence)]) {
            rows.add("${ckbReproBundleHash(item[1]).replace("sha256:", "")}  ${item[0]}")
        }
        let ordered = rows.toArray(); sort(ordered)
        File.writeTo(Path(root).join("SHA256SUMS"),
            (p9PublishJoinLines(ordered) + "\n").toArray())
        p9PublishSuccess()
    } catch (_: Exception) {
        p9PublishFailure("publish_pre_signature_write_failed")
    }
}

private func p9PublishHashParts(prefix: String, values: Array<String>): String {
    let builder = StringBuilder(prefix)
    for (value in values) { builder.append("${value.toArray().size}:${value}") }
    ckbReproBundleHash(builder.toString().toArray())
}

private func p9PublishJoinLines(values: Array<String>): String {
    let builder = StringBuilder()
    for (i in 0..values.size) {
        if (i > 0) { builder.append("\n") }; builder.append(values[i])
    }
    builder.toString()
}

private func p9PublishSuccess(): CkbReproContractResult {
    let out = CkbReproContractResult(); out.ok = true
    out.diagnostic = "ok"; out
}

private func p9PublishFailure(code: String): CkbReproContractResult {
    let out = CkbReproContractResult(); out.diagnostic = code; out
}

private func p9PublishObject(root: String, name: String, fields: Int64):
    (String, JsonObject) {
    let empty = JsonObject()
    try {
        let read = p9PublishReadBounded(
            Path(root).join(name).toString(), 16 * 1024 * 1024)
        if (read[0] != "ok") {
            return ("publish_bundle_evidence_read_failed", empty)
        }
        let object = JsonValue.fromStr(String.fromUtf8(read[1])).asObject()
        if (object.size() != fields) {
            return ("publish_bundle_evidence_field_contract_invalid", empty)
        }
        ("ok", object)
    } catch (_: Exception) { ("publish_bundle_evidence_malformed", empty) }
}

private func p9PublishFindManifestAsset(manifest: CkbReproBundleManifest,
    path: String): (Bool, CkbReproBundleAsset) {
    for (asset in manifest.assets) {
        if (asset.relativePath == path) { return (true, asset) }
    }
    (false, CkbReproBundleAsset())
}

private func p9PublishReadBounded(path: String, limit: Int64):
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
    path == "SHA256SUMS" || path == "SHA256SUMS.sig" ||
        path == "REMOTE-TAG-EVIDENCE.json.sig"
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
