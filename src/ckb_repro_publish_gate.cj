package cangjie_community_knowledge_base

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
