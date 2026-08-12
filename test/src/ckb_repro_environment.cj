package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashSet}
import std.convert.Parsable
import std.env.getVariable
import std.fs.{Directory, File, OpenMode, Path, canonicalize, exists}
import std.io.InputStream
import std.process.{ProcessRedirect, launch}
import stdx.crypto.digest.SHA256
import stdx.encoding.json.*

public class CkbReproEnvironmentLock {
    public var schemaVersion: String = ""
    public var identityStatus: String = ""
    public var certifiedPlatform: String = ""
    public var cpuArchitecture: String = ""
    public var cangjieSdkVersion: String = ""
    public var cangjieSdkHash: String = ""
    public var opensslVersion: String = ""
    public var serviceHeap: String = ""
    public var qdrantImageDigest: String = ""
    public var runCandidateCommit: String = ""
    public var runCriticalFilesManifestHash: String = ""
    public var runCriticalTreeHash: String = ""
    public var compositionManifestPath: String = ""
    public var compositionManifestHash: String = ""
    public var claudeCodeVersion: String = ""
    public var glmProvider: String = ""
    public var glmBaseUrl: String = ""
    public var glmModel: String = ""
    public var modelFingerprint: String = ""
    public var glmCredentialEnv: String = ""
    public var embeddingProvider: String = ""
    public var embeddingModel: String = ""
    public var embeddingDimension: Int64 = 0
    public var embeddingCredentialEnv: String = ""
    public var archiveTool: String = ""
    public var archiveToolVersion: String = ""
    public var experimentGroup: String = ""
    public var ckbRequired: Bool = false
    public var localDocsPolicy: String = ""
    public var modelEffort: String = ""
    public var modelBudget: String = ""
    public var timeoutSeconds: Int64 = 0
    public var transportRetryBudget: Int64 = 0
    public var promptHash: String = ""
    public var mcpCommand: String = ""
    public var mcpTransport: String = ""
    public var sandboxCapability: String = ""
    public var datasetVersion: String = ""
    public var authorityDeliveryHash: String = ""
    public var attestationAuthorityManifestPath: String = ""
    public var attestationAuthorityHash: String = ""
    public init() {}
}

public class CkbReproEnvironmentPreflightResult {
    public var ok: Bool = false
    public var startAllowed: Bool = false
    public var diagnostic: String = "not_validated"
    public var environmentManifestHash: String = ""
    public var certifiedRunInputHash: String = ""
    public var attestationEvidenceCommit: String = ""
    public var heapResult: CkbServiceHeapPreflightResult = CkbServiceHeapPreflightResult()
    public init() {}
}

// P3/P4 inject these portable identities after their contracts are complete.
// This type deliberately has no defaults that point at a developer machine.
public class CkbReproRunnerInputs {
    public var runId: String = ""
    public var repoRoot: String = ""
    public var runsRoot: String = ""
    public var datasetRoot: String = ""
    public var authorityManifestPath: String = ""
    public var ckbBin: String = ""
    public var ckbConfig: String = ""
    public var ckbStore: String = ""
    public var ckbHttpBase: String = ""
    public var claudeBin: String = ""
    public var docsRoot: String = ""
    public var candidateVersion: String = ""
    public var knowledgeVersion: String = ""
    public var providerIdentityHash: String = ""
    public var providerIdentityArtifactPath: String = ""
    public var frozenCandidateManifestPath: String = ""
    public var observedEnvironmentPath: String = ""
    public var certificationPreflightPath: String = ""
    public var certificationRunManifestPath: String = ""
    public init() {}
}

public interface CkbReproRunnerInvoker {
    func generate(args: Array<String>, runRoot: String): (Int64, String)
    func evaluate(args: Array<String>, runRoot: String,
        expectedGenerationSeal: String): Int64
}

public class CkbReproPreflightCliOptions {
    public var environmentLockPath: String = ""
    public var observedEnvironmentPath: String = ""
    public var certificationPreflightPath: String = ""
    public var certificationRunManifestPath: String = ""
    public var signingFingerprint: String = ""
    public var observedEnvironmentProjectionHash: String = ""
    public var json: Bool = false
    public var valid: Bool = false
    public var diagnostic: String = "usage_error"
    public init() {}
}

public class CkbReproPreflightCliInputs {
    public var expected: CkbReproEnvironmentLock = CkbReproEnvironmentLock()
    public var observed: CkbReproEnvironmentLock = CkbReproEnvironmentLock()
    public var heap: CkbServiceHeapPreflightResult = CkbServiceHeapPreflightResult()
    public var certificationPreflightJson: String = ""
    public var certificationRunManifestJson: String = ""
    public init() {}
}

public class CkbReproEnvironmentProbeResult {
    public var ok: Bool = false
    public var diagnostic: String = "environment_probe_unavailable"
    public var observed: CkbReproEnvironmentLock = CkbReproEnvironmentLock()
    public var attestedInputHash: String = ""
    public var attestationEvidenceCommit: String = ""
    public init() {}
}

public interface CkbReproEnvironmentProbe {
    func inspect(attested: CkbReproEnvironmentLock,
        attestedInputHash: String, evidenceRepositoryRoot: String):
        CkbReproEnvironmentProbeResult
}

public interface CkbReproGitProbeRunner {
    func run(command: String, args: Array<String>): (Int64, String)
}

private class P6FilesystemGitProbeRunner <: CkbReproGitProbeRunner {
    public func run(command: String, args: Array<String>): (Int64, String) {
        p6ProbeCommand(command, args)
    }
}

public class CkbReproAttestationAuthority {
    public var signingFingerprint: String = ""
    public var observedEnvironmentProjectionHash: String = ""
    public var frozen: Bool = false
    public init() {}
}

public class CkbReproVerifiedAttestationAuthority {
    private let fingerprint: String
    private let environmentHash: String
    private let anchorHash: String
    private init(fingerprint: String, environmentHash: String,
        anchorHash: String) {
        this.fingerprint = fingerprint
        this.environmentHash = environmentHash
        this.anchorHash = anchorHash
    }
    public func signingFingerprint(): String { this.fingerprint }
    public func observedEnvironmentProjectionHash(): String {
        this.environmentHash
    }
    public func authorityAnchorHash(): String { this.anchorHash }
    public static func load(bytes: Array<UInt8>, expectedAnchorHash: String):
        (CkbReproContractResult, CkbReproVerifiedAttestationAuthority) {
        let empty = CkbReproVerifiedAttestationAuthority("", "", "")
        let text = try { String.fromUtf8(bytes) } catch (_: Exception) {
            return (p6Failure("invalid_response_encoding"), empty)
        }
        let object = try { JsonValue.fromStr(text).asObject() }
            catch (_: Exception) {
                return (p6Failure(
                    "environment_attestation_authority_malformed"), empty)
            }
        try {
            if (object.size() != 6) {
                return (p6Failure(
                    "environment_attestation_authority_invalid"), empty)
            }
            let schema = p6String(object, "schemaVersion")
            let status = p6String(object, "status")
            let fingerprint = p6String(object, "signingFingerprint")
            let environmentHash = p6String(object,
                "observedEnvironmentProjectionHash")
            let source = p6String(object, "authoritySource")
            let sourceHash = p6String(object, "authoritySourceHash")
            let canonical =
                "{\"schemaVersion\":\"ckb-repro-environment-attestation-authority-v1\"," +
                "\"status\":\"frozen\",\"signingFingerprint\":\"${fingerprint}\"," +
                "\"observedEnvironmentProjectionHash\":\"${environmentHash}\"," +
                "\"authoritySource\":\"${source}\"," +
                "\"authoritySourceHash\":\"${sourceHash}\"}"
            if (schema !=
                    "ckb-repro-environment-attestation-authority-v1" ||
                status != "frozen" || !p6ProbeFingerprint(fingerprint) ||
                !p6HashValid(environmentHash) ||
                source !=
                    "release://ckb/environment-attestation-authority-v1" ||
                sourceHash != p6Hash(source.toArray()) ||
                canonical != text) {
                return (p6Failure(
                    "environment_attestation_authority_invalid"), empty)
            }
            let actualAnchor = p6Hash(bytes)
            if (!p6HashValid(expectedAnchorHash) ||
                actualAnchor != expectedAnchorHash) {
                return (p6Failure(
                    "environment_attestation_authority_anchor_mismatch"),
                    empty)
            }
            (p6Success(), CkbReproVerifiedAttestationAuthority(
                fingerprint, environmentHash, actualAnchor))
        } catch (_: Exception) {
            (p6Failure("environment_attestation_authority_invalid"), empty)
        }
    }
}

public class CkbReproAttestationSignatureResult {
    public var ok: Bool = false
    public var diagnostic: String = "environment_attestation_signature_invalid"
    public var signingFingerprint: String = ""
    public init() {}
}

public interface CkbReproAttestationSignatureVerifier {
    func verify(path: String): CkbReproAttestationSignatureResult
}

public class CkbReproGpgAttestationSignatureVerifier <:
    CkbReproAttestationSignatureVerifier {
    public init() {}
    public func verify(path: String): CkbReproAttestationSignatureResult {
        p6VerifyObservedEnvironmentSignature(path)
    }
}

public func loadCkbReproVerifiedAttestationAuthority(bytes: Array<UInt8>,
    expectedAnchorHash: String):
    (CkbReproContractResult, CkbReproVerifiedAttestationAuthority) {
    CkbReproVerifiedAttestationAuthority.load(bytes, expectedAnchorHash)
}

public func loadCkbReproPreflightAuthority(environmentLockPath: String):
    (CkbReproContractResult, CkbReproEnvironmentLock,
        ?CkbReproVerifiedAttestationAuthority) {
    let empty = CkbReproEnvironmentLock()
    if (!p6CliAbsolutePath(environmentLockPath) ||
        !exists(Path(environmentLockPath))) {
        return (p6Failure("environment_lock_missing"), empty,
            None<CkbReproVerifiedAttestationAuthority>)
    }
    let canonicalLock = try { canonicalize(Path(environmentLockPath)).toString() }
        catch (_: Exception) {
            return (p6Failure("preflight_path_not_canonical"), empty,
                None<CkbReproVerifiedAttestationAuthority>)
        }
    if (canonicalLock != environmentLockPath) {
        return (p6Failure("preflight_path_not_canonical"), empty,
            None<CkbReproVerifiedAttestationAuthority>)
    }
    let repositoryRoot = Path(environmentLockPath).parent.parent.parent
    let canonicalRoot = try { canonicalize(repositoryRoot).toString() }
        catch (_: Exception) {
            return (p6Failure("preflight_path_not_canonical"), empty,
                None<CkbReproVerifiedAttestationAuthority>)
        }
    let fixedLock = Path(canonicalRoot).join(
        "reproducibility/manifests/environment-lock.json").toString()
    if (fixedLock != environmentLockPath) {
        return (p6Failure("environment_lock_path_invalid"), empty,
            None<CkbReproVerifiedAttestationAuthority>)
    }
    let parsed = p6CliReadEnvironment(environmentLockPath)
    if (!parsed[0].ok) {
        return (parsed[0], parsed[1],
            None<CkbReproVerifiedAttestationAuthority>)
    }
    let checked = validateCkbReproEnvironmentLock(parsed[1], mode: "execution")
    if (!checked.ok) {
        return (checked, parsed[1],
            None<CkbReproVerifiedAttestationAuthority>)
    }
    let authorityPath = Path(canonicalRoot).join(
        parsed[1].attestationAuthorityManifestPath).toString()
    let canonicalAuthority = try { canonicalize(Path(authorityPath)).toString() }
        catch (_: Exception) {
            return (p6Failure("environment_attestation_authority_unavailable"),
                parsed[1], None<CkbReproVerifiedAttestationAuthority>)
        }
    if (canonicalAuthority != authorityPath) {
        return (p6Failure("environment_attestation_authority_unavailable"),
            parsed[1], None<CkbReproVerifiedAttestationAuthority>)
    }
    let authorityRead = p6ReadFileBounded(authorityPath, 64 * 1024)
    if (authorityRead[0] != "ok") {
        return (p6Failure("environment_attestation_authority_unavailable"),
            parsed[1], None<CkbReproVerifiedAttestationAuthority>)
    }
    let authority = loadCkbReproVerifiedAttestationAuthority(
        authorityRead[1], parsed[1].attestationAuthorityHash)
    if (!authority[0].ok) {
        return (authority[0], parsed[1],
            None<CkbReproVerifiedAttestationAuthority>)
    }
    if (authority[1].observedEnvironmentProjectionHash() !=
        ckbReproObservedEnvironmentProjectionHash(parsed[1])) {
        return (p6Failure("environment_attestation_input_mismatch"),
            parsed[1], None<CkbReproVerifiedAttestationAuthority>)
    }
    (p6Success(), parsed[1], Some(authority[1]))
}

