package cangjie_community_knowledge_base_test

import std.collection.ArrayList
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
    public var claudeCodeVersion: String = ""
    public var glmProvider: String = ""
    public var glmBaseUrl: String = ""
    public var glmModel: String = ""
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
    public init() {}
}

public class CkbReproEnvironmentPreflightResult {
    public var ok: Bool = false
    public var startAllowed: Bool = false
    public var diagnostic: String = "not_validated"
    public var environmentManifestHash: String = ""
    public var certifiedRunInputHash: String = ""
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
    public var certificationPreflightPath: String = ""
    public var certificationRunManifestPath: String = ""
    public init() {}
}

public interface CkbReproRunnerInvoker {
    func run(args: Array<String>): Int64
}

public class CkbReproPreflightCliOptions {
    public var environmentLockPath: String = ""
    public var observedEnvironmentPath: String = ""
    public var certificationPreflightPath: String = ""
    public var certificationRunManifestPath: String = ""
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
    public init() {}
}

public interface CkbReproEnvironmentProbe {
    func inspect(attested: CkbReproEnvironmentLock,
        attestedInputHash: String):
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
    public var observedEnvironmentHash: String = ""
    public var frozen: Bool = false
    public init() {}
}

public class CkbReproFilesystemEnvironmentProbe <: CkbReproEnvironmentProbe {
    private let gitRunner: CkbReproGitProbeRunner
    public init(gitRunner!: CkbReproGitProbeRunner =
        P6FilesystemGitProbeRunner()) {
        this.gitRunner = gitRunner
    }
    public func inspect(attested: CkbReproEnvironmentLock,
        attestedInputHash: String):
        CkbReproEnvironmentProbeResult {
        let out = CkbReproEnvironmentProbeResult()
        if (attestedInputHash != p6Hash(
            renderCkbReproEnvironmentLock(attested).toArray())) { return out }
        let platform = p6ProbeCommand("uname", ["-s"])
        let architecture = p6ProbeCommand("uname", ["-m"])
        let sdkPath = p6ProbeCanonicalInputPath(
            "CKB_REPRO_CJC_EXECUTABLE", "")
        if (sdkPath == "") { return out }
        let sdk = p6ProbeCommand(sdkPath, ["--version"])
        let openssl = p6ProbeCommand("openssl", ["version"])
        let repositoryRoot = p6ProbeCanonicalInputPath(
            "CKB_REPRO_REPOSITORY_ROOT", "")
        if (repositoryRoot == "") { return out }
        let commit = ckbReproProbeGitCommit(repositoryRoot, this.gitRunner)
        let claude = p6ProbeCommand("claude", ["--version"])
        let tar = p6ProbeCommand("tar", ["--version"])
        let zstd = p6ProbeCommand("zstd", ["--version"])
        let qdrantImage = p6ProbeRequiredEnv("CKB_REPRO_QDRANT_IMAGE")
        if (!qdrantImage[0]) { return out }
        let qdrant = p6ProbeCommand("docker", ["image", "inspect",
            "--format={{.Id}}", qdrantImage[1]])
        for (probe in [platform, architecture, sdk, openssl, commit,
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
        if (p6ProbeActualConfiguration(observed, repositoryRoot) != "ok") {
            return out
        }
        observed.certifiedPlatform = if (platform[1] == "Darwin") {
            "macOS"
        } else { platform[1] }
        observed.cpuArchitecture = architecture[1]
        observed.cangjieSdkVersion = sdk[1]
        observed.cangjieSdkHash = sdkHash[1]
        observed.opensslVersion = openssl[1]
        observed.runCandidateCommit = commit[1]
        observed.claudeCodeVersion = claude[1]
        observed.archiveToolVersion = "${tar[1]}|${zstd[1]}"
        observed.archiveTool = "tar+zstd"
        observed.qdrantImageDigest = qdrant[1]
        out.ok = true
        out.diagnostic = "ok"
        out.observed = observed
        out.attestedInputHash = attestedInputHash
        out
    }
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
            arg == "--certification-run-manifest") {
            if (i + 1 >= args.size) { out.diagnostic = "missing_value:${arg}"; return out }
            let value = args[i + 1]
            if (!p6CliAbsolutePath(value)) { out.diagnostic = "preflight_path_invalid"; return out }
            if (arg == "--environment-lock") {
                if (out.environmentLockPath != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.environmentLockPath = value
            } else if (arg == "--observed-environment") {
                if (out.observedEnvironmentPath != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.observedEnvironmentPath = value
            } else if (arg == "--certification-preflight") {
                if (out.certificationPreflightPath != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.certificationPreflightPath = value
            } else {
                if (out.certificationRunManifestPath != "") { out.diagnostic = "duplicate_argument:${arg}"; return out }
                out.certificationRunManifestPath = value
            }
            i += 2; continue
        }
        out.diagnostic = "unknown_argument:${arg}"; return out
    }
    if (out.environmentLockPath == "" || out.observedEnvironmentPath == "" ||
        out.certificationPreflightPath == "" ||
        out.certificationRunManifestPath == "") {
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
    let attestedInputHash = p6Hash(
        renderCkbReproEnvironmentLock(inputs.observed).toArray())
    let actual = try { probe.inspect(inputs.observed, attestedInputHash) }
        catch (_: Exception) { return p6CliPreflightFailure(
            "environment_probe_unavailable") }
    if (!actual.ok) { return p6CliPreflightFailure(actual.diagnostic) }
    if (actual.attestedInputHash != attestedInputHash) {
        return p6CliPreflightFailure("environment_attestation_input_mismatch")
    }
    runCkbReproEnvironmentPreflight(inputs.expected, actual.observed,
        inputs.heap, inputs.certificationPreflightJson,
        inputs.certificationRunManifestJson)
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
    if (!authority.frozen ||
        !p6ProbeFingerprint(authority.signingFingerprint) ||
        !p6HashValid(authority.observedEnvironmentHash)) {
        return p6CliPreflightFailure(
            "environment_attestation_authority_unavailable")
    }
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
    if (p6Hash(renderCkbReproEnvironmentLock(observed[1]).toArray()) !=
        authority.observedEnvironmentHash) {
        return p6CliPreflightFailure("environment_attestation_input_mismatch")
    }
    let attestation = p6VerifyObservedEnvironmentAttestation(
        options.observedEnvironmentPath, authority.signingFingerprint)
    if (attestation != "ok") { return p6CliPreflightFailure(attestation) }
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
    executeCkbReproPreflightCliAdapterWithProbe(options, inputs,
        CkbReproFilesystemEnvironmentProbe())
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
        "certified input hash: ${result.certifiedRunInputHash}\n"
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
        "\"certifiedRunInputHash\":\"${p6Escape(result.certifiedRunInputHash)}\"}"
}

public func parseCkbReproEnvironmentLock(bytes: Array<UInt8>):
    (CkbReproContractResult, CkbReproEnvironmentLock) {
    let lock = CkbReproEnvironmentLock()
    let decoded = p6Decode(bytes)
    if (decoded[0] != "ok") { return (p6Failure(decoded[0]), lock) }
    try {
        let object = JsonValue.fromStr(decoded[1]).asObject()
        if (object.size() != 36) {
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
        lock.claudeCodeVersion = p6String(object, "claudeCodeVersion")
        lock.glmProvider = p6String(object, "glmProvider")
        lock.glmBaseUrl = p6String(object, "glmBaseUrl")
        lock.glmModel = p6String(object, "glmModel")
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
            lock.runCriticalTreeHash, lock.promptHash, lock.authorityDeliveryHash]) {
            if (!p6HashValid(hash)) { return p6Failure("environment_hash_invalid") }
        }
        if (!lock.qdrantImageDigest.startsWith("sha256:") ||
            !p6CommitValid(lock.runCandidateCommit)) {
            return p6Failure("environment_runtime_identity_invalid")
        }
    } else if (mode == "execution") {
        return p6Failure("environment_identity_not_frozen")
    }
    if (lock.serviceHeap != "4GB") {
        return p6Failure("environment_heap_contract_invalid")
    }
    if (lock.glmProvider == "" || lock.glmModel != "GLM-5.2" ||
        !p6PublicHttpsUrl(lock.glmBaseUrl) ||
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
    "\"claudeCodeVersion\":\"${p6Escape(lock.claudeCodeVersion)}\"," +
    "\"glmProvider\":\"${p6Escape(lock.glmProvider)}\"," +
    "\"glmBaseUrl\":\"${p6Escape(lock.glmBaseUrl)}\"," +
    "\"glmModel\":\"${p6Escape(lock.glmModel)}\"," +
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
    "\"authorityDeliveryHash\":\"${p6Escape(lock.authorityDeliveryHash)}\"}"
}

public func renderCkbProviderTemplate(lock: CkbReproEnvironmentLock): String {
    "GLM_PROVIDER=${lock.glmProvider}\n" +
    "GLM_BASE_URL=${lock.glmBaseUrl}\n" +
    "GLM_MODEL=${lock.glmModel}\n" +
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
        "--model-fingerprint", "claude-code-${lock.glmModel}",
        "--run-id", inputs.runId, "--repo-root", inputs.repoRoot,
        "--runs-root", inputs.runsRoot, "--dataset-root", inputs.datasetRoot,
        "--manifest", inputs.authorityManifestPath, "--ckb-bin", inputs.ckbBin,
        "--config", inputs.ckbConfig, "--ckb-store", inputs.ckbStore,
        "--ckb-http-base", inputs.ckbHttpBase, "--claude-bin", inputs.claudeBin,
        "--docs-root", inputs.docsRoot, "--case-start", "0", "--case-end", "163",
        "--groups", lock.experimentGroup, "--transport-retries",
        "${lock.transportRetryBudget}", "--model-timeout-seconds",
        "${lock.timeoutSeconds}", "--model-effort", lock.modelEffort,
        "--model-max-budget-usd", lock.modelBudget,
        "--expected-model-version", lock.glmModel,
        "--provider-identity-hash", inputs.providerIdentityHash,
        "--provider-identity-artifact", inputs.providerIdentityArtifactPath,
        "--frozen-candidate-manifest", inputs.frozenCandidateManifestPath,
        "--certification-preflight", inputs.certificationPreflightPath,
        "--certification-run-manifest", inputs.certificationRunManifestPath
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
    runner.run(built[1])
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

private func p6PublicHttpsUrl(value: String): Bool {
    value.startsWith("https://") && !value.contains("@") &&
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

private func p6VerifyObservedEnvironmentAttestation(path: String,
    fingerprint: String): String {
    let signature = path + ".sig"
    if (!exists(Path(signature)) ||
        (try { canonicalize(Path(signature)).toString() != signature }
            catch (_: Exception) { true })) {
        return "environment_attestation_missing"
    }
    if (!p6ProbeFingerprint(fingerprint)) {
        return "environment_attestation_authority_unavailable"
    }
    let verified = p6ProbeCommand("gpg", ["--batch", "--status-fd", "1",
        "--verify", signature, path])
    if (verified[0] != 0 ||
        !verified[1].contains("VALIDSIG ${fingerprint} ")) {
        return "environment_attestation_signature_invalid"
    }
    "ok"
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
    target.experimentGroup = source.experimentGroup
    target.ckbRequired = source.ckbRequired
    target.localDocsPolicy = source.localDocsPolicy
    target.modelEffort = source.modelEffort
    target.modelBudget = source.modelBudget
    target.timeoutSeconds = source.timeoutSeconds
    target.transportRetryBudget = source.transportRetryBudget
}

private func p6ProbeActualConfiguration(target: CkbReproEnvironmentLock,
    expectedRepositoryRoot: String): String {
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
    let repositoryRoot = p6ProbeCanonicalInputPath(
        "CKB_REPRO_REPOSITORY_ROOT", "")
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
    if (!authority[0].ok || !selectCkbAuthorityDeliveryMode(authority[1]).ok) {
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