public class CkbReproFilesystemEnvironmentProbe <: CkbReproEnvironmentProbe {
    private let gitRunner: CkbReproGitProbeRunner
    private let repositoryRootOverride: String
    private let repositoryRootOverrideEnabled: Bool
    private let compositionManifestOverride: String
    public init(gitRunner!: CkbReproGitProbeRunner =
        P6FilesystemGitProbeRunner(), repositoryRootOverride!: String = "",
        repositoryRootOverrideEnabled!: Bool = false,
        compositionManifestOverride!: String = "") {
        this.gitRunner = gitRunner
        this.repositoryRootOverride = repositoryRootOverride
        this.repositoryRootOverrideEnabled = repositoryRootOverrideEnabled
        this.compositionManifestOverride = compositionManifestOverride
    }
    public func inspect(attested: CkbReproEnvironmentLock,
        attestedInputHash: String, evidenceRepositoryRoot: String):
        CkbReproEnvironmentProbeResult {
        let out = CkbReproEnvironmentProbeResult()
        if (attestedInputHash !=
            ckbReproObservedEnvironmentProjectionHash(attested)) { return out }
        let platform = p6ProbeCommand("uname", ["-s"])
        let architecture = p6ProbeCommand("uname", ["-m"])
        let sdkPath = p6ProbeCanonicalInputPath(
            "CKB_REPRO_CJC_EXECUTABLE", "")
        if (sdkPath == "") { return out }
        let sdk = p6ProbeCommand(sdkPath, ["--version"])
        let openssl = p6ProbeCommand("openssl", ["version"])
        let repositoryRoot = if (!this.repositoryRootOverrideEnabled) {
            p6ProbeCanonicalInputPath("CKB_REPRO_REPOSITORY_ROOT", "")
        } else if (this.repositoryRootOverride == evidenceRepositoryRoot) {
            this.repositoryRootOverride
        } else { "" }
        if (repositoryRoot == "") { return out }
        let candidate = ckbReproValidateCandidateCheckout(repositoryRoot,
            attested.runCandidateCommit, this.gitRunner)
        if (candidate[0] != "ok") { return out }
        let claude = p6ProbeCommand("claude", ["--version"])
        let tar = p6ProbeCommand("tar", ["--version"])
        let zstd = p6ProbeCommand("zstd", ["--version"])
        let qdrantImage = p6ProbeRequiredEnv("CKB_REPRO_QDRANT_IMAGE")
        if (!qdrantImage[0]) { return out }
        let qdrant = p6ProbeCommand("docker", ["image", "inspect",
            "--format={{.Id}}", qdrantImage[1]])
        for (probe in [platform, architecture, sdk, openssl,
            claude, tar, zstd, qdrant]) {
            if (probe[0] != 0 || probe[1] == "") { return out }
        }
        let sdkHash = p6ProbeFileHash(sdkPath, 512 * 1024 * 1024)
        if (sdkHash[0] != "ok") { return out }
        // Runtime/tool fields are measured below. Configuration fields are
        // accepted only from the hash-bound, signed frozen attestation.
        let observed = CkbReproEnvironmentLock()
        observed.schemaVersion = "ckb-repro-environment-v1"
        observed.identityStatus = "frozen"
        p6CopyUnobservableAuthorityFields(attested, observed)
        if (p6ProbeActualConfiguration(observed, repositoryRoot,
                repositoryRootBound: this.repositoryRootOverrideEnabled,
                compositionManifestOverride:
                    this.compositionManifestOverride) != "ok") {
            return out
        }
        observed.certifiedPlatform = if (platform[1] == "Darwin") {
            "macOS"
        } else { platform[1] }
        observed.cpuArchitecture = architecture[1]
        observed.cangjieSdkVersion = sdk[1]
        observed.cangjieSdkHash = sdkHash[1]
        observed.opensslVersion = openssl[1]
        observed.runCandidateCommit = candidate[1]
        observed.claudeCodeVersion = claude[1]
        observed.archiveToolVersion = "${tar[1]}|${zstd[1]}"
        observed.archiveTool = "tar+zstd"
        observed.qdrantImageDigest = qdrant[1]
        out.ok = true
        out.diagnostic = "ok"
        out.observed = observed
        out.attestedInputHash = attestedInputHash
        // The single-commit model binds the measured environment directly to
        // the clean candidate checkout selected by the run command.
        out.attestationEvidenceCommit = candidate[1]
        out
    }
}

public class CkbReproEnvironmentPlanOptions {
    public var environmentTemplatePath: String = ""
    public var compositionManifestPath: String = ""
    public var runCandidateCommit: String = ""
    public var repositoryRoot: String = ""
    public var outputPath: String = ""
    public var json: Bool = false
    public var diagnostic: String = "not_parsed"
    public init() {}
}

public class CkbReproEnvironmentPlanExecution {
    public var ok: Bool = false
    public var exitCode: Int64 = 2
    public var diagnostic: String = "not_run"
    public var output: String = ""
    public var environmentPlanHash: String = ""
    public var probeCalls: Int64 = 0
    public var providerCalls: Int64 = 0
    public var modelCalls: Int64 = 0
    public var runnerCalls: Int64 = 0
    public init() {}
}

public func parseCkbReproEnvironmentPlanOptions(args: Array<String>):
    CkbReproEnvironmentPlanOptions {
    let out = CkbReproEnvironmentPlanOptions()
    if (args.size == 0 || args[0] != "ckb-repro-environment-plan") {
        out.diagnostic = "environment_plan_command_required"; return out
    }
    let seen = HashSet<String>(); var index: Int64 = 1
    while (index < args.size) {
        let name = args[index]
        if (name == "--json") {
            if (seen.contains(name)) {
                out.diagnostic = "duplicate_argument:${name}"; return out
            }
            seen.add(name); out.json = true; index += 1; continue
        }
        if (name != "--environment-template" &&
            name != "--composition-manifest" &&
            name != "--run-candidate-commit" &&
            name != "--repository-root" && name != "--output") {
            out.diagnostic = "unknown_argument:${name}"; return out
        }
        if (seen.contains(name)) {
            out.diagnostic = "duplicate_argument:${name}"; return out
        }
        if (index + 1 >= args.size || args[index + 1].startsWith("--")) {
            out.diagnostic = "missing_argument_value:${name}"; return out
        }
        seen.add(name); let value = args[index + 1]
        if (name == "--environment-template") {
            out.environmentTemplatePath = value
        } else if (name == "--composition-manifest") {
            out.compositionManifestPath = value
        } else if (name == "--run-candidate-commit") {
            out.runCandidateCommit = value
        } else if (name == "--repository-root") {
            out.repositoryRoot = value
        } else { out.outputPath = value }
        index += 2
    }
    out.diagnostic = validateCkbReproEnvironmentPlanOptions(out); out
}

public func validateCkbReproEnvironmentPlanOptions(
    options: CkbReproEnvironmentPlanOptions): String {
    if (!p6EnvironmentPlanCanonicalFile(options.environmentTemplatePath,
            128 * 1024)) {
        return "environment_plan_template_invalid"
    }
    if (!p6EnvironmentPlanCanonicalFile(options.compositionManifestPath,
            64 * 1024)) {
        return "environment_plan_composition_invalid"
    }
    if (!p6CommitValid(options.runCandidateCommit)) {
        return "environment_plan_commit_invalid"
    }
    if (!p6EnvironmentPlanCanonicalDirectory(options.repositoryRoot)) {
        return "environment_plan_repository_invalid"
    }
    if (!p6EnvironmentPlanOutputPathValid(options.outputPath) ||
        options.outputPath.startsWith("${options.repositoryRoot}/")) {
        return "environment_plan_output_invalid"
    }
    "ok"
}

public func runCkbReproEnvironmentPlanCli(args: Array<String>):
    CkbReproEnvironmentPlanExecution {
    let options = parseCkbReproEnvironmentPlanOptions(args)
    if (options.diagnostic != "ok") {
        return p6EnvironmentPlanFailure(options.diagnostic,
            options.json || args.contains("--json"), 2, 0)
    }
    p6RunCkbReproEnvironmentPlan(options,
        CkbReproFilesystemEnvironmentProbe(
            repositoryRootOverride: options.repositoryRoot,
            repositoryRootOverrideEnabled: true,
            compositionManifestOverride: options.compositionManifestPath))
}

public func runCkbReproEnvironmentPlanCliWithProbe(args: Array<String>,
    probe: CkbReproEnvironmentProbe): CkbReproEnvironmentPlanExecution {
    let options = parseCkbReproEnvironmentPlanOptions(args)
    if (options.diagnostic != "ok") {
        return p6EnvironmentPlanFailure(options.diagnostic,
            options.json || args.contains("--json"), 2, 0)
    }
    p6RunCkbReproEnvironmentPlan(options, probe)
}

private func p6RunCkbReproEnvironmentPlan(
    options: CkbReproEnvironmentPlanOptions,
    probe: CkbReproEnvironmentProbe): CkbReproEnvironmentPlanExecution {
    let templateRead = ckbReproReadSingleFileNoFollow(
        options.environmentTemplatePath, 128 * 1024)
    let composition = ckbReproValidatedCompositionHash(
        options.compositionManifestPath)
    if (!templateRead[0] || !composition[0]) {
        return p6EnvironmentPlanFailure(if (!templateRead[0]) {
            "environment_plan_template_invalid"
        } else { "environment_plan_composition_invalid" }, options.json, 1, 0)
    }
    let template = parseCkbReproEnvironmentLock(templateRead[1])
    if (!template[0].ok || !validateCkbReproEnvironmentLock(template[1]).ok ||
        template[1].identityStatus != "planned" ||
        template[1].compositionManifestHash != "" ||
        template[1].attestationAuthorityHash != "") {
        return p6EnvironmentPlanFailure("environment_plan_template_invalid",
            options.json, 1, 0)
    }
    let target = parseCkbReproEnvironmentLock(
        renderCkbReproEnvironmentLock(template[1]).toArray())
    if (!target[0].ok) {
        return p6EnvironmentPlanFailure("environment_plan_template_invalid",
            options.json, 1, 0)
    }
    target[1].identityStatus = "frozen"
    target[1].runCandidateCommit = options.runCandidateCommit
    target[1].compositionManifestHash = composition[1]
    target[1].attestationAuthorityHash = ""
    let attestedInputHash = ckbReproObservedEnvironmentProjectionHash(target[1])
    let observed = try {
        probe.inspect(target[1], attestedInputHash, options.repositoryRoot)
    } catch (_: Exception) {
        return p6EnvironmentPlanFailure("environment_probe_unavailable",
            options.json, 1, 1)
    }
    if (!observed.ok || observed.attestedInputHash != attestedInputHash) {
        return p6EnvironmentPlanFailure(if (observed.diagnostic == "") {
            "environment_probe_unavailable"
        } else { observed.diagnostic }, options.json, 1, 1)
    }
    let checked = validateCkbReproEnvironmentLock(observed.observed,
        mode: "execution")
    if (!checked.ok || observed.attestationEvidenceCommit !=
            options.runCandidateCommit ||
        observed.observed.runCandidateCommit != options.runCandidateCommit ||
        observed.observed.compositionManifestHash != composition[1]) {
        return p6EnvironmentPlanFailure("environment_plan_observation_invalid",
            options.json, 1, 1)
    }
    let planned = parseCkbReproEnvironmentLock(
        renderCkbReproEnvironmentLock(template[1]).toArray())
    if (!planned[0].ok) {
        return p6EnvironmentPlanFailure("environment_plan_observation_invalid",
            options.json, 1, 1)
    }
    p6EnvironmentPlanCopyMeasured(observed.observed, planned[1])
    planned[1].identityStatus = "planned"
    planned[1].compositionManifestHash = ""
    planned[1].attestationAuthorityHash = ""
    let planCheck = validateCkbReproEnvironmentLock(planned[1])
    let planText = renderCkbReproEnvironmentLock(planned[1])
    let readback = parseCkbReproEnvironmentLock(planText.toArray())
    if (!planCheck.ok || !readback[0].ok ||
        renderCkbReproEnvironmentLock(readback[1]) != planText) {
        return p6EnvironmentPlanFailure("environment_plan_generation_invalid",
            options.json, 1, 1)
    }
    let published = p6EnvironmentPlanPublish(options.outputPath,
        planText.toArray())
    if (published != "ok") {
        return p6EnvironmentPlanFailure(published, options.json, 1, 1)
    }
    let out = CkbReproEnvironmentPlanExecution()
    out.ok = true; out.exitCode = 0; out.diagnostic = "ok"
    out.probeCalls = 1
    out.environmentPlanHash = ckbReproBundleHash(planText.toArray())
    out.output = if (options.json) {
        "{\"ok\":true,\"diagnostic\":\"ok\"," +
        "\"environmentPlanHash\":\"${out.environmentPlanHash}\"," +
        "\"probeCalls\":1,\"providerCalls\":0,\"modelCalls\":0," +
        "\"runnerCalls\":0}"
    } else {
        "CKB environment plan written. hash=${out.environmentPlanHash} " +
        "probeCalls=1 providerCalls=0 modelCalls=0 runnerCalls=0\n"
    }
    out
}

private func p6EnvironmentPlanPublish(path: String,
    bytes: Array<UInt8>): String {
    let target = Path(path); let parent = target.parent
    let parentIdentity = ckbReproDirectoryOwnershipIdentity(parent.toString())
    let grandparentIdentity = ckbReproDirectoryOwnershipIdentity(
        parent.parent.toString())
    if (parentIdentity == "" || grandparentIdentity == "") {
        return "environment_plan_output_invalid"
    }
    if (exists(target)) {
        let existing = ckbReproReadSingleFileNoFollow(path, 128 * 1024)
        return if (existing[0] && existing[1] == bytes) { "ok" }
            else { "environment_plan_output_conflict" }
    }
    let descriptor = CkbReproOwnedTempDescriptor()
    let token = ckbReproBundleHash(bytes).replace("sha256:", "")
    descriptor.acquireBound(parent.toString(),
        ".${target.fileName}.plan-${token}", target.fileName,
        expectedParentIdentity: parentIdentity,
        expectedGrandparentIdentity: grandparentIdentity)
    try {
        if (!descriptor.ok || !descriptor.createPayload(bytes) ||
            !descriptor.publish() || !descriptor.syncAndValidate()) {
            let recovery = ckbReproReadSingleFileNoFollow(path, 128 * 1024)
            if (recovery[0] && recovery[1] == bytes) { return "ok" }
            return if (descriptor.diagnostic == "ok") {
                "environment_plan_publish_failed"
            } else { descriptor.diagnostic }
        }
        let loaded = descriptor.readPublicTarget(128 * 1024)
        if (!loaded[0] || loaded[1] != bytes ||
            ckbReproDirectoryOwnershipIdentity(parent.toString()) !=
                parentIdentity) {
            return "environment_plan_readback_failed"
        }
        "ok"
    } finally { _ = descriptor.cleanup() }
}

private func p6EnvironmentPlanFailure(diagnostic: String, json: Bool,
    exitCode: Int64, probeCalls: Int64): CkbReproEnvironmentPlanExecution {
    let out = CkbReproEnvironmentPlanExecution()
    out.exitCode = exitCode; out.diagnostic = p6CliSafeDiagnostic(diagnostic)
    out.probeCalls = probeCalls
    out.output = if (json) {
        "{\"ok\":false,\"diagnostic\":\"${out.diagnostic}\"," +
        "\"probeCalls\":${probeCalls},\"providerCalls\":0," +
        "\"modelCalls\":0,\"runnerCalls\":0}"
    } else {
        "CKB environment plan failed: ${out.diagnostic}. " +
        "probeCalls=${probeCalls} providerCalls=0 modelCalls=0 runnerCalls=0\n"
    }
    out
}

private func p6EnvironmentPlanCopyMeasured(source: CkbReproEnvironmentLock,
    target: CkbReproEnvironmentLock): Unit {
    target.certifiedPlatform = source.certifiedPlatform
    target.cpuArchitecture = source.cpuArchitecture
    target.cangjieSdkVersion = source.cangjieSdkVersion
    target.cangjieSdkHash = source.cangjieSdkHash
    target.opensslVersion = source.opensslVersion
    target.serviceHeap = source.serviceHeap
    target.qdrantImageDigest = source.qdrantImageDigest
    target.runCandidateCommit = source.runCandidateCommit
    target.runCriticalFilesManifestHash = source.runCriticalFilesManifestHash
    target.runCriticalTreeHash = source.runCriticalTreeHash
    target.claudeCodeVersion = source.claudeCodeVersion
    target.glmProvider = source.glmProvider
    target.glmBaseUrl = source.glmBaseUrl
    target.glmModel = source.glmModel
    target.glmCredentialEnv = source.glmCredentialEnv
    target.embeddingProvider = source.embeddingProvider
    target.embeddingModel = source.embeddingModel
    target.embeddingDimension = source.embeddingDimension
    target.embeddingCredentialEnv = source.embeddingCredentialEnv
    target.archiveTool = source.archiveTool
    target.archiveToolVersion = source.archiveToolVersion
    target.promptHash = source.promptHash
    target.mcpCommand = source.mcpCommand
    target.mcpTransport = source.mcpTransport
    target.sandboxCapability = source.sandboxCapability
    target.datasetVersion = source.datasetVersion
    target.authorityDeliveryHash = source.authorityDeliveryHash
}

private func p6EnvironmentPlanCanonicalFile(path: String,
    limit: Int64): Bool {
    path != "" && Path(path).isAbsolute() &&
        (try { canonicalize(Path(path)).toString() == path }
            catch (_: Exception) { false }) &&
        ckbReproReadSingleFileNoFollow(path, limit)[0]
}

private func p6EnvironmentPlanCanonicalDirectory(path: String): Bool {
    path != "" && Path(path).isAbsolute() &&
        ckbReproDirectoryOwnershipIdentity(path) != "" &&
        (try { canonicalize(Path(path)).toString() == path }
            catch (_: Exception) { false })
}

private func p6EnvironmentPlanOutputPathValid(path: String): Bool {
    if (path == "" || !Path(path).isAbsolute()) {
        return false
    }
    let parent = Path(path).parent
    if (parent.toString() == "" ||
        ckbReproDirectoryOwnershipIdentity(parent.toString()) == "") {
        return false
    }
    let canonical = try {
        canonicalize(parent).toString() == parent.toString() &&
            parent.join(Path(path).fileName).toString() == path
    } catch (_: Exception) { false }
    canonical && (!exists(Path(path)) ||
        ckbReproReadSingleFileNoFollow(path, 128 * 1024)[0])
}

public func ckbReproProbeGitCommit(repositoryRoot: String,
    runner: CkbReproGitProbeRunner): (Int64, String) {
    if (!p6CliAbsolutePath(repositoryRoot) || !exists(Path(repositoryRoot))) {
        return (127, "")
    }
    let canonical = try { canonicalize(Path(repositoryRoot)).toString() }
        catch (_: Exception) { return (127, "") }
    if (canonical != repositoryRoot) { return (127, "") }
    try {
        for (_ in Directory.readFrom(Path(repositoryRoot))) { break }
    } catch (_: Exception) { return (127, "") }
    runner.run("git", ["-C", repositoryRoot, "rev-parse", "HEAD"])
}

public func ckbReproValidateEvidenceCommit(repositoryRoot: String,
    runCandidateCommit: String, runner: CkbReproGitProbeRunner):
    (String, String) {
    if (!p6CliAbsolutePath(repositoryRoot) ||
        !exists(Path(repositoryRoot)) || !p6CommitValid(runCandidateCommit)) {
        return ("git_run_candidate_invalid", "")
    }
    let canonical = try { canonicalize(Path(repositoryRoot)).toString() }
        catch (_: Exception) { return ("git_repository_invalid", "") }
    if (canonical != repositoryRoot) {
        return ("git_repository_invalid", "")
    }
    let candidate = runner.run("git", ["-C", repositoryRoot, "cat-file",
        "-e", "${runCandidateCommit}^{commit}"])
    if (candidate[0] != 0) { return ("git_run_candidate_missing", "") }
    let status = runner.run("git", ["-C", repositoryRoot, "status",
        "--porcelain=v1", "--untracked-files=all"])
    if (status[0] != 0) { return ("git_status_unavailable", "") }
    if (status[1] != "") { return ("git_worktree_dirty", "") }
    let head = runner.run("git", ["-C", repositoryRoot, "rev-parse", "HEAD"])
    if (head[0] != 0 || !p6CommitValid(head[1])) {
        return ("git_head_invalid", "")
    }
    if (head[1] == runCandidateCommit) {
        return ("git_evidence_commit_missing", "")
    }
    let ancestor = runner.run("git", ["-C", repositoryRoot, "merge-base",
        "--is-ancestor", runCandidateCommit, head[1]])
    if (ancestor[0] != 0) {
        return ("git_run_candidate_not_ancestor", "")
    }
    let range = "${runCandidateCommit}..${head[1]}"
    let lockPath = "reproducibility/manifests/environment-lock.json"
    let authorityPath =
        "reproducibility/manifests/environment-attestation-authority.json"
    let lockDiff = runner.run("git", ["-C", repositoryRoot, "diff",
        "--quiet", range, "--", lockPath])
    let authorityDiff = runner.run("git", ["-C", repositoryRoot, "diff",
        "--quiet", range, "--", authorityPath])
    if (lockDiff[0] != 1 || authorityDiff[0] != 1) {
        return ("git_evidence_commit_incomplete", "")
    }
    let outside = runner.run("git", ["-C", repositoryRoot, "diff",
        "--quiet", range, "--", ".", ":(exclude)${lockPath}",
        ":(exclude)${authorityPath}"])
    if (outside[0] != 0) {
        return ("git_evidence_commit_scope_invalid", "")
    }
    if (!exists(Path(repositoryRoot).join(lockPath)) ||
        !exists(Path(repositoryRoot).join(authorityPath))) {
        return ("git_evidence_commit_incomplete", "")
    }
    ("ok", head[1])
}

public func ckbReproValidateCandidateCheckout(repositoryRoot: String,
    runCandidateCommit: String, runner: CkbReproGitProbeRunner):
    (String, String) {
    if (!p6CliAbsolutePath(repositoryRoot) ||
        !exists(Path(repositoryRoot)) || !p6CommitValid(runCandidateCommit)) {
        return ("git_run_candidate_invalid", "")
    }
    let canonical = try { canonicalize(Path(repositoryRoot)).toString() }
        catch (_: Exception) { return ("git_repository_invalid", "") }
    if (canonical != repositoryRoot) {
        return ("git_repository_invalid", "")
    }
    let status = runner.run("git", ["-C", repositoryRoot, "status",
        "--porcelain=v1", "--untracked-files=all"])
    if (status[0] != 0) { return ("git_status_unavailable", "") }
    if (status[1] != "") { return ("git_worktree_dirty", "") }
    let head = runner.run("git", ["-C", repositoryRoot, "rev-parse", "HEAD"])
    if (head[0] != 0 || head[1] != runCandidateCommit) {
        return ("git_candidate_checkout_mismatch", "")
    }
    ("ok", runCandidateCommit)
}

public func parseCkbReproPreflightCliArgs(args: Array<String>):
    CkbReproPreflightCliOptions {
    let out = CkbReproPreflightCliOptions()
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "ckb-repro-preflight") { i += 1; continue }
        if (arg == "--json") {
            if (out.json) { out.diagnostic = "duplicate_argument:--json"; return out }
            out.json = true; i += 1; continue
        }
        if (arg == "--environment-lock" || arg == "--observed-environment" ||
            arg == "--certification-preflight" ||
            arg == "--certification-run-manifest" ||
            arg == "--signing-fingerprint" ||
            arg == "--observed-environment-projection-hash") {
            if (i + 1 >= args.size) { out.diagnostic = "missing_value:${arg}"; return out }
            let value = args[i + 1]
            if (arg != "--signing-fingerprint" &&
                arg != "--observed-environment-projection-hash" &&
                !p6CliAbsolutePath(value)) {
                out.diagnostic = "preflight_path_invalid"; return out
            }
            if (arg == "--environment-lock") {
                if (out.environmentLockPath != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.environmentLockPath = value
            } else if (arg == "--observed-environment") {
                if (out.observedEnvironmentPath != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.observedEnvironmentPath = value
            } else if (arg == "--certification-preflight") {
                if (out.certificationPreflightPath != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.certificationPreflightPath = value
            } else if (arg == "--certification-run-manifest") {
                if (out.certificationRunManifestPath != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.certificationRunManifestPath = value
            } else if (arg == "--signing-fingerprint") {
                if (out.signingFingerprint != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.signingFingerprint = value
            } else {
                if (out.observedEnvironmentProjectionHash != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.observedEnvironmentProjectionHash = value
            }
            i += 2; continue
        }
        out.diagnostic = "unknown_argument:${arg}"; return out
    }
    if (out.environmentLockPath == "" || out.observedEnvironmentPath == "" ||
        out.certificationPreflightPath == "" ||
        out.certificationRunManifestPath == "" || out.signingFingerprint == "" ||
        out.observedEnvironmentProjectionHash == "") {
        out.diagnostic = "required_argument_missing"; return out
    }
    out.valid = true; out.diagnostic = "ok"; out
}

public func validateCkbReproPreflightCliOptions(
    options: CkbReproPreflightCliOptions): CkbReproContractResult {
    if (!options.valid) { return p6Failure(options.diagnostic) }
    for (path in [options.environmentLockPath, options.observedEnvironmentPath,
        options.certificationPreflightPath,
        options.certificationRunManifestPath]) {
        if (!p6CliAbsolutePath(path)) { return p6Failure("preflight_path_invalid") }
    }
    if (!p6ProbeFingerprint(options.signingFingerprint) ||
        !p6HashValid(options.observedEnvironmentProjectionHash)) {
        return p6Failure("environment_attestation_authority_invalid")
    }
    p6Success()
}

public func executeCkbReproPreflightCliAdapter(
    options: CkbReproPreflightCliOptions,
    inputs: CkbReproPreflightCliInputs): CkbReproEnvironmentPreflightResult {
    let checked = validateCkbReproPreflightCliOptions(options)
    if (!checked.ok) { return p6CliPreflightFailure(checked.diagnostic) }
    runCkbReproEnvironmentPreflight(inputs.expected, inputs.observed, inputs.heap,
        inputs.certificationPreflightJson, inputs.certificationRunManifestJson)
}

public func executeCkbReproPreflightCliAdapterWithProbe(
    options: CkbReproPreflightCliOptions,
    inputs: CkbReproPreflightCliInputs,
    probe: CkbReproEnvironmentProbe): CkbReproEnvironmentPreflightResult {
    let checked = validateCkbReproPreflightCliOptions(options)
    if (!checked.ok) { return p6CliPreflightFailure(checked.diagnostic) }
    let attestedInputHash =
        ckbReproObservedEnvironmentProjectionHash(inputs.observed)
    let evidenceRoot = p6EnvironmentRepositoryRoot(
        options.environmentLockPath)
    if (evidenceRoot == "") {
        return p6CliPreflightFailure("environment_evidence_root_invalid")
    }
    let actual = try {
        probe.inspect(inputs.observed, attestedInputHash, evidenceRoot)
    }
        catch (_: Exception) { return p6CliPreflightFailure(
            "environment_probe_unavailable") }
    if (!actual.ok) { return p6CliPreflightFailure(actual.diagnostic) }
    if (actual.attestedInputHash != attestedInputHash) {
        return p6CliPreflightFailure("environment_attestation_input_mismatch")
    }
    let result = runCkbReproEnvironmentPreflight(inputs.expected, actual.observed,
        inputs.heap, inputs.certificationPreflightJson,
        inputs.certificationRunManifestJson)
    if (result.ok) {
        if (!p6CommitValid(actual.attestationEvidenceCommit)) {
            return p6CliPreflightFailure("git_evidence_commit_invalid")
        }
        result.attestationEvidenceCommit = actual.attestationEvidenceCommit
    }
    result
}

// Runs the production preflight for the release model selected by the user:
// one clean candidate commit plus runtime measurement. The commit is supplied
// by the run command instead of being written into the commit it identifies.
public func runCkbReproSingleCommitPreflight(environmentLockPath: String,
    certificationPreflightPath: String,
    certificationRunManifestPath: String, repositoryRoot: String,
    sourceCommit: String, heapRaw: String,
    probe!: CkbReproEnvironmentProbe = CkbReproFilesystemEnvironmentProbe()):
    CkbReproEnvironmentPreflightResult {
    for (item in [
        (environmentLockPath, "environment_lock_missing"),
        (certificationPreflightPath, "certification_preflight_missing"),
        (certificationRunManifestPath, "certification_run_manifest_missing")
    ]) {
        if (!p6CliAbsolutePath(item[0]) || !exists(Path(item[0]))) {
            return p6CliPreflightFailure(item[1])
        }
        if (try { canonicalize(Path(item[0])).toString() != item[0] }
            catch (_: Exception) { true }) {
            return p6CliPreflightFailure("preflight_path_not_canonical")
        }
    }
    if (!p6CliAbsolutePath(repositoryRoot) ||
        !p6CommitValid(sourceCommit)) {
        return p6CliPreflightFailure("git_run_candidate_invalid")
    }
    let expected = p6CliReadEnvironment(environmentLockPath)
    if (!expected[0].ok) {
        return p6CliPreflightFailure(expected[0].diagnostic)
    }
    expected[1].runCandidateCommit = sourceCommit
    let checked = validateCkbReproEnvironmentLock(expected[1],
        mode: "execution")
    if (!checked.ok) { return p6CliPreflightFailure(checked.diagnostic) }
    let preflight = p6CliReadUtf8(certificationPreflightPath)
    if (preflight[0] != "ok") {
        return p6CliPreflightFailure(preflight[0])
    }
    let manifest = p6CliReadUtf8(certificationRunManifestPath)
    if (manifest[0] != "ok") {
        return p6CliPreflightFailure(manifest[0])
    }
    let inputHash = ckbReproObservedEnvironmentProjectionHash(expected[1])
    let actual = try {
        probe.inspect(expected[1], inputHash, repositoryRoot)
    } catch (_: Exception) {
        return p6CliPreflightFailure("environment_probe_unavailable")
    }
    if (!actual.ok) { return p6CliPreflightFailure(actual.diagnostic) }
    if (actual.attestedInputHash != inputHash ||
        actual.attestationEvidenceCommit != sourceCommit) {
        return p6CliPreflightFailure("git_candidate_checkout_mismatch")
    }
    let result = runCkbReproEnvironmentPreflight(expected[1], actual.observed,
        ckbServiceHeapPreflight(heapRaw), preflight[1], manifest[1])
    if (result.ok) { result.attestationEvidenceCommit = sourceCommit }
    result
}

public func runCkbReproPreflightCliAdapter(
    options: CkbReproPreflightCliOptions): CkbReproEnvironmentPreflightResult {
    let checked = validateCkbReproPreflightCliOptions(options)
    if (!checked.ok) { return p6CliPreflightFailure(checked.diagnostic) }
    p6CliPreflightFailure("environment_attestation_authority_unavailable")
}

public func runCkbReproPreflightCliAdapter(
    options: CkbReproPreflightCliOptions,
    authority: CkbReproAttestationAuthority):
    CkbReproEnvironmentPreflightResult {
    let checked = validateCkbReproPreflightCliOptions(options)
    if (!checked.ok) { return p6CliPreflightFailure(checked.diagnostic) }
    p6CliPreflightFailure("environment_attestation_authority_unavailable")
}

public func runCkbReproPreflightCliAdapter(
    options: CkbReproPreflightCliOptions,
    authority: CkbReproVerifiedAttestationAuthority):
    CkbReproEnvironmentPreflightResult {
    let checked = validateCkbReproPreflightCliOptions(options)
    if (!checked.ok) { return p6CliPreflightFailure(checked.diagnostic) }
    if (authority.signingFingerprint() != options.signingFingerprint ||
        authority.observedEnvironmentProjectionHash() !=
            options.observedEnvironmentProjectionHash) {
        return p6CliPreflightFailure(
            "environment_attestation_authority_mismatch")
    }
    p6RunVerifiedPreflight(options, authority.signingFingerprint(),
        authority.observedEnvironmentProjectionHash(),
        CkbReproGpgAttestationSignatureVerifier(),
        CkbReproFilesystemEnvironmentProbe())
}

private func p6RunVerifiedPreflight(options: CkbReproPreflightCliOptions,
    signingFingerprint: String, observedEnvironmentProjectionHash: String,
    signatureVerifier: CkbReproAttestationSignatureVerifier,
    probe: CkbReproEnvironmentProbe):
    CkbReproEnvironmentPreflightResult {
    for (item in [
        (options.environmentLockPath, "environment_lock_missing"),
        (options.observedEnvironmentPath, "observed_environment_missing"),
        (options.certificationPreflightPath, "certification_preflight_missing"),
        (options.certificationRunManifestPath, "certification_run_manifest_missing")
    ]) {
        if (!exists(Path(item[0]))) { return p6CliPreflightFailure(item[1]) }
        if (try { canonicalize(Path(item[0])).toString() != item[0] }
            catch (_: Exception) { true }) {
            return p6CliPreflightFailure("preflight_path_not_canonical")
        }
    }
    let expected = p6CliReadEnvironment(options.environmentLockPath)
    if (!expected[0].ok) { return p6CliPreflightFailure(expected[0].diagnostic) }
    let observed = p6CliReadEnvironment(options.observedEnvironmentPath)
    if (!observed[0].ok) { return p6CliPreflightFailure(observed[0].diagnostic) }
    if (ckbReproObservedEnvironmentProjectionHash(observed[1]) !=
        observedEnvironmentProjectionHash) {
        return p6CliPreflightFailure("environment_attestation_input_mismatch")
    }
    let attestation = try {
        signatureVerifier.verify(options.observedEnvironmentPath)
    } catch (_: Exception) {
        return p6CliPreflightFailure(
            "environment_attestation_signature_invalid")
    }
    if (!attestation.ok) {
        return p6CliPreflightFailure(attestation.diagnostic)
    }
    if (attestation.signingFingerprint != signingFingerprint) {
        return p6CliPreflightFailure(
            "environment_attestation_signature_invalid")
    }
    let preflight = p6CliReadUtf8(options.certificationPreflightPath)
    if (preflight[0] != "ok") { return p6CliPreflightFailure(preflight[0]) }
    let manifest = p6CliReadUtf8(options.certificationRunManifestPath)
    if (manifest[0] != "ok") { return p6CliPreflightFailure(manifest[0]) }
    let heapRaw = match (getVariable("cjHeapSize")) {
        case Some(value) => value
        case None => ""
    }
    let inputs = CkbReproPreflightCliInputs()
    inputs.expected = expected[1]
    inputs.observed = observed[1]
    inputs.heap = ckbServiceHeapPreflight(heapRaw)
    inputs.certificationPreflightJson = preflight[1]
    inputs.certificationRunManifestJson = manifest[1]
    executeCkbReproPreflightCliAdapterWithProbe(options, inputs, probe)
}

public func runCkbReproPreflightCliAdapterWithAuthorityDependencies(
    options: CkbReproPreflightCliOptions,
    authority: CkbReproVerifiedAttestationAuthority,
    signatureVerifier: CkbReproAttestationSignatureVerifier,
    probe: CkbReproEnvironmentProbe):
    CkbReproEnvironmentPreflightResult {
    let checked = validateCkbReproPreflightCliOptions(options)
    if (!checked.ok) { return p6CliPreflightFailure(checked.diagnostic) }
    if (authority.signingFingerprint() != options.signingFingerprint ||
        authority.observedEnvironmentProjectionHash() !=
            options.observedEnvironmentProjectionHash) {
        return p6CliPreflightFailure(
            "environment_attestation_authority_mismatch")
    }
    p6RunVerifiedPreflight(options, authority.signingFingerprint(),
        authority.observedEnvironmentProjectionHash(), signatureVerifier,
        probe)
}

public func renderCkbReproPreflightCliHuman(
    result: CkbReproEnvironmentPreflightResult,
    lock: CkbReproEnvironmentLock): String {
    "preflight: ${if (result.ok) { "passed" } else { "blocked" }}\n" +
        "diagnostic: ${p6CliSafeDiagnostic(result.diagnostic)}\n" +
        "platform: ${p6CliPublic(lock.certifiedPlatform)} ${p6CliPublic(lock.cpuArchitecture)}\n" +
        "model: ${p6CliPublic(lock.glmProvider)}/${p6CliPublic(lock.glmModel)}\n" +
        "embedding: ${p6CliPublic(lock.embeddingProvider)}/${p6CliPublic(lock.embeddingModel)}\n" +
        "mcp transport: ${p6CliPublic(lock.mcpTransport)}\n" +
        "environment hash: ${result.environmentManifestHash}\n" +
        "certified input hash: ${result.certifiedRunInputHash}\n" +
        "attestation evidence commit: ${result.attestationEvidenceCommit}\n"
}

public func renderCkbReproPreflightCliJson(
    result: CkbReproEnvironmentPreflightResult,
    lock: CkbReproEnvironmentLock): String {
    "{\"ok\":${result.ok},\"startAllowed\":${result.startAllowed}," +
        "\"diagnostic\":\"${p6Escape(p6CliSafeDiagnostic(result.diagnostic))}\"," +
        "\"platform\":\"${p6Escape(p6CliPublic(lock.certifiedPlatform))}\"," +
        "\"architecture\":\"${p6Escape(p6CliPublic(lock.cpuArchitecture))}\"," +
        "\"provider\":\"${p6Escape(p6CliPublic(lock.glmProvider))}\"," +
        "\"model\":\"${p6Escape(p6CliPublic(lock.glmModel))}\"," +
        "\"embeddingProvider\":\"${p6Escape(p6CliPublic(lock.embeddingProvider))}\"," +
        "\"embeddingModel\":\"${p6Escape(p6CliPublic(lock.embeddingModel))}\"," +
        "\"mcpTransport\":\"${p6Escape(p6CliPublic(lock.mcpTransport))}\"," +
        "\"environmentManifestHash\":\"${p6Escape(result.environmentManifestHash)}\"," +
        "\"certifiedRunInputHash\":\"${p6Escape(result.certifiedRunInputHash)}\"," +
        "\"attestationEvidenceCommit\":\"${p6Escape(result.attestationEvidenceCommit)}\"}"
}

public func parseCkbReproEnvironmentLock(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbReproEnvironmentLock) {
    let lock = CkbReproEnvironmentLock()
    let decoded = p6Decode(bytes)
    if (decoded[0] != "ok") { return (p6Failure(decoded[0]), lock) }
    try {
        let object = JsonValue.fromStr(decoded[1]).asObject()
        if (object.size() != 41) {
            return (p6Failure("environment_field_contract_invalid"), lock)
        }
        lock.schemaVersion = p6String(object, "schemaVersion")
        lock.identityStatus = p6String(object, "identityStatus")
        lock.certifiedPlatform = p6String(object, "certifiedPlatform")
        lock.cpuArchitecture = p6String(object, "cpuArchitecture")
        lock.cangjieSdkVersion = p6String(object, "cangjieSdkVersion")
        lock.cangjieSdkHash = p6String(object, "cangjieSdkHash")
        lock.opensslVersion = p6String(object, "opensslVersion")
        lock.serviceHeap = p6String(object, "serviceHeap")
        lock.qdrantImageDigest = p6String(object, "qdrantImageDigest")
        lock.runCandidateCommit = p6String(object, "runCandidateCommit")
        lock.runCriticalFilesManifestHash = p6String(object, "runCriticalFilesManifestHash")
        lock.runCriticalTreeHash = p6String(object, "runCriticalTreeHash")
        lock.compositionManifestPath = p6String(object,
            "compositionManifestPath")
        lock.compositionManifestHash = p6String(object,
            "compositionManifestHash")
        lock.claudeCodeVersion = p6String(object, "claudeCodeVersion")
        lock.glmProvider = p6String(object, "glmProvider")
        lock.glmBaseUrl = p6String(object, "glmBaseUrl")
        lock.glmModel = p6String(object, "glmModel")
        lock.modelFingerprint = p6String(object, "modelFingerprint")
        lock.glmCredentialEnv = p6String(object, "glmCredentialEnv")
        lock.embeddingProvider = p6String(object, "embeddingProvider")
        lock.embeddingModel = p6String(object, "embeddingModel")
        lock.embeddingDimension = p6Int(object, "embeddingDimension")
        lock.embeddingCredentialEnv = p6String(object, "embeddingCredentialEnv")
        lock.archiveTool = p6String(object, "archiveTool")
        lock.archiveToolVersion = p6String(object, "archiveToolVersion")
        lock.experimentGroup = p6String(object, "experimentGroup")
        lock.ckbRequired = p6Bool(object, "ckbRequired")
        lock.localDocsPolicy = p6String(object, "localDocsPolicy")
        lock.modelEffort = p6String(object, "modelEffort")
        lock.modelBudget = p6String(object, "modelBudget")
        lock.timeoutSeconds = p6Int(object, "timeoutSeconds")
        lock.transportRetryBudget = p6Int(object, "transportRetryBudget")
        lock.promptHash = p6String(object, "promptHash")
        lock.mcpCommand = p6String(object, "mcpCommand")
        lock.mcpTransport = p6String(object, "mcpTransport")
        lock.sandboxCapability = p6String(object, "sandboxCapability")
        lock.datasetVersion = p6String(object, "datasetVersion")
        lock.authorityDeliveryHash = p6String(object, "authorityDeliveryHash")
        lock.attestationAuthorityManifestPath = p6String(object,
            "attestationAuthorityManifestPath")
        lock.attestationAuthorityHash = p6String(object,
            "attestationAuthorityHash")
    } catch (_: Exception) {
        return (p6Failure("environment_field_contract_invalid"), CkbReproEnvironmentLock())
    }
    (p6Success(), lock)
}

public func validateCkbReproEnvironmentLock(lock: CkbReproEnvironmentLock,
    mode!: String = "contract"):
    CkbReproContractResult {
    if (lock.schemaVersion != "ckb-repro-environment-v1" ||
        (lock.identityStatus != "planned" && lock.identityStatus != "frozen") ||
        (mode != "contract" && mode != "execution")) {
        return p6Failure("environment_schema_invalid")
    }
    if (lock.certifiedPlatform != "macOS" || lock.cpuArchitecture != "arm64") {
        return p6Failure("environment_platform_unsupported")
    }
    if (lock.identityStatus == "frozen") {
        if (lock.cangjieSdkVersion == "" || lock.opensslVersion == "" ||
            lock.claudeCodeVersion == "" || lock.archiveTool == "" ||
            lock.archiveToolVersion == "") {
            return p6Failure("environment_tool_identity_required")
        }
        for (hash in [lock.cangjieSdkHash, lock.runCriticalFilesManifestHash,
            lock.runCriticalTreeHash, lock.promptHash, lock.authorityDeliveryHash,
            lock.compositionManifestHash]) {
            if (!p6HashValid(hash)) { return p6Failure("environment_hash_invalid") }
        }
        if (!lock.qdrantImageDigest.startsWith("sha256:") ||
            !p6CommitValid(lock.runCandidateCommit)) {
            return p6Failure("environment_runtime_identity_invalid")
        }
    } else if (mode == "execution") {
        return p6Failure("environment_identity_not_frozen")
    }
    if (lock.attestationAuthorityManifestPath !=
        "reproducibility/manifests/environment-attestation-authority.json" ||
        (lock.attestationAuthorityHash != "" &&
            !p6HashValid(lock.attestationAuthorityHash))) {
        return p6Failure("environment_attestation_authority_invalid")
    }
    if (lock.compositionManifestPath !=
        "reproducibility/manifests/runtime-composition.json" ||
        (lock.identityStatus == "planned" &&
            lock.compositionManifestHash != "")) {
        return p6Failure("environment_composition_authority_invalid")
    }
    if (lock.serviceHeap != "4GB") {
        return p6Failure("environment_heap_contract_invalid")
    }
    if (lock.glmProvider == "" || lock.glmModel != "GLM-5.2" ||
        lock.modelFingerprint != "claude-code-glm-5.2" ||
        !p6PublicProviderUrl(lock.glmBaseUrl) ||
        !p6CredentialEnvName(lock.glmCredentialEnv)) {
        return p6Failure("environment_provider_identity_invalid")
    }
    if (lock.embeddingProvider == "" || lock.embeddingModel == "" ||
        lock.embeddingDimension <= 0 ||
        !p6CredentialEnvName(lock.embeddingCredentialEnv)) {
        return p6Failure("environment_embedding_identity_invalid")
    }
    if (lock.experimentGroup != CkbAbcdeGroups.D || !lock.ckbRequired ||
        lock.localDocsPolicy == "" || lock.modelEffort == "" ||
        lock.modelBudget == "" || lock.timeoutSeconds < 1 ||
        lock.timeoutSeconds > 3600 || lock.transportRetryBudget < 0 ||
        lock.mcpCommand == "" ||
        (lock.mcpTransport != "mcp_stdio" && lock.mcpTransport != "rest" &&
            lock.mcpTransport != "mcp_http") ||
        lock.sandboxCapability != "macos-sandbox-exec" ||
        lock.datasetVersion == "") {
        return p6Failure("environment_experiment_contract_invalid")
    }
    let canonical = renderCkbReproEnvironmentLock(lock)
    if (p6ContainsSecretOrLocalPath(canonical)) {
        return p6Failure("environment_secret_or_local_path_forbidden")
    }
    let result = p6Success()
    result.canonicalJson = canonical
    result.manifestHash = p6Hash(canonical.toArray())
    result.treeHash = p6Hash(renderCkbCertifiedRunInput(lock).toArray())
    result
}

public func runCkbReproEnvironmentPreflight(expected: CkbReproEnvironmentLock,
    observed: CkbReproEnvironmentLock, heap: CkbServiceHeapPreflightResult,
    certificationPreflightJson: String, certificationRunManifestJson: String):
    CkbReproEnvironmentPreflightResult {
    let out = CkbReproEnvironmentPreflightResult()
    out.heapResult = heap
    if (!heap.ok) {
        out.diagnostic = heap.errorCode
        return out
    }
    let expectedValidation = validateCkbReproEnvironmentLock(expected,
        mode: "execution")
    if (!expectedValidation.ok) {
        out.diagnostic = expectedValidation.diagnostic
        return out
    }
    let observedValidation = validateCkbReproEnvironmentLock(observed,
        mode: "execution")
    if (!observedValidation.ok) {
        out.diagnostic = observedValidation.diagnostic
        return out
    }
    if (renderCkbReproEnvironmentLock(expected) !=
        renderCkbReproEnvironmentLock(observed)) {
        out.diagnostic = "environment_identity_drift"
        return out
    }
    let sealDiagnostic = ckbCertificationPreflightSealDiagnostic(
        certificationPreflightJson, certificationRunManifestJson)
    if (sealDiagnostic != "ok") {
        out.diagnostic = sealDiagnostic
        return out
    }
    out.ok = true
    out.startAllowed = true
    out.diagnostic = "ok"
    out.environmentManifestHash = expectedValidation.manifestHash
    out.certifiedRunInputHash = expectedValidation.treeHash
    out
}

public func renderCkbReproEnvironmentLock(lock: CkbReproEnvironmentLock): String {
    "{\"schemaVersion\":\"${p6Escape(lock.schemaVersion)}\"," +
    "\"identityStatus\":\"${p6Escape(lock.identityStatus)}\"," +
    "\"certifiedPlatform\":\"${p6Escape(lock.certifiedPlatform)}\"," +
    "\"cpuArchitecture\":\"${p6Escape(lock.cpuArchitecture)}\"," +
    "\"cangjieSdkVersion\":\"${p6Escape(lock.cangjieSdkVersion)}\"," +
    "\"cangjieSdkHash\":\"${p6Escape(lock.cangjieSdkHash)}\"," +
    "\"opensslVersion\":\"${p6Escape(lock.opensslVersion)}\"," +
    "\"serviceHeap\":\"${p6Escape(lock.serviceHeap)}\"," +
    "\"qdrantImageDigest\":\"${p6Escape(lock.qdrantImageDigest)}\"," +
    "\"runCandidateCommit\":\"${p6Escape(lock.runCandidateCommit)}\"," +
    "\"runCriticalFilesManifestHash\":\"${p6Escape(lock.runCriticalFilesManifestHash)}\"," +
    "\"runCriticalTreeHash\":\"${p6Escape(lock.runCriticalTreeHash)}\"," +
    "\"compositionManifestPath\":\"${p6Escape(lock.compositionManifestPath)}\"," +
    "\"compositionManifestHash\":\"${p6Escape(lock.compositionManifestHash)}\"," +
    "\"claudeCodeVersion\":\"${p6Escape(lock.claudeCodeVersion)}\"," +
    "\"glmProvider\":\"${p6Escape(lock.glmProvider)}\"," +
    "\"glmBaseUrl\":\"${p6Escape(lock.glmBaseUrl)}\"," +
    "\"glmModel\":\"${p6Escape(lock.glmModel)}\"," +
    "\"modelFingerprint\":\"${p6Escape(lock.modelFingerprint)}\"," +
    "\"glmCredentialEnv\":\"${p6Escape(lock.glmCredentialEnv)}\"," +
    "\"embeddingProvider\":\"${p6Escape(lock.embeddingProvider)}\"," +
    "\"embeddingModel\":\"${p6Escape(lock.embeddingModel)}\"," +
    "\"embeddingDimension\":${lock.embeddingDimension}," +
    "\"embeddingCredentialEnv\":\"${p6Escape(lock.embeddingCredentialEnv)}\"," +
    "\"archiveTool\":\"${p6Escape(lock.archiveTool)}\"," +
    "\"archiveToolVersion\":\"${p6Escape(lock.archiveToolVersion)}\"," +
    "\"experimentGroup\":\"${p6Escape(lock.experimentGroup)}\"," +
    "\"ckbRequired\":${lock.ckbRequired}," +
    "\"localDocsPolicy\":\"${p6Escape(lock.localDocsPolicy)}\"," +
    "\"modelEffort\":\"${p6Escape(lock.modelEffort)}\"," +
    "\"modelBudget\":\"${p6Escape(lock.modelBudget)}\"," +
    "\"timeoutSeconds\":${lock.timeoutSeconds}," +
    "\"transportRetryBudget\":${lock.transportRetryBudget}," +
    "\"promptHash\":\"${p6Escape(lock.promptHash)}\"," +
    "\"mcpCommand\":\"${p6Escape(lock.mcpCommand)}\"," +
    "\"mcpTransport\":\"${p6Escape(lock.mcpTransport)}\"," +
    "\"sandboxCapability\":\"${p6Escape(lock.sandboxCapability)}\"," +
    "\"datasetVersion\":\"${p6Escape(lock.datasetVersion)}\"," +
    "\"authorityDeliveryHash\":\"${p6Escape(lock.authorityDeliveryHash)}\"," +
    "\"attestationAuthorityManifestPath\":\"${p6Escape(lock.attestationAuthorityManifestPath)}\"," +
    "\"attestationAuthorityHash\":\"${p6Escape(lock.attestationAuthorityHash)}\"}"
}

public func ckbReproObservedEnvironmentProjectionHash(
    lock: CkbReproEnvironmentLock): String {
    let canonical = renderCkbReproEnvironmentLock(lock)
    let anchored = "\"attestationAuthorityHash\":\"${p6Escape(lock.attestationAuthorityHash)}\""
    p6Hash(canonical.replace(anchored,
        "\"attestationAuthorityHash\":\"\"").toArray())
}

public func freezeCkbReproEnvironmentLock(planned: CkbReproEnvironmentLock,
    compositionManifestHash: String,
    authority: CkbReproVerifiedAttestationAuthority,
    probe: CkbReproEnvironmentProbe,
    repositoryRoot: String):
    (CkbReproContractResult, CkbReproEnvironmentLock) {
    let empty = CkbReproEnvironmentLock()
    let plannedCheck = validateCkbReproEnvironmentLock(planned)
    if (!plannedCheck.ok || planned.identityStatus != "planned" ||
        planned.compositionManifestHash != "" ||
        !p6HashValid(compositionManifestHash)) {
        return (p6Failure("environment_freeze_input_invalid"), empty)
    }
    let cloned = parseCkbReproEnvironmentLock(
        renderCkbReproEnvironmentLock(planned).toArray())
    if (!cloned[0].ok) { return (cloned[0], empty) }
    let expected = cloned[1]
    expected.identityStatus = "frozen"
    expected.compositionManifestHash = compositionManifestHash
    let projectionHash = ckbReproObservedEnvironmentProjectionHash(expected)
    if (authority.authorityAnchorHash() != planned.attestationAuthorityHash ||
        authority.observedEnvironmentProjectionHash() != projectionHash) {
        return (p6Failure("environment_attestation_authority_mismatch"), empty)
    }
    let observed = try {
        probe.inspect(expected, projectionHash, repositoryRoot)
    } catch (_: Exception) {
        return (p6Failure("environment_probe_unavailable"), empty)
    }
    if (!observed.ok || observed.attestedInputHash != projectionHash) {
        return (p6Failure(if (observed.diagnostic == "") {
            "environment_probe_unavailable"
        } else { observed.diagnostic }), empty)
    }
    let checked = validateCkbReproEnvironmentLock(observed.observed,
        mode: "execution")
    if (!checked.ok) { return (checked, empty) }
    if (renderCkbReproEnvironmentLock(observed.observed) !=
        renderCkbReproEnvironmentLock(expected)) {
        return (p6Failure("environment_identity_drift"), empty)
    }
    (checked, observed.observed)
}

public func renderCkbProviderTemplate(lock: CkbReproEnvironmentLock): String {
    "GLM_PROVIDER=${lock.glmProvider}\n" +
    "GLM_BASE_URL=${lock.glmBaseUrl}\n" +
    "GLM_MODEL=${lock.glmModel}\n" +
    "MODEL_FINGERPRINT=${lock.modelFingerprint}\n" +
    "GLM_CREDENTIAL_ENV=${lock.glmCredentialEnv}\n" +
    "EMBEDDING_PROVIDER=${lock.embeddingProvider}\n" +
    "EMBEDDING_MODEL=${lock.embeddingModel}\n" +
    "EMBEDDING_DIMENSION=${lock.embeddingDimension}\n" +
    "EMBEDDING_CREDENTIAL_ENV=${lock.embeddingCredentialEnv}\n" +
    "cjHeapSize=${lock.serviceHeap}\n"
}

public func buildCkbReproRunnerArgs(reference: CkbReproReferenceManifest,
    lock: CkbReproEnvironmentLock, inputs: CkbReproRunnerInputs):
    (CkbReproContractResult, Array<String>) {
    let empty = Array<String>()
    if (!validateCkbReproEnvironmentLock(lock).ok ||
        reference.experimentGroup != lock.experimentGroup ||
        reference.datasetVersion != lock.datasetVersion ||
        inputs.runId == "" || inputs.repoRoot == "" || inputs.runsRoot == "" ||
        inputs.datasetRoot == "" || inputs.authorityManifestPath == "" ||
        inputs.ckbBin == "" || inputs.ckbConfig == "" || inputs.ckbStore == "" ||
        inputs.ckbHttpBase == "" || inputs.claudeBin == "" ||
        inputs.docsRoot == "" || inputs.candidateVersion == "" ||
        inputs.knowledgeVersion == "" ||
        !p6HashValid(inputs.providerIdentityHash) ||
        inputs.providerIdentityArtifactPath == "" ||
        inputs.frozenCandidateManifestPath == "" ||
        inputs.certificationPreflightPath == "" ||
        inputs.certificationRunManifestPath == "") {
        return (p6Failure("runner_identity_injection_required"), empty)
    }
    let args = [
        "cangjie-eval-abcde", "--run-mode", "certification",
        "--dataset-version", lock.datasetVersion,
        "--candidate-version", inputs.candidateVersion,
        "--knowledge-version", inputs.knowledgeVersion,
        "--model-fingerprint", lock.modelFingerprint,
        "--run-id", inputs.runId, "--repo-root", inputs.repoRoot,
        "--runs-root", inputs.runsRoot, "--dataset-root", inputs.datasetRoot,
        "--manifest", inputs.authorityManifestPath, "--ckb-bin", inputs.ckbBin,
        "--config", inputs.ckbConfig, "--ckb-store", inputs.ckbStore,
        "--ckb-http-base", inputs.ckbHttpBase, "--claude-bin", inputs.claudeBin,
        "--docs-root", inputs.docsRoot, "--case-start", "0", "--case-end", "163",
        "--groups", lock.experimentGroup, "--transport-retries",
        "${lock.transportRetryBudget}", "--model-timeout-seconds",
        "${lock.timeoutSeconds}",
        "--expected-model-version", lock.glmModel,
        "--provider-identity-hash", inputs.providerIdentityHash,
        "--provider-identity-artifact", inputs.providerIdentityArtifactPath,
        "--frozen-candidate-manifest", inputs.frozenCandidateManifestPath,
        "--certification-preflight", inputs.certificationPreflightPath,
        "--certification-run-manifest", inputs.certificationRunManifestPath,
        "--generation-protocol", "completion-only-v1",
        "--samples-per-case", "1"
    ]
    let result = p6Success()
    result.canonicalJson = p6ArgsIdentity(args)
    result.manifestHash = p6Hash(result.canonicalJson.toArray())
    (result, args)
}

public func runCkbReproCertifiedStudent(reference: CkbReproReferenceManifest,
    lock: CkbReproEnvironmentLock, inputs: CkbReproRunnerInputs,
    preflight: CkbReproEnvironmentPreflightResult,
    runner: CkbReproRunnerInvoker): Int64 {
    if (!preflight.ok || !preflight.startAllowed) { return 1 }
    let built = buildCkbReproRunnerArgs(reference, lock, inputs)
    if (!built[0].ok) { return 1 }
    let generation = ArrayList<String>()
    generation.add(all: built[1]); generation.add("--generate-only")
    let runRoot = Path(inputs.runsRoot).join(inputs.runId).toString()
    let generated = runner.generate(generation.toArray(), runRoot)
    if (generated[0] != 0 || !p6HashValid(generated[1])) { return 1 }
    let evaluation = ArrayList<String>()
    evaluation.add(all: built[1]); evaluation.add("--evaluate-frozen")
    evaluation.add("--test-suites"); evaluation.add("base,plus")
    runner.evaluate(evaluation.toArray(), runRoot, generated[1])
}

private func renderCkbCertifiedRunInput(lock: CkbReproEnvironmentLock): String {
    renderCkbReproEnvironmentLock(lock).replace(
        "\"runCandidateCommit\":\"${p6Escape(lock.runCandidateCommit)}\",", "")
}

private func p6ArgsIdentity(args: Array<String>): String {
    var out = ""
    for (arg in args) { out += "${arg.toArray().size}:${arg}" }
    out
}

private func p6Decode(bytes: Array<UInt8>): (String, String) {
    try { ("ok", String.fromUtf8(bytes)) }
    catch (_: Exception) { ("invalid_response_encoding", "") }
}

private func p6Success(): CkbReproContractResult {
    let out = CkbReproContractResult()
    out.ok = true
    out.diagnostic = "ok"
    out
}

private func p6Failure(diagnostic: String): CkbReproContractResult {
    let out = CkbReproContractResult()
    out.diagnostic = diagnostic
    out
}

private func p6String(object: JsonObject, key: String): String {
    object.get(key).getOrThrow().asString().getValue()
}

private func p6Int(object: JsonObject, key: String): Int64 {
    object.get(key).getOrThrow().asInt().getValue()
}

private func p6Bool(object: JsonObject, key: String): Bool {
    object.get(key).getOrThrow().asBool().getValue()
}

private func p6HashValid(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 71 || !value.startsWith("sha256:")) { return false }
    for (i in 7..runes.size) {
        let rune = runes[i]
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
    }
    true
}

private func p6CommitValid(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size != 40) { return false }
    for (rune in runes) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'a' && rune <= r'f'))) { return false }
    }
    true
}

private func p6CredentialEnvName(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.size == 0) { return false }
    for (i in 0..runes.size) {
        let rune = runes[i]
        if (i == 0 && !((rune >= r'A' && rune <= r'Z') || rune == r'_')) {
            return false
        }
        if (i > 0 && !((rune >= r'A' && rune <= r'Z') ||
            (rune >= r'0' && rune <= r'9') || rune == r'_')) {
            return false
        }
    }
    true
}

private func p6PublicProviderUrl(value: String): Bool {
    (value.startsWith("http://") || value.startsWith("https://")) &&
        !value.contains("@") &&
        !value.contains("localhost") && !value.contains("127.0.0.1")
}

private func p6ContainsSecretOrLocalPath(value: String): Bool {
    let lower = value.toAsciiLower()
    if (lower.contains("authorization") || lower.contains("bearer ") ||
        lower.contains("api_key=") || lower.contains("password=")) {
        return true
    }
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

private func p6Escape(value: String): String {
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

private func p6VerifyObservedEnvironmentSignature(path: String):
    CkbReproAttestationSignatureResult {
    let out = CkbReproAttestationSignatureResult()
    let signature = path + ".sig"
    if (!exists(Path(signature)) ||
        (try { canonicalize(Path(signature)).toString() != signature }
            catch (_: Exception) { true })) {
        out.diagnostic = "environment_attestation_missing"
        return out
    }
    let verified = p6ProbeCommand("gpg", ["--batch", "--status-fd", "1",
        "--verify", signature, path])
    if (verified[0] != 0) { return out }
    let fields = verified[1].split(" ")
    for (i in 0..fields.size) {
        if (fields[i] == "VALIDSIG" && i + 1 < fields.size &&
            p6ProbeFingerprint(fields[i + 1])) {
            out.ok = true; out.diagnostic = "ok"
            out.signingFingerprint = fields[i + 1]
            return out
        }
    }
    out
}

private func p6ProbeFingerprint(value: String): Bool {
    if (value.toRuneArray().size != 40) { return false }
    for (rune in value.runes()) {
        if (!((rune >= r'0' && rune <= r'9') ||
            (rune >= r'A' && rune <= r'F'))) { return false }
    }
    true
}

private func p6ProbeCommand(command: String, args: Array<String>):
    (Int64, String) {
    let result = ckbReproBoundedProbeCommand(command, args, 65536)
    if (result[1] != "ok") { return (127, "") }
    (result[0], result[2])
}

public func ckbReproBoundedProbeCommand(command: String, args: Array<String>,
    maxBytes: Int64): (Int64, String, String) {
    if (maxBytes < 1 || maxBytes > 1048576) {
        return (127, "environment_probe_output_limit_invalid", "")
    }
    try {
        let process = launch(command, args, stdOut: ProcessRedirect.Pipe,
            stdErr: ProcessRedirect.Pipe)
        // Drain both pipes concurrently. Waiting or draining sequentially can
        // deadlock once either child pipe reaches its kernel capacity.
        let stdoutFuture = spawn { => p6ProbeReadPipeBounded(
            process.stdOutPipe, maxBytes) }
        let stderrFuture = spawn { => p6ProbeReadPipeBounded(
            process.stdErrPipe, maxBytes) }
        let code = process.wait()
        let stdout = stdoutFuture.get()
        let stderr = stderrFuture.get()
        if (stdout[0] != "ok") { return (code, stdout[0], "") }
        if (stderr[0] != "ok") { return (code, stderr[0], "") }
        let selected = if (stdout[1] == "") { stderr[1] } else { stdout[1] }
        (code, "ok", selected)
    } catch (_: Exception) { (127, "environment_probe_unavailable", "") }
}

public func ckbReproNormalizeProbeOutput(bytes: Array<UInt8>, maxBytes: Int64):
    (String, String) {
    if (maxBytes < 1 || bytes.size > maxBytes) {
        return ("environment_probe_output_too_large", "")
    }
    let decoded = try { String.fromUtf8(bytes) }
        catch (_: Exception) {
            return ("environment_probe_invalid_encoding", "")
        }
    for (rune in decoded.runes()) {
        if ((rune >= r'\u{0000}' && rune < r'\u{0020}') &&
            rune != r'\n' && rune != r'\r' && rune != r'\t') {
            return ("environment_probe_control_character", "")
        }
    }
    let normalized = decoded.trimAscii().replace("\n", " ")
        .replace("\r", " ").replace("\t", " ")
    if (p6ContainsSecretOrLocalPath(normalized)) {
        return ("environment_probe_path_leak", "")
    }
    ("ok", normalized)
}

public func ckbReproSdkExecutableHash(bytes: Array<UInt8>): String {
    // SDK identity is the SHA-256 of the exact `cjc` executable bytes, not
    // the path, version text, directory metadata, or SDK installation root.
    p6Hash(bytes)
}

private func p6ProbeReadPipeBounded(pipe: InputStream, maxBytes: Int64):
    (String, String) {
    let captured = ArrayList<UInt8>()
    let buffer = Array<UInt8>(8192, repeat: UInt8(0))
    var total: Int64 = 0
    try {
        while (true) {
            let count = pipe.read(buffer)
            if (count < 0 || count > buffer.size) {
                return ("environment_probe_read_failed", "")
            }
            if (count == 0) { break }
            total += count
            if (total <= maxBytes) {
                for (i in 0..count) { captured.add(buffer[i]) }
            }
        }
    } catch (_: Exception) { return ("environment_probe_read_failed", "") }
    if (total > maxBytes) {
        return ("environment_probe_output_too_large", "")
    }
    ckbReproNormalizeProbeOutput(captured.toArray(), maxBytes)
}

private func p6CopyUnobservableAuthorityFields(source: CkbReproEnvironmentLock,
    target: CkbReproEnvironmentLock): Unit {
    target.modelFingerprint = source.modelFingerprint
    target.experimentGroup = source.experimentGroup
    target.ckbRequired = source.ckbRequired
    target.localDocsPolicy = source.localDocsPolicy
    target.modelEffort = source.modelEffort
    target.modelBudget = source.modelBudget
    target.timeoutSeconds = source.timeoutSeconds
    target.transportRetryBudget = source.transportRetryBudget
    target.attestationAuthorityManifestPath =
        source.attestationAuthorityManifestPath
    target.attestationAuthorityHash = source.attestationAuthorityHash
    target.compositionManifestPath = source.compositionManifestPath
    target.compositionManifestHash = source.compositionManifestHash
}

private func p6ProbeActualConfiguration(target: CkbReproEnvironmentLock,
    expectedRepositoryRoot: String,
    repositoryRootBound!: Bool = false,
    compositionManifestOverride!: String = ""): String {
    let heap = p6ProbeRequiredEnv("cjHeapSize")
    let provider = p6ProbeRequiredEnv("GLM_PROVIDER")
    let baseUrl = p6ProbeRequiredEnv("GLM_BASE_URL")
    let model = p6ProbeRequiredEnv("GLM_MODEL")
    let providerCredential = p6ProbeRequiredEnv("GLM_CREDENTIAL_ENV")
    let embedding = p6ProbeRequiredEnv("EMBEDDING_PROVIDER")
    let embeddingModel = p6ProbeRequiredEnv("EMBEDDING_MODEL")
    let embeddingDimension = p6ProbeRequiredEnv("EMBEDDING_DIMENSION")
    let embeddingCredential = p6ProbeRequiredEnv("EMBEDDING_CREDENTIAL_ENV")
    let mcpCommand = p6ProbeRequiredEnv("CKB_REPRO_MCP_COMMAND")
    let mcpTransport = p6ProbeRequiredEnv("CKB_REPRO_MCP_TRANSPORT")
    for (value in [heap, provider, baseUrl, model, providerCredential,
        embedding, embeddingModel, embeddingDimension, embeddingCredential,
        mcpCommand, mcpTransport]) {
        if (!value[0]) { return "environment_probe_unavailable" }
    }
    if (!p6ProbeCredentialPresent(providerCredential[1]) ||
        !p6ProbeCredentialPresent(embeddingCredential[1])) {
        return "environment_probe_credential_unavailable"
    }
    let dimension = try { Int64.parse(embeddingDimension[1]) }
        catch (_: Exception) { return "environment_probe_configuration_invalid" }
    let currentRepositoryRoot = if (repositoryRootBound) { "" } else {
        p6ProbeCanonicalInputPath("CKB_REPRO_REPOSITORY_ROOT", "")
    }
    let repositoryRoot = ckbReproResolveProbeRepositoryRoot(
        expectedRepositoryRoot, repositoryRootBound, currentRepositoryRoot)
    if (repositoryRoot != expectedRepositoryRoot) {
        return "environment_probe_input_changed"
    }
    let criticalPath = p6ProbeCanonicalInputPath(
        "CKB_REPRO_RUN_CRITICAL_MANIFEST", repositoryRoot)
    let promptPath = p6ProbeCanonicalInputPath(
        "CKB_REPRO_PROMPT_INPUT", repositoryRoot)
    let datasetPath = p6ProbeCanonicalInputPath(
        "CKB_REPRO_DATASET_MANIFEST", repositoryRoot)
    let authorityPath = p6ProbeCanonicalInputPath(
        "CKB_REPRO_AUTHORITY_DELIVERY", repositoryRoot)
    if (repositoryRoot == "" || criticalPath == "" || promptPath == "" ||
        datasetPath == "" || authorityPath == "") {
        return "environment_probe_input_missing"
    }
    let criticalRead = p6ReadFileBounded(criticalPath, 16 * 1024 * 1024)
    if (criticalRead[0] != "ok") { return "environment_probe_input_missing" }
    let criticalBytes = criticalRead[1]
    let critical = parseCkbRunCriticalFilesManifest(criticalBytes)
    if (!critical[0].ok) { return "environment_probe_run_critical_invalid" }
    let checkedCritical = validateCkbRunCriticalFilesManifest(
        critical[1], repositoryRoot, mode: "execution")
    if (!checkedCritical.ok || checkedCritical.treeHash == "") {
        return "environment_probe_run_critical_invalid"
    }
    let promptRead = p6ReadFileBounded(promptPath, 16 * 1024 * 1024)
    if (promptRead[0] != "ok") { return "environment_probe_input_missing" }
    let promptBytes = promptRead[1]
    let datasetRead = p6ReadFileBounded(datasetPath, 64 * 1024 * 1024)
    if (datasetRead[0] != "ok") { return "environment_probe_input_missing" }
    let datasetBytes = datasetRead[1]
    let datasetText = try { String.fromUtf8(datasetBytes) }
        catch (_: Exception) { return "environment_probe_invalid_encoding" }
    let dataset = parseCangjieHumanEvalAuthorityManifest(datasetText)
    if (!dataset.ok || dataset.datasetVersion == "") {
        return "environment_probe_dataset_invalid"
    }
    let authorityRead = p6ReadFileBounded(authorityPath, 16 * 1024 * 1024)
    if (authorityRead[0] != "ok") { return "environment_probe_input_missing" }
    let authorityBytes = authorityRead[1]
    let authority = parseCkbAuthorityDeliveryManifest(authorityBytes)
    let authorityBundlePath = p6ProbeCanonicalInputPath(
        "CKB_REPRO_AUTHORITY_BUNDLE", repositoryRoot)
    if (!authority[0].ok || authorityBundlePath == "" ||
        ckbReproProbeAuthorityDelivery(authorityBytes, datasetBytes,
            authorityBundlePath) != "ok") {
        return "environment_probe_authority_invalid"
    }
    if (!exists(Path("/usr/bin/sandbox-exec"))) {
        return "environment_probe_sandbox_unavailable"
    }
    target.serviceHeap = heap[1]
    target.glmProvider = provider[1]
    target.glmBaseUrl = baseUrl[1]
    target.glmModel = model[1]
    target.glmCredentialEnv = providerCredential[1]
    target.embeddingProvider = embedding[1]
    target.embeddingModel = embeddingModel[1]
    target.embeddingDimension = dimension
    target.embeddingCredentialEnv = embeddingCredential[1]
    target.runCriticalFilesManifestHash = checkedCritical.manifestHash
    target.runCriticalTreeHash = checkedCritical.treeHash
    target.promptHash = p6Hash(promptBytes)
    target.mcpCommand = mcpCommand[1]
    target.mcpTransport = mcpTransport[1]
    target.sandboxCapability = "macos-sandbox-exec"
    target.datasetVersion = dataset.datasetVersion
    target.authorityDeliveryHash = p6Hash(
        renderCkbAuthorityDeliveryManifest(authority[1]).toArray())
    let compositionPath = if (compositionManifestOverride == "") {
        p6ProbeCanonicalInputPath("CKB_REPRO_COMPOSITION_MANIFEST", "")
    } else { compositionManifestOverride }
    if (compositionPath == "" ||
        (compositionManifestOverride == "" && !compositionPath.endsWith(
            "/${target.compositionManifestPath}"))) {
        return "environment_probe_composition_authority_invalid"
    }
    if (!ckbReproProbeCompositionAuthority(compositionPath,
            target.compositionManifestHash)) {
        return "environment_probe_composition_authority_invalid"
    }
    "ok"
}

public func ckbReproResolveProbeRepositoryRoot(expectedRepositoryRoot: String,
    repositoryRootBound: Bool, currentEnvironmentRoot: String): String {
    if (expectedRepositoryRoot == "") { return "" }
    if (repositoryRootBound) { return expectedRepositoryRoot }
    if (currentEnvironmentRoot == expectedRepositoryRoot) {
        return expectedRepositoryRoot
    }
    ""
}

public func ckbReproProbeCompositionAuthority(path: String,
    expectedHash: String): Bool {
    let read = ckbReproReadSingleFileNoFollow(path, 64 * 1024)
    read[0] && p6Hash(read[1]) == expectedHash
}

public func ckbReproProbeAuthorityDelivery(deliveryBytes: Array<UInt8>,
    datasetBytes: Array<UInt8>, bundlePath: String,
    policy!: CkbAuthorityTrustPolicy = ckbHumanEvalAuthorityTrustPolicy(),
    backend!: CkbReleaseArchiveBackend = CkbPortableReleaseArchiveBackend()):
    String {
    if (bundlePath == "" ||
        !validateCkbExecutionAuthorityDelivery(deliveryBytes, datasetBytes,
            bundlePath, policy: policy, backend: backend).ok) {
        return "environment_probe_authority_invalid"
    }
    "ok"
}

private func p6ProbeRequiredEnv(name: String): (Bool, String) {
    let value = match (getVariable(name)) {
        case Some(item) => item
        case None => return (false, "")
    }
    if (value == "" || value.toRuneArray().size > 4096 ||
        p6ProbeUnsafeText(value)) { return (false, "") }
    (true, value)
}

private func p6ProbeCredentialPresent(name: String): Bool {
    if (!p6CredentialEnvName(name)) { return false }
    match (getVariable(name)) {
        case Some(value) => value != ""
        case None => false
    }
}

private func p6ProbeCanonicalInputPath(name: String, root: String): String {
    let input = match (getVariable(name)) {
        case Some(value) => value
        case None => return ""
    }
    if (!p6CliAbsolutePath(input) || !exists(Path(input))) { return "" }
    let canonical = try { canonicalize(Path(input)).toString() }
        catch (_: Exception) { return "" }
    if (canonical != input) { return "" }
    if (root != "" && canonical != root && !canonical.startsWith(root + "/")) {
        return ""
    }
    canonical
}

private func p6ProbeUnsafeText(value: String): Bool {
    for (rune in value.runes()) {
        if (rune < r'\u{0020}' || rune == r'\u{007f}') { return true }
    }
    p6ContainsSecretOrLocalPath(value)
}

private func p6Hash(bytes: Array<UInt8>): String {
    let digest = SHA256()
    digest.write(bytes)
    let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(p6Hex(byte / UInt8(16)))
        out.append(p6Hex(byte % UInt8(16)))
    }
    "sha256:${out.toString()}"
}

private func p6Hex(value: UInt8): String {
    if (value < UInt8(10)) { return "${value}" }
    if (value == UInt8(10)) { return "a" }
    if (value == UInt8(11)) { return "b" }
    if (value == UInt8(12)) { return "c" }
    if (value == UInt8(13)) { return "d" }
    if (value == UInt8(14)) { return "e" }
    "f"
}

private func p6CliAbsolutePath(value: String): Bool {
    value.startsWith("/") && value != "/" && !value.endsWith("/") &&
        !value.contains("//") && !value.contains("/./") &&
        !value.contains("/../") && !value.endsWith("/.") &&
        !value.endsWith("/..") && !value.contains("\\") &&
        !value.contains("\n") && !value.contains("\r") && !value.contains("\t") &&
        value.toRuneArray().size <= 4096
}

private func p6EnvironmentRepositoryRoot(environmentLockPath: String): String {
    if (!p6CliAbsolutePath(environmentLockPath)) { return "" }
    let root = Path(environmentLockPath).parent.parent.parent.toString()
    if (!p6CliAbsolutePath(root)) { return "" }
    let fixed = Path(root).join(
        "reproducibility/manifests/environment-lock.json").toString()
    if (fixed != environmentLockPath) { return "" }
    root
}

private func p6CliPreflightFailure(code: String): CkbReproEnvironmentPreflightResult {
    let out = CkbReproEnvironmentPreflightResult(); out.diagnostic = code; out
}

private func p6CliReadEnvironment(path: String):
    (CkbReproContractResult, CkbReproEnvironmentLock) {
    let read = p6ReadFileBounded(path, 16 * 1024 * 1024)
    if (read[0] != "ok") {
        return (p6Failure("environment_lock_read_failed"), CkbReproEnvironmentLock())
    }
    parseCkbReproEnvironmentLock(read[1])
}

private func p6CliReadUtf8(path: String): (String, String) {
    let read = p6ReadFileBounded(path, 16 * 1024 * 1024)
    if (read[0] != "ok") { return ("preflight_artifact_read_failed", "") }
    try { ("ok", String.fromUtf8(read[1])) }
    catch (_: Exception) { ("invalid_response_encoding", "") }
}

private func p6ReadFileBounded(path: String, limit: Int64):
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

private func p6ProbeFileHash(path: String, limit: Int64): (String, String) {
    let digest = SHA256(); var size: Int64 = 0
    try {
        try (file = File(Path(path), OpenMode.Read)) {
            let buffer = Array<UInt8>(65536, repeat: UInt8(0))
            while (true) {
                let count = file.read(buffer)
                if (count < 0 || count > buffer.size) {
                    return ("read_failed", "")
                }
                if (count == 0) { break }
                size += count
                if (size > limit) { return ("size_invalid", "") }
                digest.write(if (count == buffer.size) { buffer }
                    else { buffer[0..count].clone() })
            }
        }
        ("ok", p6DigestHash(digest))
    } catch (_: Exception) { ("read_failed", "") }
}

private func p6DigestHash(digest: SHA256): String {
    let builder = StringBuilder()
    for (byte in digest.finish()) {
        builder.append(p6Hex(byte / UInt8(16)))
        builder.append(p6Hex(byte % UInt8(16)))
    }
    "sha256:${builder.toString()}"
}

private func p6CliSafeDiagnostic(value: String): String {
    if (value == "" || value.toRuneArray().size > 128 || value.contains(":") ||
        value.contains("/") || value.contains("\\") || value.contains(" ")) {
        return "redacted_diagnostic"
    }
    value
}

private func p6CliPublic(value: String): String {
    if (value.toRuneArray().size > 128 || p6ContainsSecretOrLocalPath(value) ||
        value.contains("/") || value.contains("\\") || value.contains("\n")) {
        return "redacted"
    }
    value
}
